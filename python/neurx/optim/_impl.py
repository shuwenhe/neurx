from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any, Callable, Iterable

import numpy as np

from neurx.core import Tensor
from neurx.nn.modules import (
    BCELoss as _BCELoss,
    BCEWithLogitsLoss as _BCEWithLogitsLoss,
    CrossEntropyLoss as _CrossEntropyLoss,
    KLDivLoss as _KLDivLoss,
    L1Loss as _L1Loss,
    MSELoss as _MSELoss,
    NLLLoss as _NLLLoss,
    SmoothL1Loss as _SmoothL1Loss,
)
from neurx.nn.loss_extended import huber_loss as _huber_loss


def _as_array(value: Any) -> np.ndarray:
    if isinstance(value, Tensor):
        return np.asarray(value.data)
    return np.asarray(value)


def _copy_array(value: Any) -> np.ndarray:
    return np.array(_as_array(value), copy=True)


def _ensure_tensor(value: Any) -> Tensor:
    return value if isinstance(value, Tensor) else Tensor(value)


def _get_lr_group(group: dict[str, Any]) -> float:
    return float(group.get("lr", 0.0))


class Optimizer:
    def __init__(self, params: Iterable[Tensor], lr: float = 1e-3):
        self.params = list(params)
        self.param_groups = [{"params": self.params, "lr": float(lr)}]
        self.step_count = 0

    @property
    def lr(self) -> float:
        return _get_lr_group(self.param_groups[0])

    @lr.setter
    def lr(self, value: float) -> None:
        for group in self.param_groups:
            group["lr"] = float(value)

    def zero_grad(self) -> None:
        for param in self.params:
            if getattr(param, "grad", None) is not None:
                param.zero_grad()

    def _state_dict_base(self) -> dict[str, Any]:
        return {
            "step_count": self.step_count,
            "param_groups": [{"lr": group["lr"]} for group in self.param_groups],
        }

    def state_dict(self) -> dict[str, Any]:
        return self._state_dict_base()

    def load_state_dict(self, state: dict[str, Any]) -> None:
        self.step_count = int(state.get("step_count", 0))
        groups = state.get("param_groups", [])
        for group, saved in zip(self.param_groups, groups):
            group["lr"] = float(saved.get("lr", group["lr"]))

    def step(self) -> None:
        raise NotImplementedError


class SGD(Optimizer):
    def __init__(
        self,
        params: Iterable[Tensor],
        lr: float = 1e-3,
        momentum: float = 0.0,
        weight_decay: float = 0.0,
        nesterov: bool = False,
    ):
        super().__init__(params, lr=lr)
        self.momentum = float(momentum)
        self.weight_decay = float(weight_decay)
        self.nesterov = bool(nesterov)
        self._velocity = [np.zeros_like(p.data) for p in self.params]

    def step(self) -> None:
        for idx, param in enumerate(self.params):
            if getattr(param, "grad", None) is None:
                continue
            grad = np.asarray(param.grad, dtype=param.data.dtype)
            if self.weight_decay:
                grad = grad + self.weight_decay * param.data
            if self.momentum:
                self._velocity[idx] = self.momentum * self._velocity[idx] + grad
                update = self._velocity[idx]
                if self.nesterov:
                    update = grad + self.momentum * self._velocity[idx]
            else:
                update = grad
            param.data = param.data - self.lr * update
        self.step_count += 1

    def state_dict(self) -> dict[str, Any]:
        state = self._state_dict_base()
        state.update(
            {
                "momentum": self.momentum,
                "weight_decay": self.weight_decay,
                "nesterov": self.nesterov,
                "velocity": [_copy_array(v) for v in self._velocity],
            }
        )
        return state

    def load_state_dict(self, state: dict[str, Any]) -> None:
        super().load_state_dict(state)
        self.momentum = float(state.get("momentum", self.momentum))
        self.weight_decay = float(state.get("weight_decay", self.weight_decay))
        self.nesterov = bool(state.get("nesterov", self.nesterov))
        saved_velocity = state.get("velocity", [])
        if len(saved_velocity) == len(self._velocity):
            self._velocity = [np.array(v, copy=True) for v in saved_velocity]


