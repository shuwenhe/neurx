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
        "checkpoint_step",
        "checkpoint_loss",
        "checkpoint_params",
        "checkpoint_param_count",
    ):
        assert runtime.supports_runtime_function("checkpoint", function_name)


def test_s_checkpoint_runtime_state_helpers():
    runtime = _load_runtime_module()
    params = [{"shape": [2], "data": [1.0, 2.0], "requires_grad": False}]
    checkpoint = {"step": 7, "loss": 1.25, "params": params}
    assert runtime.invoke_runtime_function("checkpoint", "checkpoint_step", checkpoint) == 7
    assert runtime.invoke_runtime_function("checkpoint", "checkpoint_loss", checkpoint) == 1.25
    assert runtime.invoke_runtime_function("checkpoint", "checkpoint_params", checkpoint) is params
    assert runtime.invoke_runtime_function("checkpoint", "checkpoint_param_count", checkpoint) == 1
