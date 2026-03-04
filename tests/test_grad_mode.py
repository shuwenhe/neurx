import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from neurx import Tensor, enable_grad, is_grad_enabled, no_grad, set_grad_enabled


def test_default_grad_enabled():
    assert is_grad_enabled() is True


def test_no_grad_blocks_graph_construction():
    x = Tensor(np.array([2.0], dtype=np.float64), requires_grad=True)
    w = Tensor(np.array([3.0], dtype=np.float64), requires_grad=True)

    with no_grad():
        y = x * 2.0

    assert y.requires_grad is False

    out = y * w
    out.sum().backward()

    assert np.allclose(x.grad, np.array([0.0]))
    assert np.allclose(w.grad, y.to_numpy())


def test_enable_grad_inside_no_grad():
    x = Tensor(np.array([1.5], dtype=np.float64), requires_grad=True)

    with no_grad():
        y = x * 2.0
        with enable_grad():
            z = x * 3.0

    assert y.requires_grad is False
    assert z.requires_grad is True

    x.zero_grad()
    z.sum().backward()
    assert np.allclose(x.grad, np.array([3.0]))


def test_set_grad_enabled_context():
    x = Tensor(np.array([2.0], dtype=np.float64), requires_grad=True)

    with set_grad_enabled(False):
        a = x * 4.0
    with set_grad_enabled(True):
        b = x * 5.0

    assert a.requires_grad is False
    assert b.requires_grad is True


def test_leaf_creation_respects_explicit_requires_grad():
    with no_grad():
        p = Tensor(np.array([1.0], dtype=np.float64), requires_grad=True)
        q = p * 2.0

    assert p.requires_grad is True
    assert q.requires_grad is False
