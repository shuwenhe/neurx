import os
import numpy as np

from tensor.core.tensor import Tensor
from tensor.core.nn import Linear
from tensor.cuda.ops import DeviceArray, to_host


def _to_np(x):
    if isinstance(x, DeviceArray):
        return to_host(x)
    return x


def test_cuda_add_mul_matmul_linear():
    os.environ["TENSOR_DEVICE"] = "cuda"
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


if __name__ == "__main__":
    test_cuda_add_mul_matmul_linear()
    print("CUDA smoke test passed")