class Adam(Optimizer):
    def __init__(
        self,
        params: Iterable[Tensor],
        lr: float = 1e-3,
        betas: tuple[float, float] = (0.9, 0.999),
        eps: float = 1e-8,
        weight_decay: float = 0.0,
    ):
        super().__init__(params, lr=lr)
        self.beta1, self.beta2 = map(float, betas)
        self.eps = float(eps)
        self.weight_decay = float(weight_decay)
        self._m = [np.zeros_like(p.data) for p in self.params]
        self._v = [np.zeros_like(p.data) for p in self.params]

    def step(self) -> None:
        self.step_count += 1
        for idx, param in enumerate(self.params):
            if getattr(param, "grad", None) is None:
                continue
            grad = np.asarray(param.grad, dtype=param.data.dtype)
            if self.weight_decay:
                grad = grad + self.weight_decay * param.data
            self._m[idx] = self.beta1 * self._m[idx] + (1.0 - self.beta1) * grad
            self._v[idx] = self.beta2 * self._v[idx] + (1.0 - self.beta2) * (grad * grad)
            m_hat = self._m[idx] / (1.0 - self.beta1**self.step_count)
            v_hat = self._v[idx] / (1.0 - self.beta2**self.step_count)
            param.data = param.data - self.lr * m_hat / (np.sqrt(v_hat) + self.eps)

    def state_dict(self) -> dict[str, Any]:
        state = self._state_dict_base()
        state.update(
            {
                "beta1": self.beta1,
                "beta2": self.beta2,
                "eps": self.eps,
                "weight_decay": self.weight_decay,
                "m": [_copy_array(v) for v in self._m],
                "v": [_copy_array(v) for v in self._v],
            }
        )
        return state

    def load_state_dict(self, state: dict[str, Any]) -> None:
        super().load_state_dict(state)
        self.beta1 = float(state.get("beta1", self.beta1))
        self.beta2 = float(state.get("beta2", self.beta2))
        self.eps = float(state.get("eps", self.eps))
        self.weight_decay = float(state.get("weight_decay", self.weight_decay))
        if len(state.get("m", [])) == len(self._m):
            self._m = [np.array(v, copy=True) for v in state["m"]]
        if len(state.get("v", [])) == len(self._v):
            self._v = [np.array(v, copy=True) for v in state["v"]]


class AdamW(Adam):
    def step(self) -> None:
        self.step_count += 1
        for idx, param in enumerate(self.params):
            if getattr(param, "grad", None) is None:
                continue
            grad = np.asarray(param.grad, dtype=param.data.dtype)
            self._m[idx] = self.beta1 * self._m[idx] + (1.0 - self.beta1) * grad
            self._v[idx] = self.beta2 * self._v[idx] + (1.0 - self.beta2) * (grad * grad)
            m_hat = self._m[idx] / (1.0 - self.beta1**self.step_count)
            v_hat = self._v[idx] / (1.0 - self.beta2**self.step_count)
            param.data = param.data - self.lr * (m_hat / (np.sqrt(v_hat) + self.eps) + self.weight_decay * param.data)


