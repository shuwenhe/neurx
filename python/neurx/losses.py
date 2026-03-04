import numpy as np

from neurx.neurx import Tensor
from neurx.nn import functional as F


def cross_entropy(
    logits: Tensor,
    targets,
    weight=None,
    ignore_index: int = -100,
    reduction: str = "mean",
    label_smoothing: float = 0.0,
    dim=None,
):
    # Delegate to functional for consistent behavior.
    return F.cross_entropy(
        logits,
        targets,
        weight=weight,
        ignore_index=ignore_index,
        reduction=reduction,
        label_smoothing=label_smoothing,
        dim=dim,
    )


def cross_entropy_loss(
    logits: Tensor,
    targets,
    weight=None,
    ignore_index: int = -100,
    reduction: str = "mean",
    label_smoothing: float = 0.0,
    dim=None,
):
    # Backwards-compat alias used by __init__.py
    return cross_entropy(
        logits,
        targets,
        weight=weight,
        ignore_index=ignore_index,
        reduction=reduction,
        label_smoothing=label_smoothing,
        dim=dim,
    )
