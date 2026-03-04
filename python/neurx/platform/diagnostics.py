from __future__ import annotations

import os
import platform as py_platform
import sys
from dataclasses import dataclass
from importlib import metadata

import numpy as np

from neurx.platform.config import get_runtime_config


def _tensor_version() -> str:
    try:
        return metadata.version("neurx")
    except Exception:
        try:
            from neurx.version import __version__

            return __version__
        except Exception:
            return "unknown"


def _cuda_available() -> bool:
    try:
        from neurx.cuda import ops as cuda_ops

        return bool(cuda_ops.available())
    except Exception:
        return False


def runtime_info() -> dict[str, object]:
    cfg = get_runtime_config()
    return {
        "tensor_version": _tensor_version(),
        "python_version": sys.version.split()[0],
        "platform": py_platform.platform(),
        "numpy_version": np.__version__,
        "default_device": cfg.default_device,
        "fallback_to_cpu": cfg.fallback_to_cpu,
        "strict_checks": cfg.strict_checks,
        "deterministic": cfg.deterministic,
        "seed": cfg.seed,
        "cuda_available": _cuda_available(),
        "env": {k: os.environ.get(k) for k in ("TENSOR_DEVICE", "TENSOR_FALLBACK_TO_CPU", "TENSOR_LOG_LEVEL")},
    }


@dataclass(frozen=True)
class CheckResult:
    name: str
    passed: bool
    detail: str


def doctor(require_cuda: bool = False) -> list[CheckResult]:
    info = runtime_info()
    results = [
        CheckResult("python", True, f"Python {info['python_version']}"),
        CheckResult("numpy", True, f"NumPy {info['numpy_version']}"),
        CheckResult("config.default_device", True, str(info["default_device"])),
        CheckResult("cuda.extension", bool(info["cuda_available"]), f"available={info['cuda_available']}"),
    ]
    if require_cuda and not info["cuda_available"]:
        results.append(CheckResult("require_cuda", False, "CUDA is required but unavailable"))
    else:
        results.append(CheckResult("require_cuda", True, f"require_cuda={require_cuda}"))
    return results


def format_doctor_report(results: list[CheckResult]) -> str:
    lines = ["neurx doctor report"]
    for item in results:
        status = "PASS" if item.passed else "FAIL"
        lines.append(f"- [{status}] {item.name}: {item.detail}")
    return "\n".join(lines)

