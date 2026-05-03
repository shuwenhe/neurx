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
        "autocast_is_enabled",
        "autocast_depth",
        "new_grad_scaler",
        "scale_loss",
        "update_scale",
        "grad_scaler_step",
        "grad_scaler_state_dict",
        "grad_scaler_load_state_dict",
        "grad_scaler_is_enabled",
        "grad_scaler_get_scale",
        "grad_scaler_found_inf",
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
        "checkpoint_manager_last_saved_step",
        "checkpoint_manager_last_saved_epoch",
        "checkpoint_manager_best_step",
        "checkpoint_manager_best_epoch",
        "checkpoint_manager_best_score",
        "checkpoint_manager_save_count",
        "checkpoint_manager_prune_count",
        "checkpoint_manager_next_save_step",
        "checkpoint_manager_has_best",
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
        "training_logger_is_enabled",
        "training_logger_message_count",
        "training_logger_last_step",
        "training_logger_last_epoch",
        "training_logger_last_flush_step",
        "training_logger_last_flush_epoch",
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
        "train_step_autograd_loss",
        "train_step_autograd_record_count",
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
    autocast_inactive = {"enabled": True, "dtype_code": 7, "nesting": 0}
    autocast_active = {"enabled": True, "dtype_code": 7, "nesting": 1}
    autocast_other = {"enabled": False, "dtype_code": 9, "nesting": 0}
    assert runtime.invoke_runtime_function("amp", "is_autocast_enabled", autocast_inactive) is False
    assert runtime.invoke_runtime_function("amp", "is_autocast_enabled", autocast_active) is True
    assert runtime.invoke_runtime_function("amp", "autocast_state_dict", autocast) is autocast
    assert runtime.invoke_runtime_function("amp", "autocast_load_state_dict", autocast, autocast_other) is autocast_other
    assert runtime.invoke_runtime_function("amp", "autocast_is_enabled", autocast) is True
    assert runtime.invoke_runtime_function("amp", "autocast_depth", autocast) == 2

    amp_s = Path(__file__).resolve().parents[1] / "train" / "amp.s"
    scaler = {
        "scale": 1024.0,
        "growth_factor": 2.0,
        "backoff_factor": 0.5,
        "growth_interval": 2000,
        "growth_tracker": 7,
        "enabled": True,
        "found_inf": False,
    }
    assert runtime.invoke_runtime_function("amp", "grad_scaler_is_enabled", scaler) is True
    assert runtime.invoke_runtime_function("amp", "grad_scaler_get_scale", scaler) == 1024.0
    assert runtime.invoke_runtime_function("amp", "grad_scaler_found_inf", scaler) is False
    stepped = runtime.invoke_runtime_function("amp", "grad_scaler_step", scaler, 2.0)
    stepped_inf = runtime.invoke_runtime_function("amp", "grad_scaler_step", scaler, 1.0e40)
    assert runtime.invoke_runtime_function("amp", "grad_scaler_get_scale", stepped) == 1024.0
    assert runtime.invoke_runtime_function("amp", "grad_scaler_found_inf", stepped) is False
    assert runtime.invoke_runtime_function("amp", "grad_scaler_get_scale", stepped_inf) == 512.0
    assert runtime.invoke_runtime_function("amp", "grad_scaler_found_inf", stepped_inf) is True

    amp_ir = Path(__file__).resolve().parents[1] / "build" / "ir" / "train" / "amp.ir"
    amp_s_text = amp_s.read_text(encoding="utf-8")
    amp_ir_text = amp_ir.read_text(encoding="utf-8")
    assert "state.enabled && state.nesting > 0" in amp_s_text
    assert "MOV|t3|0|_" in amp_ir_text
    assert "MOV|nesting|state.nesting|_" in amp_ir_text
    assert "ADD|t5|nesting|1" in amp_ir_text
    assert "SUB|t5|state.nesting|1" in amp_ir_text

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
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save", checkpoint, 3) is False
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save", checkpoint, 4) is True
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save_best", checkpoint, 0.5) is False
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save_best", checkpoint, 0.6) is True


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
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_last_saved_step", checkpoint) == 1
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_last_saved_epoch", checkpoint) == 1
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_best_step", checkpoint) == 1
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_best_epoch", checkpoint) == 1
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_best_score", checkpoint) == 0.5
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_save_count", checkpoint) == 2
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_prune_count", checkpoint) == 0
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_next_save_step", checkpoint) == 4
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_has_best", checkpoint) is True
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save", checkpoint, 3) is False
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save", checkpoint, 4) is True
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save", checkpoint_other, 7) is False
    assert runtime.invoke_runtime_function("checkpoint_manager", "checkpoint_manager_should_save", checkpoint_other, 8) is True

    checkpoint_ir = Path(__file__).resolve().parents[1] / "build" / "ir" / "train" / "checkpoint_manager.ir"
    loop_ir = Path(__file__).resolve().parents[1] / "build" / "ir" / "train" / "loop.ir"
    checkpoint_ir_text = checkpoint_ir.read_text(encoding="utf-8")
    loop_ir_text = loop_ir.read_text(encoding="utf-8")
    assert "CMP_GT|t19|score|state.best_score" in checkpoint_ir_text
    assert "CMP_GT|t21|score|state.best_score" in checkpoint_ir_text
    assert "CALL|t35|checkpoint_manager_best_score|1" in loop_ir_text
    assert "MOV|best_score|t35|_" in loop_ir_text

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
    assert runtime.invoke_runtime_function("logging", "training_logger_is_enabled", logger) is True
    assert runtime.invoke_runtime_function("logging", "training_logger_message_count", logger) == 5
    assert runtime.invoke_runtime_function("logging", "training_logger_last_step", logger) == 10
    assert runtime.invoke_runtime_function("logging", "training_logger_last_epoch", logger) == 2
    assert runtime.invoke_runtime_function("logging", "training_logger_last_flush_step", logger) == 8
    assert runtime.invoke_runtime_function("logging", "training_logger_last_flush_epoch", logger) == 1


def test_s_train_loop_autograd_closure_round_trip():
    runtime = _load_runtime_module()
    pipeline = {
        "loop": {"epoch": 0, "step": 0, "should_stop": False, "last_valid_tokens": 0},
        "loader": {"token_ids": [1, 2, 3, 4, 5, 6, 7, 8], "cursor": 0, "config": {"batch_size": 1, "seq_len": 2}},
        "logger": {"enabled": True, "message_count": 0, "last_step": 0, "last_epoch": 0, "last_flush_step": 0, "last_flush_epoch": 0},
        "scaler": {"scale": 1.0, "growth_factor": 2.0, "backoff_factor": 0.5, "growth_interval": 2, "growth_tracker": 0, "enabled": True, "found_inf": False},
        "checkpoint": {"keep_last_n": 4, "keep_every_n_steps": 2, "save_best_only": False, "last_saved_step": -1, "last_saved_epoch": -1, "best_step": -1, "best_epoch": -1, "best_score": 0.0, "save_count": 0, "prune_count": 0, "next_save_step": 2, "has_best": False},
        "autocast": {"enabled": False, "dtype_code": 0, "nesting": 0},
        "metrics": {"step": 0, "epoch": 0, "batch_index": 0, "valid_tokens": 0, "loss": 0.0, "score": 0.0},
        "last_loss": 0.0,
        "best_score": 0.0,
    }

    loss_tensor = runtime.invoke_runtime_function("loop", "train_step_autograd_loss", pipeline)
    record_count = runtime.invoke_runtime_function("loop", "train_step_autograd_record_count", pipeline)
    assert loss_tensor.shape == (1,)
    assert record_count == 1
