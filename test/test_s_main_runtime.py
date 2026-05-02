from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_main_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "main.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "main.ir" in runtime_files

    for function_name in (
        "new_config",
        "trainer_config_state_dict",
        "trainer_config_load_state_dict",
        "new_state",
        "init_state",
        "trainer_state_dict",
        "trainer_load_state_dict",
        "trainer_step_output_state_dict",
        "trainer_step_output_load_state_dict",
        "new_trainer_session",
        "trainer_session_state_dict",
        "trainer_session_load_state_dict",
        "new_trainer_snapshot",
        "new_trainer_pipeline",
        "new_trainer_checkpoint",
        "save_trainer_checkpoint",
        "load_trainer_checkpoint",
        "save_trainer_session_checkpoint",
        "load_trainer_session_checkpoint",
        "trainer_pipeline_state_dict",
        "trainer_pipeline_load_state_dict",
        "run_training_pipeline",
        "pipeline_checkpoint",
        "save_training_pipeline_checkpoint",
        "load_training_pipeline_checkpoint",
        "trainer_snapshot_state_dict",
        "trainer_snapshot_load_state_dict",
        "run_trainer_snapshot",
        "stop_trainer_pipeline",
        "resume_trainer_pipeline",
        "new_example",
        "process_example",
        "example_state_dict",
        "example_load_state_dict",
    ):
        assert runtime.supports_runtime_function("main", function_name)


def test_s_main_runtime_state_helpers_round_trip():
    runtime = _load_runtime_module()
    config = {"epochs": 4, "batch_size": 8, "learning_rate": 0.01, "grad_clip": 1.5}
    config_other = {"epochs": 7, "batch_size": 16, "learning_rate": 0.02, "grad_clip": 2.0}
    assert runtime.invoke_runtime_function("main", "trainer_config_state_dict", config) is config
    assert runtime.invoke_runtime_function("main", "trainer_config_load_state_dict", config, config_other) is config_other
    state = {"step": 3, "last_loss": 1.25}
    other = {"step": 7, "last_loss": 0.5}
    assert runtime.invoke_runtime_function("main", "trainer_state_dict", state) is state
    assert runtime.invoke_runtime_function("main", "trainer_load_state_dict", state, other) is other
    assert runtime.invoke_runtime_function("main", "trainer_step_output_state_dict", state) is state
    assert runtime.invoke_runtime_function("main", "trainer_step_output_load_state_dict", state, other) is other
    session = {"config": {"epochs": 1}, "state": state, "sample": {"data": [1.0], "shape": [1]}}
    restored = {"config": {"epochs": 2}, "state": other, "sample": {"data": [2.0], "shape": [1]}}
    assert runtime.invoke_runtime_function("main", "trainer_session_state_dict", session) is session
    assert runtime.invoke_runtime_function("main", "trainer_session_load_state_dict", session, restored) is restored
    ckpt = runtime.invoke_runtime_function("main", "new_trainer_checkpoint", 5, 1.25, [])
    assert ckpt["step"] == 5
    assert ckpt["loss"] == 1.25
    saved = runtime.invoke_runtime_function("main", "save_trainer_checkpoint", "/tmp/nowhere", 7, 2.5, [])
    assert saved["step"] == 7
    assert saved["loss"] == 2.5
    loaded = runtime.invoke_runtime_function("main", "load_trainer_checkpoint", "/tmp/nowhere")
    assert loaded["step"] == 0
    assert loaded["loss"] == 0.0
    pipeline = {
        "session": session,
        "snapshot": {"checkpoint_state": {"step": 9, "loss": 3.5, "params": [1, 2]}},
    }
    saved_pipeline = runtime.invoke_runtime_function("main", "save_training_pipeline_checkpoint", "/tmp/nowhere", pipeline)
    assert saved_pipeline["step"] == 9
    assert saved_pipeline["loss"] == 3.5
    loaded_pipeline = runtime.invoke_runtime_function("main", "load_training_pipeline_checkpoint", "/tmp/nowhere")
    assert loaded_pipeline["step"] == 0
    assert loaded_pipeline["loss"] == 0.0
