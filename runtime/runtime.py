from __future__ import annotations

import json
import os
import math
from functools import lru_cache
from pathlib import Path
from typing import Any

import numpy as np


def _runtime_root() -> Path:
    return Path(__file__).resolve().parents[1] / "build" / "ir"


def _module_ir_path(module_name: str) -> Path:
    root = _runtime_root()
    direct = root / f"{module_name}.ir"
    if direct.exists():
        return direct
    nested = root / module_name / f"{module_name}.ir"
    if nested.exists():
        return nested
    matches = sorted(root.rglob(f"{module_name}.ir"))
    return matches[0] if matches else direct


def _runtime_ir_files() -> list[Path]:
    root = _runtime_root()
    if not root.exists():
        return []
    return sorted(path for path in root.rglob("*.ir") if path.is_file())


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


_UNHANDLED = object()


def _tensor_like(value: Any) -> tuple[np.ndarray, list[int], bool]:
    if isinstance(value, dict):
        data = value.get("data", [])
        shape = value.get("shape", [])
        requires_grad = bool(value.get("requires_grad", False))
    elif isinstance(value, (list, tuple, np.ndarray)):
        data = value
        shape = list(np.asarray(value).shape)
        requires_grad = False
    else:
        data = getattr(value, "data")
        shape = getattr(value, "shape")
        requires_grad = bool(getattr(value, "requires_grad", False))
    array = np.asarray(data, dtype=float)
    return array, [int(dim) for dim in shape], requires_grad


def _tensor_dict(data: Any, shape: list[int], requires_grad: bool, grad: Any = None) -> dict[str, Any]:
    return {
        "data": np.asarray(data).tolist() if isinstance(data, np.ndarray) else data,
        "shape": [int(dim) for dim in shape],
        "requires_grad": bool(requires_grad),
        "grad": grad,
    }


def _same_shape_like(a: Any, b: Any) -> bool:
    _, shape_a, _ = _tensor_like(a)
    _, shape_b, _ = _tensor_like(b)
    return shape_a == shape_b


