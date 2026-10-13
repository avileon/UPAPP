"""
Faces in, numbers out.

This module answers one question about one image: where are the faces, which
way is each one turned, how sharp is it, and what is its embedding. It decides
nothing. Whether a face is "the same person", "turned far enough" or "sharp
enough" is a product rule, and product rules live in the Node server next to
the thresholds that tune them. Keeping the two apart means a threshold can be
changed without touching a model, and a model can be swapped without anybody
re-deriving what the thresholds meant.

Models (OpenCV Zoo, both licensed for commercial use):
  - YuNet  (MIT)        detection + 5 landmarks
  - SFace  (Apache-2.0) 128-d identity embedding

InsightFace's pretrained packs are deliberately *not* used: their weights are
licensed for non-commercial research only, and UP is a product.
"""

from __future__ import annotations

import base64
import threading
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

DETECTOR_FILE = "face_detection_yunet_2023mar.onnx"
RECOGNIZER_FILE = "face_recognition_sface_2021dec.onnx"

# Longest side the detector ever sees. Phone photos arrive at 4000px; YuNet
# does not get more accurate past this, only slower.
MAX_SIDE = 1280

# Low on purpose. The service reports what it found with a confidence; the
# caller decides what confidence is enough. 0.6 only removes the obvious junk.
DETECTION_FLOOR = 0.6

MAX_FACES = 10

# Blur is measured on the face rescaled to this width, so the number means the
# same thing whether the face filled the frame or was a speck in a group shot.
BLUR_FACE_WIDTH = 112


class BadImage(ValueError):
    """The bytes are not an image OpenCV can decode."""


@dataclass(frozen=True)
class Face:
    box: tuple[int, int, int, int]
    score: float
    landmarks: tuple[tuple[float, float], ...]
    yaw: float
    pitch: float
    blur: float
    embedding: np.ndarray  # float32[128], L2-normalised

    def to_json(self) -> dict:
        return {
            "box": list(self.box),
            "score": round(self.score, 4),
            "landmarks": [[round(x, 1), round(y, 1)] for x, y in self.landmarks],
            "yaw": round(self.yaw, 4),
            "pitch": round(self.pitch, 4),
            "blur": round(self.blur, 1),
            "embedding": base64.b64encode(
                self.embedding.astype("<f4").tobytes()
            ).decode("ascii"),
        }


def head_pose(landmarks) -> tuple[float, float]:
    """
    Yaw and pitch, estimated from YuNet's five points.

    Not angles — ratios, which is all the server needs to tell "straight" from
    "turned". Both are normalised by the distance between the eyes, so they do
    not depend on how far the face is from the camera.

    yaw   = horizontal offset of the nose tip from the midpoint of the eyes.
            0 is frontal. Positive means the nose points toward the *right
            edge of the image* — image coordinates, never "the person's
            right", because the client may or may not mirror its preview and
            the raw frame is the only thing both sides agree on.
    pitch = vertical offset of the nose below the eyes. Larger when the head
            tips down, smaller when it tips up. There is no universal zero;
            compare against the same person's frontal frame.
    """
    pts = np.asarray(landmarks, dtype=np.float64).reshape(5, 2)
    eye_a, eye_b, nose = pts[0], pts[1], pts[2]
    mid = (eye_a + eye_b) / 2.0
    interocular = float(np.linalg.norm(eye_a - eye_b))
    if interocular < 1e-6:
        return 0.0, 0.0
    yaw = float(np.clip((nose[0] - mid[0]) / interocular, -1.0, 1.0))
    pitch = float(np.clip((nose[1] - mid[1]) / interocular, -1.0, 2.0))
    return yaw, pitch


def decode(data: bytes) -> np.ndarray:
    if not data:
        raise BadImage("empty")
    buf = np.frombuffer(data, dtype=np.uint8)
    # IMREAD_COLOR honours EXIF orientation, which matters: a phone photo
    # stored sideways would otherwise read as a face turned ninety degrees.
    img = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    if img is None or img.size == 0:
        raise BadImage("undecodable")
    return img


def shrink(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    side = max(h, w)
    if side <= MAX_SIDE:
        return img
    f = MAX_SIDE / side
    return cv2.resize(img, (round(w * f), round(h * f)), interpolation=cv2.INTER_AREA)


def _blur(img: np.ndarray, box) -> float:
    x, y, w, h = box
    H, W = img.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 - x0 < 8 or y1 - y0 < 8:
        return 0.0
    crop = cv2.cvtColor(img[y0:y1, x0:x1], cv2.COLOR_BGR2GRAY)
    scale = BLUR_FACE_WIDTH / crop.shape[1]
    crop = cv2.resize(crop, (BLUR_FACE_WIDTH, max(8, round(crop.shape[0] * scale))))
    return float(cv2.Laplacian(crop, cv2.CV_64F).var())


class Analyzer:
    """
    Holds both networks. One instance per process.

    OpenCV's DNN objects are not safe to call from two threads at once, and the
    detector's input size is mutable state set per image. A lock is the honest
    answer: the box has two cores, an image takes ~100 ms, and a queue of a
    few requests is fine for the traffic this sees.
    """

    def __init__(self, models_dir: str | Path):
        models_dir = Path(models_dir)
        det = models_dir / DETECTOR_FILE
        rec = models_dir / RECOGNIZER_FILE
        for f in (det, rec):
            if not f.is_file():
                raise FileNotFoundError(f"model missing: {f}")
        self._detector = cv2.FaceDetectorYN.create(
            str(det), "", (320, 320), DETECTION_FLOOR, 0.3, 5000
        )
        self._recognizer = cv2.FaceRecognizerSF.create(str(rec), "")
        self._lock = threading.Lock()

    def analyze(self, data: bytes) -> dict:
        img = shrink(decode(data))
        h, w = img.shape[:2]
        with self._lock:
            faces = self._faces(img)
        return {"width": w, "height": h, "faces": [f.to_json() for f in faces]}

    def _faces(self, img: np.ndarray) -> list[Face]:
        h, w = img.shape[:2]
        self._detector.setInputSize((w, h))
        _, rows = self._detector.detect(img)
        if rows is None:
            return []
        # Largest first: in a group photo the person holding the phone is
        # usually the biggest face, and callers that look at faces[0] get the
        # sensible one.
        rows = sorted(rows, key=lambda r: r[2] * r[3], reverse=True)[:MAX_FACES]
        out = []
        for row in rows:
            box = tuple(int(round(v)) for v in row[0:4])
            landmarks = tuple(
                (float(row[4 + 2 * i]), float(row[5 + 2 * i])) for i in range(5)
            )
            aligned = self._recognizer.alignCrop(img, row)
            feat = self._recognizer.feature(aligned).reshape(-1).astype(np.float32)
            norm = float(np.linalg.norm(feat))
            if norm > 0:
                feat = feat / norm
            yaw, pitch = head_pose(landmarks)
            out.append(
                Face(
                    box=box,
                    score=float(row[14]),
                    landmarks=landmarks,
                    yaw=yaw,
                    pitch=pitch,
                    blur=_blur(img, box),
                    embedding=feat,
                )
            )
        return out


def cosine(a: np.ndarray, b: np.ndarray) -> float:
    """Reference implementation of what the Node side does. Tests use it."""
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))


def embedding_from_b64(s: str) -> np.ndarray:
    return np.frombuffer(base64.b64decode(s), dtype="<f4")
