from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_train_runtime_compiled_functions_present():
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
        "autocast_state_dict",
        "autocast_load_state_dict",
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
        "checkpoint_manager_should_save",
        "checkpoint_manager_save",
        "checkpoint_manager_mark_best",
        "checkpoint_manager_load_latest",
        "checkpoint_manager_load_best",
        "checkpoint_manager_should_save_best",
        "checkpoint_manager_state_dict",
        "checkpoint_manager_load_state_dict",
    ):
        assert runtime.supports_runtime_function("checkpoint_manager", function_name)

    for function_name in (
        "new_training_logger",
        "training_logger_enable",
        "training_logger_disable",
        "training_logger_log",
        "training_logger_flush",
        "training_logger_state_dict",
        "training_logger_load_state_dict",
    ):
        assert runtime.supports_runtime_function("logging", function_name)

    for function_name in (
        "new_training_loop_state",
        "new_training_run_state",
        "new_training_pipeline_state",
        "new_training_metrics_state",
        "training_loop_state_dict",
        "training_loop_load_state_dict",
        "training_loop_run_state_dict",
        "training_loop_run_state_load_state_dict",
        "run_training_loop",
        "train_epoch",
        "train_epochs",
        "stop_training_run",
        "resume_training_run",
        "train_step",
        "train_steps",
        "stop_training_pipeline",
        "resume_training_pipeline",
        "training_pipeline_loop_state_dict",
        "training_pipeline_loop_load_state_dict",
        "training_pipeline_loader_state_dict",
        "training_pipeline_loader_load_state_dict",
        "training_pipeline_logger_state_dict",
        "training_pipeline_logger_load_state_dict",
        "training_pipeline_scaler_state_dict",
        "training_pipeline_scaler_load_state_dict",
        "training_pipeline_checkpoint_state_dict",
        "training_pipeline_checkpoint_load_state_dict",
        "training_pipeline_autocast_state_dict",
        "training_pipeline_autocast_load_state_dict",
        "training_metrics_state_dict",
        "training_metrics_load_state_dict",
        "training_pipeline_metrics_state_dict",
        "training_pipeline_metrics_load_state_dict",
        "training_pipeline_state_dict",
        "training_pipeline_load_state_dict",
        "training_pipeline_metrics",
        "training_pipeline_set_metrics",
    ):
        assert runtime.supports_runtime_function("loop", function_name)


