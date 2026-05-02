from __future__ import annotations

import os
import json
import math
from functools import lru_cache
from pathlib import Path
from typing import Any

import numpy as np


def _runtime_root() -> Path:
    return Path(__file__).resolve().parents[3] / "build" / "ir"


def _runtime_manifest_path() -> Path:
    return _runtime_root() / "manifest.json"


def _module_ir_path(module_name: str) -> Path:
    root = _runtime_root()
    direct = root / f"{module_name}.ir"
    if direct.exists():
        return direct
    matches = sorted(root.rglob(f"{module_name}.ir"))
    return matches[0] if matches else direct


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
    raise NotImplementedError(f"unsupported intrinsic: {name}")


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
    data.setdefault("artifact_root", str(_runtime_root()))
    data.setdefault("ir_files", [])
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
