from __future__ import annotations

import os
import pickle
import random
import tempfile
from pathlib import Path
from typing import Any

import numpy as np


def _capture_rng_state() -> dict[str, Any]:
    return {
        "python": random.getstate(),
        "numpy": np.random.get_state(),
    }


def _restore_rng_state(state: dict[str, Any] | None) -> None:
    if not isinstance(state, dict):
        return
    py_state = state.get("python")
    np_state = state.get("numpy")
    if py_state is not None:
        random.setstate(py_state)
    if np_state is not None:
        np.random.set_state(np_state)


def _atomic_pickle_dump(obj: Any, path: str | os.PathLike[str]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix=f".{target.name}.", suffix=".tmp", dir=str(target.parent))
    try:
        with os.fdopen(fd, "wb") as f:
            pickle.dump(obj, f, protocol=pickle.HIGHEST_PROTOCOL)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp_path, target)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


def _load_pickle(path: str | os.PathLike[str]) -> Any:
    with open(path, "rb") as f:
        return pickle.load(f)


def save_checkpoint(
    path: str | os.PathLike[str],
    *,
    model=None,
    optimizer=None,
    scaler=None,
    step: int | None = None,
    epoch: int | None = None,
    metrics: dict[str, Any] | None = None,
    metadata: dict[str, Any] | None = None,
    extra_state: dict[str, Any] | None = None,
    include_rng_state: bool = True,
) -> dict[str, Any]:
    if model is not None and not hasattr(model, "state_dict"):
        raise TypeError("model must implement state_dict()")
    if optimizer is not None and not hasattr(optimizer, "state_dict"):
        raise TypeError("optimizer must implement state_dict()")
    if scaler is not None and not hasattr(scaler, "state_dict"):
        raise TypeError("scaler must implement state_dict()")

    checkpoint = {
        "format": "tensor.checkpoint",
        "version": 1,
        "training": {
            "step": int(step) if step is not None else None,
            "epoch": int(epoch) if epoch is not None else None,
        },
        "metrics": dict(metrics) if metrics is not None else {},
        "model_state": model.state_dict() if model is not None else None,
        "optimizer_state": optimizer.state_dict() if optimizer is not None else None,
        "scaler_state": scaler.state_dict() if scaler is not None else None,
        "metadata": dict(metadata) if metadata is not None else {},
        "extra_state": dict(extra_state) if extra_state is not None else {},
        "rng_state": _capture_rng_state() if include_rng_state else None,
    }
    _atomic_pickle_dump(checkpoint, path)
    return checkpoint


def load_checkpoint(
    path: str | os.PathLike[str],
    *,
    model=None,
    optimizer=None,
    scaler=None,
    strict: bool = True,
    restore_rng_state: bool = True,
) -> dict[str, Any]:
    checkpoint = _load_pickle(path)

    model_state = checkpoint.get("model_state")
    if model is not None and model_state is not None:
        if not hasattr(model, "load_state_dict"):
            raise TypeError("model must implement load_state_dict()")
        try:
            model.load_state_dict(model_state, strict=strict)
        except TypeError:
            model.load_state_dict(model_state)

    optimizer_state = checkpoint.get("optimizer_state")
    if optimizer is not None and optimizer_state is not None:
        if not hasattr(optimizer, "load_state_dict"):
            raise TypeError("optimizer must implement load_state_dict()")
        optimizer.load_state_dict(optimizer_state)

    scaler_state = checkpoint.get("scaler_state")
    if scaler is not None and scaler_state is not None:
        if not hasattr(scaler, "load_state_dict"):
            raise TypeError("scaler must implement load_state_dict()")
        scaler.load_state_dict(scaler_state)

    if restore_rng_state:
        _restore_rng_state(checkpoint.get("rng_state"))

    return checkpoint
