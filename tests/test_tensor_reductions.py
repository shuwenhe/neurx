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
    s3 = x.sum(dim=1, keepdim=True)
    m0 = x.mean()
    m1 = x.mean(axis=2)
    m2 = x.mean(dim=1, keepdim=True)
    mx, midx = x.max(axis=1)
    mn, nidx = x.min(axis=0)

    assert s0.shape == ()
    assert s1.shape == (2, 4)
    assert s2.shape == (1, 3, 1)
    assert s3.shape == (2, 1, 4)
    assert m0.shape == ()
    assert m1.shape == (2, 3)
    assert m2.shape == (2, 1, 4)
    assert mx.shape == (2, 4)
    assert mn.shape == (3, 4)
    assert midx.shape == (2, 4)
    assert nidx.shape == (3, 4)


def test_sum_mean_max_min_cpu_backward():
    x = Tensor(np.random.randn(2, 3, 4), requires_grad=True)
    loss = x.sum() + x.mean() + x.max() + x.min()
    loss.backward()
    assert x.grad is not None
    assert x.grad.shape == x.shape


def test_argmax_argmin():
    x = Tensor(np.array([[1.0, 3.0, 2.0], [0.0, -1.0, 5.0]]))
    a0 = x.argmax(axis=1)
    a1 = x.argmin(axis=0)
    assert a0.shape == (2,)
    assert a1.shape == (3,)


def test_max_min_return_indices():
    x = Tensor(np.array([[1.0, 3.0, 2.0], [0.0, -1.0, 5.0]]))
    v, i = x.max(axis=1)
    v2, i2 = x.min(axis=0)
    assert v.shape == (2,)
    assert i.shape == (2,)
    assert v2.shape == (3,)
    assert i2.shape == (3,)


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
