from __future__ import annotations

import threading
from contextlib import ContextDecorator
from dataclasses import dataclass
from typing import Any

import numpy as np

_STATE = threading.local()


def _set_state(enabled: bool, dtype) -> None:
    _STATE.enabled = bool(enabled)
    _STATE.dtype = dtype


def is_autocast_enabled() -> bool:
    return bool(getattr(_STATE, "enabled", False))


def get_autocast_dtype():
    return getattr(_STATE, "dtype", np.float16)


class autocast(ContextDecorator):
    def __init__(self, enabled: bool = True, dtype=np.float16):
        self.enabled = bool(enabled)
        self.dtype = dtype
        self._prev_enabled = None
        self._prev_dtype = None

    def __enter__(self):
        self._prev_enabled = is_autocast_enabled()
        self._prev_dtype = get_autocast_dtype()
        _set_state(self.enabled, self.dtype)
        return self

    def __exit__(self, exc_type, exc, tb):
        _set_state(self._prev_enabled, self._prev_dtype)
        return False


def _foreach_grad(optimizer):
    for p in getattr(optimizer, "params", []):
        grad = getattr(p, "grad", None)
        if grad is not None:
            yield p, grad


@dataclass
class GradScaler:
    init_scale: float = 2.0**16
    growth_factor: float = 2.0
    backoff_factor: float = 0.5
    growth_interval: int = 2000
    enabled: bool = True

    def __post_init__(self):
        if self.init_scale <= 0:
            raise ValueError("init_scale must be > 0")
        if self.growth_factor <= 1.0:
            raise ValueError("growth_factor must be > 1")
        if not (0.0 < self.backoff_factor < 1.0):
            raise ValueError("backoff_factor must satisfy 0 < backoff_factor < 1")
        if self.growth_interval < 1:
            raise ValueError("growth_interval must be >= 1")
        self._scale = float(self.init_scale)
        self._growth_tracker = 0

    @property
    def scale(self) -> float:
        return self._scale

    def scale_loss(self, loss):
        if not self.enabled:
            return loss
        return loss * self._scale

    def _unscale_(self, optimizer) -> bool:
        if not self.enabled:
            return False
        found_inf = False
        inv = 1.0 / self._scale
        for _, grad in _foreach_grad(optimizer):
            grad *= inv
            if not np.all(np.isfinite(grad)):
                found_inf = True
        return found_inf

    def step(self, optimizer) -> bool:
        found_inf = self._unscale_(optimizer)
        if not found_inf:
            optimizer.step()
            self.update(found_inf=False)
            return True
        self.update(found_inf=True)
        return False

    def update(self, *, found_inf: bool) -> None:
        if not self.enabled:
            return
        if found_inf:
            self._scale = max(1.0, self._scale * self.backoff_factor)
            self._growth_tracker = 0
            return
        self._growth_tracker += 1
        if self._growth_tracker >= self.growth_interval:
            self._scale *= self.growth_factor
            self._growth_tracker = 0

    def state_dict(self) -> dict[str, Any]:
        return {
            "enabled": self.enabled,
            "scale": self._scale,
            "growth_tracker": self._growth_tracker,
            "growth_factor": self.growth_factor,
            "backoff_factor": self.backoff_factor,
            "growth_interval": self.growth_interval,
        }

    def load_state_dict(self, state: dict[str, Any]) -> None:
        self.enabled = bool(state.get("enabled", self.enabled))
        self._scale = float(state.get("scale", self._scale))
        self._growth_tracker = int(state.get("growth_tracker", self._growth_tracker))
        self.growth_factor = float(state.get("growth_factor", self.growth_factor))
        self.backoff_factor = float(state.get("backoff_factor", self.backoff_factor))
        self.growth_interval = int(state.get("growth_interval", self.growth_interval))