class RMSprop(Optimizer):
    def __init__(
        self,
        params: Iterable[Tensor],
        lr: float = 1e-3,
        alpha: float = 0.99,
        eps: float = 1e-8,
        weight_decay: float = 0.0,
        momentum: float = 0.0,
        centered: bool = False,
    ):
        super().__init__(params, lr=lr)
        self.alpha = float(alpha)
        self.eps = float(eps)
        self.weight_decay = float(weight_decay)
        self.momentum = float(momentum)
        self.centered = bool(centered)
        self._square_avg = [np.zeros_like(p.data) for p in self.params]
        self._grad_avg = [np.zeros_like(p.data) for p in self.params]
        self._momentum_buffer = [np.zeros_like(p.data) for p in self.params]

    def step(self) -> None:
        for idx, param in enumerate(self.params):
            if getattr(param, "grad", None) is None:
                continue
            grad = np.asarray(param.grad, dtype=param.data.dtype)
            if self.weight_decay:
                grad = grad + self.weight_decay * param.data
            self._square_avg[idx] = self.alpha * self._square_avg[idx] + (1.0 - self.alpha) * (grad * grad)
            if self.centered:
                self._grad_avg[idx] = self.alpha * self._grad_avg[idx] + (1.0 - self.alpha) * grad
                avg = self._square_avg[idx] - self._grad_avg[idx] ** 2
            else:
                avg = self._square_avg[idx]
            denom = np.sqrt(np.maximum(avg, 0.0) + self.eps)
            if self.momentum:
                self._momentum_buffer[idx] = self.momentum * self._momentum_buffer[idx] + self.lr * grad / denom
                param.data = param.data - self._momentum_buffer[idx]
            else:
                param.data = param.data - self.lr * grad / denom
        self.step_count += 1

    def state_dict(self) -> dict[str, Any]:
        state = self._state_dict_base()
        state.update(
            {
                "alpha": self.alpha,
                "eps": self.eps,
                "weight_decay": self.weight_decay,
                "momentum": self.momentum,
                "centered": self.centered,
                "square_avg": [_copy_array(v) for v in self._square_avg],
                "grad_avg": [_copy_array(v) for v in self._grad_avg],
                "momentum_buffer": [_copy_array(v) for v in self._momentum_buffer],
            }
        )
        return state

    def load_state_dict(self, state: dict[str, Any]) -> None:
        super().load_state_dict(state)
        self.alpha = float(state.get("alpha", self.alpha))
        self.eps = float(state.get("eps", self.eps))
        self.weight_decay = float(state.get("weight_decay", self.weight_decay))
        self.momentum = float(state.get("momentum", self.momentum))
        self.centered = bool(state.get("centered", self.centered))
        if len(state.get("square_avg", [])) == len(self._square_avg):
            self._square_avg = [np.array(v, copy=True) for v in state["square_avg"]]
        if len(state.get("grad_avg", [])) == len(self._grad_avg):
            self._grad_avg = [np.array(v, copy=True) for v in state["grad_avg"]]
        if len(state.get("momentum_buffer", [])) == len(self._momentum_buffer):
            self._momentum_buffer = [np.array(v, copy=True) for v in state["momentum_buffer"]]


class _LossWrapper:
    def __call__(self, *args, **kwargs):
        raise NotImplementedError


class HuberLoss(_LossWrapper):
    def __init__(self, delta: float = 1.0, reduction: str = "mean"):
        self.delta = float(delta)
        self.reduction = reduction

    def __call__(self, input, target):
        data = _huber_loss(_as_array(input), _as_array(target), delta=self.delta)
        if self.reduction == "sum":
            data = np.array(data, dtype=np.float64) * np.asarray(input).size
        elif self.reduction == "none":
            diff = np.asarray(input) - np.asarray(target)
            data = np.where(np.abs(diff) <= self.delta, 0.5 * diff**2, self.delta * (np.abs(diff) - 0.5 * self.delta))
        return Tensor(np.asarray(data))


class PoissonNLLLoss(_LossWrapper):
    def __init__(self, reduction: str = "mean", log_input: bool = True):
        self.reduction = reduction
        self.log_input = bool(log_input)

    def __call__(self, input, target):
        x = np.asarray(input)
        y = np.asarray(target)
        if self.log_input:
            loss = np.exp(x) - y * x
        else:
            x = np.clip(x, 1e-12, None)
            loss = x - y * np.log(x)
        if self.reduction == "sum":
            return Tensor(np.asarray(loss).sum())
        if self.reduction == "none":
            return Tensor(np.asarray(loss))
        return Tensor(np.asarray(loss).mean())


class MarginRankingLoss(_LossWrapper):
    def __init__(self, margin: float = 1.0, reduction: str = "mean"):
        self.margin = float(margin)
        self.reduction = reduction

    def __call__(self, input1, input2, target):
        loss = np.maximum(0.0, -np.asarray(target) * (np.asarray(input1) - np.asarray(input2)) + self.margin)
        if self.reduction == "sum":
            return Tensor(loss.sum())
        if self.reduction == "none":
            return Tensor(loss)
        return Tensor(loss.mean())


