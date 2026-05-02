from __future__ import annotations

from dataclasses import dataclass


@dataclass
class grad_mode_state:
    grad_enabled: bool = True
    grad_accumulation: bool = False


def new_state() -> grad_mode_state:
    return grad_mode_state()


def set_grad_enabled(state: grad_mode_state, enabled: bool) -> grad_mode_state:
    return grad_mode_state(
        grad_enabled=bool(enabled),
        grad_accumulation=state.grad_accumulation,
    )


def no_grad(state: grad_mode_state) -> grad_mode_state:
    return set_grad_enabled(state, False)


def enable_grad(state: grad_mode_state) -> grad_mode_state:
    return set_grad_enabled(state, True)


def set_gradient_accumulation(state: grad_mode_state, accumulate: bool) -> grad_mode_state:
    return grad_mode_state(
        grad_enabled=state.grad_enabled,
        grad_accumulation=bool(accumulate),
    )


def gradient_accumulation(state: grad_mode_state, enable: bool) -> grad_mode_state:
    return set_gradient_accumulation(state, enable)


def set_detect_anomaly(state: grad_mode_state, enabled: bool) -> grad_mode_state:
    del enabled
    return state


def is_grad_enabled(state: grad_mode_state) -> bool:
    return state.grad_enabled


def is_grad_accumulation_enabled(state: grad_mode_state) -> bool:
    return state.grad_accumulation


def get_gradient_accumulation(state: grad_mode_state) -> bool:
    return state.grad_accumulation


__all__ = [
    "grad_mode_state",
    "new_state",
    "set_grad_enabled",
    "no_grad",
    "enable_grad",
    "set_gradient_accumulation",
    "gradient_accumulation",
    "set_detect_anomaly",
    "is_grad_enabled",
    "is_grad_accumulation_enabled",
    "get_gradient_accumulation",
]
