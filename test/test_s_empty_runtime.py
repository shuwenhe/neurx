from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_empty_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "empty.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "empty.ir" in runtime_files

    for function_name in ("add_one", "double_value"):
        assert runtime.supports_runtime_function("empty", function_name)


def test_s_empty_runtime_math_helpers():
    runtime = _load_runtime_module()
    assert runtime.invoke_runtime_function("empty", "add_one", 4) == 5
    assert runtime.invoke_runtime_function("empty", "double_value", 4) == 8
