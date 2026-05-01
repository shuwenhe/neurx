from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_checkpoint_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "checkpoint.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "checkpoint.ir" in runtime_files

    for function_name in (
        "new_checkpoint",
        "checkpoint_state_dict",
        "checkpoint_load_state_dict",
        "save_checkpoint",
        "load_checkpoint",
    ):
        assert runtime.supports_runtime_function("checkpoint", function_name)
