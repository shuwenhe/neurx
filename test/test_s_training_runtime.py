from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_training_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    for ir_name in ("amp.ir", "checkpoint_manager.ir", "logging.ir", "loop.ir"):
        assert any(Path(path).name == ir_name for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    for ir_name in ("amp.ir", "checkpoint_manager.ir", "logging.ir", "loop.ir"):
        assert ir_name in runtime_files

    for function_name in (
        "new_autocast_state",
        "is_autocast_enabled",
        "get_autocast_dtype",
        "set_autocast_enabled",
        "set_autocast_dtype",
        "new_grad_scaler",
        "scale_loss",
        "update_scale",
        "grad_scaler_step",
        "grad_scaler_state_dict",
        "grad_scaler_load_state_dict",
    ):
        assert runtime.supports_runtime_function("amp", function_name)

    for function_name in (
        "new_checkpoint_manager",
        "checkpoint_manager_save",
        "checkpoint_manager_load_latest",
        "checkpoint_manager_load_best",
    ):
        assert runtime.supports_runtime_function("checkpoint_manager", function_name)

    for function_name in (
        "new_training_logger",
        "training_logger_log",
    ):
        assert runtime.supports_runtime_function("logging", function_name)

    for function_name in (
        "new_training_loop_state",
        "run_training_loop",
    ):
        assert runtime.supports_runtime_function("loop", function_name)
