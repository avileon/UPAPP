# face-svc

The face-analysis sidecar for UP. One endpoint, loopback only, stateless.
Spec: [`docs/FACE_VERIFICATION_SPEC.md`](../docs/FACE_VERIFICATION_SPEC.md).

```
POST /analyze   image bytes (JPEG/PNG, ≤ 8 MB) → { width, height, faces: [...] }
GET  /health                                   → { ok, models: { file: sha256 } }
```

Each face: `box`, `score`, 5 `landmarks`, `yaw`, `pitch`, `blur`, and a
base64 float32[128] `embedding` (L2-normalised — cosine is a dot product).

It reports; it does not decide. Thresholds (what counts as the same person,
turned enough, sharp enough) live in the Node server.

## Models

| Model | Job | License |
|---|---|---|
| YuNet 2023mar | detection + 5 landmarks | MIT |
| SFace 2021dec | 128-d identity embedding | Apache-2.0 |

Pinned by sha256 in `models.lock`; `fetch-models.sh` refuses anything else.
InsightFace weights are **not** used — they are non-commercial only.

Measured: ~85 ms for a 640px photo, ~260 ms at 1280px, one core.
Same person across two different photos: cosine ≈ 0.62. Different people: ≤ 0.20.

## Run locally

```bash
cd face-svc
./fetch-models.sh
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest -q
.venv/bin/python -m face_svc.server        # 127.0.0.1:8091
```

## On the server

Installed by `server/deploy/face-setup.sh` (run from `provision.sh` and
`update.sh`): venv in `/opt/up/face-venv`, models in `/opt/up/face-models`,
systemd unit `up-face.service`. Logs: `journalctl -u up-face`.

The access log is method, path, status and milliseconds — never an image, a
score or an embedding.
