from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_dataloader_mvp_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "dataloader_mvp.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "dataloader_mvp.ir" in runtime_files

    for function_name in (
        "new_config",
        "new_state",
        "dataloader_config_state_dict",
        "dataloader_config_load_state_dict",
        "dataloader_state_state_dict",
        "dataloader_state_load_state_dict",
        "dataloader_batch_state_dict",
        "dataloader_batch_load_state_dict",
        "dataloader_step_output_state_dict",
        "dataloader_step_output_load_state_dict",
        "dataloader_token_count",
        "dataloader_batch_span",
        "dataloader_config_batch_size",
        "dataloader_config_seq_len",
        "dataloader_state_cursor",
        "dataloader_state_tokens",
        "dataloader_state_config",
        "dataloader_batch_input_ids",
        "dataloader_batch_target_ids",
        "dataloader_batch_valid_tokens",
        "dataloader_step_output_state",
        "dataloader_step_output_batch",
        "has_next",
        "next_batch",
    ):
        assert runtime.supports_runtime_function("dataloader_mvp", function_name)


def test_s_dataloader_mvp_runtime_state_helpers_round_trip():
    runtime = _load_runtime_module()
    config = {"batch_size": 3, "seq_len": 4}
    other_config = {"batch_size": 5, "seq_len": 6}
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_config_state_dict", config) is config
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_config_load_state_dict", config, other_config) is other_config

    state = {"token_ids": [1, 2, 3, 4, 5, 6, 7], "cursor": 2, "config": config}
    other_state = {"token_ids": [9, 8], "cursor": 0, "config": other_config}
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_state_state_dict", state) is state
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_state_load_state_dict", state, other_state) is other_state
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_token_count", state) == 7
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_batch_span", config) == 12
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_config_batch_size", config) == 3
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_config_seq_len", config) == 4
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_state_cursor", state) == 2
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_state_tokens", state) is state["token_ids"]
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_state_config", state) is config

    batch = {"input_ids": [1, 2, 3], "target_ids": [2, 3, 4], "valid_tokens": 3}
    other_batch = {"input_ids": [4, 5], "target_ids": [5, 6], "valid_tokens": 2}
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_batch_state_dict", batch) is batch
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_batch_load_state_dict", batch, other_batch) is other_batch
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_batch_input_ids", batch) is batch["input_ids"]
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_batch_target_ids", batch) is batch["target_ids"]
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_batch_valid_tokens", batch) == 3

    output = {"state": state, "batch": batch}
    other_output = {"state": other_state, "batch": other_batch}
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_step_output_state_dict", output) is output
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_step_output_load_state_dict", output, other_output) is other_output
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_step_output_state", output) is state
    assert runtime.invoke_runtime_function("dataloader_mvp", "dataloader_step_output_batch", output) is batch


def test_s_dataloader_mvp_runtime_batch_generation():
    runtime = _load_runtime_module()
    state = {
        "token_ids": [1, 2, 3, 4, 5, 6, 7],
        "cursor": 0,
        "config": {"batch_size": 2, "seq_len": 2},
    }
    assert runtime.invoke_runtime_function("dataloader_mvp", "has_next", state) is True
    output = runtime.invoke_runtime_function("dataloader_mvp", "next_batch", state)
    assert output["state"]["cursor"] == 4
    assert output["batch"]["input_ids"] == [1, 2, 3, 4]
    assert output["batch"]["target_ids"] == [2, 3, 4, 5]
    assert output["batch"]["valid_tokens"] == 4
