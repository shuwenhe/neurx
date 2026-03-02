import os
import numpy as np

from tensor import Tensor
from tensor.cuda.ops import DeviceArray, available, to_host


def _cuda_runtime_ok() -> bool:
    if not available():
        return False
    try:
        x = Tensor(np.zeros((2, 2), dtype=np.float32), device="cuda")
        _ = x + x
        return True
    except Exception:
        return False


def _to_np(x):
    if isinstance(x, DeviceArray):
        return to_host(x)
    return x


def _value_only(v):
    if isinstance(v, tuple):
        return v[0]
    return v


def test_cuda_reductions_match_cpu():
    os.environ["TENSOR_DEVICE"] = "cuda"
    if not _cuda_runtime_ok():
        print("CUDA not available; skipping reduction test.")
        return

    x_np = np.random.randn(2, 3, 4).astype(np.float32)
    x_cuda = Tensor(x_np, device="cuda")
    x_cpu = Tensor(x_np, device="cpu")

    ops = ("sum", "mean", "max", "min")
    axes = (None, 0, 1, 2)
    keepdims_opts = (False, True)

    for name in ops:
        for axis in axes:
            for keepdims in keepdims_opts:
                cuda_out = _value_only(getattr(x_cuda, name)(axis=axis, keepdims=keepdims))
                cpu_out = _value_only(getattr(x_cpu, name)(axis=axis, keepdims=keepdims))
                assert cuda_out.shape == cpu_out.shape
                assert np.allclose(_to_np(cuda_out.data), cpu_out.to_numpy(), atol=1e-5, rtol=1e-5)


def test_cuda_indices_behavior():
    os.environ["TENSOR_DEVICE"] = "cuda"
    if not _cuda_runtime_ok():
        print("CUDA not available; skipping indices test.")
        return

    x_np = np.random.randn(2, 3, 4).astype(np.float32)
    x = Tensor(x_np, device="cuda")

    v_max, i_max = x.max(axis=-1)
    v_min, i_min = x.min(axis=-1)
    a_max = x.argmax(axis=-1)
    a_min = x.argmin(axis=-1)

    assert v_max.device == "cuda"
    assert v_min.device == "cuda"
    assert i_max.device == "cuda"
    assert i_min.device == "cuda"
    assert a_max.device == "cuda"
    assert a_min.device == "cuda"

    assert i_max.shape == (2, 3)
    assert i_min.shape == (2, 3)
    assert a_max.shape == (2, 3)
    assert a_min.shape == (2, 3)

    assert i_max.to_numpy().dtype == np.int32
    assert i_min.to_numpy().dtype == np.int32
    assert a_max.to_numpy().dtype == np.int32
    assert a_min.to_numpy().dtype == np.int32

    assert np.array_equal(i_max.to_numpy(), x_np.argmax(axis=-1).astype(np.int32))
    assert np.array_equal(i_min.to_numpy(), x_np.argmin(axis=-1).astype(np.int32))
    assert np.array_equal(a_max.to_numpy(), x_np.argmax(axis=-1).astype(np.int32))
    assert np.array_equal(a_min.to_numpy(), x_np.argmin(axis=-1).astype(np.int32))

    # Non-lastdim currently falls back to CPU indices.
    a_cpu = x.argmax(axis=1)
    assert a_cpu.device == "cpu"
    assert a_cpu.to_numpy().dtype == np.int64
    assert a_cpu.shape == (2, 4)