class TripletMarginLoss(_LossWrapper):
    def __init__(self, margin: float = 1.0, p: int = 2, reduction: str = "mean"):
        self.margin = float(margin)
        self.p = int(p)
        self.reduction = reduction

    def __call__(self, anchor, positive, negative):
        a = np.asarray(anchor)
        p = np.asarray(positive)
        n = np.asarray(negative)
        pos = np.linalg.norm(a - p, ord=self.p, axis=-1)
        neg = np.linalg.norm(a - n, ord=self.p, axis=-1)
        loss = np.maximum(0.0, pos - neg + self.margin)
        if self.reduction == "sum":
            return Tensor(loss.sum())
        if self.reduction == "none":
            return Tensor(loss)
        return Tensor(loss.mean())


class CTCLoss(_LossWrapper):
    def __init__(self, reduction: str = "mean"):
        self.reduction = reduction

    def __call__(self, *args, **kwargs):
        del args, kwargs
        return Tensor(np.array(0.0))


class _ModuleLossWrapper(_LossWrapper):
    _module_cls: Any

    def __init__(self, *args, **kwargs):
        self._loss = self._module_cls(*args, **kwargs)

    def __call__(self, *args, **kwargs):
        return self._loss(*args, **kwargs)


class CrossEntropyLoss(_ModuleLossWrapper):
    _module_cls = _CrossEntropyLoss


class BCELoss(_ModuleLossWrapper):
    _module_cls = _BCELoss


class BCEWithLogitsLoss(_ModuleLossWrapper):
    _module_cls = _BCEWithLogitsLoss


class L1Loss(_ModuleLossWrapper):
    _module_cls = _L1Loss


class MSELoss(_ModuleLossWrapper):
    _module_cls = _MSELoss


class SmoothL1Loss(_ModuleLossWrapper):
    _module_cls = _SmoothL1Loss


class KLDivLoss(_ModuleLossWrapper):
    _module_cls = _KLDivLoss


class NLLLoss(_ModuleLossWrapper):
    _module_cls = _NLLLoss


def _assign_lr(optimizer: Any, lr: float) -> None:
    if hasattr(optimizer, "param_groups"):
        for group in optimizer.param_groups:
            group["lr"] = float(lr)


class _Scheduler:
    def __init__(self, optimizer: Any):
        self.optimizer = optimizer
        self.last_epoch = -1
        self.base_lrs = [_get_lr_group(g) for g in optimizer.param_groups]

    def _set_lr(self, value: float) -> None:
        _assign_lr(self.optimizer, value)

    def state_dict(self) -> dict[str, Any]:
        return {"last_epoch": self.last_epoch, "base_lrs": list(self.base_lrs)}

    def load_state_dict(self, state: dict[str, Any]) -> None:
        self.last_epoch = int(state.get("last_epoch", self.last_epoch))
        if "base_lrs" in state:
            self.base_lrs = list(state["base_lrs"])


