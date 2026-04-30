from __future__ import annotations

import os
import json
import math
from functools import lru_cache
from pathlib import Path
from typing import Any

import numpy as np


def _runtime_root() -> Path:
    return Path(__file__).resolve().parent / "_s_runtime"


def _runtime_manifest_path() -> Path:
    return _runtime_root() / "manifest.json"


def _module_ir_path(module_name: str) -> Path:
    return _runtime_root() / f"{module_name}.ir"


def ops_runtime_enabled() -> bool:
    mode = os.environ.get("NEURX_S_OPS_BACKEND", "auto").strip().lower()
    return mode in {"1", "true", "on", "yes", "auto", "s"}


@lru_cache(maxsize=None)
def _load_module_functions(module_name: str) -> dict[str, list[list[str]]]:
    ir_path = _module_ir_path(module_name)
    if not ir_path.exists():
        return {}
    functions: dict[str, list[list[str]]] = {}
    current_name: str | None = None
    current_ops: list[list[str]] = []
    for raw_line in ir_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line == "SSEED-TARGET-V1":
            continue
        parts = line.split("|")
        opcode = parts[0]
        if opcode == "FUNC_BEGIN":
            current_name = parts[1]
            current_ops = []
            continue
        if opcode == "FUNC_END":
            if current_name is not None:
                functions[current_name] = current_ops[:]
            current_name = None
            current_ops = []
            continue
        if current_name is not None:
            current_ops.append(parts)
    return functions


def supports_runtime_function(module_name: str, function_name: str) -> bool:
    return function_name in _load_module_functions(module_name)


