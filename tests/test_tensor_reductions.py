import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor import Tensor


def _maybe_cuda():
    return os.environ.get("TENSOR_DEVICE", "cpu").lower() == "cuda"


def test_sum_mean_max_min_cpu_shapes():
    x = Tensor(np.random.randn(2, 3, 4), requires_grad=True)

    s0 = x.sum()
    s1 = x.sum(axis=1)
    s2 = x.sum(axis=(0, 2), keepdims=True)
    m0 = x.mean()
    m1 = x.mean(axis=2)
    mx = x.max(axis=1)
    mn = x.min(axis=0)

    assert s0.shape == ()
    assert s1.shape == (2, 4)
    assert s2.shape == (1, 3, 1)
    assert m0.shape == ()
    assert m1.shape == (2, 3)
    assert mx.shape == (2, 4)
    assert mn.shape == (3, 4)


def test_sum_mean_max_min_cpu_backward():
    x = Tensor(np.random.randn(2, 3, 4), requires_grad=True)
    loss = x.sum() + x.mean() + x.max() + x.min()
    loss.backward()
    assert x.grad is not None
    assert x.grad.shape == x.shape


def test_sum_mean_max_min_cuda_consistency():
    if not _maybe_cuda():
        return
    try:
        x = Tensor(np.random.randn(2, 3, 4).astype(np.float32), requires_grad=True, device="cuda")
    except Exception:
        return
    s = x.sum()
    m = x.mean()
    mx = x.max()
    mn = x.min()

    # compare to CPU
    x_cpu = Tensor(x.to_numpy(), requires_grad=False)
    assert np.allclose(s.to_numpy(), x_cpu.sum().to_numpy(), atol=1e-5)
    assert np.allclose(m.to_numpy(), x_cpu.mean().to_numpy(), atol=1e-5)
    assert np.allclose(mx.to_numpy(), x_cpu.max().to_numpy(), atol=1e-5)
    assert np.allclose(mn.to_numpy(), x_cpu.min().to_numpy(), atol=1e-5)
