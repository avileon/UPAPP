"""The HTTP layer: routes, limits, and what it refuses to log."""

import http.client
import json
import threading
from pathlib import Path

import pytest

from face_svc import server as srv_mod
from face_svc.server import MAX_BODY, build_server

HERE = Path(__file__).parent
MODELS = HERE.parent / "models"
FIX = HERE / "fixtures"


@pytest.fixture(scope="module")
def svc():
    s = build_server(str(MODELS), "127.0.0.1", 0)
    t = threading.Thread(target=s.serve_forever, daemon=True)
    t.start()
    yield s.server_address[1]
    s.shutdown()


def call(port, method, path, body=None, headers=None):
    c = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
    c.request(method, path, body=body, headers=headers or {})
    r = c.getresponse()
    data = r.read()
    c.close()
    return r.status, json.loads(data) if data else None


def test_health_reports_model_hashes(svc):
    status, body = call(svc, "GET", "/health")
    assert status == 200 and body["ok"] is True
    assert set(body["models"]) == {
        "face_detection_yunet_2023mar.onnx",
        "face_recognition_sface_2021dec.onnx",
    }
    assert all(len(h) == 64 for h in body["models"].values())


def test_analyze(svc):
    status, body = call(svc, "POST", "/analyze", (FIX / "collins.jpg").read_bytes())
    assert status == 200
    assert len(body["faces"]) == 1
    assert {"box", "score", "landmarks", "yaw", "pitch", "blur", "embedding"} <= set(body["faces"][0])


def test_bad_image(svc):
    assert call(svc, "POST", "/analyze", b"hello") == (400, {"error": "bad_image"})


def test_empty_body(svc):
    status, body = call(svc, "POST", "/analyze", b"")
    assert status == 400


def test_too_large_is_refused_without_reading(svc):
    c = http.client.HTTPConnection("127.0.0.1", svc, timeout=10)
    c.putrequest("POST", "/analyze")
    c.putheader("Content-Length", str(MAX_BODY + 1))
    c.endheaders()
    r = c.getresponse()
    assert r.status == 413
    c.close()


def test_unknown_routes(svc):
    assert call(svc, "GET", "/analyze")[0] == 404
    assert call(svc, "POST", "/health", b"x")[0] == 404


def test_log_carries_no_biometrics(svc, capfd):
    call(svc, "POST", "/analyze", (FIX / "collins.jpg").read_bytes())
    err = capfd.readouterr().err
    assert "[face] POST /analyze 200" in err
    for leak in ("embedding", "score", "yaw", "landmarks", "127.0.0.1 -"):
        assert leak not in err


def test_defaults_bind_loopback():
    # The port is the only access control this service has.
    import inspect

    src = inspect.getsource(srv_mod.main)
    assert '"FACE_SVC_HOST", "127.0.0.1"' in src
