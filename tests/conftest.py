import os
import pytest


@pytest.fixture(autouse=True)
def _force_cpu_device():
    # Force CPU for tests unless a test explicitly sets CUDA.
    os.environ["TENSOR_DEVICE"] = "cpu"
    yield
