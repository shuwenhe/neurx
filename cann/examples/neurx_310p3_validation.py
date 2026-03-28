#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path


def _run_neurx_training_loop_test(repo_root: Path, python_bin: str) -> tuple[bool, str]:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(repo_root / "python")
    cmd = [python_bin, "-m", "pytest", "-q", "tests/test_training_loop.py"]
    result = subprocess.run(cmd, cwd=repo_root, env=env, capture_output=True, text=True, check=False)
    output = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
    return result.returncode == 0, output.strip()


def _run_neurx_npu_backend_smoke(repo_root: Path, python_bin: str) -> tuple[bool, str]:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(repo_root / "python")
    env["TENSOR_DEVICE"] = "npu"
    code = r'''
import numpy as np
from neurx.neurx import Tensor
from neurx.platform import runtime_info

info = runtime_info()
print("runtime_device", info.get("default_device"))
print("npu_available", info.get("npu_available"))

a = Tensor(np.random.randn(8, 16).astype(np.float32), requires_grad=True)
b = Tensor(np.random.randn(16, 4).astype(np.float32), requires_grad=True)
out = (a @ b).mean()
out.backward()

assert a.grad is not None
assert b.grad is not None
assert a.grad.shape == (8, 16)
assert b.grad.shape == (16, 4)
print("neurx_npu_backend_smoke=OK")
'''
    cmd = [python_bin, "-c", code]
    result = subprocess.run(cmd, cwd=repo_root, env=env, capture_output=True, text=True, check=False)
    output = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
    return result.returncode == 0, output.strip()


def _device_worker(device_id: int, rounds: int) -> tuple[int, bool, str]:
    try:
        import torch
        import torch_npu  # noqa: F401

        if not hasattr(torch, "npu") or not torch.npu.is_available():
            return device_id, False, "torch.npu is not available"

        device = torch.device(f"npu:{device_id}")
        torch.npu.set_device(device)

        total = 0.0
        for _ in range(rounds):
            a = torch.randn(1024, 1024, device=device)
            b = torch.randn(1024, 1024, device=device)
            c = a @ b
            total += float(c.mean().cpu())
        return device_id, True, f"ok mean_acc={total:.6f}"
    except Exception as exc:
        return device_id, False, str(exc)


def _run_npu_parallel_smoke(device_count: int, rounds: int) -> dict:
    workers = []
    with ProcessPoolExecutor(max_workers=device_count) as executor:
        for dev in range(device_count):
            workers.append(executor.submit(_device_worker, dev, rounds))
    results = [f.result() for f in workers]

    failures = [{"device": dev, "error": msg} for dev, ok, msg in results if not ok]
    return {
        "ok": len(failures) == 0,
        "results": [{"device": dev, "ok": ok, "detail": msg} for dev, ok, msg in results],
        "failures": failures,
    }


def _detect_npu_count() -> int:
    import torch
    import torch_npu  # noqa: F401

    if not hasattr(torch, "npu") or not torch.npu.is_available():
        return 0
    return int(torch.npu.device_count())


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate neurx on Ascend 310P3 (8-card smoke)")
    parser.add_argument("--python", default="/usr/bin/python3", help="Python executable with torch_npu installed")
    parser.add_argument("--rounds", type=int, default=3, help="Matmul rounds per device")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]

    print("== Step 1: neurx training-loop unit tests ==")
    neurx_ok, neurx_output = _run_neurx_training_loop_test(repo_root, args.python)
    print(neurx_output)

    print("== Step 2: neurx NPU backend smoke ==")
    neurx_npu_ok, neurx_npu_output = _run_neurx_npu_backend_smoke(repo_root, args.python)
    print(neurx_npu_output)

    print("== Step 3: 310P3 multi-card compute smoke ==")
    # Keep runtime in this process too, so device count is explicit in summary.
    npu_count = subprocess.run(
        [
            args.python,
            "-c",
            "import torch, torch_npu; print(int(torch.npu.is_available()) * torch.npu.device_count())",
        ],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if npu_count.returncode != 0:
        print(npu_count.stderr.strip(), file=sys.stderr)
        return 2

    try:
        device_count = int((npu_count.stdout or "0").strip())
    except ValueError:
        print(f"Invalid npu_count output: {npu_count.stdout}", file=sys.stderr)
        return 2

    if device_count <= 0:
        print("No NPU device available in current runtime", file=sys.stderr)
        return 2

    smoke = _run_npu_parallel_smoke(device_count=device_count, rounds=args.rounds)

    summary = {
        "neurx_training_loop_test_ok": neurx_ok,
        "neurx_npu_backend_smoke_ok": neurx_npu_ok,
        "npu_device_count": device_count,
        "npu_smoke_ok": smoke["ok"],
        "npu_failures": smoke["failures"],
    }
    print("== Summary ==")
    print(json.dumps(summary, ensure_ascii=False, indent=2))

    if neurx_ok and neurx_npu_ok and smoke["ok"]:
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())