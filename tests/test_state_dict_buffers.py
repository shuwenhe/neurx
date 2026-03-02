import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor.nn import Module, Linear
from tensor.tensor import Tensor


class Toy(Module):
    def __init__(self):
        super().__init__()
        self.l1 = Linear(3, 4)
        self.register_buffer("running_mean", Tensor(np.zeros((4,))))
        self.register_buffer("tmp_cache", Tensor(np.ones((4,))), persistent=False)

    def forward(self, x):
        return self.l1(x)


def test_state_dict_includes_persistent_buffers():
    m = Toy()
    state = m.state_dict()
    assert "running_mean" in state
    assert "tmp_cache" not in state


def test_state_dict_roundtrip():
    m = Toy()
    state = m.state_dict()
    m2 = Toy()
    m2.load_state_dict(state)
    for k, v in state.items():
        assert np.allclose(m2.state_dict()[k], v)
