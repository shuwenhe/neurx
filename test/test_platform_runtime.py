import numpy as np
import pytest

from neurx.platform import format_doctor_report, get_runtime_config, runtime_info, doctor


def test_runtime_config_from_env(monkeypatch):
    monkeypatch.setenv("TENSOR_DEVICE", "mps")
    monkeypatch.setenv("TENSOR_LOG_LEVEL", "debug")
    cfg = get_runtime_config(reload=True)
    assert cfg.default_device == "mps"
    assert cfg.log_level == "DEBUG"


def test_runtime_info_has_required_fields():
    info = runtime_info()
    required = {
        "tensor_version",
        "python_version",
        "platform",
        "numpy_version",
        "default_device",
        "cuda_available",
        "mps_available",
        "env",
    }
    assert required.issubset(set(info.keys()))


def test_doctor_report_format():
    results = doctor(require_cuda=False)
    text = format_doctor_report(results)
    assert "neurx doctor report" in text
    assert any(item.name == "python" for item in results)


def test_doctor_reports_mps(monkeypatch):
    from neurx.platform import diagnostics

    monkeypatch.setattr(diagnostics, "_mps_available", lambda: True)
    results = doctor(require_cuda=False, require_mps=True)
    assert any(item.name == "mps.runtime" and item.passed for item in results)
    assert any(item.name == "require_mps" and item.passed for item in results)


def test_tensor_fallback_to_cpu_when_cuda_unavailable(monkeypatch):
    from neurx.core import neurx as tensor_core

    monkeypatch.setenv("TENSOR_DEVICE", "cuda")
    monkeypatch.setenv("TENSOR_FALLBACK_TO_CPU", "1")
    monkeypatch.setattr(tensor_core, "_cuda_ops", None)
    cfg = get_runtime_config(reload=True)
    assert cfg.default_device == "cuda"
    t = tensor_core.Tensor(np.ones((2, 2), dtype=np.float32))
    assert t.device == "cpu"


def test_tensor_cuda_strict_raises_when_unavailable(monkeypatch):
    from neurx.core import neurx as tensor_core
    from neurx.platform import BackendNotAvailableError

    monkeypatch.setenv("TENSOR_DEVICE", "cuda")
    monkeypatch.setenv("TENSOR_FALLBACK_TO_CPU", "0")
    monkeypatch.setattr(tensor_core, "_cuda_ops", None)
    get_runtime_config(reload=True)
    with pytest.raises(BackendNotAvailableError):
        tensor_core.Tensor(np.ones((2, 2), dtype=np.float32))


def test_tensor_mps_device_helpers():
    from neurx.core import neurx as tensor_core

    t = tensor_core.Tensor(np.ones((2, 2), dtype=np.float32))
    mps_t = t.mps()
    assert mps_t.device == "mps"
    assert mps_t.cpu().device == "cpu"
