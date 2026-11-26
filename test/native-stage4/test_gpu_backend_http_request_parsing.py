"""Verify GPU backend reads full HTTP bodies and rejects prompt-parse fallback paths."""
import json
import os
import socket
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "artifact/build/s_runner/NeurX"
BACKEND_IR = ROOT / "artifact/build/production_s_inference/gpu_backend_enhanced.ir"
RUNTIME_LIB = ROOT / "artifact/build/s_gpu_runtime/libneurx_s_cuda.so"
MODEL = Path("/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
HOST = "127.0.0.1"
PORT = 18084


def _wait_health(timeout_s: float = 30.0) -> None:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            with urlopen(f"http://{HOST}:{PORT}/health", timeout=1.0) as response:
                body = json.loads(response.read().decode("utf-8", "replace"))
            if body.get("status") == "ok":
                return
        except Exception:
            pass
        time.sleep(0.1)
    raise TimeoutError("backend health timeout")


def _http_request_bytes(payload: bytes) -> tuple[int, bytes]:
    with socket.create_connection((HOST, PORT), timeout=5.0) as conn:
        conn.sendall(payload)
        chunks = []
        while True:
            data = conn.recv(65536)
            if not data:
                break
            chunks.append(data)
    raw = b"".join(chunks)
    status = int(raw.split(b" ", 2)[1])
    body = raw.split(b"\r\n\r\n", 1)[1] if b"\r\n\r\n" in raw else b""
    return status, body


def _split_stream_generate(prompt: str, max_new_tokens: int = 64) -> tuple[int, list[dict]]:
    body = json.dumps(
        {
            "action": "generate",
            "prompt": prompt,
            "stream": True,
            "max_new_tokens": max_new_tokens,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    request = (
        f"POST /v1/generate HTTP/1.1\r\n"
        f"Host: {HOST}:{PORT}\r\n"
        "Connection: close\r\n"
        "Content-Type: application/json\r\n"
        f"Content-Length: {len(body)}\r\n\r\n"
    ).encode("utf-8")

    split = max(1, len(body) // 3)
    with socket.create_connection((HOST, PORT), timeout=5.0) as conn:
        conn.sendall(request + body[:split])
        time.sleep(0.05)
        conn.sendall(body[split:])
        chunks = []
        while True:
            data = conn.recv(65536)
            if not data:
                break
            chunks.append(data)
    raw = b"".join(chunks)
    status = int(raw.split(b" ", 2)[1])
    response_body = raw.split(b"\r\n\r\n", 1)[1].decode("utf-8", "replace")
    events = [json.loads(line) for line in response_body.splitlines() if line.strip()]
    return status, events


class GpuBackendHttpParsing(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not (RUNNER.is_file() and BACKEND_IR.is_file() and RUNTIME_LIB.is_file()):
            raise unittest.SkipTest("required backend artifacts are missing")
        if not MODEL.is_dir():
            raise unittest.SkipTest("qwen2.5 model directory is missing")

        cls.tempdir = tempfile.TemporaryDirectory(prefix="neurx-gpu-http-")
        cls.log_path = Path(cls.tempdir.name) / "backend.log"
        environment = os.environ.copy()
        environment.update(
            {
                "NEURX_ROOT": str(ROOT),
                "NEURX_MODEL_DIR": str(MODEL),
                "NEURX_INFER_DEVICE": "gpu",
                "NEURX_CUDA_DEVICE": "0",
                "NEURX_S_HOST": HOST,
                "NEURX_S_PORT": str(PORT),
                "NEURX_CHAT_MAX_NEW_TOKENS": "1024",
                "LD_PRELOAD": str(RUNTIME_LIB),
            }
        )
        cls.log_file = cls.log_path.open("w")
        cls.backend = subprocess.Popen(
            [str(RUNNER), str(BACKEND_IR)],
            stdout=cls.log_file,
            stderr=subprocess.STDOUT,
            env=environment,
        )
        _wait_health()

    @classmethod
    def tearDownClass(cls) -> None:
        if hasattr(cls, "backend") and cls.backend.poll() is None:
            cls.backend.terminate()
            try:
                cls.backend.wait(timeout=5)
            except subprocess.TimeoutExpired:
                cls.backend.kill()
                cls.backend.wait(timeout=5)
        if hasattr(cls, "log_file"):
            cls.log_file.close()
        if hasattr(cls, "tempdir"):
            cls.tempdir.cleanup()

    def test_chinese_stream_request_from_split_tcp_body(self) -> None:
        prompt = (
            "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n"
            "<|im_start|>user\n请用中文解释什么是大语言模型，并举一个实际应用例子。<|im_end|>\n"
            "<|im_start|>assistant\n"
        )
        status, events = _split_stream_generate(prompt, 64)
        self.assertEqual(status, 200)
        self.assertTrue(events, "expected NDJSON events")
        self.assertTrue(any(event.get("done") is False for event in events), events)
        self.assertTrue(any(event.get("done") is True for event in events), events)
        self.assertTrue(
            any(event.get("generated_tokens", 0) > 0 for event in events if event.get("done") is True),
            events,
        )

    def test_multiturn_stream_request_from_split_tcp_body(self) -> None:
        prompt = (
            "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n"
            "<|im_start|>user\n我的项目名称是 NeurX，请记住这个名称。<|im_end|>\n"
            "<|im_start|>assistant\n好的，我记住了。<|im_end|>\n"
            "<|im_start|>user\n刚才告诉你的项目名称是什么？请用中文回答。<|im_end|>\n"
            "<|im_start|>assistant\n"
        )
        status, events = _split_stream_generate(prompt, 64)
        self.assertEqual(status, 200)
        self.assertTrue(events, "expected NDJSON events")
        self.assertTrue(any(event.get("done") is False for event in events), events)
        self.assertTrue(any(event.get("done") is True for event in events), events)

    def test_missing_prompt_is_explicit_error_not_hello_fallback(self) -> None:
        body = b'{"action":"generate","stream":true,"max_new_tokens":16}'
        payload = (
            f"POST /v1/generate HTTP/1.1\r\n"
            f"Host: {HOST}:{PORT}\r\n"
            "Connection: close\r\n"
            "Content-Type: application/json\r\n"
            f"Content-Length: {len(body)}\r\n\r\n"
        ).encode("utf-8") + body
        status, response_body = _http_request_bytes(payload)
        self.assertEqual(status, 400)
        response = json.loads(response_body.decode("utf-8", "replace"))
        self.assertEqual(response.get("status"), "error")
        self.assertEqual(response.get("error"), "missing_or_invalid_prompt")
        self.assertEqual(response.get("fallback_status"), True)


if __name__ == "__main__":
    unittest.main()
