from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "runtime" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_reasoning_posttrain_bridge():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("posttrain", "new_reasoning_posttrain_pipeline"):
        return

    for module_name, function_name in (
        ("agent/runtime", "new_agent_runtime_state"),
        ("agent/runtime", "agent_runtime_step"),
        ("reasoning/data", "reasoning_trace_from_agent"),
        ("reasoning/data", "reasoning_trace_dataset_count"),
        ("posttrain/data", "posttrain_data_source_kind"),
        ("posttrain/data", "posttrain_data_source_size"),
        ("posttrain", "reasoning_trace_to_posttrain_data"),
        ("posttrain", "new_reasoning_posttrain_pipeline"),
        ("posttrain", "reasoning_sample_mode_to_stage"),
        ("posttrain", "posttrain_step_from_inputs"),
    ):
        assert runtime.supports_runtime_function(module_name, function_name)

    state = runtime.invoke_runtime_function("agent/runtime", "new_agent_runtime_state", "solve task", "analyze", 3)
    state = runtime.invoke_runtime_function("agent/runtime", "agent_runtime_step", state, "context")
    state = runtime.invoke_runtime_function("agent/runtime", "agent_runtime_step", state, "follow-up")

    traces = runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_from_agent", state, "agent-runtime")
    data = runtime.invoke_runtime_function("posttrain", "reasoning_trace_to_posttrain_data", traces, "preference")
    assert runtime.invoke_runtime_function("posttrain/data", "posttrain_data_source_kind", data) == "reasoning_trace"
    assert runtime.invoke_runtime_function("posttrain/data", "posttrain_data_source_size", data) == runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_dataset_count", traces)

    pipeline = runtime.invoke_runtime_function("posttrain", "new_reasoning_posttrain_pipeline", traces, "preference", "reward-demo", "run-demo", "/tmp")
    assert pipeline["loop"]["cfg"]["stage"] == "dpo"
    assert pipeline["loop"]["data"]["source_kind"] == "reasoning_trace"
    assert pipeline["loop"]["data"]["source_size"] == runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_dataset_count", traces)

    stepped = runtime.invoke_runtime_function(
        "posttrain",
        "posttrain_step_from_inputs",
        pipeline,
        1.0,
        0.1,
        0.0,
        0.5,
        0.25,
        2,
    )
    assert stepped["loop"]["global_step"] == 1
    assert stepped["loop"]["data"]["pair_cursor"] == 2
    assert stepped["loop"]["data"]["source_kind"] == "reasoning_trace"
    assert stepped["metrics"]["step"] == 1
