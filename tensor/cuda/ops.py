import numpy as np

try:
    from . import _tensor_cuda as _cuda
except Exception:
    _cuda = None


def available() -> bool:
    return _cuda is not None


def _ensure_array(x: np.ndarray) -> np.ndarray:
    if not isinstance(x, np.ndarray):
        raise TypeError("cuda ops require numpy.ndarray inputs")
    if not x.flags["C_CONTIGUOUS"]:
        x = np.ascontiguousarray(x)
    if x.dtype not in (np.float32, np.float64):
        raise TypeError("cuda ops only support float32/float64")
    return x


def add(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    a = _ensure_array(a)
    b = _ensure_array(b)
    return _cuda.add(a, b)


def mul(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    if _cuda is None:
        raise RuntimeError("tensor.cuda backend not available")
    a = _ensure_array(a)
    b = _ensure_array(b)
    return _cuda.mul(a, b)
