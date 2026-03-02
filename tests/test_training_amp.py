import os

import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor.nn import Linear
from tensor.optim import AdamW
from tensor.tensor import Tensor
from tensor.training import GradScaler, autocast, get_autocast_dtype, is_autocast_enabled


def test_autocast_context_state():
    assert is_autocast_enabled() is False
    with autocast(enabled=True, dtype=np.float16):
        assert is_autocast_enabled() is True
        assert get_autocast_dtype() == np.float16
    assert is_autocast_enabled() is False


def test_grad_scaler_step_updates_params():
    np.random.seed(0)
    model = Linear(3, 2)
    optimizer = AdamW(model.parameters(), lr=1e-3)
    scaler = GradScaler(init_scale=128.0, growth_interval=1)

    x = Tensor(np.random.randn(4, 3))
    loss = (model(x) * model(x)).mean()
    optimizer.zero_grad()
    scaler.scale_loss(loss).backward()
    before = model.weight.to_numpy().copy()
    stepped = scaler.step(optimizer)
    after = model.weight.to_numpy().copy()

    assert stepped is True
    assert not np.allclose(before, after)
    assert scaler.scale > 128.0


def test_grad_scaler_state_dict_roundtrip():
    scaler = GradScaler(init_scale=64.0, growth_interval=10)
    state = scaler.state_dict()
    other = GradScaler(init_scale=2.0)
    other.load_state_dict(state)
    assert other.state_dict()["scale"] == state["scale"]
    assert other.state_dict()["growth_interval"] == state["growth_interval"]
