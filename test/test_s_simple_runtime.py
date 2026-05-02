from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_simple_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "simple.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "simple.ir" in runtime_files

    for function_name in ("sum2", "product2"):
        assert runtime.supports_runtime_function("simple", function_name)


def test_s_simple_runtime_arithmetic_round_trip():
    runtime = _load_runtime_module()
    assert runtime.invoke_runtime_function("simple", "sum2", 7, 5) == 12
    assert runtime.invoke_runtime_function("simple", "product2", 7, 5) == 35
