import os
import numpy as np

from tensor.core.tensor import Tensor


def test_cuda_add_mul():
    os.environ["TENSOR_DEVICE"] = "cuda"
    a = Tensor(np.random.randn(1024).astype(np.float32), requires_grad=False)
    b = Tensor(np.random.randn(1024).astype(np.float32), requires_grad=False)

    c = a + b
    d = a * b

    assert np.allclose(c.data, a.data + b.data)
    assert np.allclose(d.data, a.data * b.data)


if __name__ == "__main__":
    test_cuda_add_mul()
    print("CUDA smoke test passed")
