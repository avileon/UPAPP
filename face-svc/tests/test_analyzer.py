"""
Real models, real photographs. Fixtures are public-domain NASA portraits plus
two images bundled with scikit-image — see fixtures/SOURCES.md.

The identity thresholds asserted here are the ones the spec proposes
(accept >= 0.40, reject < 0.30). If a model change breaks these, the Node-side
thresholds need re-deriving too — that is the point of asserting them.
"""

from pathlib import Path

import cv2
import numpy as np
import pytest

from face_svc.analyzer import (
    Analyzer,
    BadImage,
    MAX_SIDE,
    cosine,
    embedding_from_b64,
    head_pose,
)

HERE = Path(__file__).parent
FIX = HERE / "fixtures"
MODELS = HERE.parent / "models"


@pytest.fixture(scope="session")
def analyzer():
    return Analyzer(MODELS)


def read(name: str) -> bytes:
    return (FIX / name).read_bytes()


def emb(analyzer, name: str) -> np.ndarray:
    faces = analyzer.analyze(read(name))["faces"]
    assert len(faces) == 1, f"{name}: expected one face, got {len(faces)}"
    return embedding_from_b64(faces[0]["embedding"])


# -- detection ---------------------------------------------------------------

def test_no_face(analyzer):
    assert analyzer.analyze(read("no_face_cat.jpg"))["faces"] == []


@pytest.mark.parametrize("name", ["armstrong_a.jpg", "armstrong_b.jpg", "collins.jpg", "jemison.jpg"])
def test_one_confident_face(analyzer, name):
    faces = analyzer.analyze(read(name))["faces"]
    assert len(faces) == 1
    f = faces[0]
    assert f["score"] >= 0.9
    assert len(f["landmarks"]) == 5
    assert len(embedding_from_b64(f["embedding"])) == 128


def test_two_people_two_faces(analyzer):
    a = cv2.imread(str(FIX / "armstrong_b.jpg"))
    b = cv2.imread(str(FIX / "jemison.jpg"))
    h = min(a.shape[0], b.shape[0])
    side = np.hstack([a[:h], b[:h]])
    ok, buf = cv2.imencode(".jpg", side)
    faces = analyzer.analyze(buf.tobytes())["faces"]
    assert len(faces) == 2
    # Largest first.
    areas = [f["box"][2] * f["box"][3] for f in faces]
    assert areas == sorted(areas, reverse=True)


def test_large_image_is_shrunk(analyzer):
    img = cv2.imread(str(FIX / "armstrong_b.jpg"))
    big = cv2.resize(img, (img.shape[1] * 4, img.shape[0] * 4))
    ok, buf = cv2.imencode(".jpg", big)
    r = analyzer.analyze(buf.tobytes())
    assert max(r["width"], r["height"]) == MAX_SIDE
    assert len(r["faces"]) == 1


def test_png_accepted(analyzer):
    img = cv2.imread(str(FIX / "collins.jpg"))
    ok, buf = cv2.imencode(".png", img)
    assert len(analyzer.analyze(buf.tobytes())["faces"]) == 1


@pytest.mark.parametrize("data", [b"", b"not an image", b"\xff\xd8\xff\x00garbage"])
def test_bad_image(analyzer, data):
    with pytest.raises(BadImage):
        analyzer.analyze(data)


# -- identity ----------------------------------------------------------------

def test_same_person_different_photos_matches(analyzer):
    assert cosine(emb(analyzer, "armstrong_a.jpg"), emb(analyzer, "armstrong_b.jpg")) >= 0.40


@pytest.mark.parametrize(
    "a,b",
    [
        ("armstrong_a.jpg", "jemison.jpg"),
        ("armstrong_a.jpg", "collins.jpg"),
        ("armstrong_b.jpg", "collins.jpg"),
        ("collins.jpg", "jemison.jpg"),
    ],
)
def test_different_people_do_not_match(analyzer, a, b):
    assert cosine(emb(analyzer, a), emb(analyzer, b)) < 0.30


def test_embedding_is_normalised(analyzer):
    e = emb(analyzer, "collins.jpg")
    assert abs(float(np.linalg.norm(e)) - 1.0) < 1e-4


def test_reencoded_photo_is_near_identical(analyzer):
    # The "same frame sent twice" guard in the spec relies on this being ~1.
    img = cv2.imread(str(FIX / "armstrong_b.jpg"))
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 70])
    again = embedding_from_b64(analyzer.analyze(buf.tobytes())["faces"][0]["embedding"])
    assert cosine(emb(analyzer, "armstrong_b.jpg"), again) > 0.95


# -- head pose ---------------------------------------------------------------

def test_frontal_portraits_are_centred(analyzer):
    for name in ["armstrong_a.jpg", "armstrong_b.jpg", "jemison.jpg", "collins.jpg"]:
        f = analyzer.analyze(read(name))["faces"][0]
        assert abs(f["yaw"]) < 0.12, name


def _pts(nose_x, nose_y=60.0):
    # eyes at (40,40) and (80,40): interocular 40, midpoint x=60
    return [(40, 40), (80, 40), (nose_x, nose_y), (45, 80), (75, 80)]


def test_yaw_sign_is_image_coordinates():
    yaw_right, _ = head_pose(_pts(nose_x=72))  # nose toward image right
    yaw_left, _ = head_pose(_pts(nose_x=48))
    assert yaw_right == pytest.approx(0.3)
    assert yaw_left == pytest.approx(-0.3)


def test_yaw_is_scale_invariant():
    small = head_pose(_pts(nose_x=72))
    big = head_pose([(x * 5, y * 5) for x, y in _pts(nose_x=72)])
    assert small == pytest.approx(big)


def test_pitch_moves_with_nose():
    _, down = head_pose(_pts(60, nose_y=70))
    _, up = head_pose(_pts(60, nose_y=50))
    assert down > up


def test_degenerate_landmarks():
    assert head_pose([(10, 10)] * 5) == (0.0, 0.0)


# -- blur --------------------------------------------------------------------

def test_blurred_photo_scores_lower(analyzer):
    img = cv2.imread(str(FIX / "armstrong_b.jpg"))
    sharp = analyzer.analyze(read("armstrong_b.jpg"))["faces"][0]["blur"]
    ok, buf = cv2.imencode(".jpg", cv2.GaussianBlur(img, (0, 0), 3))
    faces = analyzer.analyze(buf.tobytes())["faces"]
    assert faces, "still detectable when blurred"
    assert faces[0]["blur"] < sharp / 3
