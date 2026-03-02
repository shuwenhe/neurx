import numpy as np

from tensor.tensor import Tensor
from tensor.nn import functional as F


def cross_entropy(logits: Tensor, targets):
    # Delegate to functional for consistent behavior.
    return F.cross_entropy(logits, targets)


def cross_entropy_loss(logits: Tensor, targets):
    # Backwards-compat alias used by __init__.py
    return cross_entropy(logits, targets)
