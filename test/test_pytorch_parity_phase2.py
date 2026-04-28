import numpy as np
import pytest

import neurx
from neurx import nn, optim


class _Tiny(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc = nn.Linear(2, 1)

    def forward(self, x):
        return self.fc(x)


def test_optimizer_param_groups_lr_step():
    p1 = neurx.Tensor([1.0], requires_grad=True)
    p2 = neurx.Tensor([1.0], requires_grad=True)

    optimizer = optim.SGD(
        [
            {"params": [p1], "lr": 0.1},
            {"params": [p2], "lr": 0.01},
        ],
        momentum=0.0,
        weight_decay=0.0,
    )

    p1.grad = np.array([1.0])
    p2.grad = np.array([1.0])
    optimizer.step()

    assert np.allclose(p1.data, np.array([0.9]))
    assert np.allclose(p2.data, np.array([0.99]))


def test_optimizer_state_dict_contains_param_groups_and_loads_them():
    p1 = neurx.Tensor([1.0], requires_grad=True)
    p2 = neurx.Tensor([2.0], requires_grad=True)

    opt1 = optim.Adam(
        [
            {"params": [p1], "lr": 1e-3},
            {"params": [p2], "lr": 2e-3},
        ]
    )
    state = opt1.state_dict()

    assert "param_groups" in state
    assert len(state["param_groups"]) == 2
    assert state["param_groups"][0]["lr"] == 1e-3
    assert state["param_groups"][1]["lr"] == 2e-3

    q1 = neurx.Tensor([3.0], requires_grad=True)
    q2 = neurx.Tensor([4.0], requires_grad=True)
    opt2 = optim.Adam(
        [
            {"params": [q1], "lr": 9e-3},
            {"params": [q2], "lr": 9e-3},
        ]
    )
    opt2.load_state_dict(state)

    assert opt2.param_groups[0]["lr"] == 1e-3
    assert opt2.param_groups[1]["lr"] == 2e-3


def test_module_load_state_dict_strict_runtime_error_and_incompatible_keys():
    model = _Tiny()
    state = model.state_dict()

    broken = dict(state)
    removed_key = next(iter(broken.keys()))
    del broken[removed_key]
    broken["unexpected.weight"] = np.array([1.0])

    with pytest.raises(RuntimeError):
        model.load_state_dict(broken, strict=True)

    result = model.load_state_dict(broken, strict=False)
    assert hasattr(result, "missing_keys")
    assert hasattr(result, "unexpected_keys")
    assert removed_key in result.missing_keys
    assert "unexpected.weight" in result.unexpected_keys
