from __future__ import annotations

from neurx.core import Tensor, ones_like, zeros_like


def backward(t: Tensor) -> Tensor:
    if not getattr(t, "requires_grad", False):
        return zeros_like(t)
    return ones_like(t)


__all__ = ["backward"]
