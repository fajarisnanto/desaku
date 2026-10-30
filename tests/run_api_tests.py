"""Run the real Godot HTTP client against a local, disposable mock server.
Uses only Python's standard library; never reads real credentials or contacts a provider.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

counts = {"valid": 0, "requests": 0}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        counts["requests"] += 1
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
            assert body["model"] == "mock-village"
            assert body["stream"] is False

            assert body["reasoning_effort"] == "none"
            assert "Creative" in body["messages"][0]["content"]
            planning = self.path.startswith("/plan")
            assert body["messages"][1]["content"] == ("Plan an office improvement." if planning else "A neighbor says hello.")
            assert body["max_tokens"] == (420 if planning else 96)
        except (ValueError, KeyError, AssertionError):
            self.reply(400, {"error": "Invalid test request"})
            return
        if self.headers.get("Authorization") != "Bearer test-session-key":
            self.reply(401, {"error": "Unauthorized"})
            return
        if self.path in ("/slow", "/plan-slow"):
            time.sleep(2)
        if planning:
            content = json.dumps({"action":"build","item":"art","slot":0,"reason":"Design workspace"})
            if self.path == "/plan-invalid": content = "not json"
            if self.path == "/plan-malformed": content = "[]"
            self.reply(200, {"choices":[{"message":{"content":content}}]})
            return
        if self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/v1/chat/completions")
            self.end_headers()
        elif self.path == "/malformed":
            self.reply(200, {"choices": "invalid"})
        elif self.path == "/empty":
            self.reply(200, {"choices": [{"message": {"content": " "}}]})
        else:
            if self.path == "/v1/chat/completions":
                counts["valid"] += 1
            self.reply(200, {"choices": [{"message": {"content": "Hello, neighbor! Shall we take a walk?"}}]})

    def reply(self, status, data):
        encoded = json.dumps(data).encode()
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass

parser = argparse.ArgumentParser()
parser.add_argument("--godot", default="Godot_v4.7.2-stable_win64_console.exe")
args = parser.parse_args()
project = Path(__file__).resolve().parent.parent
server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
env = dict(os.environ, VILLAGE_TEST_BASE=f"http://127.0.0.1:{server.server_port}")
try:
    result = subprocess.run([args.godot, "--headless", "--path", str(project), "--script", "res://tests/test_api.gd"], env=env, timeout=45)
    assert result.returncode == 0, f"Godot tests failed: {result.returncode}"
    assert counts == {"valid": 1, "requests": 10}, counts
    print("MOCK SERVER: PASS | ten dialogue/planning requests; no redirect or unauthorized extra calls")
finally:
    server.shutdown()
    server.server_close()