def test_s_train_loop_runtime_state_helpers_round_trip():
    runtime = _load_runtime_module()
    loop_state = {"epoch": 2, "step": 5, "should_stop": False, "last_valid_tokens": 7}
    other_loop_state = {"epoch": 9, "step": 11, "should_stop": True, "last_valid_tokens": 3}
    assert runtime.invoke_runtime_function("loop", "training_loop_state_dict", loop_state) is loop_state
    assert runtime.invoke_runtime_function("loop", "training_loop_load_state_dict", loop_state, other_loop_state) is other_loop_state
    run_state = {"loop": loop_state, "loader": {"cursor": 0}}
    other_run_state = {"loop": other_loop_state, "loader": {"cursor": 4}}
    assert runtime.invoke_runtime_function("loop", "training_loop_run_state_dict", run_state) is run_state
    assert runtime.invoke_runtime_function("loop", "training_loop_run_state_load_state_dict", run_state, other_run_state) is other_run_state
    pipeline_state = {
        "loop": loop_state,
        "loader": {"cursor": 0},
        "logger": {"enabled": True},
        "scaler": {"enabled": False},
        "checkpoint": {"has_best": False},
        "autocast": {"enabled": False},
        "metrics": {"step": 0},
        "last_loss": 1.5,
        "best_score": 0.2,
    }
    other_pipeline_state = {
        "loop": other_loop_state,
        "loader": {"cursor": 3},
        "logger": {"enabled": False},
        "scaler": {"enabled": True},
        "checkpoint": {"has_best": True},
        "autocast": {"enabled": True},
        "metrics": {"step": 9},
        "last_loss": 0.25,
        "best_score": 0.8,
    }
    assert runtime.invoke_runtime_function("loop", "training_pipeline_state_dict", pipeline_state) is pipeline_state
    assert runtime.invoke_runtime_function("loop", "training_pipeline_load_state_dict", pipeline_state, other_pipeline_state) is other_pipeline_state
    assert runtime.invoke_runtime_function("loop", "training_pipeline_loop_state_dict", pipeline_state) is pipeline_state["loop"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_loop_load_state_dict", pipeline_state, other_pipeline_state["loop"]) is other_pipeline_state["loop"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_loader_state_dict", pipeline_state) is pipeline_state["loader"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_loader_load_state_dict", pipeline_state, other_pipeline_state["loader"]) is other_pipeline_state["loader"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_logger_state_dict", pipeline_state) is pipeline_state["logger"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_logger_load_state_dict", pipeline_state, other_pipeline_state["logger"]) is other_pipeline_state["logger"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_scaler_state_dict", pipeline_state) is pipeline_state["scaler"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_scaler_load_state_dict", pipeline_state, other_pipeline_state["scaler"]) is other_pipeline_state["scaler"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_checkpoint_state_dict", pipeline_state) is pipeline_state["checkpoint"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_checkpoint_load_state_dict", pipeline_state, other_pipeline_state["checkpoint"]) is other_pipeline_state["checkpoint"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_autocast_state_dict", pipeline_state) is pipeline_state["autocast"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_autocast_load_state_dict", pipeline_state, other_pipeline_state["autocast"]) is other_pipeline_state["autocast"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_metrics_state_dict", pipeline_state) is pipeline_state["metrics"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_metrics_load_state_dict", pipeline_state, other_pipeline_state["metrics"]) is other_pipeline_state["metrics"]
    assert runtime.invoke_runtime_function("loop", "training_pipeline_metrics", pipeline_state) is pipeline_state["metrics"]


def test_s_train_amp_runtime_state_helpers_round_trip():
    runtime = _load_runtime_module()
    autocast = {"enabled": True, "dtype_code": 7, "nesting": 2}
    autocast_other = {"enabled": False, "dtype_code": 9, "nesting": 0}
    assert runtime.invoke_runtime_function("amp", "autocast_state_dict", autocast) is autocast
    assert runtime.invoke_runtime_function("amp", "autocast_load_state_dict", autocast, autocast_other) is autocast_other


def test_s_train_checkpoint_manager_and_logging_round_trip():
    runtime = _load_runtime_module()
    checkpoint = {
        "keep_last_n": 4,
        "keep_every_n_steps": 2,
        "save_best_only": False,
        "last_saved_step": 1,
        "last_saved_epoch": 1,
        "best_step": 1,
        "best_epoch": 1,
        "best_score": 0.5,
        "save_count": 2,
        "prune_count": 0,
        "next_save_step": 4,
        "has_best": True,
    }
    checkpoint_other = {
        "keep_last_n": 8,
        "keep_every_n_steps": 4,
        "save_best_only": True,
        "last_saved_step": 7,
        "last_saved_epoch": 3,
        "best_step": 7,
        "best_epoch": 3,
        "best_score": 0.8,
        "save_count": 3,
        "prune_count": 1,
        "next_save_step": 8,
        "has_best": False,
    }
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_state_dict", checkpoint) is checkpoint
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_load_state_dict", checkpoint, checkpoint_other) is checkpoint_other

    logger = {
        "enabled": True,
        "message_count": 5,
        "last_step": 10,
        "last_epoch": 2,
        "last_flush_step": 8,
        "last_flush_epoch": 1,
    }
    logger_other = {
        "enabled": False,
        "message_count": 1,
        "last_step": 2,
        "last_epoch": 1,
        "last_flush_step": 0,
        "last_flush_epoch": 0,
    }
    assert runtime.invoke_runtime_function("logging", "training_logger_state_dict", logger) is logger
    assert runtime.invoke_runtime_function("logging", "training_logger_load_state_dict", logger, logger_other) is logger_other
