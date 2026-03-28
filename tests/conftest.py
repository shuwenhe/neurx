import os
import pytest


@pytest.fixture(autouse=True)
def _force_cpu_device():
    # Keep historical default as CPU, but allow batch backend tests to override via env.
    requested = os.environ.get("NEURX_TEST_DEVICE") or os.environ.get("TENSOR_DEVICE") or "cpu"
    os.environ["TENSOR_DEVICE"] = requested
    yield
