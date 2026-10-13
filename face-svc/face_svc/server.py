"""
The HTTP face of the analyzer. Loopback only, stateless, quiet.

    POST /analyze   raw image bytes  -> {width, height, faces: [...]}
    GET  /health                     -> {ok, models: {file: sha256}}

Nothing is written to disk, and the access log carries method, path, status
and timing only — never a byte of an image, an embedding or a score. These are
photographs of people's faces and numbers derived from them; a log that keeps
them is a biometric database nobody meant to build.

Run:  python -m face_svc.server --models /opt/up/face-models
Env:  FACE_SVC_HOST (default 127.0.0.1), FACE_SVC_PORT (default 8091),
      FACE_SVC_MODELS (default ./models)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from .analyzer import DETECTOR_FILE, RECOGNIZER_FILE, Analyzer, BadImage

MAX_BODY = 8 * 1024 * 1024


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def make_handler(analyzer: Analyzer, model_hashes: dict):
    class Handler(BaseHTTPRequestHandler):
        server_version = "up-face/1"
        sys_version = ""

        def _send(self, status: int, body: dict):
            payload = json.dumps(body, separators=(",", ":")).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)

        def do_GET(self):
            if self.path == "/health":
                self._send(200, {"ok": True, "models": model_hashes})
            else:
                self._send(404, {"error": "not_found"})

        def do_POST(self):
            if self.path != "/analyze":
                self._send(404, {"error": "not_found"})
                return
            length = self.headers.get("Content-Length")
            if length is None:
                self._send(411, {"error": "length_required"})
                return
            try:
                n = int(length)
            except ValueError:
                self._send(400, {"error": "bad_length"})
                return
            if n <= 0:
                self._send(400, {"error": "empty_body"})
                return
            if n > MAX_BODY:
                # Do not read it. Closing is cheaper than draining 50 MB.
                self.close_connection = True
                self._send(413, {"error": "too_large"})
                return
            data = self.rfile.read(n)
            try:
                result = analyzer.analyze(data)
            except BadImage:
                self._send(400, {"error": "bad_image"})
                return
            except Exception:  # noqa: BLE001 — a model error is a 500, not a crash
                self._send(500, {"error": "analyze_failed"})
                return
            self._send(200, result)

        def log_message(self, fmt, *args):  # noqa: D401
            # Replaced by log_request below; silence the default line, which
            # would include the client address and the raw request line.
            pass

        def log_request(self, code="-", size="-"):
            ms = (time.perf_counter() - self._t0) * 1000 if hasattr(self, "_t0") else 0
            sys.stderr.write(f"[face] {self.command} {self.path} {code} {ms:.0f}ms\n")

        def handle_one_request(self):
            self._t0 = time.perf_counter()
            super().handle_one_request()

    return Handler


def build_server(models_dir: str, host: str, port: int) -> ThreadingHTTPServer:
    models = Path(models_dir)
    analyzer = Analyzer(models)
    hashes = {f: _sha256(models / f) for f in (DETECTOR_FILE, RECOGNIZER_FILE)}
    srv = ThreadingHTTPServer((host, port), make_handler(analyzer, hashes))
    srv.daemon_threads = True
    return srv


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="UP face analysis service")
    p.add_argument("--models", default=os.environ.get("FACE_SVC_MODELS", "models"))
    p.add_argument("--host", default=os.environ.get("FACE_SVC_HOST", "127.0.0.1"))
    p.add_argument("--port", type=int, default=int(os.environ.get("FACE_SVC_PORT", "8091")))
    a = p.parse_args(argv)
    srv = build_server(a.models, a.host, a.port)
    sys.stderr.write(f"[face] listening on {a.host}:{a.port}\n")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
