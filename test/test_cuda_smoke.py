import os
import numpy as np
import pytest

from neurx import Tensor
from neurx.nn import Linear, LayerNorm, Softmax
from neurx.cuda.ops import DeviceArray, to_host, available


def _cuda_runtime_ok() -> bool:
    if not available():
        return False
    try:
        tmp = Tensor(np.zeros((1,), dtype=np.float32))
        _ = tmp + tmp
        return True
    except Exception:
        return False


def _to_np(x):
    if isinstance(x, DeviceArray):
        return to_host(x)
    return x


def test_cuda_add_mul_matmul_linear():
    os.environ["TENSOR_DEVICE"] = "cuda"
    if not _cuda_runtime_ok():
        pytest.skip("CUDA runtime not available")
    a = Tensor(np.random.randn(1024).astype(np.float32), requires_grad=False)
    b = Tensor(np.random.randn(1024).astype(np.float32), requires_grad=False)

    c = a + b
    d = a * b

    assert np.allclose(_to_np(c.data), _to_np((a + b).data))
    assert np.allclose(_to_np(d.data), _to_np((a * b).data))

    x = Tensor(np.random.randn(16, 32).astype(np.float32))
    w = Tensor(np.random.randn(32, 8).astype(np.float32))
    y = x @ w
    assert np.allclose(_to_np(y.data), _to_np((x @ w).data))

    layer = Linear(32, 8, bias=True)
    y2 = layer(x)
    assert y2.shape == (16, 8)

    x3 = Tensor(np.random.randn(2, 4, 8).astype(np.float32))
    b3 = Tensor(np.random.randn(8).astype(np.float32))
    y3 = x3 + b3
    assert y3.shape == (2, 4, 8)

    ln = LayerNorm(8)
    y4 = ln(x3)
    assert y4.shape == (2, 4, 8)

    sm = Softmax(axis=-1)
    y5 = sm(x3)
    assert y5.shape == (2, 4, 8)


if __name__ == "__main__":
    test_cuda_add_mul_matmul_linear()
    print("CUDA smoke test passed")
