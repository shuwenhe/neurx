import numpy as np

from neurx import Tensor
import neurx
from neurx.ad import backward, enable_grad, new_state
from neurx.autograd import Function


def test_python_ad_and_autograd_imports_work():
    assert neurx.ad is not None
    assert neurx.optim is not None

    state = new_state()
    assert state.grad_enabled is True
    assert state.grad_accumulation is False

    enabled = enable_grad(state)
    assert enabled.grad_enabled is True

    assert Function is not None

    x = Tensor([1.0, 2.0, 3.0], requires_grad=True)
    grad = backward(x)
    assert np.allclose(grad.to_numpy(), [1.0, 1.0, 1.0])