def _tensor_backward_rule_add(a: Any, b: Any, upstream: Any, grad_a: Any | None = None, grad_b: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    data_b, shape_b, req_b = _tensor_like(b)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    ready = shape_a == shape_b == upstream_shape
    if grad_a is None:
        grad_a = _tensor_dict(upstream_data.copy(), upstream_shape, False)
    if grad_b is None:
        grad_b = _tensor_dict(upstream_data.copy(), upstream_shape, False)
    return {
        "op": "add",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(data_b, shape_b, req_b),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": grad_b,
        "ready": ready,
    }


def _tensor_backward_rule_mul(a: Any, b: Any, upstream: Any, grad_a: Any | None = None, grad_b: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    data_b, shape_b, req_b = _tensor_like(b)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    ready = shape_a == shape_b == upstream_shape
    if grad_a is None:
        grad_a = _tensor_dict(np.multiply(upstream_data, data_b), upstream_shape, False)
    if grad_b is None:
        grad_b = _tensor_dict(np.multiply(upstream_data, data_a), upstream_shape, False)
    return {
        "op": "mul",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(data_b, shape_b, req_b),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": grad_b,
        "ready": ready,
    }


def _tensor_backward_rule_sub(a: Any, b: Any, upstream: Any, grad_a: Any | None = None, grad_b: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    data_b, shape_b, req_b = _tensor_like(b)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    ready = shape_a == shape_b == upstream_shape
    if grad_a is None:
        grad_a = _tensor_dict(np.array(upstream_data, copy=True), upstream_shape, False)
    if grad_b is None:
        grad_b = _tensor_dict(np.negative(upstream_data), upstream_shape, False)
    return {
        "op": "sub",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(data_b, shape_b, req_b),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": grad_b,
        "ready": ready,
    }


def _tensor_backward_rule_div(a: Any, b: Any, upstream: Any, grad_a: Any | None = None, grad_b: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    data_b, shape_b, req_b = _tensor_like(b)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    ready = shape_a == shape_b == upstream_shape
    if grad_a is None:
        grad_a = _tensor_dict(np.divide(upstream_data, data_b), upstream_shape, False)
    if grad_b is None:
        numerator = np.multiply(upstream_data, data_a)
        denominator = np.multiply(data_b, data_b)
        grad_b = _tensor_dict(np.negative(np.divide(numerator, denominator)), upstream_shape, False)
    return {
        "op": "div",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(data_b, shape_b, req_b),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": grad_b,
        "ready": ready,
    }


def _tensor_backward_rule_matmul(a: Any, b: Any, upstream: Any, grad_a: Any | None = None, grad_b: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    data_b, shape_b, req_b = _tensor_like(b)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    if grad_a is None:
        grad_a_data = np.zeros_like(data_a)
    else:
        grad_a_data, _, _ = _tensor_like(grad_a)
    if grad_b is None:
        grad_b_data = np.zeros_like(data_b)
    else:
        grad_b_data, _, _ = _tensor_like(grad_b)
    ready = False
    if len(shape_a) == 1 and len(shape_b) == 1:
        ready = len(upstream_shape) == 1
        grad_a_data = data_b * float(upstream_data.reshape(-1)[0])
        grad_b_data = data_a * float(upstream_data.reshape(-1)[0])
    elif len(shape_a) == 2 and len(shape_b) == 2:
        ready = len(upstream_shape) == 2
        grad_a_data = np.matmul(upstream_data, data_b.T)
        grad_b_data = np.matmul(data_a.T, upstream_data)
    elif len(shape_a) == 2 and len(shape_b) == 1:
        ready = len(upstream_shape) == 1
        grad_b_data = np.matmul(data_a.T, upstream_data)
    return {
        "op": "matmul",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(data_b, shape_b, req_b),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": _tensor_dict(grad_a_data, shape_a, False),
        "grad_b": _tensor_dict(grad_b_data, shape_b, False),
        "ready": ready,
    }


def _tensor_backward_rule_sum(a: Any, upstream: Any, grad_a: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    scalar = float(np.asarray(upstream_data).reshape(-1)[0]) if upstream_data.size else 0.0
    if grad_a is None:
        grad_a = _tensor_dict(np.full_like(data_a, scalar), shape_a, False)
    return {
        "op": "sum",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "ready": len(upstream_shape) == 1,
    }


def _tensor_backward_rule_mean(a: Any, upstream: Any, grad_a: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    denom = float(len(data_a)) if len(data_a) else 1.0
    scalar = float(np.asarray(upstream_data).reshape(-1)[0]) if upstream_data.size else 0.0
    if grad_a is None:
        grad_a = _tensor_dict(np.full_like(data_a, scalar / denom), shape_a, False)
    return {
        "op": "mean",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "ready": len(upstream_shape) == 1,
    }


def _tensor_backward_rule_sum_dim(a: Any, upstream: Any, dim: int, keepdim: bool, grad_a: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    axis = dim if dim >= 0 else dim + len(shape_a)
    expanded = np.asarray(upstream_data)
    if expanded.size == 1:
        grad_data = np.full(shape_a, float(expanded.reshape(-1)[0]))
    else:
        if not keepdim:
            expanded = np.expand_dims(expanded, axis=axis)
        grad_data = np.broadcast_to(expanded, shape_a)
    if grad_a is None:
        grad_a = _tensor_dict(grad_data, shape_a, False)
    return {
        "op": "sum_dim",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "ready": True,
    }


def _tensor_backward_rule_mean_dim(a: Any, upstream: Any, dim: int, keepdim: bool, grad_a: Any | None = None) -> dict[str, Any]:
    data_a, shape_a, req_a = _tensor_like(a)
    upstream_data, upstream_shape, _ = _tensor_like(upstream)
    axis = dim if dim >= 0 else dim + len(shape_a)
    expanded = np.asarray(upstream_data)
    denom = float(shape_a[axis]) if shape_a else 1.0
    if expanded.size == 1:
        grad_data = np.full(shape_a, float(expanded.reshape(-1)[0]) / denom)
    else:
        if not keepdim:
            expanded = np.expand_dims(expanded, axis=axis)
        grad_data = np.broadcast_to(expanded, shape_a) / denom
    if grad_a is None:
        grad_a = _tensor_dict(grad_data, shape_a, False)
    return {
        "op": "mean_dim",
        "primal_a": _tensor_dict(data_a, shape_a, req_a),
        "primal_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "upstream": _tensor_dict(upstream_data, upstream_shape, False),
        "grad_a": grad_a,
        "grad_b": _tensor_dict(np.zeros_like(data_a), shape_a, False),
        "ready": True,
    }


def _tensor_transform_chain_from_op(op: str) -> dict[str, Any]:
    eqn = {"primitive": op, "params": [], "inputs": [], "outputs": []}
    return {"steps": [op], "params": [""], "inputs": [], "outputs": [], "eqns": [eqn], "ready": True, "linearized": True}


def _string_list(value: Any) -> list[str]:
    if isinstance(value, (list, tuple)):
        return [str(item) for item in value]
    return []


def _tracer_like(value: Any) -> tuple[str, bool, bool, int, list[str], list[str], list[str]]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            bool(value.get("active", False)),
            bool(value.get("linearized", False)),
            int(value.get("op_count", len(value.get("ops", [])))),
            _string_list(value.get("ops", [])),
            _string_list(value.get("params", [])),
            _string_list(value.get("tags", [])),
        )
    return (
        str(getattr(value, "name")),
        bool(getattr(value, "active", False)),
        bool(getattr(value, "linearized", False)),
        int(getattr(value, "op_count", len(getattr(value, "ops", [])))),
        _string_list(getattr(value, "ops", [])),
        _string_list(getattr(value, "params", [])),
        _string_list(getattr(value, "tags", [])),
    )


def _tracer_inputs_outputs(value: Any) -> tuple[list[str], list[str]]:
    if isinstance(value, dict):
        return _string_list(value.get("inputs", [])), _string_list(value.get("outputs", []))
    return _string_list(getattr(value, "inputs", [])), _string_list(getattr(value, "outputs", []))


def _tracer_eqns(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, dict):
        return [
            {
                "primitive": str(eqn.get("primitive", "")),
                "params": _string_list(eqn.get("params", [])),
                "inputs": _string_list(eqn.get("inputs", [])),
                "outputs": _string_list(eqn.get("outputs", [])),
            }
            for eqn in value.get("eqns", [])
        ]
    return [
        {
            "primitive": str(getattr(eqn, "primitive", "")),
            "params": _string_list(getattr(eqn, "params", [])),
            "inputs": _string_list(getattr(eqn, "inputs", [])),
            "outputs": _string_list(getattr(eqn, "outputs", [])),
        }
        for eqn in getattr(value, "eqns", [])
    ]


def _tracer_dict(name: str, active: bool, linearized: bool, op_count: int, ops: list[str], params: list[str], tags: list[str], inputs: list[str] | None = None, outputs: list[str] | None = None, eqns: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    return {
        "name": name,
        "active": bool(active),
        "linearized": bool(linearized),
        "op_count": int(op_count),
        "ops": list(ops),
        "params": list(params),
        "inputs": list(inputs or []),
        "outputs": list(outputs or []),
        "eqns": list(eqns or []),
        "tags": list(tags),
    }


def _function_like(value: Any) -> tuple[str, bool, bool, bool, bool, int, list[str], list[str]]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            bool(value.get("forward_enabled", False)),
            bool(value.get("backward_enabled", False)),
            bool(value.get("apply_enabled", False)),
            bool(value.get("linearized", False)),
            int(value.get("arity", 0)),
            _string_list(value.get("params", [])),
            _string_list(value.get("tags", [])),
        )
    return (
        str(getattr(value, "name")),
        bool(getattr(value, "forward_enabled", False)),
        bool(getattr(value, "backward_enabled", False)),
        bool(getattr(value, "apply_enabled", False)),
        bool(getattr(value, "linearized", False)),
        int(getattr(value, "arity", 0)),
        _string_list(getattr(value, "params", [])),
        _string_list(getattr(value, "tags", [])),
    )


def _function_dict(name: str, forward_enabled: bool, backward_enabled: bool, apply_enabled: bool, linearized: bool, arity: int, params: list[str], tags: list[str]) -> dict[str, Any]:
    return {
        "name": name,
        "forward_enabled": bool(forward_enabled),
        "backward_enabled": bool(backward_enabled),
        "apply_enabled": bool(apply_enabled),
        "linearized": bool(linearized),
        "arity": int(arity),
        "params": list(params),
        "tags": list(tags),
    }


def _batch_like(value: Any) -> tuple[str, bool, int, int, list[str], list[str]]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            bool(value.get("active", False)),
            int(value.get("batch_size", 0)),
            int(value.get("batch_dim", 0)),
            _string_list(value.get("primitives", [])),
            _string_list(value.get("params", [])),
        )
    return (
        str(getattr(value, "name")),
        bool(getattr(value, "active", False)),
        int(getattr(value, "batch_size", 0)),
        int(getattr(value, "batch_dim", 0)),
        _string_list(getattr(value, "primitives", [])),
        _string_list(getattr(value, "params", [])),
    )


def _batch_dict(name: str, active: bool, batch_size: int, batch_dim: int, primitives: list[str], params: list[str]) -> dict[str, Any]:
    return {
        "name": name,
        "active": bool(active),
        "batch_size": int(batch_size),
        "batch_dim": int(batch_dim),
        "primitives": list(primitives),
        "params": list(params),
    }


def _stage_dict(
    name: str,
    backend: str,
    mode: str,
    jit_enabled: bool,
    lowered: bool,
    compiled: bool,
    executed: bool,
    stages: list[str],
    params: list[str],
    control_enabled: bool = False,
    control_cond_enabled: bool = False,
    control_loop_enabled: bool = False,
    control_scan_enabled: bool = False,
    control_iterations: int = 0,
    control_branches: list[str] | None = None,
    control_params: list[str] | None = None,
) -> dict[str, Any]:
    return {
        "name": name,
        "backend": backend,
        "mode": mode,
        "jit_enabled": bool(jit_enabled),
        "lowered": bool(lowered),
        "compiled": bool(compiled),
        "executed": bool(executed),
        "stages": list(stages),
        "params": list(params),
        "control_enabled": bool(control_enabled),
        "control_cond_enabled": bool(control_cond_enabled),
        "control_loop_enabled": bool(control_loop_enabled),
        "control_scan_enabled": bool(control_scan_enabled),
        "control_iterations": int(control_iterations),
        "control_branches": list(control_branches or []),
        "control_params": list(control_params or []),
    }


def _compile_dict(
    name: str,
    backend: str,
    mode: str,
    captured: bool,
    lowered: bool,
    compiled: bool,
    executed: bool,
    ready: bool,
    linearized: bool,
    dynamic: bool,
    fullgraph: bool,
    debug: bool,
    node_count: int,
    nodes: list[str],
    ops: list[str],
    params: list[str],
    inputs: list[str],
    outputs: list[str],
    edges: list[str],
    passes: list[str],
    cache_keys: list[str],
    tags: list[str],
) -> dict[str, Any]:
    return {
        "name": name,
        "backend": backend,
        "mode": mode,
        "captured": bool(captured),
        "lowered": bool(lowered),
        "compiled": bool(compiled),
        "executed": bool(executed),
        "ready": bool(ready),
        "linearized": bool(linearized),
        "dynamic": bool(dynamic),
        "fullgraph": bool(fullgraph),
        "debug": bool(debug),
        "node_count": int(node_count),
        "nodes": list(nodes),
        "ops": list(ops),
        "params": list(params),
        "inputs": list(inputs),
        "outputs": list(outputs),
        "edges": list(edges),
        "passes": list(passes),
        "cache_keys": list(cache_keys),
        "tags": list(tags),
    }


def _compile_like(value: Any) -> tuple[str, str, str, bool, bool, bool, bool, bool, bool, bool, bool, bool, int, list[str], list[str], list[str], list[str], list[str], list[str], list[str], list[str], list[str]]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            str(value.get("backend", "")),
            str(value.get("mode", "")),
            bool(value.get("captured", False)),
            bool(value.get("lowered", False)),
            bool(value.get("compiled", False)),
            bool(value.get("executed", False)),
            bool(value.get("ready", False)),
            bool(value.get("linearized", False)),
            bool(value.get("dynamic", False)),
            bool(value.get("fullgraph", False)),
            bool(value.get("debug", False)),
            int(value.get("node_count", 0)),
            _string_list(value.get("nodes", [])),
            _string_list(value.get("ops", [])),
            _string_list(value.get("params", [])),
            _string_list(value.get("inputs", [])),
            _string_list(value.get("outputs", [])),
            _string_list(value.get("edges", [])),
            _string_list(value.get("passes", [])),
            _string_list(value.get("cache_keys", [])),
            _string_list(value.get("tags", [])),
        )
    return (
        str(getattr(value, "name")),
        str(getattr(value, "backend", "")),
        str(getattr(value, "mode", "")),
        bool(getattr(value, "captured", False)),
        bool(getattr(value, "lowered", False)),
        bool(getattr(value, "compiled", False)),
        bool(getattr(value, "executed", False)),
        bool(getattr(value, "ready", False)),
        bool(getattr(value, "linearized", False)),
        bool(getattr(value, "dynamic", False)),
        bool(getattr(value, "fullgraph", False)),
        bool(getattr(value, "debug", False)),
        int(getattr(value, "node_count", 0)),
        _string_list(getattr(value, "nodes", [])),
        _string_list(getattr(value, "ops", [])),
        _string_list(getattr(value, "params", [])),
        _string_list(getattr(value, "inputs", [])),
        _string_list(getattr(value, "outputs", [])),
        _string_list(getattr(value, "edges", [])),
        _string_list(getattr(value, "passes", [])),
        _string_list(getattr(value, "cache_keys", [])),
        _string_list(getattr(value, "tags", [])),
    )


def _control_dict(name: str, cond_enabled: bool, loop_enabled: bool, scan_enabled: bool, iterations: int, branches: list[str], params: list[str]) -> dict[str, Any]:
    return {
        "name": name,
        "cond_enabled": bool(cond_enabled),
        "loop_enabled": bool(loop_enabled),
        "scan_enabled": bool(scan_enabled),
        "iterations": int(iterations),
        "branches": list(branches),
        "params": list(params),
    }


def _control_like(value: Any) -> tuple[str, bool, bool, bool, int, list[str], list[str]]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            bool(value.get("cond_enabled", False)),
            bool(value.get("loop_enabled", False)),
            bool(value.get("scan_enabled", False)),
            int(value.get("iterations", 0)),
            _string_list(value.get("branches", [])),
            _string_list(value.get("params", [])),
        )
    return (
        str(getattr(value, "name")),
        bool(getattr(value, "cond_enabled", False)),
        bool(getattr(value, "loop_enabled", False)),
        bool(getattr(value, "scan_enabled", False)),
        int(getattr(value, "iterations", 0)),
        _string_list(getattr(value, "branches", [])),
        _string_list(getattr(value, "params", [])),
    )


def _backward_dict(
    name: str,
    ready: bool,
    seeded: bool,
    executed: bool,
    steps: list[str],
    params: list[str],
    inputs: list[str],
    outputs: list[str],
    tags: list[str],
    upstream: list[float],
) -> dict[str, Any]:
    return {
        "name": name,
        "ready": bool(ready),
        "seeded": bool(seeded),
        "executed": bool(executed),
        "steps": list(steps),
        "params": list(params),
        "inputs": list(inputs),
        "outputs": list(outputs),
        "tags": list(tags),
        "upstream": list(upstream),
    }


def _backward_like(value: Any) -> tuple[str, bool, bool, bool, list[str], list[str], list[str], list[str], list[str], list[float]]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            bool(value.get("ready", False)),
            bool(value.get("seeded", False)),
            bool(value.get("executed", False)),
            _string_list(value.get("steps", [])),
            _string_list(value.get("params", [])),
            _string_list(value.get("inputs", [])),
            _string_list(value.get("outputs", [])),
            _string_list(value.get("tags", [])),
            [float(v) for v in value.get("upstream", [])],
        )
    return (
        str(getattr(value, "name")),
        bool(getattr(value, "ready", False)),
        bool(getattr(value, "seeded", False)),
        bool(getattr(value, "executed", False)),
        _string_list(getattr(value, "steps", [])),
        _string_list(getattr(value, "params", [])),
        _string_list(getattr(value, "inputs", [])),
        _string_list(getattr(value, "outputs", [])),
        _string_list(getattr(value, "tags", [])),
        [float(v) for v in getattr(value, "upstream", [])],
    )


def _backward_rule_like(value: Any) -> tuple[str, Any, Any, Any, Any, Any, bool]:
    if isinstance(value, dict):
        return (
            str(value.get("op", "")),
            value.get("primal_a"),
            value.get("primal_b"),
            value.get("upstream"),
            value.get("grad_a"),
            value.get("grad_b"),
            bool(value.get("ready", False)),
        )
    return (
        str(getattr(value, "op", "")),
        getattr(value, "primal_a", None),
        getattr(value, "primal_b", None),
        getattr(value, "upstream", None),
        getattr(value, "grad_a", None),
        getattr(value, "grad_b", None),
        bool(getattr(value, "ready", False)),
    )


def _stage_like(value: Any) -> tuple[str, str, str, bool, bool, bool, bool, list[str], list[str]]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            str(value.get("backend", "eager")),
            str(value.get("mode", "default")),
            bool(value.get("jit_enabled", False)),
            bool(value.get("lowered", False)),
            bool(value.get("compiled", False)),
            bool(value.get("executed", False)),
            _string_list(value.get("stages", [])),
            _string_list(value.get("params", [])),
        )
    return (
        str(getattr(value, "name")),
        str(getattr(value, "backend", "eager")),
        str(getattr(value, "mode", "default")),
        bool(getattr(value, "jit_enabled", False)),
        bool(getattr(value, "lowered", False)),
        bool(getattr(value, "compiled", False)),
        bool(getattr(value, "executed", False)),
        _string_list(getattr(value, "stages", [])),
        _string_list(getattr(value, "params", [])),
    )


def _stage_control_like(value: Any) -> tuple[bool, bool, bool, bool, int, list[str], list[str]]:
    if isinstance(value, dict):
        return (
            bool(value.get("control_enabled", False)),
            bool(value.get("control_cond_enabled", False)),
            bool(value.get("control_loop_enabled", False)),
            bool(value.get("control_scan_enabled", False)),
            int(value.get("control_iterations", 0)),
            _string_list(value.get("control_branches", [])),
            _string_list(value.get("control_params", [])),
        )
    return (
        bool(getattr(value, "control_enabled", False)),
        bool(getattr(value, "control_cond_enabled", False)),
        bool(getattr(value, "control_loop_enabled", False)),
        bool(getattr(value, "control_scan_enabled", False)),
        int(getattr(value, "control_iterations", 0)),
        _string_list(getattr(value, "control_branches", [])),
        _string_list(getattr(value, "control_params", [])),
    )


def _jaxpr_like(value: Any) -> tuple[str, int, list[str], list[str], list[str], list[str], bool, bool]:
    if isinstance(value, dict):
        return (
            str(value.get("name", "")),
            int(value.get("eqn_count", len(value.get("primitives", [])))),
            _string_list(value.get("primitives", [])),
            _string_list(value.get("params", [])),
            _string_list(value.get("inputs", [])),
            _string_list(value.get("outputs", [])),
            bool(value.get("ready", False)),
            bool(value.get("linearized", False)),
        )
    return (
        str(getattr(value, "name")),
        int(getattr(value, "eqn_count", len(getattr(value, "primitives", [])))),
        _string_list(getattr(value, "primitives", [])),
        _string_list(getattr(value, "params", [])),
        _string_list(getattr(value, "inputs", [])),
        _string_list(getattr(value, "outputs", [])),
        bool(getattr(value, "ready", False)),
        bool(getattr(value, "linearized", False)),
    )


def _jaxpr_eqns(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, dict):
        return [
            {
                "primitive": str(eqn.get("primitive", "")),
                "params": _string_list(eqn.get("params", [])),
                "inputs": _string_list(eqn.get("inputs", [])),
                "outputs": _string_list(eqn.get("outputs", [])),
            }
            for eqn in value.get("eqns", [])
        ]
    return [
        {
            "primitive": str(getattr(eqn, "primitive", "")),
            "params": _string_list(getattr(eqn, "params", [])),
            "inputs": _string_list(getattr(eqn, "inputs", [])),
            "outputs": _string_list(getattr(eqn, "outputs", [])),
        }
        for eqn in getattr(value, "eqns", [])
    ]


def _transform_chain_eqns(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, dict):
        return [
            {
                "primitive": str(eqn.get("primitive", "")),
                "params": _string_list(eqn.get("params", [])),
                "inputs": _string_list(eqn.get("inputs", [])),
                "outputs": _string_list(eqn.get("outputs", [])),
            }
            for eqn in value.get("eqns", [])
        ]
    return [
        {
            "primitive": str(getattr(eqn, "primitive", "")),
            "params": _string_list(getattr(eqn, "params", [])),
            "inputs": _string_list(getattr(eqn, "inputs", [])),
            "outputs": _string_list(getattr(eqn, "outputs", [])),
        }
        for eqn in getattr(value, "eqns", [])
    ]


def _jaxpr_dict(name: str, eqn_count: int, primitives: list[str], params: list[str], inputs: list[str], outputs: list[str], ready: bool, linearized: bool, eqns: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    return {
        "name": name,
        "eqn_count": int(eqn_count),
        "primitives": list(primitives),
        "params": list(params),
        "inputs": list(inputs),
        "outputs": list(outputs),
        "eqns": list(eqns or []),
        "ready": bool(ready),
        "linearized": bool(linearized),
    }


def _invoke_special_module_function(module_name: str, function_name: str, args: tuple[Any, ...]) -> Any:
    if module_name == "ad":
        if function_name in {
            "new_tracer_state",
            "tracer_name",
            "tracer_active",
            "tracer_linearized",
            "tracer_op_count",
            "tracer_tag_count",
            "tracer_input_count",
            "tracer_output_count",
            "tracer_eqn_count",
            "tracer_has_op",
            "tracer_has_input",
            "tracer_has_output",
            "tracer_has_eqn",
            "tracer_has_tag",
            "tracer_add_op",
            "tracer_add_eqn",
            "tracer_add_eqn_with_param",
            "tracer_add_eqn_with_io",
            "tracer_add_tag",
            "tracer_clear_tags",
            "tracer_add_input",
            "tracer_add_output",
            "tracer_clear_inputs",
            "tracer_clear_outputs",
            "tracer_clear_eqns",
            "tracer_set_active",
            "tracer_set_linearized",
            "tracer_state_dict",
            "tracer_load_state_dict",
            "tracer_capture",
            "tracer_capture_with_io",
            "tracer_to_transform_chain",
            "transform_chain_to_tracer",
        }:
            return invoke_runtime_function("ad/tracer", function_name, *args)
        if function_name in {
            "new_jaxpr_graph",
            "jaxpr_name",
            "jaxpr_eqn_count",
            "jaxpr_primitive_count",
            "jaxpr_input_count",
            "jaxpr_output_count",
            "jaxpr_has_primitive",
            "jaxpr_ready",
            "jaxpr_is_linearized",
            "jaxpr_add_eqn",
            "jaxpr_add_eqn_with_params",
            "jaxpr_add_eqn_with_io",
            "jaxpr_add_input",
            "jaxpr_add_output",
            "jaxpr_state_dict",
            "jaxpr_load_state_dict",
            "jaxpr_from_tracer",
            "jaxpr_to_tracer",
            "jaxpr_capture",
            "jaxpr_capture_with_params",
            "jaxpr_capture_with_io",
            "jaxpr_to_transform_chain",
            "transform_chain_to_jaxpr",
        }:
            return invoke_runtime_function("ad/jaxpr", function_name, *args)
    if module_name == "function":
        if function_name == "new_function":
            return _function_dict(str(args[0]), False, False, False, False, int(args[1]), [], [])
        if function_name == "function_name":
            name, _, _, _, _, _, _, _ = _function_like(args[0])
            return name
        if function_name == "function_arity":
            _, _, _, _, _, arity, _, _ = _function_like(args[0])
            return arity
        if function_name == "function_tag_count":
            _, _, _, _, _, _, _, tags = _function_like(args[0])
            return len(tags)
        if function_name == "function_param_count":
            _, _, _, _, _, _, params, _ = _function_like(args[0])
            return len(params)
        if function_name == "function_has_tag":
            _, _, _, _, _, _, _, tags = _function_like(args[0])
            return str(args[1]) in tags
        if function_name == "function_has_param":
            _, _, _, _, _, _, params, _ = _function_like(args[0])
            return str(args[1]) in params
        if function_name == "add_function_tag":
            name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, params, tags = _function_like(args[0])
            tags = list(tags)
            tags.append(str(args[1]))
            return _function_dict(name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, params, tags)
        if function_name == "add_function_param":
            name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, params, tags = _function_like(args[0])
            params = list(params)
            params.append(str(args[1]))
            return _function_dict(name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, params, tags)
        if function_name == "clear_function_tags":
            name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, params, _ = _function_like(args[0])
            return _function_dict(name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, params, [])
        if function_name == "clear_function_params":
            name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, _, tags = _function_like(args[0])
            return _function_dict(name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, [], tags)
        if function_name == "enable_forward":
            name, _, backward_enabled, apply_enabled, linearized, arity, params, tags = _function_like(args[0])
            return _function_dict(name, True, backward_enabled, apply_enabled, linearized, arity, params, tags)
        if function_name == "enable_backward":
            name, forward_enabled, _, apply_enabled, linearized, arity, params, tags = _function_like(args[0])
            return _function_dict(name, forward_enabled, True, apply_enabled, linearized, arity, params, tags)
        if function_name == "enable_apply":
            name, forward_enabled, backward_enabled, _, linearized, arity, params, tags = _function_like(args[0])
            return _function_dict(name, forward_enabled, backward_enabled, True, linearized, arity, params, tags)
        if function_name == "set_linearized":
            name, forward_enabled, backward_enabled, apply_enabled, _, arity, params, tags = _function_like(args[0])
            return _function_dict(name, forward_enabled, backward_enabled, apply_enabled, bool(args[1]), arity, params, tags)
        if function_name == "function_ready":
            _, forward_enabled, backward_enabled, apply_enabled, _, _, _, _ = _function_like(args[0])
            return forward_enabled and backward_enabled and apply_enabled
        if function_name == "function_is_linearized":
            _, _, _, _, linearized, _, _, _ = _function_like(args[0])
            return linearized
        if function_name == "function_state_dict":
            return _function_dict(*_function_like(args[0]))
        if function_name == "function_load_state_dict":
            return args[1]
        if function_name == "function_transform_chain":
            name, forward_enabled, backward_enabled, apply_enabled, linearized, arity, params, tags = _function_like(args[0])
            eqns = [
                {
                    "primitive": str(tag),
                    "params": [str(params[i])] if i < len(params) and str(params[i]) else [],
                    "inputs": [],
                    "outputs": [],
                }
                for i, tag in enumerate(tags)
            ]
            return {
                "steps": list(tags),
                "params": list(params),
                "inputs": [],
                "outputs": [],
                "eqns": eqns,
                "ready": bool(forward_enabled and backward_enabled and apply_enabled),
                "linearized": bool(linearized),
            }
        if function_name == "transform_chain_to_function":
            chain = args[0]
            name = str(args[1])
            arity = int(args[2])
            steps = _string_list(chain.get("steps", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "steps", []))
            params = _string_list(chain.get("params", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "params", []))
            eqns = _transform_chain_eqns(chain)
            if eqns:
                steps = [eqn["primitive"] for eqn in eqns]
                params = [",".join(eqn["params"]) for eqn in eqns]
            ready = bool(chain.get("ready", False)) if isinstance(chain, dict) else bool(getattr(chain, "ready", False))
            linearized = bool(chain.get("linearized", False)) if isinstance(chain, dict) else bool(getattr(chain, "linearized", False))
            return _function_dict(name, ready, ready or linearized, ready and linearized, linearized, arity, params, steps)
        if function_name == "tag_flow":
            return _invoke_special_module_function(module_name, "add_function_tag", args)
        if function_name == "backward_pass":
            return _invoke_special_module_function(module_name, "add_function_tag", ( _invoke_special_module_function(module_name, "set_linearized", ( _invoke_special_module_function(module_name, "enable_backward", args), True)), "backward_pass"))
        if function_name == "backward_pass_state":
            return _invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_backward", args), True))
        if function_name == "forward":
            return _invoke_special_module_function(module_name, "enable_forward", args)
        if function_name == "backward":
            return _invoke_special_module_function(module_name, "enable_backward", args)
        if function_name == "apply":
            return _invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_apply", (_invoke_special_module_function(module_name, "enable_backward", (_invoke_special_module_function(module_name, "enable_forward", args),)), True)), True))
        if function_name == "linearize":
            return _invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_backward", (_invoke_special_module_function(module_name, "enable_forward", args),)), True))
        if function_name == "jvp":
            return _invoke_special_module_function(module_name, "add_function_tag", (_invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_forward", args), True)), "jvp"))
        if function_name == "vjp":
            return _invoke_special_module_function(module_name, "add_function_tag", (_invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_backward", args), True)), "vjp"))
        if function_name == "grad":
            return _invoke_special_module_function(module_name, "add_function_tag", (_invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_backward", (_invoke_special_module_function(module_name, "enable_forward", args),)), True)), "grad"))
        if function_name == "value_and_grad":
            return _invoke_special_module_function(module_name, "add_function_tag", (_invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_backward", (_invoke_special_module_function(module_name, "enable_forward", args),)), True)), "value_and_grad"))
        if function_name in {"function_add", "function_mul", "function_matmul", "function_sum", "function_mean"}:
            fn = _invoke_special_module_function(module_name, "set_linearized", (_invoke_special_module_function(module_name, "enable_forward", args), True))
            op = function_name.removeprefix("function_")
            fn = _invoke_special_module_function(module_name, "add_function_param", (fn, f"op={op}"))
            return _invoke_special_module_function(module_name, "add_function_tag", (fn, op))
        if function_name in {"add", "mul", "matmul", "sum", "mean"}:
            return _invoke_special_module_function(module_name, f"function_{function_name}", args)
        if function_name in {"function_transform_chain_jvp", "function_transform_chain_vjp", "function_transform_chain_grad", "function_transform_chain_value_and_grad"}:
            chain = _invoke_special_module_function(module_name, "function_transform_chain", args)
            suffix = function_name.removeprefix("function_transform_chain_")
            return _invoke_special_module_function(module_name, f"transform_chain_{suffix}", (chain,))
        if function_name in {"function_transform_chain_add", "function_transform_chain_mul", "function_transform_chain_matmul", "function_transform_chain_sum", "function_transform_chain_mean"}:
            chain = _invoke_special_module_function(module_name, "function_transform_chain", args)
            suffix = function_name.removeprefix("function_transform_chain_")
            return _invoke_special_module_function(module_name, f"transform_chain_{suffix}", (chain,))
    if module_name == "engine/backward":
        if function_name == "new_backward_state":
            return _backward_dict(str(args[0]), False, False, False, [], [], [], [], [], [])
        if function_name == "backward_rule_add":
            return _tensor_backward_rule_add(args[0], args[1], args[2])
        if function_name == "backward_rule_mul":
            return _tensor_backward_rule_mul(args[0], args[1], args[2])
        if function_name == "backward_rule_sub":
            return _tensor_backward_rule_sub(args[0], args[1], args[2])
        if function_name == "backward_rule_div":
            return _tensor_backward_rule_div(args[0], args[1], args[2])
        if function_name == "backward_rule_matmul":
            return _tensor_backward_rule_matmul(args[0], args[1], args[2])
        if function_name == "backward_rule_sum":
            return _tensor_backward_rule_sum(args[0], args[1])
        if function_name == "backward_rule_mean":
            return _tensor_backward_rule_mean(args[0], args[1])
        if function_name == "backward_rule_sum_dim":
            return _tensor_backward_rule_sum_dim(args[0], args[1], int(args[2]), bool(args[3]))
        if function_name == "backward_rule_mean_dim":
            return _tensor_backward_rule_mean_dim(args[0], args[1], int(args[2]), bool(args[3]))
        if function_name == "backward_rule_from_op":
            op = str(args[0])
            if op == "add":
                return _tensor_backward_rule_add(args[1], args[2], args[3])
            if op == "mul":
                return _tensor_backward_rule_mul(args[1], args[2], args[3])
            if op == "sub":
                return _tensor_backward_rule_sub(args[1], args[2], args[3])
            if op == "div":
                return _tensor_backward_rule_div(args[1], args[2], args[3])
            if op == "matmul":
                return _tensor_backward_rule_matmul(args[1], args[2], args[3])
            if op == "sum":
                return _tensor_backward_rule_sum(args[1], args[3])
            if op == "mean":
                return _tensor_backward_rule_mean(args[1], args[3])
            if op == "sum_dim":
                return _tensor_backward_rule_sum_dim(args[1], args[3], 0, False)
            if op == "mean_dim":
                return _tensor_backward_rule_mean_dim(args[1], args[3], 0, False)
            return _tensor_backward_rule_add(args[1], args[2], args[3])
        if function_name == "backward_rule_sum_dim_from_state":
            return _tensor_backward_rule_sum_dim(args[1], args[2], 0, False)
        if function_name == "backward_rule_mean_dim_from_state":
            return _tensor_backward_rule_mean_dim(args[1], args[2], 0, False)
        if function_name == "backward_rule_from_state":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            op = steps[-1] if steps else "add"
            if op == "sum_dim":
                return invoke_runtime_function("engine/backward", "backward_rule_sum_dim_from_state", args[0], args[1], args[3])
            if op == "mean_dim":
                return invoke_runtime_function("engine/backward", "backward_rule_mean_dim_from_state", args[0], args[1], args[3])
            return invoke_runtime_function("engine/backward", "backward_rule_from_op", op, args[1], args[2], args[3])
        if function_name == "backward_execute_state":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            a = args[1]
            b = args[2]
            upstream_tensor = args[3]
            next_state = _backward_dict(name, True, True, executed, steps, params, inputs, outputs, tags, upstream)
            for step in reversed(steps):
                rule = invoke_runtime_function("engine/backward", "backward_rule_from_op", step, a, b, upstream_tensor)
                next_state = invoke_runtime_function("engine/backward", "backward_apply_rule", next_state, rule)
            return next_state
        if function_name == "backward_apply_rule":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            rule = args[1]
            op, primal_a, primal_b, rule_upstream, grad_a, grad_b, rule_ready = _backward_rule_like(rule)
            next_state = _backward_dict(name, ready or rule_ready, seeded or rule_ready, executed or rule_ready, steps, params, inputs, outputs, tags, upstream)
            if op:
                next_state["tags"] = list(next_state["tags"]) + [op]
            if rule_upstream is not None:
                try:
                    upstream_arr, _, _ = _tensor_like(rule_upstream)
                    next_state["upstream"] = list(np.asarray(upstream_arr).reshape(-1).tolist())
                except Exception:
                    pass
            next_state["executed"] = bool(rule_ready)
            next_state["seeded"] = bool(rule_ready)
            return next_state
        if function_name == "backward_name":
            name, _, _, _, _, _, _, _, _, _ = _backward_like(args[0])
            return name
        if function_name == "backward_ready":
            _, ready, _, _, _, _, _, _, _, _ = _backward_like(args[0])
            return ready
        if function_name == "backward_seeded":
            _, _, seeded, _, _, _, _, _, _, _ = _backward_like(args[0])
            return seeded
        if function_name == "backward_executed":
            _, _, _, executed, _, _, _, _, _, _ = _backward_like(args[0])
            return executed
        if function_name == "backward_step_count":
            _, _, _, _, steps, _, _, _, _, _ = _backward_like(args[0])
            return len(steps)
        if function_name == "backward_param_count":
            _, _, _, _, _, params, _, _, _, _ = _backward_like(args[0])
            return len(params)
        if function_name == "backward_input_count":
            _, _, _, _, _, _, inputs, _, _, _ = _backward_like(args[0])
            return len(inputs)
        if function_name == "backward_output_count":
            _, _, _, _, _, _, _, outputs, _, _ = _backward_like(args[0])
            return len(outputs)
        if function_name == "backward_tag_count":
            _, _, _, _, _, _, _, _, tags, _ = _backward_like(args[0])
            return len(tags)
        if function_name == "backward_has_step":
            _, _, _, _, steps, _, _, _, _, _ = _backward_like(args[0])
            return str(args[1]) in steps
        if function_name == "backward_has_param":
            _, _, _, _, _, params, _, _, _, _ = _backward_like(args[0])
            return str(args[1]) in params
        if function_name == "backward_has_input":
            _, _, _, _, _, _, inputs, _, _, _ = _backward_like(args[0])
            return str(args[1]) in inputs
        if function_name == "backward_has_output":
            _, _, _, _, _, _, _, outputs, _, _ = _backward_like(args[0])
            return str(args[1]) in outputs
        if function_name == "backward_has_tag":
            _, _, _, _, _, _, _, _, tags, _ = _backward_like(args[0])
            return str(args[1]) in tags
        if function_name == "backward_add_step":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            steps = list(steps)
            steps.append(str(args[1]))
            return _backward_dict(name, True, seeded, executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_add_step_with_param":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            steps = list(steps)
            params = list(params)
            steps.append(str(args[1]))
            params.append(str(args[2]))
            return _backward_dict(name, True, seeded, executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_add_input":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            inputs = list(inputs)
            inputs.append(str(args[1]))
            return _backward_dict(name, True, seeded, executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_add_output":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            outputs = list(outputs)
            outputs.append(str(args[1]))
            return _backward_dict(name, True, seeded, executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_add_tag":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            tags = list(tags)
            tags.append(str(args[1]))
            return _backward_dict(name, True, seeded, executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_clear_steps":
            name, ready, seeded, executed, _, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            return _backward_dict(name, ready, seeded, executed, [], params, inputs, outputs, tags, upstream)
        if function_name == "backward_clear_params":
            name, ready, seeded, executed, steps, _, inputs, outputs, tags, upstream = _backward_like(args[0])
            return _backward_dict(name, ready, seeded, executed, steps, [], inputs, outputs, tags, upstream)
        if function_name == "backward_clear_inputs":
            name, ready, seeded, executed, steps, params, _, outputs, tags, upstream = _backward_like(args[0])
            return _backward_dict(name, ready, seeded, executed, steps, params, [], outputs, tags, upstream)
        if function_name == "backward_clear_outputs":
            name, ready, seeded, executed, steps, params, inputs, _, tags, upstream = _backward_like(args[0])
            return _backward_dict(name, ready, seeded, executed, steps, params, inputs, [], tags, upstream)
        if function_name == "backward_clear_tags":
            name, ready, seeded, executed, steps, params, inputs, outputs, _, upstream = _backward_like(args[0])
            return _backward_dict(name, ready, seeded, executed, steps, params, inputs, outputs, [], upstream)
        if function_name == "backward_set_ready":
            name, _, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            return _backward_dict(name, bool(args[1]), seeded, executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_set_seeded":
            name, ready, _, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            return _backward_dict(name, ready, bool(args[1]), executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_set_executed":
            name, ready, seeded, _, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            return _backward_dict(name, ready, seeded, bool(args[1]), steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_set_upstream":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, _ = _backward_like(args[0])
            upstream = [float(v) for v in _string_list(args[1])] if isinstance(args[1], (list, tuple)) else [float(v) for v in np.asarray(args[1]).reshape(-1)]
            return _backward_dict(name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream)
        if function_name == "backward_state_dict":
            return _backward_dict(*_backward_like(args[0]))
        if function_name == "backward_load_state_dict":
            return args[1]
        if function_name == "backward_to_tracer":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            return _tracer_dict(name, ready, seeded or executed, len(steps), steps, params, tags, inputs, outputs, [])
        if function_name == "tracer_to_backward":
            state = args[0]
            name = str(args[1])
            ops = _string_list(state.get("ops", [])) if isinstance(state, dict) else _string_list(getattr(state, "ops", []))
            params = _string_list(state.get("params", [])) if isinstance(state, dict) else _string_list(getattr(state, "params", []))
            inputs = _string_list(state.get("inputs", [])) if isinstance(state, dict) else _string_list(getattr(state, "inputs", []))
            outputs = _string_list(state.get("outputs", [])) if isinstance(state, dict) else _string_list(getattr(state, "outputs", []))
            tags = _string_list(state.get("tags", [])) if isinstance(state, dict) else _string_list(getattr(state, "tags", []))
            active = bool(state.get("active", False)) if isinstance(state, dict) else bool(getattr(state, "active", False))
            linearized = bool(state.get("linearized", False)) if isinstance(state, dict) else bool(getattr(state, "linearized", False))
            return _backward_dict(name, active, linearized, False, ops, params, inputs, outputs, tags, [])
        if function_name == "backward_to_jaxpr":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            return _jaxpr_dict(name, len(steps), steps, params, inputs, outputs, ready, seeded or executed, [])
        if function_name == "jaxpr_to_backward":
            graph = args[0]
            name = str(graph.get("name", "")) if isinstance(graph, dict) else str(getattr(graph, "name", ""))
            primitives = _string_list(graph.get("primitives", [])) if isinstance(graph, dict) else _string_list(getattr(graph, "primitives", []))
            params = _string_list(graph.get("params", [])) if isinstance(graph, dict) else _string_list(getattr(graph, "params", []))
            inputs = _string_list(graph.get("inputs", [])) if isinstance(graph, dict) else _string_list(getattr(graph, "inputs", []))
            outputs = _string_list(graph.get("outputs", [])) if isinstance(graph, dict) else _string_list(getattr(graph, "outputs", []))
            ready = bool(graph.get("ready", False)) if isinstance(graph, dict) else bool(getattr(graph, "ready", False))
            linearized = bool(graph.get("linearized", False)) if isinstance(graph, dict) else bool(getattr(graph, "linearized", False))
            return _backward_dict(name, ready, linearized, False, primitives, params, inputs, outputs, [], [])
        if function_name == "backward_seed_state":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            _, _, loss_requires_grad = _tensor_like(args[1])
            if not loss_requires_grad:
                return _backward_dict(name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream)
            loss_data, loss_shape, _ = _tensor_like(args[1])
            upstream_values = np.ones_like(loss_data, dtype=float).reshape(-1).tolist()
            return _backward_dict(name, True, True, executed, steps, params, inputs, outputs, tags, upstream_values)
        if function_name == "backward_pass_state":
            name, ready, seeded, executed, steps, params, inputs, outputs, tags, upstream = _backward_like(args[0])
            seeded_state = _invoke_special_module_function(module_name, "backward_seed_state", args)
            if isinstance(seeded_state, dict):
                seeded_name, seeded_ready, seeded_seeded, _, seeded_steps, seeded_params, seeded_inputs, seeded_outputs, seeded_tags, seeded_upstream = _backward_like(seeded_state)
                return _backward_dict(seeded_name, seeded_ready, seeded_seeded, True, seeded_steps, seeded_params, seeded_inputs, seeded_outputs, seeded_tags, seeded_upstream)
            return seeded_state
        if function_name == "backward_pass":
            if len(args) == 1:
                _, loss_shape, loss_requires_grad = _tensor_like(args[0])
                loss_data, _, _ = _tensor_like(args[0])
            else:
                _, _, _, _, _, _, _, _, _, _ = _backward_like(args[0])
                _, _, loss_requires_grad = _tensor_like(args[1])
                loss_data, loss_shape, _ = _tensor_like(args[1])
            if not loss_requires_grad:
                return _tensor_dict(np.zeros_like(loss_data, dtype=float), loss_shape, False)
            return _tensor_dict(np.ones_like(loss_data, dtype=float), loss_shape, False)
        if function_name == "backward":
            if len(args) == 1:
                return _invoke_special_module_function(module_name, "backward_pass", ( _invoke_special_module_function(module_name, "new_backward_state", ("backward",)), args[0]))
            return _invoke_special_module_function(module_name, "backward_pass", args)
    if module_name == "runtime/stage":
        if function_name == "new_stage_state":
            return _stage_dict(str(args[0]), str(args[1]), str(args[2]), False, False, False, False, [], [], False, False, False, False, 0, [], [])
        if function_name == "stage_name":
            name, _, _, _, _, _, _, _, _ = _stage_like(args[0])
            return name
        if function_name == "stage_backend":
            _, backend, _, _, _, _, _, _, _ = _stage_like(args[0])
            return backend
        if function_name == "stage_mode":
            _, _, mode, _, _, _, _, _, _ = _stage_like(args[0])
            return mode
        if function_name == "stage_jit_enabled":
            _, _, _, jit_enabled, _, _, _, _, _ = _stage_like(args[0])
            return jit_enabled
        if function_name == "stage_lowered":
            _, _, _, _, lowered, _, _, _, _ = _stage_like(args[0])
            return lowered
        if function_name == "stage_compiled":
            _, _, _, _, _, compiled, _, _, _ = _stage_like(args[0])
            return compiled
        if function_name == "stage_executed":
            _, _, _, _, _, _, executed, _, _ = _stage_like(args[0])
            return executed
        if function_name == "stage_stage_count":
            _, _, _, _, _, _, _, stages, _ = _stage_like(args[0])
            return len(stages)
        if function_name == "stage_param_count":
            _, _, _, _, _, _, _, _, params = _stage_like(args[0])
            return len(params)
        if function_name == "stage_has_stage":
            _, _, _, _, _, _, _, stages, _ = _stage_like(args[0])
            return str(args[1]) in stages
        if function_name == "stage_has_param":
            _, _, _, _, _, _, _, _, params = _stage_like(args[0])
            return str(args[1]) in params
        if function_name == "stage_add_stage":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            stages = list(stages)
            stages.append(str(args[1]))
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_add_param":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            params = list(params)
            params.append(str(args[1]))
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_jit_enabled":
            name, backend, mode, _, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, bool(args[1]), lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_lowered":
            name, backend, mode, jit_enabled, _, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, bool(args[1]), compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_compiled":
            name, backend, mode, jit_enabled, lowered, _, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, bool(args[1]), executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_executed":
            name, backend, mode, jit_enabled, lowered, compiled, _, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, bool(args[1]), stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_clear_stages":
            name, backend, mode, jit_enabled, lowered, compiled, executed, _, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, [], params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_clear_params":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, _ = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, [], control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_state_dict":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(
                name,
                backend,
                mode,
                jit_enabled,
                lowered,
                compiled,
                executed,
                stages,
                params,
                control_enabled,
                control_cond_enabled,
                control_loop_enabled,
                control_scan_enabled,
                control_iterations,
                control_branches,
                control_params,
            )
        if function_name == "stage_load_state_dict":
            return args[1]
        if function_name == "stage_control_enabled":
            control_enabled, _, _, _, _, _, _ = _stage_control_like(args[0])
            return control_enabled
        if function_name == "stage_control_cond_enabled":
            _, control_cond_enabled, _, _, _, _, _ = _stage_control_like(args[0])
            return control_cond_enabled
        if function_name == "stage_control_loop_enabled":
            _, _, control_loop_enabled, _, _, _, _ = _stage_control_like(args[0])
            return control_loop_enabled
        if function_name == "stage_control_scan_enabled":
            _, _, _, control_scan_enabled, _, _, _ = _stage_control_like(args[0])
            return control_scan_enabled
        if function_name == "stage_control_iterations":
            _, _, _, _, control_iterations, _, _ = _stage_control_like(args[0])
            return control_iterations
        if function_name == "stage_control_branch_count":
            _, _, _, _, _, control_branches, _ = _stage_control_like(args[0])
            return len(control_branches)
        if function_name == "stage_control_param_count":
            _, _, _, _, _, _, control_params = _stage_control_like(args[0])
            return len(control_params)
        if function_name == "stage_has_control_branch":
            _, _, _, _, _, control_branches, _ = _stage_control_like(args[0])
            return str(args[1]) in control_branches
        if function_name == "stage_has_control_param":
            _, _, _, _, _, _, control_params = _stage_control_like(args[0])
            return str(args[1]) in control_params
        if function_name == "stage_add_control_branch":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            control_branches = list(control_branches)
            control_branches.append(str(args[1]))
            branch = str(args[1])
            return _stage_dict(
                name,
                backend,
                mode,
                jit_enabled,
                lowered,
                compiled,
                executed,
                stages,
                params,
                True,
                control_cond_enabled or branch == "cond",
                control_loop_enabled or branch == "while_loop",
                control_scan_enabled or branch == "scan",
                control_iterations,
                control_branches,
                control_params,
            )
        if function_name == "stage_add_control_param":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            control_params = list(control_params)
            control_params.append(str(args[1]))
            return _stage_dict(
                name,
                backend,
                mode,
                jit_enabled,
                lowered,
                compiled,
                executed,
                stages,
                params,
                control_enabled or len(control_branches) > 0 or len(control_params) > 0,
                control_cond_enabled,
                control_loop_enabled,
                control_scan_enabled,
                control_iterations,
                control_branches,
                control_params,
            )
        if function_name == "stage_set_control_enabled":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            _, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, bool(args[1]), control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_control_cond_enabled":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, _, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            enabled = bool(args[1])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled or enabled, enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_control_loop_enabled":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, _, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            enabled = bool(args[1])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled or enabled, control_cond_enabled, enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_control_scan_enabled":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, _, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            enabled = bool(args[1])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled or enabled, control_cond_enabled, control_loop_enabled, enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_set_control_iterations":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, _, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, int(args[1]), control_branches, control_params)
        if function_name == "stage_clear_control_branches":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, _, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, [], control_params)
        if function_name == "stage_clear_control_params":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, _ = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, [])
        if function_name == "stage_control_state_dict":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "stage_to_control_state":
            name, backend, mode, _, _, _, _, _, _ = _stage_like(args[0])
            _, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _control_dict(name, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "control_state_to_stage":
            control = args[0]
            backend = str(args[1])
            mode = str(args[2])
            name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params = _control_like(control)
            return _stage_dict(
                name,
                backend,
                mode,
                False,
                False,
                False,
                False,
                [],
                [],
                bool(cond_enabled or loop_enabled or scan_enabled or len(branches) > 0 or len(params) > 0),
                cond_enabled,
                loop_enabled,
                scan_enabled,
                iterations,
                branches,
                params,
            )
        if function_name == "stage_to_transform_chain":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            eqns = [
                {
                    "primitive": stage,
                    "params": [param] if param else [],
                    "inputs": [],
                    "outputs": [],
                }
                for stage, param in zip(stages, params)
            ]
            for index, branch in enumerate(control_branches):
                param = control_params[index] if index < len(control_params) else ""
                eqns.append(
                    {
                        "primitive": branch,
                        "params": [param] if param else [],
                        "inputs": [],
                        "outputs": [],
                    }
                )
            if len(control_params) > len(control_branches):
                for param in control_params[len(control_branches):]:
                    eqns.append({"primitive": "control_param", "params": [param] if param else [], "inputs": [], "outputs": []})
            return {
                "steps": list(stages),
                "params": list(params),
                "inputs": [],
                "outputs": [],
                "eqns": eqns,
                "ready": bool(jit_enabled or lowered or compiled or executed or len(stages) > 0 or control_enabled or len(control_branches) > 0),
                "linearized": bool(lowered or compiled or executed or control_loop_enabled or control_scan_enabled),
            }
        if function_name == "transform_chain_to_stage":
            chain = args[0]
            name = str(args[1])
            backend = str(args[2])
            mode = str(args[3])
            stages = _string_list(chain.get("steps", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "steps", []))
            params = _string_list(chain.get("params", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "params", []))
            eqns = _transform_chain_eqns(chain)
            control_enabled = False
            control_cond_enabled = False
            control_loop_enabled = False
            control_scan_enabled = False
            control_iterations = 0
            control_branches: list[str] = []
            control_params: list[str] = []
            if eqns:
                stages = [eqn["primitive"] for eqn in eqns]
                params = [",".join(eqn["params"]) for eqn in eqns]
                filtered_stages: list[str] = []
                filtered_params: list[str] = []
                for eqn in eqns:
                    primitive = eqn["primitive"]
                    joined = ",".join(eqn["params"])
                    if primitive in {"jit", "lower", "compile", "execute"}:
                        filtered_stages.append(primitive)
                        filtered_params.append(joined)
                    elif primitive == "control_param":
                        control_enabled = True
                        if joined:
                            control_params.append(joined)
                    else:
                        control_enabled = True
                        control_branches.append(primitive)
                        if joined:
                            control_params.append(joined)
                        if primitive == "cond":
                            control_cond_enabled = True
                        if primitive == "while_loop":
                            control_loop_enabled = True
                        if primitive == "scan":
                            control_scan_enabled = True
                stages = filtered_stages
                params = filtered_params
            jit_enabled = "jit" in stages
            lowered = "lower" in stages
            compiled = "compile" in stages
            executed = "execute" in stages
            if len(stages) > 0 and not jit_enabled:
                jit_enabled = True
            if compiled:
                lowered = True
            if executed:
                lowered = True
                compiled = True
            return _stage_dict(name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "jit":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            stages = list(stages)
            if "jit" not in stages:
                stages.append("jit")
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, True, lowered, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "lower":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            stages = list(stages)
            if "jit" not in stages:
                stages.append("jit")
            if "lower" not in stages:
                stages.append("lower")
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, True, True, compiled, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "compile":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            stages = list(stages)
            if "jit" not in stages:
                stages.append("jit")
            if "lower" not in stages:
                stages.append("lower")
            if "compile" not in stages:
                stages.append("compile")
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, True, True, True, executed, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
        if function_name == "execute":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            stages = list(stages)
            if "jit" not in stages:
                stages.append("jit")
            if "lower" not in stages:
                stages.append("lower")
            if "compile" not in stages:
                stages.append("compile")
            if "execute" not in stages:
                stages.append("execute")
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _stage_dict(name, backend, mode, True, True, True, True, stages, params, control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params)
    if module_name == "runtime/compile":
        if function_name == "new_compile_state":
            return _compile_dict(str(args[0]), str(args[1]), str(args[2]), False, False, False, False, False, False, False, False, False, 0, [], [], [], [], [], [], [], [], [])
        if function_name == "compile_name":
            name = _compile_like(args[0])[0]
            return name
        if function_name == "compile_backend":
            backend = _compile_like(args[0])[1]
            return backend
        if function_name == "compile_mode":
            mode = _compile_like(args[0])[2]
            return mode
        if function_name == "compile_captured":
            captured = _compile_like(args[0])[3]
            return captured
        if function_name == "compile_lowered":
            lowered = _compile_like(args[0])[4]
            return lowered
        if function_name == "compile_compiled":
            compiled = _compile_like(args[0])[5]
            return compiled
        if function_name == "compile_executed":
            executed = _compile_like(args[0])[6]
            return executed
        if function_name == "compile_ready":
            ready = _compile_like(args[0])[7]
            return ready
        if function_name == "compile_is_linearized":
            linearized = _compile_like(args[0])[8]
            return linearized
        if function_name == "compile_node_count":
            node_count = _compile_like(args[0])[12]
            return node_count
        if function_name == "compile_pass_count":
            passes = _compile_like(args[0])[19]
            return len(passes)
        if function_name == "compile_param_count":
            params = _compile_like(args[0])[15]
            return len(params)
        if function_name == "compile_input_count":
            inputs = _compile_like(args[0])[16]
            return len(inputs)
        if function_name == "compile_output_count":
            outputs = _compile_like(args[0])[17]
            return len(outputs)
        if function_name == "compile_edge_count":
            edges = _compile_like(args[0])[18]
            return len(edges)
        if function_name == "compile_has_node":
            nodes = _compile_like(args[0])[13]
            return str(args[1]) in nodes
        if function_name == "compile_has_edge":
            edges = _compile_like(args[0])[18]
            return str(args[1]) in edges
        if function_name == "compile_has_pass":
            passes = _compile_like(args[0])[19]
            return str(args[1]) in passes
        if function_name == "compile_has_cache_key":
            cache_keys = _compile_like(args[0])[20]
            return str(args[1]) in cache_keys
        if function_name == "compile_add_node":
            return _invoke_special_module_function(module_name, "compile_add_node_with_io", (args[0], args[1], args[2], [], [], []))
        if function_name == "compile_add_edge":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            edges = list(edges)
            edges.append(str(args[1]))
            return _compile_dict(name, backend, mode, True, lowered, compiled, executed, True, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_add_node_with_io":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            nodes = list(nodes)
            ops = list(ops)
            params = list(params)
            input_list = list(inputs)
            output_list = list(outputs)
            nodes.append(str(args[1]))
            ops.append(str(args[2]))
            params.append(",".join(_string_list(args[3]) if len(args) > 3 else []))
            if len(args) > 4:
                input_list.extend(_string_list(args[4]))
            if len(args) > 5:
                output_list.extend(_string_list(args[5]))
            return _compile_dict(name, backend, mode, True, lowered, compiled, executed, True, linearized, dynamic, fullgraph, debug, len(nodes), nodes, ops, params, input_list, output_list, edges, passes, cache_keys, tags)
        if function_name == "compile_add_input":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            inputs = list(inputs)
            inputs.append(str(args[1]))
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready or len(inputs) > 0, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_add_output":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            outputs = list(outputs)
            outputs.append(str(args[1]))
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready or len(outputs) > 0, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_add_pass":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            passes = list(passes)
            pass_name = str(args[1])
            passes.append(pass_name)
            return _compile_dict(name, backend, mode, True, lowered or pass_name in {"jit", "lower"}, compiled or pass_name == "compile", executed or pass_name == "execute", True, linearized or pass_name in {"lower", "compile", "execute"}, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_normalize":
            return _UNHANDLED
        if function_name == "compile_shape_specialize":
            return _UNHANDLED
        if function_name == "compile_fuse_linear_activation":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            nodes = list(nodes)
            ops = list(ops)
            params = list(params)
            edges = list(edges)
            tags = list(tags)
            fused = 0
            i = 0
            while i + 1 < len(ops):
                if ops[i] == "linear" and ops[i + 1] in {"gelu", "relu", "silu", "swish"}:
                    left_node = nodes[i]
                    right_node = nodes[i + 1]
                    fused_op = f"linear+{ops[i + 1]}"
                    fused_node = f"{left_node}+{right_node}"
                    ops[i] = fused_op
                    nodes[i] = fused_node
                    del nodes[i + 1]
                    del ops[i + 1]
                    del params[i + 1]
                    edges = [
                        edge.replace(f"->{left_node}", f"->{fused_node}")
                        .replace(f"->{right_node}", f"->{fused_node}")
                        .replace(f"{right_node}->", f"{fused_node}->")
                        for edge in edges
                    ]
                    deduped_edges: list[str] = []
                    for edge in edges:
                        if edge not in deduped_edges:
                            deduped_edges.append(edge)
                    edges = deduped_edges
                    tags.append(f"fused={fused_op}@{left_node}")
                    fused += 1
                    i += 1
                else:
                    i += 1
            node_count = len(nodes)
            passes = list(passes)
            passes.append("fuse_linear_activation")
            tags.append("fused=none" if fused == 0 else f"fused_count={fused}")
            return _compile_dict(name, backend, mode, True, lowered, compiled, executed, True, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_linearize":
            return _UNHANDLED
        if function_name == "compile_lower_graph":
            return _UNHANDLED
        if function_name == "compile_set_linearized":
            return _UNHANDLED
        if function_name == "compile_add_param":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            params = list(params)
            params.append(str(args[1]))
            return _compile_dict(name, backend, mode, True, lowered, compiled, executed, True, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_add_cache_key":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            cache_keys = list(cache_keys)
            cache_keys.append(str(args[1]))
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_add_tag":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            tags = list(tags)
            tags.append(str(args[1]))
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_set_captured":
            name, backend, mode, _, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            captured = bool(args[1])
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready or captured, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_set_lowered":
            name, backend, mode, captured, _, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            lowered = bool(args[1])
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready, linearized or lowered, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_set_compiled":
            name, backend, mode, captured, lowered, _, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            compiled = bool(args[1])
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready, linearized or compiled, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_set_executed":
            name, backend, mode, captured, lowered, compiled, _, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            executed = bool(args[1])
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready or executed, linearized or executed, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_set_dynamic":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, _, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready, linearized, bool(args[1]), fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_set_fullgraph":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, _, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, bool(args[1]), debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_set_debug":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, _, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            return _compile_dict(name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, bool(args[1]), node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags)
        if function_name == "compile_state_dict":
            return _compile_dict(*_compile_like(args[0]))
        if function_name == "compile_load_state_dict":
            return args[1]
        if function_name == "compile_to_stage":
            name, backend, mode, captured, lowered, compiled, executed, ready, linearized, dynamic, fullgraph, debug, node_count, nodes, ops, params, inputs, outputs, edges, passes, cache_keys, tags = _compile_like(args[0])
            control_enabled = dynamic or fullgraph or debug
            return _stage_dict(name, backend, mode, ready or captured, lowered or compiled or executed, compiled or executed, executed, passes, params, control_enabled, fullgraph, dynamic, mode == "max-autotune", 1 if dynamic else 0, [], [])
        if function_name == "stage_to_compile":
            name, backend, mode, jit_enabled, lowered, compiled, executed, stages, params = _stage_like(args[0])
            control_enabled, control_cond_enabled, control_loop_enabled, control_scan_enabled, control_iterations, control_branches, control_params = _stage_control_like(args[0])
            return _compile_dict(name, backend, mode, jit_enabled or len(stages) > 0, lowered, compiled, executed, jit_enabled or lowered or compiled or executed or len(stages) > 0, lowered or compiled or executed, control_loop_enabled, control_cond_enabled, False, len(stages), list(stages), list(stages), list(params), [], [], [], list(stages), [], [])
    if module_name == "tensor":
        if function_name == "tensor_backward_add_grad_a":
            grad_a, _, _ = _tensor_like(args[0])
            return _tensor_dict(np.array(grad_a, copy=True), list(np.asarray(grad_a).shape), False)
        if function_name == "tensor_backward_add_grad_b":
            grad_b, _, _ = _tensor_like(args[0])
            return _tensor_dict(np.array(grad_b, copy=True), list(np.asarray(grad_b).shape), False)
        if function_name == "tensor_backward_mul_grad_a":
            data_a, shape_a, _ = _tensor_like(args[0])
            data_b, shape_b, _ = _tensor_like(args[1])
            upstream_data, upstream_shape, _ = _tensor_like(args[2])
            return _tensor_dict(np.multiply(upstream_data, data_b), upstream_shape, False)
        if function_name == "tensor_backward_mul_grad_b":
            data_a, shape_a, _ = _tensor_like(args[0])
            data_b, shape_b, _ = _tensor_like(args[1])
            upstream_data, upstream_shape, _ = _tensor_like(args[2])
            return _tensor_dict(np.multiply(upstream_data, data_a), upstream_shape, False)
        if function_name == "tensor_backward_sub_grad_a":
            upstream_data, upstream_shape, _ = _tensor_like(args[0])
            return _tensor_dict(np.array(upstream_data, copy=True), upstream_shape, False)
        if function_name == "tensor_backward_sub_grad_b":
            upstream_data, upstream_shape, _ = _tensor_like(args[0])
            return _tensor_dict(np.negative(upstream_data), upstream_shape, False)
        if function_name == "tensor_backward_div_grad_a":
            data_a, shape_a, _ = _tensor_like(args[0])
            data_b, shape_b, _ = _tensor_like(args[1])
            upstream_data, upstream_shape, _ = _tensor_like(args[2])
            return _tensor_dict(np.divide(upstream_data, data_b), upstream_shape, False)
        if function_name == "tensor_backward_div_grad_b":
            data_a, shape_a, _ = _tensor_like(args[0])
            data_b, shape_b, _ = _tensor_like(args[1])
            upstream_data, upstream_shape, _ = _tensor_like(args[2])
            numerator = np.multiply(upstream_data, data_a)
            denominator = np.multiply(data_b, data_b)
            return _tensor_dict(np.negative(np.divide(numerator, denominator)), upstream_shape, False)
        if function_name == "tensor_backward_matmul_grad_a":
            data_a, shape_a, _ = _tensor_like(args[0])
            data_b, shape_b, _ = _tensor_like(args[1])
            upstream_data, upstream_shape, _ = _tensor_like(args[2])
            if len(shape_a) == 1 and len(shape_b) == 1:
                return _tensor_dict(np.asarray(data_b) * float(np.asarray(upstream_data).reshape(-1)[0]), shape_b, False)
            if len(shape_a) == 2 and len(shape_b) == 2:
                return _tensor_dict(np.matmul(upstream_data, np.asarray(data_b).T), shape_a, False)
            if len(shape_a) == 2 and len(shape_b) == 1:
                return _tensor_dict(np.multiply(np.asarray(upstream_data).reshape(-1, 1), np.asarray(data_b).reshape(1, -1)), shape_a, False)
            return _tensor_dict(np.zeros_like(np.asarray(data_a)), shape_a, False)
        if function_name == "tensor_backward_matmul_grad_b":
            data_a, shape_a, _ = _tensor_like(args[0])
            data_b, shape_b, _ = _tensor_like(args[1])
            upstream_data, upstream_shape, _ = _tensor_like(args[2])
            if len(shape_a) == 1 and len(shape_b) == 1:
                return _tensor_dict(np.asarray(data_a) * float(np.asarray(upstream_data).reshape(-1)[0]), shape_a, False)
            if len(shape_a) == 2 and len(shape_b) == 2:
                return _tensor_dict(np.matmul(np.asarray(data_a).T, upstream_data), shape_b, False)
            if len(shape_a) == 2 and len(shape_b) == 1:
                return _tensor_dict(np.matmul(np.asarray(data_a).T, upstream_data), shape_b, False)
            return _tensor_dict(np.zeros_like(np.asarray(data_b)), shape_b, False)
        if function_name == "tensor_backward_sum_grad":
            data_a, shape_a, _ = _tensor_like(args[0])
            upstream_data, upstream_shape, _ = _tensor_like(args[1])
            scalar = float(np.asarray(upstream_data).reshape(-1)[0]) if np.asarray(upstream_data).size else 0.0
            return _tensor_dict(np.full_like(np.asarray(data_a), scalar), shape_a, False)
        if function_name == "tensor_backward_mean_grad":
            data_a, shape_a, _ = _tensor_like(args[0])
            upstream_data, upstream_shape, _ = _tensor_like(args[1])
            scalar = float(np.asarray(upstream_data).reshape(-1)[0]) if np.asarray(upstream_data).size else 0.0
            denom = float(len(np.asarray(data_a))) if len(np.asarray(data_a)) else 1.0
            return _tensor_dict(np.full_like(np.asarray(data_a), scalar / denom), shape_a, False)
        if function_name == "tensor_backward_sum_dim_grad":
            data_a, shape_a, _ = _tensor_like(args[0])
            upstream_data, upstream_shape, _ = _tensor_like(args[1])
            dim = int(args[2])
            keepdim = bool(args[3])
            axis = dim if dim >= 0 else dim + len(shape_a)
            expanded = np.asarray(upstream_data)
            if expanded.size == 1:
                return _tensor_dict(np.full(shape_a, float(expanded.reshape(-1)[0])), shape_a, False)
            if not keepdim:
                expanded = np.expand_dims(expanded, axis=axis)
            return _tensor_dict(np.broadcast_to(expanded, shape_a), shape_a, False)
        if function_name == "tensor_backward_mean_dim_grad":
            data_a, shape_a, _ = _tensor_like(args[0])
            upstream_data, upstream_shape, _ = _tensor_like(args[1])
            dim = int(args[2])
            keepdim = bool(args[3])
            axis = dim if dim >= 0 else dim + len(shape_a)
            expanded = np.asarray(upstream_data)
            if expanded.size == 1:
                denom = float(shape_a[axis]) if shape_a else 1.0
                return _tensor_dict(np.full(shape_a, float(expanded.reshape(-1)[0]) / denom), shape_a, False)
            if not keepdim:
                expanded = np.expand_dims(expanded, axis=axis)
            denom = float(shape_a[axis]) if shape_a else 1.0
            return _tensor_dict(np.broadcast_to(expanded, shape_a) / denom, shape_a, False)
        if function_name == "negative":
            data_a, shape_a, req_a = _tensor_like(args[0])
            return _tensor_dict(np.negative(data_a), shape_a, req_a)
        if function_name == "abs":
            data_a, shape_a, req_a = _tensor_like(args[0])
            return _tensor_dict(np.abs(data_a), shape_a, req_a)
        if function_name == "square":
            data_a, shape_a, req_a = _tensor_like(args[0])
            return _tensor_dict(np.square(data_a), shape_a, req_a)
        if function_name == "reciprocal":
            data_a, shape_a, req_a = _tensor_like(args[0])
            return _tensor_dict(np.reciprocal(data_a), shape_a, req_a)
        if function_name == "maximum":
            data_a, shape_a, req_a = _tensor_like(args[0])
            data_b, shape_b, req_b = _tensor_like(args[1])
            return _tensor_dict(np.maximum(data_a, data_b), list(np.broadcast_shapes(tuple(shape_a), tuple(shape_b))), req_a or req_b)
        if function_name == "minimum":
            data_a, shape_a, req_a = _tensor_like(args[0])
            data_b, shape_b, req_b = _tensor_like(args[1])
            return _tensor_dict(np.minimum(data_a, data_b), list(np.broadcast_shapes(tuple(shape_a), tuple(shape_b))), req_a or req_b)
        if function_name == "broadcast_to":
            data_a, shape_a, req_a = _tensor_like(args[0])
            target_shape = [int(dim) for dim in args[1]]
            return _tensor_dict(np.broadcast_to(data_a, target_shape), target_shape, req_a)
        if function_name == "concatenate":
            data_a, shape_a, req_a = _tensor_like(args[0])
            data_b, shape_b, req_b = _tensor_like(args[1])
            dim = int(args[2])
            axis = dim if dim >= 0 else dim + len(shape_a)
            shape_out = list(shape_a)
            shape_out[axis] = shape_out[axis] + shape_b[axis]
            return _tensor_dict(np.concatenate([data_a, data_b], axis=axis), shape_out, req_a or req_b)
        if function_name == "stack":
            data_a, shape_a, req_a = _tensor_like(args[0])
            data_b, shape_b, req_b = _tensor_like(args[1])
            dim = int(args[2])
            axis = dim if dim >= 0 else dim + len(shape_a) + 1
            stacked = np.stack([data_a, data_b], axis=axis)
            return _tensor_dict(stacked, list(stacked.shape), req_a or req_b)
        if function_name in {
            "trace_op",
            "trace_op_with_param",
            "trace_add",
            "trace_mul",
            "trace_matmul",
            "trace_sum",
            "trace_mean",
            "trace_sum_dim",
            "trace_mean_dim",
            "trace_broadcast_to",
            "trace_concatenate",
            "trace_stack",
            "trace_to_transform_chain",
            "trace_to_jaxpr",
        }:
            if function_name == "trace_op":
                state = args[0]
                op = str(args[1])
                param = ""
                inputs = []
                outputs = []
                eqns = [{"primitive": op, "params": [], "inputs": [], "outputs": []}]
            elif function_name == "trace_op_with_param":
                state = args[0]
                op = str(args[1])
                param = str(args[2])
                inputs = []
                outputs = []
                eqns = [{"primitive": op, "params": [param], "inputs": [], "outputs": []}]
            elif function_name == "trace_add":
                state = args[0]
                op = "add"
                param = ""
                inputs = ["arg0", "arg1"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_mul":
                state = args[0]
                op = "mul"
                param = ""
                inputs = ["arg0", "arg1"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_matmul":
                state = args[0]
                op = "matmul"
                param = ""
                inputs = ["arg0", "arg1"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_sum":
                state = args[0]
                op = "sum"
                param = ""
                inputs = ["arg0"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_mean":
                state = args[0]
                op = "mean"
                param = ""
                inputs = ["arg0"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_sum_dim":
                state = args[0]
                op = "sum_dim"
                param = f"dim={int(args[2])};keepdim={bool(args[3])}"
                inputs = ["arg0"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [param], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_mean_dim":
                state = args[0]
                op = "mean_dim"
                param = f"dim={int(args[2])};keepdim={bool(args[3])}"
                inputs = ["arg0"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [param], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_broadcast_to":
                state = args[0]
                op = "broadcast_to"
                param = f"shape={list(args[2])}"
                inputs = ["arg0"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [param], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_concatenate":
                state = args[0]
                op = "concatenate"
                param = f"dim={int(args[3])}"
                inputs = ["arg0", "arg1"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [param], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_stack":
                state = args[0]
                op = "stack"
                param = f"dim={int(args[3])}"
                inputs = ["arg0", "arg1"]
                outputs = ["out0"]
                eqns = [{"primitive": op, "params": [param], "inputs": inputs, "outputs": outputs}]
            elif function_name == "trace_to_transform_chain":
                state = args[0]
                name, active, linearized, op_count, ops, params, tags = _tracer_like(state)
                inputs, outputs = _tracer_inputs_outputs(state)
                return {"steps": list(ops), "params": list(params), "inputs": list(inputs), "outputs": list(outputs), "eqns": _tracer_eqns(state), "ready": bool(active or op_count > 0), "linearized": bool(linearized)}
            else:
                state = args[0]
                return invoke_runtime_function("ad/jaxpr", "jaxpr_from_tracer", state, str(args[1]))
            name, active, linearized, op_count, ops, params, tags = _tracer_like(state)
            tracer_inputs, tracer_outputs = _tracer_inputs_outputs(state)
            ops = list(ops)
            params = list(params)
            ops.append(op)
            params.append(param)
            tracer_inputs = list(tracer_inputs)
            tracer_outputs = list(tracer_outputs)
            tracer_inputs.extend(inputs)
            tracer_outputs.extend(outputs)
            existing_eqns = _tracer_eqns(state)
            existing_eqns = list(existing_eqns)
            existing_eqns.extend(eqns)
            return _tracer_dict(name, True, linearized, len(ops), ops, params, tags, tracer_inputs, tracer_outputs, existing_eqns)
    if module_name == "ad/tracer":
        if function_name == "new_tracer_state":
            return _tracer_dict(str(args[0]), False, False, 0, [], [], [], [], [])
        if function_name == "tracer_name":
            name, _, _, _, _, _, _ = _tracer_like(args[0])
            return name
        if function_name == "tracer_active":
            _, active, _, _, _, _, _ = _tracer_like(args[0])
            return active
        if function_name == "tracer_linearized":
            _, _, linearized, _, _, _, _ = _tracer_like(args[0])
            return linearized
        if function_name == "tracer_op_count":
            _, _, _, op_count, _, _, _ = _tracer_like(args[0])
            return op_count
        if function_name == "tracer_tag_count":
            _, _, _, _, _, _, tags = _tracer_like(args[0])
            return len(tags)
        if function_name == "tracer_param_count":
            _, _, _, _, _, params, _ = _tracer_like(args[0])
            return len(params)
        if function_name == "tracer_input_count":
            _, _, _, _, _, inputs, _, _ = _tracer_like(args[0])
            return len(inputs)
        if function_name == "tracer_output_count":
            _, _, _, _, _, _, outputs, _ = _tracer_like(args[0])
            return len(outputs)
        if function_name == "tracer_eqn_count":
            return len(_tracer_eqns(args[0]))
        if function_name == "tracer_has_op":
            _, _, _, _, ops, _, _ = _tracer_like(args[0])
            return str(args[1]) in ops
        if function_name == "tracer_has_input":
            _, _, _, _, _, inputs, _, _ = _tracer_like(args[0])
            return str(args[1]) in inputs
        if function_name == "tracer_has_output":
            _, _, _, _, _, _, outputs, _ = _tracer_like(args[0])
            return str(args[1]) in outputs
        if function_name == "tracer_has_eqn":
            return any(eqn["primitive"] == str(args[1]) for eqn in _tracer_eqns(args[0]))
        if function_name == "tracer_has_param":
            _, _, _, _, _, params, _ = _tracer_like(args[0])
            return str(args[1]) in params
        if function_name == "tracer_has_tag":
            _, _, _, _, _, _, tags = _tracer_like(args[0])
            return str(args[1]) in tags
        if function_name == "tracer_add_op":
            name, active, linearized, _, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            ops = list(ops)
            ops.append(str(args[1]))
            eqns = list(eqns)
            eqns.append({"primitive": str(args[1]), "params": [], "inputs": [], "outputs": []})
            return _tracer_dict(name, True, linearized, len(ops), ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_add_op_with_param":
            name, active, linearized, _, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            ops = list(ops)
            params = list(params)
            ops.append(str(args[1]))
            params.append(str(args[2]))
            eqns = _tracer_eqns(args[0])
            eqns = list(eqns)
            eqns.append({"primitive": str(args[1]), "params": [str(args[2])], "inputs": [], "outputs": []})
            return _tracer_dict(name, True, linearized, len(ops), ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_add_eqn":
            return _invoke_special_module_function(module_name, "tracer_add_eqn_with_io", (args[0], args[1], [], [], []))
        if function_name == "tracer_add_eqn_with_param":
            return _invoke_special_module_function(module_name, "tracer_add_eqn_with_io", (args[0], args[1], [str(args[2])], [], []))
        if function_name == "tracer_add_eqn_with_io":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            primitive = str(args[1])
            eqn_params = _string_list(args[2]) if len(args) > 2 else []
            eqn_inputs = _string_list(args[3]) if len(args) > 3 else []
            eqn_outputs = _string_list(args[4]) if len(args) > 4 else []
            ops = list(ops)
            params = list(params)
            eqns = list(eqns)
            ops.append(primitive)
            params.append(",".join(eqn_params))
            inputs = list(inputs) + list(eqn_inputs)
            outputs = list(outputs) + list(eqn_outputs)
            eqns.append({"primitive": primitive, "params": list(eqn_params), "inputs": list(eqn_inputs), "outputs": list(eqn_outputs)})
            return _tracer_dict(name, True, linearized, len(ops), ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_add_input":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            inputs = list(inputs)
            inputs.append(str(args[1]))
            return _tracer_dict(name, active, linearized, op_count, ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_add_output":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            outputs = list(outputs)
            outputs.append(str(args[1]))
            return _tracer_dict(name, active, linearized, op_count, ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_add_tag":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            tags = list(tags)
            tags.append(str(args[1]))
            return _tracer_dict(name, active, linearized, op_count, ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_clear_tags":
            name, active, linearized, op_count, ops, params, _ = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            return _tracer_dict(name, active, linearized, op_count, ops, params, [], inputs, outputs, eqns)
        if function_name == "tracer_clear_inputs":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            _, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            return _tracer_dict(name, active, linearized, op_count, ops, params, tags, [], outputs, eqns)
        if function_name == "tracer_clear_outputs":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, _ = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            return _tracer_dict(name, active, linearized, op_count, ops, params, tags, inputs, [], eqns)
        if function_name == "tracer_clear_eqns":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            return _tracer_dict(name, active, linearized, op_count, ops, params, tags, inputs, outputs, [])
        if function_name == "tracer_clear_params":
            name, active, linearized, op_count, ops, _, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            return _tracer_dict(name, active, linearized, op_count, ops, [], tags, inputs, outputs, eqns)
        if function_name == "tracer_set_active":
            name, _, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            return _tracer_dict(name, bool(args[1]), linearized, op_count, ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_set_linearized":
            name, active, _, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            return _tracer_dict(name, active, bool(args[1]), op_count, ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_state_dict":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            eqns = _tracer_eqns(args[0])
            return _tracer_dict(name, active, linearized, op_count, ops, params, tags, inputs, outputs, eqns)
        if function_name == "tracer_load_state_dict":
            return args[1]
        if function_name == "tracer_capture":
            return _invoke_special_module_function(module_name, "tracer_add_op", args)
        if function_name == "tracer_capture_with_param":
            return _invoke_special_module_function(module_name, "tracer_add_op_with_param", args)
        if function_name == "tracer_capture_with_io":
            return _invoke_special_module_function(module_name, "tracer_add_eqn_with_io", args)
        if function_name == "tracer_to_transform_chain":
            name, active, linearized, op_count, ops, params, tags = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            return {"steps": list(ops), "params": list(params), "inputs": list(inputs), "outputs": list(outputs), "ready": bool(active or op_count > 0), "linearized": bool(linearized)}
        if function_name == "transform_chain_to_tracer":
            chain = args[0]
            name = str(args[1])
            steps = _string_list(chain.get("steps", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "steps", []))
            params = _string_list(chain.get("params", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "params", []))
            inputs = _string_list(chain.get("inputs", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "inputs", []))
            outputs = _string_list(chain.get("outputs", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "outputs", []))
            eqns = _transform_chain_eqns(chain)
            if eqns:
                steps = [eqn["primitive"] for eqn in eqns]
                params = [",".join(eqn["params"]) for eqn in eqns]
                inputs = [item for eqn in eqns for item in eqn["inputs"]]
                outputs = [item for eqn in eqns for item in eqn["outputs"]]
            ready = bool(chain.get("ready", False)) if isinstance(chain, dict) else bool(getattr(chain, "ready", False))
            linearized = bool(chain.get("linearized", False)) if isinstance(chain, dict) else bool(getattr(chain, "linearized", False))
            if not eqns:
                eqns = [{"primitive": step, "params": [param] if param else [], "inputs": [], "outputs": []} for step, param in zip(steps, params)]
            return _tracer_dict(name, ready, linearized, len(steps), steps, params, [], inputs, outputs, eqns)
    if module_name == "ad/jaxpr":
        if function_name == "new_jaxpr_graph":
            return _jaxpr_dict(str(args[0]), 0, [], [], [], [], False, False, [])
        if function_name == "jaxpr_name":
            name, _, _, _, _, _, _, _ = _jaxpr_like(args[0])
            return name
        if function_name == "jaxpr_eqn_count":
            _, eqn_count, _, _, _, _, _, _ = _jaxpr_like(args[0])
            return eqn_count
        if function_name == "jaxpr_primitive_count":
            _, _, primitives, _, _, _, _, _ = _jaxpr_like(args[0])
            return len(primitives)
        if function_name == "jaxpr_param_count":
            _, _, _, params, _, _, _, _ = _jaxpr_like(args[0])
            return len(params)
        if function_name == "jaxpr_input_count":
            _, _, _, _, inputs, _, _, _ = _jaxpr_like(args[0])
            return len(inputs)
        if function_name == "jaxpr_output_count":
            _, _, _, _, _, outputs, _, _ = _jaxpr_like(args[0])
            return len(outputs)
        if function_name == "jaxpr_has_primitive":
            _, _, primitives, _, _, _, _, _ = _jaxpr_like(args[0])
            return str(args[1]) in primitives
        if function_name == "jaxpr_ready":
            _, _, _, _, _, _, ready, _ = _jaxpr_like(args[0])
            return ready
        if function_name == "jaxpr_is_linearized":
            _, _, _, _, _, _, _, linearized = _jaxpr_like(args[0])
            return linearized
        if function_name == "jaxpr_add_eqn":
            name, eqn_count, primitives, params, inputs, outputs, ready, linearized = _jaxpr_like(args[0])
            primitives = list(primitives)
            primitives.append(str(args[1]))
            params = list(params)
            params.append("")
            eqns = _jaxpr_eqns(args[0])
            eqns = list(eqns)
            eqns.append({"primitive": str(args[1]), "params": [], "inputs": [], "outputs": []})
            return _jaxpr_dict(name, len(primitives), primitives, params, inputs, outputs, True, linearized, eqns)
        if function_name == "jaxpr_add_eqn_with_params":
            name, eqn_count, primitives, params, inputs, outputs, ready, linearized = _jaxpr_like(args[0])
            primitives = list(primitives)
            params = list(params)
            primitives.append(str(args[1]))
            params.append(",".join(str(item) for item in args[2]))
            eqns = _jaxpr_eqns(args[0])
            eqns = list(eqns)
            eqns.append({"primitive": str(args[1]), "params": _string_list(args[2]), "inputs": [], "outputs": []})
            return _jaxpr_dict(name, len(primitives), primitives, params, inputs, outputs, True, linearized, eqns)
        if function_name == "jaxpr_add_eqn_with_io":
            name, eqn_count, primitives, params, inputs, outputs, ready, linearized = _jaxpr_like(args[0])
            primitives = list(primitives)
            params = list(params)
            primitives.append(str(args[1]))
            param_list = _string_list(args[2]) if len(args) > 2 else []
            params.append(",".join(param_list))
            eqns = _jaxpr_eqns(args[0])
            eqns = list(eqns)
            eqns.append({
                "primitive": str(args[1]),
                "params": list(param_list),
                "inputs": _string_list(args[3]) if len(args) > 3 else [],
                "outputs": _string_list(args[4]) if len(args) > 4 else [],
            })
            return _jaxpr_dict(name, len(primitives), primitives, params, inputs, outputs, True, linearized, eqns)
        if function_name == "jaxpr_add_input":
            name, eqn_count, primitives, params, inputs, outputs, ready, linearized = _jaxpr_like(args[0])
            inputs = list(inputs)
            inputs.append(str(args[1]))
            return _jaxpr_dict(name, eqn_count, primitives, params, inputs, outputs, ready, linearized, _jaxpr_eqns(args[0]))
        if function_name == "jaxpr_add_output":
            name, eqn_count, primitives, params, inputs, outputs, ready, linearized = _jaxpr_like(args[0])
            outputs = list(outputs)
            outputs.append(str(args[1]))
            return _jaxpr_dict(name, eqn_count, primitives, params, inputs, outputs, ready, linearized, _jaxpr_eqns(args[0]))
        if function_name == "jaxpr_state_dict":
            return _jaxpr_dict(*_jaxpr_like(args[0]), _jaxpr_eqns(args[0]))
        if function_name == "jaxpr_load_state_dict":
            return args[1]
        if function_name == "jaxpr_from_tracer":
            _, active, linearized, op_count, ops, params, _ = _tracer_like(args[0])
            inputs, outputs = _tracer_inputs_outputs(args[0])
            return _jaxpr_dict(str(args[1]), op_count, list(ops), list(params), list(inputs), list(outputs), active or op_count > 0, linearized, _tracer_eqns(args[0]))
        if function_name == "jaxpr_to_tracer":
            name, eqn_count, primitives, params, inputs, outputs, ready, linearized = _jaxpr_like(args[0])
            return _tracer_dict(name, ready, linearized, eqn_count, list(primitives), list(params), [], list(inputs), list(outputs), _jaxpr_eqns(args[0]))
        if function_name == "jaxpr_capture":
            return _invoke_special_module_function(module_name, "jaxpr_add_eqn", args)
        if function_name == "jaxpr_capture_with_params":
            return _invoke_special_module_function(module_name, "jaxpr_add_eqn_with_params", args)
        if function_name == "jaxpr_capture_with_io":
            return _invoke_special_module_function(module_name, "jaxpr_add_eqn_with_io", args)
        if function_name == "jaxpr_to_transform_chain":
            name, eqn_count, primitives, params, inputs, outputs, ready, linearized = _jaxpr_like(args[0])
            return {"steps": list(primitives), "params": list(params), "inputs": list(inputs), "outputs": list(outputs), "eqns": _jaxpr_eqns(args[0]), "ready": bool(ready or eqn_count > 0), "linearized": bool(linearized)}
        if function_name == "transform_chain_to_jaxpr":
            chain = args[0]
            steps = _string_list(chain.get("steps", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "steps", []))
            params = _string_list(chain.get("params", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "params", []))
            inputs = _string_list(chain.get("inputs", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "inputs", []))
            outputs = _string_list(chain.get("outputs", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "outputs", []))
            eqns = _transform_chain_eqns(chain)
            if eqns:
                steps = [eqn["primitive"] for eqn in eqns]
                params = [",".join(eqn["params"]) for eqn in eqns]
                inputs = [item for eqn in eqns for item in eqn["inputs"]]
                outputs = [item for eqn in eqns for item in eqn["outputs"]]
            ready = bool(chain.get("ready", False)) if isinstance(chain, dict) else bool(getattr(chain, "ready", False))
            linearized = bool(chain.get("linearized", False)) if isinstance(chain, dict) else bool(getattr(chain, "linearized", False))
            if not eqns:
                eqns = [{"primitive": step, "params": [param] if param else [], "inputs": [], "outputs": []} for step, param in zip(steps, params)]
            return _jaxpr_dict(str(args[1]), len(steps), steps, params, inputs, outputs, ready, linearized, eqns)
    if module_name == "tensor/batch":
        if function_name == "new_batch_state":
            return _batch_dict(str(args[0]), False, int(args[1]), int(args[2]), [], [])
        if function_name == "batch_name":
            name, _, _, _, _, _ = _batch_like(args[0])
            return name
        if function_name == "batch_active":
            _, active, _, _, _, _ = _batch_like(args[0])
            return active
        if function_name == "batch_batch_size":
            _, _, batch_size, _, _, _ = _batch_like(args[0])
            return batch_size
        if function_name == "batch_batch_dim":
            _, _, _, batch_dim, _, _ = _batch_like(args[0])
            return batch_dim
        if function_name == "batch_primitive_count":
            _, _, _, _, primitives, _ = _batch_like(args[0])
            return len(primitives)
        if function_name == "batch_param_count":
            _, _, _, _, _, params = _batch_like(args[0])
            return len(params)
        if function_name == "batch_has_primitive":
            _, _, _, _, primitives, _ = _batch_like(args[0])
            return str(args[1]) in primitives
        if function_name == "batch_has_param":
            _, _, _, _, _, params = _batch_like(args[0])
            return str(args[1]) in params
        if function_name == "batch_add_primitive":
            name, active, batch_size, batch_dim, primitives, params = _batch_like(args[0])
            primitives = list(primitives)
            primitives.append(str(args[1]))
            return _batch_dict(name, True, batch_size, batch_dim, primitives, params)
        if function_name == "batch_add_param":
            name, active, batch_size, batch_dim, primitives, params = _batch_like(args[0])
            params = list(params)
            params.append(str(args[1]))
            return _batch_dict(name, True, batch_size, batch_dim, primitives, params)
        if function_name == "batch_set_active":
            name, _, batch_size, batch_dim, primitives, params = _batch_like(args[0])
            return _batch_dict(name, bool(args[1]), batch_size, batch_dim, primitives, params)
        if function_name == "batch_set_batch_size":
            name, active, _, batch_dim, primitives, params = _batch_like(args[0])
            return _batch_dict(name, active, int(args[1]), batch_dim, primitives, params)
        if function_name == "batch_set_batch_dim":
            name, active, batch_size, _, primitives, params = _batch_like(args[0])
            return _batch_dict(name, active, batch_size, int(args[1]), primitives, params)
        if function_name == "batch_clear_primitives":
            name, active, batch_size, batch_dim, _, params = _batch_like(args[0])
            return _batch_dict(name, active, batch_size, batch_dim, [], params)
        if function_name == "batch_clear_params":
            name, active, batch_size, batch_dim, primitives, _ = _batch_like(args[0])
            return _batch_dict(name, active, batch_size, batch_dim, primitives, [])
        if function_name == "batch_state_dict":
            name, active, batch_size, batch_dim, primitives, params = _batch_like(args[0])
            return _batch_dict(name, active, batch_size, batch_dim, primitives, params)
        if function_name == "batch_load_state_dict":
            return args[1]
        if function_name == "batch_to_transform_chain":
            name, active, batch_size, batch_dim, primitives, params = _batch_like(args[0])
            return {
                "steps": list(primitives),
                "params": list(params),
                "inputs": [],
                "outputs": [],
                "eqns": [{"primitive": primitive, "params": [param] if param else [], "inputs": [], "outputs": []} for primitive, param in zip(primitives, params)],
                "ready": bool(active or len(primitives) > 0),
                "linearized": False,
            }
        if function_name == "transform_chain_to_batch":
            chain = args[0]
            name = str(args[1])
            batch_size = int(args[2])
            batch_dim = int(args[3])
            primitives = _string_list(chain.get("steps", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "steps", []))
            params = _string_list(chain.get("params", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "params", []))
            eqns = _transform_chain_eqns(chain)
            if eqns:
                primitives = [eqn["primitive"] for eqn in eqns]
                params = [",".join(eqn["params"]) for eqn in eqns]
            active = bool(chain.get("ready", False)) if isinstance(chain, dict) else bool(getattr(chain, "ready", False))
            return _batch_dict(name, active, batch_size, batch_dim, primitives, params)
        if function_name == "vmap_unary":
            primitive = str(args[0])
            data, shape, req = _tensor_like(args[1])
            data = np.asarray(data)
            if primitive == "negative":
                out = np.negative(data)
                return _tensor_dict(out, shape, req)
            if primitive == "abs":
                out = np.abs(data)
                return _tensor_dict(out, shape, req)
            if primitive == "square":
                out = np.multiply(data, data)
                return _tensor_dict(out, shape, req)
            if primitive == "reciprocal":
                out = np.divide(1.0, data)
                return _tensor_dict(out, shape, req)
            if primitive == "sum" or primitive == "mean":
                if not shape:
                    return _tensor_dict(np.array(data, copy=True), shape, req)
                batch = shape[0]
                if batch <= 0:
                    return _tensor_dict(np.asarray([]), [0], req)
                reshaped = data.reshape(batch, -1)
                if primitive == "sum":
                    out = reshaped.sum(axis=1)
                else:
                    out = reshaped.mean(axis=1)
                return _tensor_dict(out, [batch], req)
            return _tensor_dict(data, shape, req)
        if function_name == "vmap_binary":
            primitive = str(args[0])
            data_a, shape_a, req_a = _tensor_like(args[1])
            data_b, shape_b, req_b = _tensor_like(args[2])
            np_a = np.asarray(data_a)
            np_b = np.asarray(data_b)
            if primitive == "add":
                out = np.add(np_a, np_b)
            elif primitive == "sub":
                out = np.subtract(np_a, np_b)
            elif primitive == "mul":
                out = np.multiply(np_a, np_b)
            elif primitive == "div":
                out = np.divide(np_a, np_b)
            elif primitive == "maximum":
                out = np.maximum(np_a, np_b)
            elif primitive == "minimum":
                out = np.minimum(np_a, np_b)
            elif primitive == "matmul":
                out = np.matmul(np_a, np_b)
            elif primitive == "concatenate":
                out = np.concatenate([np_a, np_b], axis=0)
            elif primitive == "stack":
                out = np.stack([np_a, np_b], axis=0)
            else:
                out = np.add(np_a, np_b)
            return _tensor_dict(out, list(np.asarray(out).shape), req_a or req_b)
        if function_name == "vmap_ternary":
            primitive = str(args[0])
            if primitive == "where":
                cond_data, cond_shape, cond_req = _tensor_like(args[1])
                x_data, x_shape, x_req = _tensor_like(args[2])
                y_data, y_shape, y_req = _tensor_like(args[3])
                out = np.where(np.asarray(cond_data).astype(bool), np.asarray(x_data), np.asarray(y_data))
                return _tensor_dict(out, list(np.asarray(out).shape), cond_req or x_req or y_req)
            return _tensor_dict(np.asarray(_tensor_like(args[2])[0]), _tensor_like(args[2])[1], _tensor_like(args[2])[2])
        if function_name == "vmap_add":
            return _invoke_special_module_function(module_name, "vmap_binary", ("add", args[0], args[1]))
        if function_name == "vmap_sub":
            return _invoke_special_module_function(module_name, "vmap_binary", ("sub", args[0], args[1]))
        if function_name == "vmap_mul":
            return _invoke_special_module_function(module_name, "vmap_binary", ("mul", args[0], args[1]))
        if function_name == "vmap_div":
            return _invoke_special_module_function(module_name, "vmap_binary", ("div", args[0], args[1]))
        if function_name == "vmap_maximum":
            return _invoke_special_module_function(module_name, "vmap_binary", ("maximum", args[0], args[1]))
        if function_name == "vmap_minimum":
            return _invoke_special_module_function(module_name, "vmap_binary", ("minimum", args[0], args[1]))
        if function_name == "vmap_matmul":
            return _invoke_special_module_function(module_name, "vmap_binary", ("matmul", args[0], args[1]))
        if function_name == "vmap_sum":
            return _invoke_special_module_function(module_name, "vmap_unary", ("sum", args[0]))
        if function_name == "vmap_mean":
            return _invoke_special_module_function(module_name, "vmap_unary", ("mean", args[0]))
        if function_name == "vmap_negative":
            return _invoke_special_module_function(module_name, "vmap_unary", ("negative", args[0]))
        if function_name == "vmap_abs":
            return _invoke_special_module_function(module_name, "vmap_unary", ("abs", args[0]))
        if function_name == "vmap_square":
            return _invoke_special_module_function(module_name, "vmap_unary", ("square", args[0]))
        if function_name == "vmap_reciprocal":
            return _invoke_special_module_function(module_name, "vmap_unary", ("reciprocal", args[0]))
        if function_name == "vmap_where":
            return _invoke_special_module_function(module_name, "vmap_ternary", ("where", args[0], args[1], args[2]))
    if module_name == "runtime/control":
        if function_name == "new_control_state":
            return _control_dict(str(args[0]), False, False, False, int(args[1]), [], [])
        if function_name == "control_name":
            name, _, _, _, _, _, _ = _control_like(args[0])
            return name
        if function_name == "control_cond_enabled":
            _, cond_enabled, _, _, _, _, _ = _control_like(args[0])
            return cond_enabled
        if function_name == "control_loop_enabled":
            _, _, loop_enabled, _, _, _, _ = _control_like(args[0])
            return loop_enabled
        if function_name == "control_scan_enabled":
            _, _, _, scan_enabled, _, _, _ = _control_like(args[0])
            return scan_enabled
        if function_name == "control_iterations":
            _, _, _, _, iterations, _, _ = _control_like(args[0])
            return iterations
        if function_name == "control_branch_count":
            _, _, _, _, _, branches, _ = _control_like(args[0])
            return len(branches)
        if function_name == "control_param_count":
            _, _, _, _, _, _, params = _control_like(args[0])
            return len(params)
        if function_name == "control_has_branch":
            _, _, _, _, _, branches, _ = _control_like(args[0])
            return str(args[1]) in branches
        if function_name == "control_has_param":
            _, _, _, _, _, _, params = _control_like(args[0])
            return str(args[1]) in params
        if function_name == "control_add_branch":
            name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params = _control_like(args[0])
            branches = list(branches)
            branches.append(str(args[1]))
            return _control_dict(name, True, loop_enabled, scan_enabled, iterations, branches, params)
        if function_name == "control_add_param":
            name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params = _control_like(args[0])
            params = list(params)
            params.append(str(args[1]))
            return _control_dict(name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params)
        if function_name == "control_set_cond_enabled":
            name, _, loop_enabled, scan_enabled, iterations, branches, params = _control_like(args[0])
            return _control_dict(name, bool(args[1]), loop_enabled, scan_enabled, iterations, branches, params)
        if function_name == "control_set_loop_enabled":
            name, cond_enabled, _, scan_enabled, iterations, branches, params = _control_like(args[0])
            return _control_dict(name, cond_enabled, bool(args[1]), scan_enabled, iterations, branches, params)
        if function_name == "control_set_scan_enabled":
            name, cond_enabled, loop_enabled, _, iterations, branches, params = _control_like(args[0])
            return _control_dict(name, cond_enabled, loop_enabled, bool(args[1]), iterations, branches, params)
        if function_name == "control_set_iterations":
            name, cond_enabled, loop_enabled, scan_enabled, _, branches, params = _control_like(args[0])
            return _control_dict(name, cond_enabled, loop_enabled, scan_enabled, int(args[1]), branches, params)
        if function_name == "control_clear_branches":
            name, cond_enabled, loop_enabled, scan_enabled, iterations, _, params = _control_like(args[0])
            return _control_dict(name, cond_enabled, loop_enabled, scan_enabled, iterations, [], params)
        if function_name == "control_clear_params":
            name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, _ = _control_like(args[0])
            return _control_dict(name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, [])
        if function_name == "control_state_dict":
            name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params = _control_like(args[0])
            return _control_dict(name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params)
        if function_name == "control_load_state_dict":
            return args[1]
        if function_name == "control_to_transform_chain":
            name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params = _control_like(args[0])
            eqns = [
                {
                    "primitive": branch,
                    "params": [param] if param else [],
                    "inputs": [],
                    "outputs": [],
                }
                for branch, param in zip(branches, params)
            ]
            return {
                "steps": list(branches),
                "params": list(params),
                "inputs": [],
                "outputs": [],
                "eqns": eqns,
                "ready": bool(cond_enabled or loop_enabled or scan_enabled or len(branches) > 0),
                "linearized": bool(loop_enabled or scan_enabled),
            }
        if function_name == "transform_chain_to_control":
            chain = args[0]
            name = str(args[1])
            iterations = int(args[2])
            branches = _string_list(chain.get("steps", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "steps", []))
            params = _string_list(chain.get("params", [])) if isinstance(chain, dict) else _string_list(getattr(chain, "params", []))
            eqns = _transform_chain_eqns(chain)
            if eqns:
                branches = [eqn["primitive"] for eqn in eqns]
                params = [",".join(eqn["params"]) for eqn in eqns]
            cond_enabled = "cond" in branches
            loop_enabled = "while_loop" in branches
            scan_enabled = "scan" in branches
            if len(branches) > 0 and not cond_enabled:
                cond_enabled = True
            return _control_dict(name, cond_enabled, loop_enabled, scan_enabled, iterations, branches, params)
        if function_name in {"cond", "control_select"}:
            if len(args) == 4:
                predicate = args[1]
                true_val = args[2]
                false_val = args[3]
            else:
                predicate = args[0]
                true_val = args[1]
                false_val = args[2]
            if isinstance(predicate, dict):
                pred_data, _, _ = _tensor_like(predicate)
                predicate = bool(np.asarray(pred_data).reshape(-1)[0]) if pred_data.size else False
            return true_val if bool(predicate) else false_val
        if function_name == "while_loop":
            if len(args) == 4:
                value = args[1]
                steps = int(args[2])
                op = str(args[3])
            else:
                value = args[0]
                steps = int(args[1])
                op = str(args[2])
            current = value
            i = 0
            while i < steps:
                if op == "add":
                    data, shape, req = _tensor_like(current)
                    current = _tensor_dict(np.asarray(data) + 1.0, shape, req)
                elif op == "mul":
                    data, shape, req = _tensor_like(current)
                    current = _tensor_dict(np.asarray(data) * 2.0, shape, req)
                elif op == "negate":
                    current = invoke_runtime_function("tensor", "negative", current)
                elif op == "square":
                    current = invoke_runtime_function("tensor", "square", current)
                i = i + 1
            return current
        if function_name == "scan_sum":
            value = args[1] if len(args) > 1 else args[0]
            data, shape, req = _tensor_like(value)
            arr = np.asarray(data, dtype=float).reshape(-1)
            out = np.cumsum(arr)
            return _tensor_dict(out, [len(out)], req)
        if function_name == "scan_prod":
            value = args[1] if len(args) > 1 else args[0]
            data, shape, req = _tensor_like(value)
            arr = np.asarray(data, dtype=float).reshape(-1)
            out = np.cumprod(arr)
            return _tensor_dict(out, [len(out)], req)
        if function_name == "scan":
            return _invoke_special_module_function(module_name, "scan_sum", args)
    if module_name == "tensor/autograd":
        if function_name == "tensor_backward_rule_add":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_add_grad_a", args[2])
            grad_b = invoke_runtime_function("tensor", "tensor_backward_add_grad_b", args[2])
            return _tensor_backward_rule_add(args[0], args[1], args[2], grad_a=grad_a, grad_b=grad_b)
        if function_name == "tensor_backward_rule_mul":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_mul_grad_a", args[0], args[1], args[2])
            grad_b = invoke_runtime_function("tensor", "tensor_backward_mul_grad_b", args[0], args[1], args[2])
            return _tensor_backward_rule_mul(args[0], args[1], args[2], grad_a=grad_a, grad_b=grad_b)
        if function_name == "tensor_backward_rule_sub":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_sub_grad_a", args[2])
            grad_b = invoke_runtime_function("tensor", "tensor_backward_sub_grad_b", args[2])
            return _tensor_backward_rule_sub(args[0], args[1], args[2], grad_a=grad_a, grad_b=grad_b)
        if function_name == "tensor_backward_rule_div":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_div_grad_a", args[0], args[1], args[2])
            grad_b = invoke_runtime_function("tensor", "tensor_backward_div_grad_b", args[0], args[1], args[2])
            return _tensor_backward_rule_div(args[0], args[1], args[2], grad_a=grad_a, grad_b=grad_b)
        if function_name == "tensor_backward_rule_matmul":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_matmul_grad_a", args[0], args[1], args[2])
            grad_b = invoke_runtime_function("tensor", "tensor_backward_matmul_grad_b", args[0], args[1], args[2])
            return _tensor_backward_rule_matmul(args[0], args[1], args[2], grad_a=grad_a, grad_b=grad_b)
        if function_name == "tensor_backward_rule_sum":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_sum_grad", args[0], args[1])
            return _tensor_backward_rule_sum(args[0], args[1], grad_a=grad_a)
        if function_name == "tensor_backward_rule_mean":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_mean_grad", args[0], args[1])
            return _tensor_backward_rule_mean(args[0], args[1], grad_a=grad_a)
        if function_name == "tensor_backward_rule_sum_dim":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_sum_dim_grad", args[0], args[1], args[2], args[3])
            return _tensor_backward_rule_sum_dim(args[0], args[1], int(args[2]), bool(args[3]), grad_a=grad_a)
        if function_name == "tensor_backward_rule_mean_dim":
            grad_a = invoke_runtime_function("tensor", "tensor_backward_mean_dim_grad", args[0], args[1], args[2], args[3])
            return _tensor_backward_rule_mean_dim(args[0], args[1], int(args[2]), bool(args[3]), grad_a=grad_a)
        if function_name == "tensor_transform_chain_from_op":
            return _tensor_transform_chain_from_op(str(args[0]))
        if function_name == "tensor_transform_chain_add":
            return _tensor_transform_chain_from_op("add")
        if function_name == "tensor_transform_chain_mul":
            return _tensor_transform_chain_from_op("mul")
        if function_name == "tensor_transform_chain_sub":
            return _tensor_transform_chain_from_op("sub")
        if function_name == "tensor_transform_chain_div":
            return _tensor_transform_chain_from_op("div")
        if function_name == "tensor_transform_chain_matmul":
            return _tensor_transform_chain_from_op("matmul")
        if function_name == "tensor_transform_chain_sum":
            return _tensor_transform_chain_from_op("sum")
        if function_name == "tensor_transform_chain_mean":
            return _tensor_transform_chain_from_op("mean")
        if function_name == "tensor_transform_chain_sum_dim":
            return _tensor_transform_chain_from_op("sum_dim")
        if function_name == "tensor_transform_chain_mean_dim":
            return _tensor_transform_chain_from_op("mean_dim")
    if module_name == "shape":
        if function_name == "broadcast_shape":
            return list(np.broadcast_shapes(tuple(int(x) for x in args[0]), tuple(int(x) for x in args[1])))
        if function_name == "normalize_axes":
            axes = [int(x) for x in args[0]]
            ndim = int(args[1])
            return [ax + ndim if ax < 0 else ax for ax in axes]
        if function_name == "infer_matmul_shape":
            a_shape = [int(x) for x in args[0]]
            b_shape = [int(x) for x in args[1]]
            if len(a_shape) == 1 and len(b_shape) == 1:
                return [1]
            if len(a_shape) == 1 and len(b_shape) == 2:
                return [b_shape[1]]
            if len(a_shape) == 2 and len(b_shape) == 1:
                return [a_shape[0]]
            if len(a_shape) == 2 and len(b_shape) == 2:
                return [a_shape[0], b_shape[1]]
            return list(a_shape)
        if function_name == "expand_shape":
            shape = [int(x) for x in args[0]]
            dim = int(args[1])
            axis = dim if dim >= 0 else dim + len(shape) + 1
            return shape[:axis] + [1] + shape[axis:]
        if function_name == "squeeze_shape":
            shape = [int(x) for x in args[0]]
            squeezed = [dim for dim in shape if dim != 1]
            return squeezed or [1]
        if function_name == "infer_reduce_shape":
            shape = [int(x) for x in args[0]]
            dim = int(args[1])
            keepdim = bool(args[2])
            axis = dim if dim >= 0 else dim + len(shape)
            if keepdim:
                out = list(shape)
                out[axis] = 1
                return out
            out = [shape[i] for i in range(len(shape)) if i != axis]
            return out or [1]
        if function_name == "concat_shape":
            a_shape = [int(x) for x in args[0]]
            b_shape = [int(x) for x in args[1]]
            dim = int(args[2])
            axis = dim if dim >= 0 else dim + len(a_shape)
            out = list(a_shape)
            if len(a_shape) == len(b_shape):
                out[axis] = a_shape[axis] + b_shape[axis]
            return out
        if function_name == "stack_shape":
            shape = [int(x) for x in args[0]]
            dim = int(args[1])
            axis = dim if dim >= 0 else dim + len(shape) + 1
            return shape[:axis] + [1] + shape[axis:]
        if function_name == "flatten_shape":
            shape = [int(x) for x in args[0]]
            start = int(args[1])
            end = int(args[2])
            ndim = len(shape)
            start = start + ndim if start < 0 else start
            end = end + ndim if end < 0 else end
            if start > end:
                return list(shape)
            flat = 1
            for i in range(start, end + 1):
                flat *= shape[i]
            return shape[:start] + [flat] + shape[end + 1:]
    if module_name == "reduce":
        def _reduce_all_np(op: str, data: Any) -> dict[str, Any]:
            arr = np.asarray(data, dtype=float)
            if op == "sum":
                result = np.sum(arr)
            elif op == "mean":
                result = np.mean(arr) if arr.size else 0.0
            elif op == "max":
                result = np.max(arr) if arr.size else 0.0
            elif op == "min":
                result = np.min(arr) if arr.size else 0.0
            elif op == "prod":
                result = np.prod(arr) if arr.size else 1.0
            else:
                raise ValueError(op)
            return result

        def _reduce_dim_np(op: str, data: Any, shape: list[int], dim: int, keepdim: bool) -> Any:
            arr = np.asarray(data, dtype=float).reshape(shape)
            axis = dim if dim >= 0 else dim + arr.ndim
            if op == "sum":
                result = np.sum(arr, axis=axis, keepdims=keepdim)
            elif op == "mean":
                result = np.mean(arr, axis=axis, keepdims=keepdim)
            elif op == "max":
                result = np.max(arr, axis=axis, keepdims=keepdim)
            elif op == "min":
                result = np.min(arr, axis=axis, keepdims=keepdim)
            elif op == "prod":
                result = np.prod(arr, axis=axis, keepdims=keepdim)
            else:
                raise ValueError(op)
            return result

        if function_name in {"reduce_sum", "reduce_mean", "reduce_max", "reduce_min", "reduce_prod"}:
            data_a, shape_a, req_a = _tensor_like(args[0])
            op = function_name.removeprefix("reduce_")
            reduced = _reduce_all_np(op, data_a)
            return _tensor_dict(np.asarray([reduced]), [1], req_a)
        if function_name in {"reduce_sum_dim", "reduce_mean_dim", "reduce_max_dim", "reduce_min_dim", "reduce_prod_dim"}:
            data_a, shape_a, req_a = _tensor_like(args[0])
            dim = int(args[1])
            keepdim = bool(args[2])
            op = function_name.removeprefix("reduce_").removesuffix("_dim")
            reduced = _reduce_dim_np(op, data_a, shape_a, dim, keepdim)
            reduced_arr = np.asarray(reduced)
            out_shape = list(reduced_arr.shape) if reduced_arr.shape else [1]
            return _tensor_dict(reduced_arr, out_shape, req_a)
    if module_name == "indexing":
        if function_name == "pad":
            data_a, shape_a, req_a = _tensor_like(args[0])
            before = int(args[1])
            after = int(args[2])
            value = float(args[3])
            before = max(before, 0)
            after = max(after, 0)
            padded = np.pad(np.asarray(data_a), (before, after), mode="constant", constant_values=value)
            return _tensor_dict(padded, [int(padded.shape[0])], req_a)
        if function_name == "slice":
            data_a, shape_a, req_a = _tensor_like(args[0])
            start = max(int(args[1]), 0)
            end = min(int(args[2]), len(data_a))
            if end < start:
                end = start
            sliced = np.asarray(data_a)[start:end]
            return _tensor_dict(sliced, [int(sliced.shape[0])], req_a)
        if function_name == "gather":
            data_a, shape_a, req_a = _tensor_like(args[0])
            indices = np.asarray(args[1], dtype=np.int64)
            gathered = np.asarray(data_a)[indices]
            return _tensor_dict(gathered, [int(gathered.shape[0])], req_a)
    return _UNHANDLED


def _execute_intrinsic(name: str, args: list[Any]) -> Any:
    if name == "add":
        if len(args) != 2:
            raise ValueError(f"add expects 2 args, got {len(args)}")
        return np.add(args[0], args[1])
    if name == "sub":
        if len(args) != 2:
            raise ValueError(f"sub expects 2 args, got {len(args)}")
        return np.subtract(args[0], args[1])
    if name == "mul":
        if len(args) != 2:
            raise ValueError(f"mul expects 2 args, got {len(args)}")
        return np.multiply(args[0], args[1])
    if name == "div":
        if len(args) != 2:
            raise ValueError(f"div expects 2 args, got {len(args)}")
        return np.divide(args[0], args[1])
    if name == "pow":
        if len(args) != 2:
            raise ValueError(f"pow expects 2 args, got {len(args)}")
        return np.power(args[0], args[1])
    if name == "matmul":
        if len(args) != 2:
            raise ValueError(f"matmul expects 2 args, got {len(args)}")
        return np.matmul(args[0], args[1])
    if name == "linear":
        if len(args) != 3:
            raise ValueError(f"linear expects 3 args, got {len(args)}")
        return np.matmul(args[0], args[1]) + np.asarray(args[2])
    if name == "layer_norm":
        if len(args) != 5:
            raise ValueError(f"layer_norm expects 5 args, got {len(args)}")
        x = np.asarray(args[0])
        weight = np.asarray(args[1])
        bias = np.asarray(args[2])
        normalized_dims = int(args[3])
        eps = float(args[4])
        norm_axes = tuple(range(x.ndim - normalized_dims, x.ndim))
        mean = x.mean(axis=norm_axes, keepdims=True)
        var = x.var(axis=norm_axes, keepdims=True)
        return (x - mean) / np.sqrt(var + eps) * weight + bias
    if name == "rms_norm":
        if len(args) != 5:
            raise ValueError(f"rms_norm expects 5 args, got {len(args)}")
        x = np.asarray(args[0])
        weight = np.asarray(args[1])
        bias = np.asarray(args[2])
        normalized_dims = int(args[3])
        eps = float(args[4])
        norm_axes = tuple(range(x.ndim - normalized_dims, x.ndim))
        mean_sq = (x * x).mean(axis=norm_axes, keepdims=True)
        return x / np.sqrt(mean_sq + eps) * weight + bias
    if name == "scaled_dot_product_attention":
        if len(args) != 5:
            raise ValueError(f"scaled_dot_product_attention expects 5 args, got {len(args)}")
        query = np.asarray(args[0])
        key = np.asarray(args[1])
        value = np.asarray(args[2])
        mask = np.asarray(args[3])
        has_mask = bool(args[4])
        scores = np.matmul(query, np.swapaxes(key, -2, -1)) / math.sqrt(float(query.shape[-1]))
        if has_mask:
            scores = scores + mask
        shifted = scores - np.max(scores, axis=-1, keepdims=True)
        weights = np.exp(shifted)
        weights = weights / np.sum(weights, axis=-1, keepdims=True)
        return np.matmul(weights, value), weights
    if name == "causal_attention":
        if len(args) != 3:
            raise ValueError(f"causal_attention expects 3 args, got {len(args)}")
        query = np.asarray(args[0])
        key = np.asarray(args[1])
        value = np.asarray(args[2])
        seq_len_q = query.shape[-2]
        seq_len_k = key.shape[-2]
        scores = np.matmul(query, np.swapaxes(key, -2, -1)) / math.sqrt(float(query.shape[-1]))
        row_positions = np.arange(seq_len_q).reshape(-1, 1)
        col_positions = np.arange(seq_len_k).reshape(1, -1)
        offset = max(seq_len_k - seq_len_q, 0)
        causal_mask = col_positions <= (row_positions + offset)
        scores = np.where(causal_mask, scores, -1.0e9)
        shifted = scores - np.max(scores, axis=-1, keepdims=True)
        weights = np.exp(shifted)
        weights = weights / np.sum(weights, axis=-1, keepdims=True)
        return np.matmul(weights, value), weights
    if name == "kv_cache_attention":
        if len(args) != 6:
            raise ValueError(f"kv_cache_attention expects 6 args, got {len(args)}")
        query = np.asarray(args[0])
        key = np.asarray(args[1])
        value = np.asarray(args[2])
        past_key = np.asarray(args[3])
        past_value = np.asarray(args[4])
        has_past = bool(args[5])
        if has_past:
            key = np.concatenate([past_key, key], axis=2)
            value = np.concatenate([past_value, value], axis=2)
        output, weights = _execute_intrinsic("causal_attention", [query, key, value])
        return output, weights, key, value
    if name == "qkv_projection":
        if len(args) != 4:
            raise ValueError(f"qkv_projection expects 4 args, got {len(args)}")
        x = np.asarray(args[0])
        weight = np.asarray(args[1])
        bias = np.asarray(args[2])
        n_heads = int(args[3])
        qkv = np.matmul(x, weight) + bias
        batch_size, seq_len, three_channels = qkv.shape
        channels = three_channels // 3
        head_dim = channels // n_heads
        qkv = qkv.reshape(batch_size, seq_len, 3, n_heads, head_dim).transpose(2, 0, 3, 1, 4)
        return qkv[0], qkv[1], qkv[2]
    if name == "rope_apply":
        if len(args) != 3:
            raise ValueError(f"rope_apply expects 3 args, got {len(args)}")
        x = np.asarray(args[0])
        cos = np.asarray(args[1])[None, None, :, :]
        sin = np.asarray(args[2])[None, None, :, :]
        x1 = x[..., ::2]
        x2 = x[..., 1::2]
        out = np.empty_like(x)
        out[..., ::2] = x1 * cos - x2 * sin
        out[..., 1::2] = x1 * sin + x2 * cos
        return out
    if name == "mlp_block":
        if len(args) != 5:
            raise ValueError(f"mlp_block expects 5 args, got {len(args)}")
        x = np.asarray(args[0])
        fc1_weight = np.asarray(args[1])
        fc1_bias = np.asarray(args[2])
        fc2_weight = np.asarray(args[3])
        fc2_bias = np.asarray(args[4])
        hidden = np.matmul(x, fc1_weight) + fc1_bias
        sigmoid = np.where(
            hidden >= 0,
            1.0 / (1.0 + np.exp(-1.702 * hidden)),
            np.exp(1.702 * hidden) / (1.0 + np.exp(1.702 * hidden)),
        )
        hidden = hidden * sigmoid
        return np.matmul(hidden, fc2_weight) + fc2_bias
    if name == "transformer_block_forward":
        if len(args) != 15:
            raise ValueError(f"transformer_block_forward expects 15 args, got {len(args)}")
        x = np.asarray(args[0])
        ln1_weight = np.asarray(args[1])
        ln1_bias = np.asarray(args[2])
        qkv_weight = np.asarray(args[3])
        qkv_bias = np.asarray(args[4])
        out_weight = np.asarray(args[5])
        out_bias = np.asarray(args[6])
        ln2_weight = np.asarray(args[7])
        ln2_bias = np.asarray(args[8])
        fc1_weight = np.asarray(args[9])
        fc1_bias = np.asarray(args[10])
        fc2_weight = np.asarray(args[11])
        fc2_bias = np.asarray(args[12])
        eps = float(args[13])
        n_heads = int(args[14])
        mean = x.mean(axis=-1, keepdims=True)
        var = x.var(axis=-1, keepdims=True)
        norm1 = (x - mean) / np.sqrt(var + eps) * ln1_weight + ln1_bias
        q, k, v = _execute_intrinsic("qkv_projection", [norm1, qkv_weight, qkv_bias, n_heads])
        attn, _ = _execute_intrinsic("causal_attention", [q, k, v])
        batch_size, _, seq_len, head_dim = attn.shape
        channels = n_heads * head_dim
        attn = attn.transpose(0, 2, 1, 3).reshape(batch_size, seq_len, channels)
        x = x + np.matmul(attn, out_weight) + out_bias
        mean = x.mean(axis=-1, keepdims=True)
        var = x.var(axis=-1, keepdims=True)
        norm2 = (x - mean) / np.sqrt(var + eps) * ln2_weight + ln2_bias
        return x + _execute_intrinsic("mlp_block", [norm2, fc1_weight, fc1_bias, fc2_weight, fc2_bias])
    if name == "lm_head_logits":
        if len(args) != 3:
            raise ValueError(f"lm_head_logits expects 3 args, got {len(args)}")
        hidden = np.asarray(args[0])
        weight = np.asarray(args[1])
        bias = np.asarray(args[2])
        return np.matmul(hidden, weight) + bias
    if name == "sampling_top_k_top_p":
        if len(args) != 6:
            raise ValueError(f"sampling_top_k_top_p expects 6 args, got {len(args)}")
        logits = np.asarray(args[0], dtype=np.float64).copy()
        token_ids = np.asarray(args[1], dtype=np.int64).reshape(-1)
        temperature = float(args[2])
        top_k = int(args[3])
        top_p = float(args[4])
        repetition_penalty = float(args[5])
        if repetition_penalty != 1.0 and token_ids.size > 0:
            for token_id in np.unique(token_ids):
                if 0 <= token_id < logits.shape[0]:
                    if logits[token_id] > 0:
                        logits[token_id] /= repetition_penalty
                    else:
                        logits[token_id] *= repetition_penalty
        if top_k > 0 and top_k < logits.shape[0]:
            filtered = np.full_like(logits, -np.inf)
            top_idx = np.argpartition(logits, -top_k)[-top_k:]
            filtered[top_idx] = logits[top_idx]
            logits = filtered
        if top_p < 1.0:
            sorted_idx = np.argsort(logits)[::-1]
            sorted_logits = logits[sorted_idx]
            finite_mask = np.isfinite(sorted_logits)
            if np.any(finite_mask):
                finite_logits = sorted_logits[finite_mask]
                shifted = finite_logits - np.max(finite_logits)
                probs = np.exp(shifted)
                probs = probs / (probs.sum() + 1e-12)
                cum_probs = np.cumsum(probs)
                keep_mask = cum_probs <= top_p
                if not np.any(keep_mask):
                    keep_mask[0] = True
                else:
                    first_exceed = np.argmax(cum_probs > top_p)
                    if cum_probs[first_exceed] > top_p:
                        keep_mask[first_exceed] = True
                keep_idx = sorted_idx[finite_mask][keep_mask]
                filtered = np.full_like(logits, -np.inf)
                filtered[keep_idx] = logits[keep_idx]
                logits = filtered
        if temperature > 0.0:
            logits = logits / max(temperature, 1e-12)
        return logits
    if name == "generation_step":
        if len(args) != 6:
            raise ValueError(f"generation_step expects 6 args, got {len(args)}")
        filtered = _execute_intrinsic("sampling_top_k_top_p", args)
        return int(np.argmax(filtered))
    if name == "embedding_lookup":
        if len(args) != 3:
            raise ValueError(f"embedding_lookup expects 3 args, got {len(args)}")
        weight = np.asarray(args[0])
        input_ids = np.asarray(args[1], dtype=np.int64)
        padding_idx = int(args[2])
        out = weight[input_ids]
        if padding_idx >= 0:
            out = np.array(out, copy=True)
            out[input_ids == padding_idx] = 0
        return out
    if name == "exp":
        if len(args) != 1:
            raise ValueError(f"exp expects 1 arg, got {len(args)}")
        return np.exp(args[0])
    if name == "log":
        if len(args) != 1:
            raise ValueError(f"log expects 1 arg, got {len(args)}")
        return np.log(args[0])
    if name == "sqrt":
        if len(args) != 1:
            raise ValueError(f"sqrt expects 1 arg, got {len(args)}")
        return np.sqrt(args[0])
    if name == "sum":
        if len(args) != 3:
            raise ValueError(f"sum expects 3 args, got {len(args)}")
        return np.sum(args[0], axis=int(args[1]), keepdims=bool(args[2]))
    if name == "mean":
        if len(args) != 3:
            raise ValueError(f"mean expects 3 args, got {len(args)}")
        return np.mean(args[0], axis=int(args[1]), keepdims=bool(args[2]))
    if name == "len":
        if len(args) != 1:
            raise ValueError(f"len expects 1 arg, got {len(args)}")
        return len(args[0])
    if name == "zeros_like":
        if len(args) != 1:
            raise ValueError(f"zeros_like expects 1 arg, got {len(args)}")
        return np.zeros_like(np.asarray(args[0]))
    if name == "ones_like":
        if len(args) != 1:
            raise ValueError(f"ones_like expects 1 arg, got {len(args)}")
        return np.ones_like(np.asarray(args[0]))
    if name == "read_text_file":
        if len(args) != 1:
            raise ValueError(f"read_text_file expects 1 arg, got {len(args)}")
        return Path(args[0]).read_text(encoding="utf-8")
    if name == "write_text_file":
        if len(args) != 2:
            raise ValueError(f"write_text_file expects 2 args, got {len(args)}")
        path = Path(args[0])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(str(args[1]), encoding="utf-8")
        return None
    if name == "append_text_file":
        if len(args) != 2:
            raise ValueError(f"append_text_file expects 2 args, got {len(args)}")
        path = Path(args[0])
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(str(args[1]))
        return None
    if name == "file_exists":
        if len(args) != 1:
            raise ValueError(f"file_exists expects 1 arg, got {len(args)}")
        return Path(args[0]).exists()
    if name == "env_get":
        if len(args) not in {1, 2}:
            raise ValueError(f"env_get expects 1 or 2 args, got {len(args)}")
        default_value = "" if len(args) == 1 else str(args[1])
        return os.environ.get(str(args[0]), default_value)
    if name == "env_has":
        if len(args) != 1:
            raise ValueError(f"env_has expects 1 arg, got {len(args)}")
        return str(args[0]) in os.environ
    if name == "json_parse":
        if len(args) != 1:
            raise ValueError(f"json_parse expects 1 arg, got {len(args)}")
        return json.loads(str(args[0]))
    if name == "json_stringify":
        if len(args) != 1:
            raise ValueError(f"json_stringify expects 1 arg, got {len(args)}")
        return json.dumps(args[0], ensure_ascii=True)
    if name == "new_checkpoint":
        if len(args) != 3:
            raise ValueError(f"new_checkpoint expects 3 args, got {len(args)}")
        return {
            "step": int(args[0]),
            "loss": float(args[1]),
            "params": args[2],
        }
    if name == "checkpoint_state_dict":
        if len(args) != 1:
            raise ValueError(f"checkpoint_state_dict expects 1 arg, got {len(args)}")
        return args[0]
    if name == "checkpoint_load_state_dict":
        if len(args) != 2:
            raise ValueError(f"checkpoint_load_state_dict expects 2 args, got {len(args)}")
        return args[1]
    if name == "save_checkpoint":
        if len(args) == 4:
            return {
                "step": int(args[1]),
                "loss": float(args[2]),
                "params": args[3],
            }
        if len(args) == 2:
            payload = args[1]
            if isinstance(payload, dict):
                if "checkpoint_state" in payload and isinstance(payload["checkpoint_state"], dict):
                    payload = payload["checkpoint_state"]
                elif "snapshot" in payload and isinstance(payload["snapshot"], dict):
                    snapshot = payload["snapshot"]
                    payload = snapshot.get("checkpoint_state", snapshot)
                elif "state" in payload and isinstance(payload["state"], dict):
                    payload = payload["state"]
            if isinstance(payload, dict):
                return {
                    "step": int(payload.get("step", 0)),
                    "loss": float(payload.get("loss", 0.0)),
                    "params": payload.get("params", []),
                }
            return {
                "step": 0,
                "loss": 0.0,
                "params": [],
            }
        raise ValueError(f"save_checkpoint expects 2 or 4 args, got {len(args)}")
    if name == "load_checkpoint":
        if len(args) != 1:
            raise ValueError(f"load_checkpoint expects 1 arg, got {len(args)}")
        return {
            "step": 0,
            "loss": 0.0,
            "params": [],
        }
    if name == "new_trainer_pipeline":
        if len(args) != 1:
            raise ValueError(f"new_trainer_pipeline expects 1 arg, got {len(args)}")
        session = args[0]
        return {
            "session": session,
            "snapshot": _execute_intrinsic("new_trainer_snapshot", [session]),
        }
    if name == "trainer_pipeline_state_dict":
        if len(args) != 1:
            raise ValueError(f"trainer_pipeline_state_dict expects 1 arg, got {len(args)}")
        pipeline = args[0]
        if not isinstance(pipeline, dict):
            return pipeline
        return {
            "session": pipeline.get("session"),
            "snapshot": _execute_intrinsic("trainer_snapshot_state_dict", [pipeline.get("snapshot", {})]),
        }
    if name == "trainer_pipeline_load_state_dict":
        if len(args) != 2:
            raise ValueError(f"trainer_pipeline_load_state_dict expects 2 args, got {len(args)}")
        pipeline = args[0]
        other = args[1]
        if not isinstance(pipeline, dict) or not isinstance(other, dict):
            return other
        return {
            "session": other.get("session"),
            "snapshot": _execute_intrinsic("trainer_snapshot_load_state_dict", [pipeline.get("snapshot", {}), other.get("snapshot", {})]),
        }
    if name == "run_trainer_snapshot":
        if len(args) != 2:
            raise ValueError(f"run_trainer_snapshot expects 2 args, got {len(args)}")
        session = args[0]
        batch = args[1]
        next_state = session.get("state", {}) if isinstance(session, dict) else {}
        if isinstance(session, dict) and isinstance(session.get("state"), dict) and isinstance(batch, dict):
            token_ids = batch.get("token_ids", [])
            denom = len(token_ids) if hasattr(token_ids, "__len__") else 0
            loss = float(next_state.get("last_loss", 0.0))
            if denom > 0:
                loss = 1.0 / float(denom)
            next_state = {
                "step": int(next_state.get("step", 0)) + 1,
                "last_loss": loss,
                "optimizer": next_state.get("optimizer"),
                "adam": next_state.get("adam"),
                "rmsprop": next_state.get("rmsprop"),
            }
            next_session = {
                "config": session.get("config"),
                "state": next_state,
                "sample": session.get("sample"),
            }
            return _execute_intrinsic("new_trainer_snapshot", [next_session])
        return _execute_intrinsic("new_trainer_snapshot", [session])
    if name == "run_training_pipeline":
        if len(args) != 2:
            raise ValueError(f"run_training_pipeline expects 2 args, got {len(args)}")
        pipeline = args[0]
        batch = args[1]
        if not isinstance(pipeline, dict):
            return pipeline
        next_snapshot = _execute_intrinsic("run_trainer_snapshot", [pipeline.get("session", {}), batch])
        return {
            "session": next_snapshot.get("session"),
            "snapshot": next_snapshot,
        }
    if name == "stop_trainer_pipeline":
        if len(args) != 1:
            raise ValueError(f"stop_trainer_pipeline expects 1 arg, got {len(args)}")
        return args[0]
    if name == "resume_trainer_pipeline":
        if len(args) != 1:
            raise ValueError(f"resume_trainer_pipeline expects 1 arg, got {len(args)}")
        return args[0]
    if name == "pipeline_checkpoint":
        if len(args) != 1:
            raise ValueError(f"pipeline_checkpoint expects 1 arg, got {len(args)}")
        pipeline = args[0]
        if not isinstance(pipeline, dict):
            return pipeline
        return _execute_intrinsic("checkpoint_state_dict", [pipeline.get("snapshot", {}).get("checkpoint_state", {})])
    if name == "save_trainer_session_checkpoint":
        if len(args) != 2:
            raise ValueError(f"save_trainer_session_checkpoint expects 2 args, got {len(args)}")
        return _execute_intrinsic("save_checkpoint", [args[0], args[1]])
    if name == "load_trainer_session_checkpoint":
        if len(args) != 1:
            raise ValueError(f"load_trainer_session_checkpoint expects 1 arg, got {len(args)}")
        ckpt = _execute_intrinsic("load_checkpoint", [args[0]])
        session = {
            "config": {
                "epochs": 0,
                "batch_size": 0,
                "learning_rate": 0.0,
                "grad_clip": 0.0,
            },
            "state": {
                "step": 0,
                "last_loss": 0.0,
                "optimizer": None,
                "adam": None,
                "rmsprop": None,
            },
            "sample": {
                "data": [],
                "shape": [],
            },
        }
        return {
            "session": session,
            "checkpoint_state": ckpt,
        }
    if name == "save_training_pipeline_checkpoint":
        if len(args) != 2:
            raise ValueError(f"save_training_pipeline_checkpoint expects 2 args, got {len(args)}")
        return _execute_intrinsic("save_checkpoint", [args[0], args[1]])
    if name == "load_training_pipeline_checkpoint":
        if len(args) != 1:
            raise ValueError(f"load_training_pipeline_checkpoint expects 1 arg, got {len(args)}")
        snapshot = _execute_intrinsic("load_trainer_session_checkpoint", [args[0]])
        return {
            "session": snapshot.get("session"),
            "snapshot": snapshot,
        }
    if name == "new_trainer_snapshot":
        if len(args) != 1:
            raise ValueError(f"new_trainer_snapshot expects 1 arg, got {len(args)}")
        session = args[0]
        step = 0
        loss = 0.0
        if isinstance(session, dict):
            state = session.get("state", {})
            if isinstance(state, dict):
                step = int(state.get("step", 0))
                loss = float(state.get("last_loss", 0.0))
        return {
            "session": session,
            "checkpoint_state": {
                "step": step,
                "loss": loss,
                "params": [],
            },
        }
    if name == "trainer_snapshot_state_dict":
        if len(args) != 1:
            raise ValueError(f"trainer_snapshot_state_dict expects 1 arg, got {len(args)}")
        snapshot = args[0]
        if not isinstance(snapshot, dict):
            return snapshot
        return {
            "session": snapshot.get("session"),
            "checkpoint_state": _execute_intrinsic("checkpoint_state_dict", [snapshot.get("checkpoint_state", {})]),
        }
    if name == "trainer_snapshot_load_state_dict":
        if len(args) != 2:
            raise ValueError(f"trainer_snapshot_load_state_dict expects 2 args, got {len(args)}")
        snapshot = args[0]
        other = args[1]
        if not isinstance(snapshot, dict) or not isinstance(other, dict):
            return other
        return {
            "session": other.get("session"),
            "checkpoint_state": _execute_intrinsic("checkpoint_load_state_dict", [snapshot.get("checkpoint_state", {}), other.get("checkpoint_state", {})]),
        }
    if name == "dataloader_mvp_has_next":
        if len(args) != 1:
            raise ValueError(f"dataloader_mvp_has_next expects 1 arg, got {len(args)}")
        state = args[0]
        if not isinstance(state, dict):
            return False
        token_ids = state.get("token_ids", [])
        config = state.get("config", {})
        if not isinstance(config, dict):
            return False
        batch_size = int(config.get("batch_size", 0))
        seq_len = int(config.get("seq_len", 0))
        return batch_size > 0 and seq_len > 0 and len(token_ids) > seq_len
    if name == "dataloader_mvp_next_batch":
        if len(args) != 1:
            raise ValueError(f"dataloader_mvp_next_batch expects 1 arg, got {len(args)}")
        state = args[0]
        if not isinstance(state, dict):
            return state
        token_ids = list(state.get("token_ids", []))
        config = state.get("config", {})
        if not isinstance(config, dict):
            config = {}
        batch_size = int(config.get("batch_size", 0))
        seq_len = int(config.get("seq_len", 0))
        total = len(token_ids)
        cursor = int(state.get("cursor", 0))
        input_ids: list[int] = []
        target_ids: list[int] = []
        if batch_size > 0 and seq_len > 0 and total > seq_len:
            for _ in range(batch_size):
                if cursor + seq_len + 1 >= total:
                    cursor = 0
                for i in range(seq_len):
                    input_ids.append(token_ids[cursor + i])
                    target_ids.append(token_ids[cursor + i + 1])
                cursor = cursor + seq_len
        next_state = {
            "token_ids": token_ids,
            "cursor": cursor,
            "config": config,
        }
        return {
            "state": next_state,
            "batch": {
                "input_ids": input_ids,
                "target_ids": target_ids,
                "valid_tokens": len(input_ids),
            },
        }
    if name == "mse_loss":
        if len(args) != 3:
            raise ValueError(f"mse_loss expects 3 args, got {len(args)}")
        diff = np.asarray(args[0]) - np.asarray(args[1])
        loss = diff * diff
        reduction = str(args[2])
        if reduction == "mean":
            return np.array(loss.mean())
        if reduction == "sum":
            return np.array(loss.sum())
        if reduction == "none":
            return loss
        raise ValueError(f"unsupported mse_loss reduction: {reduction}")
    if name == "bce_loss":
        if len(args) != 3:
            raise ValueError(f"bce_loss expects 3 args, got {len(args)}")
        input_arr = np.asarray(args[0])
        target_arr = np.asarray(args[1], dtype=input_arr.dtype)
        reduction = str(args[2])
        clipped = np.clip(input_arr, 1.0e-7, 1.0 - 1.0e-7)
        loss = -(target_arr * np.log(clipped) + (1.0 - target_arr) * np.log(1.0 - clipped))
        if reduction == "mean":
            return np.array(loss.mean())
        if reduction == "sum":
            return np.array(loss.sum())
        if reduction == "none":
            return loss
        raise ValueError(f"unsupported bce_loss reduction: {reduction}")
    if name == "bce_with_logits_loss":
        if len(args) != 3:
            raise ValueError(f"bce_with_logits_loss expects 3 args, got {len(args)}")
        input_arr = np.asarray(args[0])
        target_arr = np.asarray(args[1], dtype=input_arr.dtype)
        reduction = str(args[2])
        max_term = np.maximum(input_arr, 0.0)
        loss = max_term - input_arr * target_arr + np.log1p(np.exp(-np.abs(input_arr)))
        if reduction == "mean":
            return np.array(loss.mean())
        if reduction == "sum":
            return np.array(loss.sum())
        if reduction == "none":
            return loss
        raise ValueError(f"unsupported bce_with_logits_loss reduction: {reduction}")
    if name == "l1_loss":
        if len(args) != 3:
            raise ValueError(f"l1_loss expects 3 args, got {len(args)}")
        loss = np.abs(np.asarray(args[0]) - np.asarray(args[1]))
        reduction = str(args[2])
        if reduction == "mean":
            return np.array(loss.mean())
        if reduction == "sum":
            return np.array(loss.sum())
        if reduction == "none":
            return loss
        raise ValueError(f"unsupported l1_loss reduction: {reduction}")
    if name == "smooth_l1_loss":
        if len(args) != 4:
            raise ValueError(f"smooth_l1_loss expects 4 args, got {len(args)}")
        input_arr = np.asarray(args[0])
        target_arr = np.asarray(args[1], dtype=input_arr.dtype)
        reduction = str(args[2])
        beta = float(args[3])
        diff = input_arr - target_arr
        abs_diff = np.abs(diff)
        if beta == 0.0:
            loss = abs_diff
        else:
            loss = np.where(abs_diff < beta, 0.5 * diff * diff / beta, abs_diff - 0.5 * beta)
        if reduction == "mean":
            return np.array(loss.mean())
        if reduction == "sum":
            return np.array(loss.sum())
        if reduction == "none":
            return loss
        raise ValueError(f"unsupported smooth_l1_loss reduction: {reduction}")
    if name == "kl_div_loss":
        if len(args) != 4:
            raise ValueError(f"kl_div_loss expects 4 args, got {len(args)}")
        input_arr = np.asarray(args[0])
        target_arr = np.asarray(args[1], dtype=input_arr.dtype)
        reduction = str(args[2])
        log_target = bool(args[3])
        if log_target:
            target_prob = np.exp(target_arr)
            loss = target_prob * (target_arr - input_arr)
        else:
            target_prob = target_arr
            loss = np.where(target_arr > 0.0, target_arr * (np.log(np.clip(target_arr, 1.0e-10, None)) - input_arr), 0.0)
        if reduction == "none":
            return loss
        if reduction == "sum":
            return np.array(loss.sum())
        if reduction == "batchmean":
            batch = input_arr.shape[0] if input_arr.ndim > 0 else 1
            return np.array(loss.sum() / float(max(batch, 1)))
        if reduction == "mean":
            return np.array(loss.mean())
        raise ValueError(f"unsupported kl_div_loss reduction: {reduction}")
    if name == "nll_loss":
        if len(args) != 6:
            raise ValueError(f"nll_loss expects 6 args, got {len(args)}")
        return _nll_loss_forward(args[0], args[1], int(args[2]), str(args[3]), float(args[4]), int(args[5]))
    if name == "cross_entropy":
        if len(args) != 6:
            raise ValueError(f"cross_entropy expects 6 args, got {len(args)}")
        x = np.asarray(args[0])
        target = np.asarray(args[1])
        ignore_index = int(args[2])
        reduction = str(args[3])
        label_smoothing = float(args[4])
        dim = int(args[5])
        dim = dim + x.ndim if dim < 0 else dim
        shifted = x - np.max(x, axis=dim, keepdims=True)
        log_probs = shifted - np.log(np.sum(np.exp(shifted), axis=dim, keepdims=True))
        return _nll_loss_forward(log_probs, target, ignore_index, reduction, label_smoothing, dim)
    if name == "sgd_step":
        if len(args) != 4:
            raise ValueError(f"sgd_step expects 4 args, got {len(args)}")
        param = np.asarray(args[0])
        grad = np.asarray(args[1])
        lr = float(args[2])
        weight_decay = float(args[3])
        if weight_decay != 0.0:
            grad = grad + weight_decay * param
        return param - lr * grad
    if name == "adam_step":
        if len(args) != 10:
            raise ValueError(f"adam_step expects 10 args, got {len(args)}")
        param = np.asarray(args[0])
        grad = np.asarray(args[1])
        m = np.asarray(args[2])
        v = np.asarray(args[3])
        lr = float(args[4])
        beta1 = float(args[5])
        beta2 = float(args[6])
        eps = float(args[7])
        weight_decay = float(args[8])
        step = int(args[9])
        if weight_decay != 0.0:
            grad = grad + weight_decay * param
        next_m = beta1 * m + (1.0 - beta1) * grad
        next_v = beta2 * v + (1.0 - beta2) * (grad * grad)
        m_hat = next_m / (1.0 - beta1 ** step)
        v_hat = next_v / (1.0 - beta2 ** step)
        updated = param - lr * m_hat / (np.sqrt(v_hat) + eps)
        return updated, next_m, next_v
    if name == "adamw_step":
        if len(args) != 10:
            raise ValueError(f"adamw_step expects 10 args, got {len(args)}")
        param = np.asarray(args[0])
        grad = np.asarray(args[1])
        m = np.asarray(args[2])
        v = np.asarray(args[3])
        lr = float(args[4])
        beta1 = float(args[5])
        beta2 = float(args[6])
        eps = float(args[7])
        weight_decay = float(args[8])
        step = int(args[9])
        if weight_decay != 0.0:
            grad = grad + weight_decay * param
        next_m = beta1 * m + (1.0 - beta1) * grad
        next_v = beta2 * v + (1.0 - beta2) * (grad * grad)
        m_hat = next_m / (1.0 - beta1 ** step)
        v_hat = next_v / (1.0 - beta2 ** step)
        updated = param - lr * m_hat / (np.sqrt(v_hat) + eps)
        return updated, next_m, next_v
    if name == "rmsprop_step":
        if len(args) != 7:
            raise ValueError(f"rmsprop_step expects 7 args, got {len(args)}")
        param = np.asarray(args[0])
        grad = np.asarray(args[1])
        square_avg = np.asarray(args[2])
        lr = float(args[3])
        alpha = float(args[4])
        eps = float(args[5])
        weight_decay = float(args[6])
        if weight_decay != 0.0:
            grad = grad + weight_decay * param
        next_square_avg = alpha * square_avg + (1.0 - alpha) * (grad * grad)
        updated = param - lr * grad / (np.sqrt(next_square_avg) + eps)
        return updated, next_square_avg
    if name == "train_step_autograd_loss":
        if len(args) != 1:
            raise ValueError(f"train_step_autograd_loss expects 1 arg, got {len(args)}")
        state = args[0]
        if isinstance(state, dict):
            loss = float(state.get("last_loss", 0.0))
        else:
            loss = float(state)
        return np.array([(loss + 1.0) / 2.0])
    if name == "train_step_autograd_record_count":
        if len(args) != 1:
            raise ValueError(f"train_step_autograd_record_count expects 1 arg, got {len(args)}")
        return 1
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
    if name == "softplus":
        if len(args) != 2:
            raise ValueError(f"softplus expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        beta = float(args[1])
        beta_x = beta * x
        return np.where(beta_x > 20, x, np.log1p(np.exp(beta_x)) / beta)
    if name == "softsign":
        if len(args) != 1:
            raise ValueError(f"softsign expects 1 arg, got {len(args)}")
        x = np.asarray(args[0])
        return x / (1.0 + np.abs(x))
    if name == "swish":
        if len(args) != 2:
            raise ValueError(f"swish expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        beta = float(args[1])
        beta_x = beta * x
        sigmoid_x = np.where(
            beta_x >= 0,
            1.0 / (1.0 + np.exp(-beta_x)),
            np.exp(beta_x) / (1.0 + np.exp(beta_x)),
        )
        return x * sigmoid_x
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
    if name == "prelu":
        if len(args) != 2:
            raise ValueError(f"prelu expects 2 args, got {len(args)}")
        x = np.asarray(args[0])
        weight = float(args[1])
        return np.where(x > 0, x, weight * x)
    if name == "rrelu":
        if len(args) != 4:
            raise ValueError(f"rrelu expects 4 args, got {len(args)}")
        x = np.asarray(args[0])
        lower = float(args[1])
        upper = float(args[2])
        training = bool(args[3])
        slope = (lower + upper) * 0.5
        slope_arr = np.random.uniform(lower, upper, size=x.shape) if training else slope
        return np.where(x > 0, x, slope_arr * x)
    if name == "update_scale":
        if len(args) != 2:
            raise ValueError(f"update_scale expects 2 args, got {len(args)}")
        state = args[0]
        found_inf = bool(args[1])
        if not isinstance(state, dict):
            return state
        if not bool(state.get("enabled", True)):
            return state
        next_scale = float(state.get("scale", 1.0))
        next_tracker = int(state.get("growth_tracker", 0)) + 1
        next_found_inf = False
        if found_inf:
            next_scale = next_scale * float(state.get("backoff_factor", 0.5))
            if next_scale < 1.0:
                next_scale = 1.0
            next_tracker = 0
            next_found_inf = True
        elif next_tracker >= int(state.get("growth_interval", 1)):
            next_scale = next_scale * float(state.get("growth_factor", 2.0))
            next_tracker = 0
        return {
            "scale": next_scale,
            "growth_factor": float(state.get("growth_factor", 2.0)),
            "backoff_factor": float(state.get("backoff_factor", 0.5)),
            "growth_interval": int(state.get("growth_interval", 1)),
            "growth_tracker": next_tracker,
            "enabled": bool(state.get("enabled", True)),
            "found_inf": next_found_inf,
        }
    raise NotImplementedError(f"unsupported intrinsic: {name}")


def _resolve_ir_operand(scope: dict[str, Any], operand: str) -> Any:
    if operand in scope:
        return scope[operand]
    if operand.startswith('"') and operand.endswith('"'):
        return operand[1:-1]
    if operand == "[]":
        return []
    if operand in {"true", "false"}:
        return operand == "true"
    try:
        if "." in operand:
            return float(operand)
        return int(operand)
    except ValueError:
        pass
    value: Any = scope
    for part in operand.split("."):
        if isinstance(value, dict) and part in value:
            value = value[part]
        elif hasattr(value, part):
            value = getattr(value, part)
        else:
            raise KeyError(operand)
    return value


def _bool_from_value(value: Any) -> bool:
    if isinstance(value, np.ndarray):
        if value.shape == ():
            return bool(value.item())
        return bool(np.all(value))
    return bool(value)


def _nll_loss_forward(input_data: Any, target_data: Any, ignore_index: int, reduction: str, label_smoothing: float, dim: int) -> Any:
    x = np.asarray(input_data)
    target = np.asarray(target_data, dtype=np.int64)
    dim = dim + x.ndim if dim < 0 else dim
    if x.ndim == 1:
        x_moved = x.reshape(1, x.shape[0])
        target_shape = target.shape
        target_flat = target.reshape(-1)
    else:
        x_moved = np.moveaxis(x, dim, -1)
        target_shape = target.shape
        target_flat = target.reshape(-1)
    class_count = x_moved.shape[-1]
    x_flat = x_moved.reshape(-1, class_count)
    valid_mask = target_flat != ignore_index
    targets_valid = target_flat[valid_mask]
    loss_flat = np.zeros(x_flat.shape[0], dtype=x_flat.dtype)
    if targets_valid.size > 0:
        logp_valid = x_flat[valid_mask]
        nll_component = -logp_valid[np.arange(targets_valid.size), targets_valid]
        if label_smoothing > 0.0:
            smooth_component = -logp_valid.mean(axis=1)
            loss_valid = (1.0 - label_smoothing) * nll_component + label_smoothing * smooth_component
        else:
            loss_valid = nll_component
        loss_flat[valid_mask] = loss_valid
    else:
        loss_valid = np.zeros((0,), dtype=x_flat.dtype)
    if reduction == "none":
        return loss_flat.reshape(target_shape)
    if reduction == "sum":
        return np.array(loss_valid.sum())
    if reduction == "mean":
        if loss_valid.size == 0:
            return np.array(0.0, dtype=x_flat.dtype)
        return np.array(loss_valid.mean())
    raise ValueError(f"unsupported nll_loss reduction: {reduction}")


def invoke_runtime_function(module_name: str, function_name: str, *args: Any) -> Any:
    special = _invoke_special_module_function(module_name, function_name, args)
    if special is not _UNHANDLED:
        return special
    functions = _load_module_functions(module_name)
    if function_name not in functions:
        raise LookupError(f"runtime function not found: {module_name}.{function_name}")
    scope: dict[str, Any] = {}
    call_args: list[Any] = []
    arg_iter = iter(args)
    ops = functions[function_name]
    labels = {op[1]: idx for idx, op in enumerate(ops) if op and op[0] == "LABEL" and len(op) > 1}
    pc = 0
    while pc < len(ops):
        op = ops[pc]
        opcode = op[0]
        if opcode == "PARAM":
            scope[op[1]] = next(arg_iter)
        elif opcode == "ARG":
            arg_name = op[1]
            call_args.append(_resolve_ir_operand(scope, arg_name))
        elif opcode == "MOV":
            target = op[1]
            source = op[2]
            scope[target] = _resolve_ir_operand(scope, source)
        elif opcode in {"ADD", "SUB", "MUL", "DIV"}:
            target = op[1]
            left = _resolve_ir_operand(scope, op[2])
            right = _resolve_ir_operand(scope, op[3])
            if opcode == "ADD":
                scope[target] = left + right
            elif opcode == "SUB":
                scope[target] = left - right
            elif opcode == "MUL":
                scope[target] = left * right
            else:
                scope[target] = left / right
        elif opcode in {"CMP_EQ", "CMP_NE", "CMP_LT", "CMP_LE", "CMP_GT", "CMP_GE"}:
            target = op[1]
            left = _resolve_ir_operand(scope, op[2])
            right = _resolve_ir_operand(scope, op[3])
            if opcode == "CMP_EQ":
                scope[target] = left == right
            elif opcode == "CMP_NE":
                scope[target] = left != right
            elif opcode == "CMP_LT":
                scope[target] = left < right
            elif opcode == "CMP_LE":
                scope[target] = left <= right
            elif opcode == "CMP_GT":
                scope[target] = left > right
            else:
                scope[target] = left >= right
        elif opcode == "JUMP":
            label = op[1]
            if label not in labels:
                raise KeyError(label)
            pc = labels[label]
            continue
        elif opcode == "JUMP_IF_FALSE":
            label = op[1]
            condition = _resolve_ir_operand(scope, op[2])
            if not _bool_from_value(condition):
                if label not in labels:
                    raise KeyError(label)
                pc = labels[label]
                continue
        elif opcode == "LABEL":
            pass
        elif opcode == "CALL":
            target = op[1]
            callee = op[2]
            arity = int(op[3])
            callee_args = call_args[-arity:] if arity > 0 else []
            if callee != "call" and supports_runtime_function(module_name, callee):
                scope[target] = invoke_runtime_function(module_name, callee, *callee_args)
            else:
                scope[target] = _execute_intrinsic(callee, callee_args)
            call_args = []
        elif opcode == "RET":
            ret_name = op[1]
            if ret_name == "_":
                return None
            if ret_name in scope:
                return scope[ret_name]
            try:
                return _resolve_ir_operand(scope, ret_name)
            except KeyError:
                return ret_name
        pc += 1
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


def try_invoke_tensor_function(function_name: str, *args: Any) -> Any | None:
    if not ops_runtime_enabled() or not runtime_available():
        return None
    if not supports_runtime_function("tensor", function_name):
        return None
    try:
        return invoke_runtime_function("tensor", function_name, *args)
    except Exception:
        return None


def runtime_available() -> bool:
    return bool(_runtime_ir_files())


def runtime_manifest() -> dict[str, Any]:
    ir_files = [str(path.relative_to(_runtime_root())) for path in _runtime_ir_files()]
    return {
        "available": bool(ir_files),
        "artifact_root": str(_runtime_root()),
        "ir_files": ir_files,
    }


def compiled_runtime_files() -> list[str]:
    manifest = runtime_manifest()
    artifact_root = Path(manifest["artifact_root"])
    return [str(artifact_root / name) for name in manifest.get("ir_files", [])]


def runtime_status() -> dict[str, Any]:
    manifest = runtime_manifest()
    ready = bool(manifest.get("available", False)) and len(manifest.get("ir_files", [])) > 0
    return {
        "available": bool(manifest.get("available", False)),
        "artifact_root": manifest.get("artifact_root", str(_runtime_root())),
        "ir_count": len(manifest.get("ir_files", [])),
        "ir_files": manifest.get("ir_files", []),
        "ready": ready,
    }
