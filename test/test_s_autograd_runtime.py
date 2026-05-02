from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_autograd_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "autograd.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "autograd.ir" in runtime_files

    for function_name in (
        "new_state",
        "zeros_like",
        "ones_like",
        "register_tensor",
        "set_grad",
        "accumulate_grad",
        "grad_of",
        "record_count",
        "backward_seed",
        "backward",
    ):
        assert runtime.supports_runtime_function("autograd", function_name)


def test_s_autograd_runtime_record_count():
    runtime = _load_runtime_module()
    state = {"records": [{"id": 1}, {"id": 2}, {"id": 3}]}
    assert runtime.invoke_runtime_function("autograd", "record_count", state) == 3
