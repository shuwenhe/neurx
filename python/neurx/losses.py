from neurx.nn.functional import (
    bce_loss,
    bce_with_logits_loss,
    cross_entropy,
    kl_div_loss,
    l1_loss,
    mse_loss,
    nll_loss,
    smooth_l1_loss,
)

cross_entropy_loss = cross_entropy

__all__ = [
    "cross_entropy",
    "cross_entropy_loss",
    "mse_loss",
    "nll_loss",
    "bce_loss",
    "bce_with_logits_loss",
    "l1_loss",
    "smooth_l1_loss",
    "kl_div_loss",
]