def _execute_intrinsic(name: str, args: list[Any]) -> Any:
    if name == "add":
        if len(args) != 2:
            raise ValueError(f"add expects 2 args, got {len(args)}")
        return np.add(args[0], args[1])
    if name == "mul":
        if len(args) != 2:
            raise ValueError(f"mul expects 2 args, got {len(args)}")
        return np.multiply(args[0], args[1])
    if name == "matmul":
        if len(args) != 2:
            raise ValueError(f"matmul expects 2 args, got {len(args)}")
        return np.matmul(args[0], args[1])
    if name == "relu":
        if len(args) != 1:
            raise ValueError(f"relu expects 1 arg, got {len(args)}")
        return np.maximum(args[0], 0)
    if name == "sigmoid":
        if len(args) != 1:
            raise ValueError(f"sigmoid expects 1 arg, got {len(args)}")
        x = np.asarray(args[0])
        return np.where(
            x >= 0,
            1.0 / (1.0 + np.exp(-x)),
            np.exp(x) / (1.0 + np.exp(x)),
        )
    if name == "tanh":
        if len(args) != 1:
            raise ValueError(f"tanh expects 1 arg, got {len(args)}")
        return np.tanh(args[0])
    if name == "softmax":
        if len(args) != 2:
            raise ValueError(f"softmax expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        dim = int(args[1])
        dim = dim + x.ndim if dim < 0 else dim
        x_shifted = x - np.max(x, axis=dim, keepdims=True)
        exp_x = np.exp(x_shifted)
        return exp_x / np.sum(exp_x, axis=dim, keepdims=True)
    if name == "log_softmax":
        if len(args) != 2:
            raise ValueError(f"log_softmax expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        dim = int(args[1])
        dim = dim + x.ndim if dim < 0 else dim
        x_shifted = x - np.max(x, axis=dim, keepdims=True)
        logsumexp = np.log(np.sum(np.exp(x_shifted), axis=dim, keepdims=True))
        return x_shifted - logsumexp
    if name == "leaky_relu":
        if len(args) != 2:
            raise ValueError(f"leaky_relu expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        negative_slope = float(args[1])
        return np.where(x > 0, x, negative_slope * x)
    if name == "elu":
        if len(args) != 2:
            raise ValueError(f"elu expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        alpha = float(args[1])
        return np.where(x > 0, x, alpha * (np.exp(x) - 1.0))
    if name == "selu":
        if len(args) != 1:
            raise ValueError(f"selu expects 1 arg, got {len(args)}")
        x = np.asarray(args[0])
        alpha = 1.6732632423543772
        scale = 1.0507009873554805
        inner = np.where(x > 0, x, alpha * (np.exp(x) - 1.0))
        return scale * inner
    if name == "gelu":
        if len(args) != 2:
            raise ValueError(f"gelu expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        approximate = bool(args[1])
        if approximate:
            gelu_coef_a = np.sqrt(2.0 / np.pi)
            gelu_coef_b = 0.044715
            x_cubed = x ** 3
            tanh_arg = gelu_coef_a * (x + gelu_coef_b * x_cubed)
            return 0.5 * x * (1.0 + np.tanh(tanh_arg))
        erf_x = np.vectorize(math.erf, otypes=[float])(x / np.sqrt(2.0))
        cdf = 0.5 * (1.0 + erf_x)
        return x * cdf
    if name == "silu":
        if len(args) != 1:
            raise ValueError(f"silu expects 1 arg, got {len(args)}")
        x = np.asarray(args[0])
        sigmoid_x = np.where(
            x >= 0,
            1.0 / (1.0 + np.exp(-x)),
            np.exp(x) / (1.0 + np.exp(x)),
        )
        return x * sigmoid_x
    if name == "mish":
        if len(args) != 1:
            raise ValueError(f"mish expects 1 arg, got {len(args)}")
        x = np.asarray(args[0])
        softplus = np.where(x > 20, x, np.log(1.0 + np.exp(x)))
        return x * np.tanh(softplus)
    if name == "hardtanh":
        if len(args) != 3:
            raise ValueError(f"hardtanh expects 3 args, got {len(args)}")
        x = np.asarray(args[0])
        min_val = float(args[1])
        max_val = float(args[2])
        return np.clip(x, min_val, max_val)
    if name == "hardswish":
        if len(args) != 1:
            raise ValueError(f"hardswish expects 1 arg, got {len(args)}")
        x = np.asarray(args[0])
        clipped = np.clip(x + 3.0, 0.0, 6.0) / 6.0
        return x * clipped
    raise NotImplementedError(f"unsupported intrinsic: {name}")


def invoke_runtime_function(module_name: str, function_name: str, *args: Any) -> Any:
    functions = _load_module_functions(module_name)
    if function_name not in functions:
        raise LookupError(f"runtime function not found: {module_name}.{function_name}")
    scope: dict[str, Any] = {}
    call_args: list[Any] = []
    arg_iter = iter(args)
    for op in functions[function_name]:
        opcode = op[0]
        if opcode == "PARAM":
            scope[op[1]] = next(arg_iter)
        elif opcode == "ARG":
            call_args.append(scope[op[1]])
        elif opcode == "CALL":
            target = op[1]
            callee = op[2]
            arity = int(op[3])
            scope[target] = _execute_intrinsic(callee, call_args[-arity:])
            call_args = []
        elif opcode == "RET":
            return scope[op[1]]
    raise RuntimeError(f"runtime function did not return: {module_name}.{function_name}")


def try_invoke_ops_function(function_name: str, *args: Any) -> Any | None:
    if not ops_runtime_enabled() or not runtime_available():
        return None
    if not supports_runtime_function("ops", function_name):
        return None
    try:
        return invoke_runtime_function("ops", function_name, *args)
    except Exception:
        return None


def runtime_available() -> bool:
    return _runtime_manifest_path().exists()


def runtime_manifest() -> dict[str, Any]:
    manifest_path = _runtime_manifest_path()
    if not manifest_path.exists():
        return {
            "available": False,
            "artifact_root": str(_runtime_root()),
            "ir_files": [],
        }
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    data["available"] = True
    return data


def compiled_runtime_files() -> list[str]:
    manifest = runtime_manifest()
    artifact_root = Path(manifest["artifact_root"])
    return [str(artifact_root / name) for name in manifest.get("ir_files", [])]


def runtime_status() -> dict[str, Any]:
    manifest = runtime_manifest()
    return {
        "available": bool(manifest.get("available", False)),
        "artifact_root": manifest.get("artifact_root", str(_runtime_root())),
        "ir_count": len(manifest.get("ir_files", [])),
        "ir_files": manifest.get("ir_files", []),
    }