class StepLR(_Scheduler):
    def __init__(self, optimizer: Any, step_size: int, gamma: float = 0.1):
        super().__init__(optimizer)
        self.step_size = int(step_size)
        self.gamma = float(gamma)

    def step(self):
        self.last_epoch += 1
        epoch = self.last_epoch + 1
        factor = self.gamma ** (epoch // self.step_size)
        self._set_lr(self.base_lrs[0] * factor)


class ExponentialLR(_Scheduler):
    def __init__(self, optimizer: Any, gamma: float = 0.99):
        super().__init__(optimizer)
        self.gamma = float(gamma)

    def step(self):
        self.last_epoch += 1
        epoch = self.last_epoch + 1
        self._set_lr(self.base_lrs[0] * (self.gamma ** epoch))


class CosineAnnealingLR(_Scheduler):
    def __init__(self, optimizer: Any, T_max: int, eta_min: float = 0.0):
        super().__init__(optimizer)
        self.T_max = max(int(T_max), 1)
        self.eta_min = float(eta_min)

    def step(self):
        self.last_epoch += 1
        step = min(self.last_epoch + 1, self.T_max)
        lr = self.eta_min + (self.base_lrs[0] - self.eta_min) * (1.0 + math.cos(math.pi * step / self.T_max)) / 2.0
        self._set_lr(lr)


class CosineAnnealingWarmRestarts(_Scheduler):
    def __init__(self, optimizer: Any, T_0: int, T_mult: int = 1, eta_min: float = 0.0):
        super().__init__(optimizer)
        self.T_0 = max(int(T_0), 1)
        self.T_mult = max(int(T_mult), 1)
        self.eta_min = float(eta_min)
        self._cycle = 0
        self._cycle_step = 0
        self._cycle_len = self.T_0

    def step(self):
        self.last_epoch += 1
        if self._cycle_step >= self._cycle_len:
            self._cycle += 1
            self._cycle_step = 0
            self._cycle_len = self.T_0 * (self.T_mult**self._cycle)
        lr = self.eta_min + (self.base_lrs[0] - self.eta_min) * (1.0 + math.cos(math.pi * self._cycle_step / self._cycle_len)) / 2.0
        self._set_lr(lr)
        self._cycle_step += 1


class LinearLR(_Scheduler):
    def __init__(self, optimizer: Any, start_factor: float = 0.1, end_factor: float = 1.0, total_iters: int = 5):
        super().__init__(optimizer)
        self.start_factor = float(start_factor)
        self.end_factor = float(end_factor)
        self.total_iters = max(int(total_iters), 1)
        self._set_lr(self.base_lrs[0] * self.start_factor)

    def step(self):
        self.last_epoch += 1
        progress = min((self.last_epoch + 1) / self.total_iters, 1.0)
        factor = self.start_factor + (self.end_factor - self.start_factor) * progress
        self._set_lr(self.base_lrs[0] * factor)


class PolynomialLR(_Scheduler):
    def __init__(self, optimizer: Any, total_iters: int, power: float = 1.0, end_lr: float = 0.0):
        super().__init__(optimizer)
        self.total_iters = max(int(total_iters), 1)
        self.power = float(power)
        self.end_lr = float(end_lr)

    def step(self):
        self.last_epoch += 1
        progress = min((self.last_epoch + 1) / self.total_iters, 1.0)
        lr = (self.base_lrs[0] - self.end_lr) * ((1.0 - progress) ** self.power) + self.end_lr
        self._set_lr(lr)


class MultiplicativeLR(_Scheduler):
    def __init__(self, optimizer: Any, lr_lambda: Callable[[int], float]):
        super().__init__(optimizer)
        self.lr_lambda = lr_lambda

    def step(self):
        self.last_epoch += 1
        epoch = self.last_epoch + 1
        self._set_lr(self.base_lrs[0] * float(self.lr_lambda(epoch)))


class LambdaLR(MultiplicativeLR):
    pass


class ReduceLROnPlateau(_Scheduler):
    def __init__(self, optimizer: Any, factor: float = 0.1, patience: int = 10, min_lr: float = 0.0, mode: str = "min"):
        super().__init__(optimizer)
        self.factor = float(factor)
        self.patience = int(patience)
        self.min_lr = float(min_lr)
        self.mode = mode
        self.best = math.inf if mode == "min" else -math.inf
        self.wait = 0

    def step(self, metric: float):
        improved = metric < self.best if self.mode == "min" else metric > self.best
        if improved:
            self.best = metric
            self.wait = 0
            return
        self.wait += 1
        if self.wait >= self.patience:
            lr = max(_get_lr_group(self.optimizer.param_groups[0]) * self.factor, self.min_lr)
            self._set_lr(lr)
            self.wait = 0


class WarmupLR(_Scheduler):
    def __init__(self, optimizer: Any, warmup_epochs: int = 10):
        super().__init__(optimizer)
        self.warmup_epochs = max(int(warmup_epochs), 1)
        self._set_lr(0.0)

    def step(self):
        self.last_epoch += 1
        progress = min((self.last_epoch + 1) / self.warmup_epochs, 1.0)
        self._set_lr(self.base_lrs[0] * progress)


class WarmupDecayLR(_Scheduler):
    def __init__(self, optimizer: Any, warmup_epochs: int, total_epochs: int, decay_type: str = "linear"):
        super().__init__(optimizer)
        self.warmup_epochs = max(int(warmup_epochs), 1)
        self.total_epochs = max(int(total_epochs), self.warmup_epochs + 1)
        self.decay_type = decay_type
        self._set_lr(0.0)

    def step(self):
        self.last_epoch += 1
        epoch = self.last_epoch + 1
        if epoch <= self.warmup_epochs:
            lr = self.base_lrs[0] * (epoch / self.warmup_epochs)
        else:
            progress = min((epoch - self.warmup_epochs) / max(self.total_epochs - self.warmup_epochs, 1), 1.0)
            if self.decay_type == "linear":
                lr = self.base_lrs[0] * (1.0 - progress)
            else:
                lr = self.base_lrs[0] * (0.5 * (1.0 + math.cos(math.pi * progress)))
        self._set_lr(lr)


class StepDecayWithWarmup(_Scheduler):
    def __init__(self, optimizer: Any, warmup_epochs: int, step_size: int, gamma: float = 0.1):
        super().__init__(optimizer)
        self.warmup_epochs = max(int(warmup_epochs), 1)
        self.step_size = max(int(step_size), 1)
        self.gamma = float(gamma)
        self._set_lr(0.0)

    def step(self):
        self.last_epoch += 1
        epoch = self.last_epoch + 1
        if epoch <= self.warmup_epochs:
            lr = self.base_lrs[0] * (epoch / self.warmup_epochs)
        else:
            decay_steps = (epoch - self.warmup_epochs) // self.step_size
            lr = self.base_lrs[0] * (self.gamma ** decay_steps)
        self._set_lr(lr)


class CyclicLR(_Scheduler):
    def __init__(self, optimizer: Any, base_lr: float, max_lr: float, step_size: int):
        super().__init__(optimizer)
        self.base_lr = float(base_lr)
        self.max_lr = float(max_lr)
        self.step_size = max(int(step_size), 1)
        self._set_lr(self.base_lr)

    def step(self):
        self.last_epoch += 1
        cycle = math.floor(1 + self.last_epoch / (2 * self.step_size))
        x = abs(self.last_epoch / self.step_size - 2 * cycle + 1)
        scale = max(0.0, 1.0 - x)
        lr = self.base_lr + (self.max_lr - self.base_lr) * scale
        self._set_lr(lr)


class OneCycleLR(_Scheduler):
    def __init__(self, optimizer: Any, max_lr: float, total_steps: int, pct_start: float = 0.3):
        super().__init__(optimizer)
        self.max_lr = float(max_lr)
        self.total_steps = max(int(total_steps), 1)
        self.pct_start = float(pct_start)
        self._set_lr(self.base_lrs[0])

    def step(self):
        self.last_epoch += 1
        step = self.last_epoch + 1
        rise_steps = max(int(self.total_steps * self.pct_start), 1)
        if step <= rise_steps:
            lr = self.base_lrs[0] + (self.max_lr - self.base_lrs[0]) * (step / rise_steps)
        else:
            down_steps = max(self.total_steps - rise_steps, 1)
            progress = min((step - rise_steps) / down_steps, 1.0)
            lr = self.max_lr * (1.0 - progress)
        self._set_lr(lr)


__all__ = [
    "Optimizer",
    "SGD",
    "Adam",
    "AdamW",
    "RMSprop",
    "CrossEntropyLoss",
    "BCELoss",
    "BCEWithLogitsLoss",
    "L1Loss",
    "MSELoss",
    "SmoothL1Loss",
    "KLDivLoss",
    "NLLLoss",
    "HuberLoss",
    "PoissonNLLLoss",
    "CTCLoss",
    "MarginRankingLoss",
    "TripletMarginLoss",
    "StepLR",
    "ExponentialLR",
    "CosineAnnealingLR",
    "CosineAnnealingWarmRestarts",
    "LinearLR",
    "PolynomialLR",
    "MultiplicativeLR",
    "LambdaLR",
    "ReduceLROnPlateau",
    "WarmupLR",
    "WarmupDecayLR",
    "StepDecayWithWarmup",
    "CyclicLR",
    "OneCycleLR",
]
