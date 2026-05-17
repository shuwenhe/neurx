from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "runtime" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_reasoning_trace_dataset_adapter():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("reasoning/data", "reasoning_trace_from_agent"):
        return

    for module_name, function_name in (
        ("agent/runtime", "new_agent_runtime_state"),
        ("agent/runtime", "agent_runtime_step"),
        ("reasoning/data", "new_reasoning_trace_dataset_state"),
        ("reasoning/data", "reasoning_trace_dataset_add_sample"),
        ("reasoning/data", "reasoning_trace_dataset_count"),
        ("reasoning/data", "reasoning_trace_dataset_has_next"),
        ("reasoning/data", "reasoning_trace_dataset_next"),
        ("reasoning/data", "reasoning_trace_dataset_render"),
        ("reasoning/data", "reasoning_trace_from_agent"),
        ("reasoning/data", "reasoning_trace_sample_render"),
    ):
        assert runtime.supports_runtime_function(module_name, function_name)

    state = runtime.invoke_runtime_function("agent/runtime", "new_agent_runtime_state", "solve task", "analyze", 3)
    state = runtime.invoke_runtime_function("agent/runtime", "agent_runtime_step", state, "context")
    state = runtime.invoke_runtime_function("agent/runtime", "agent_runtime_step", state, "follow-up")

    dataset = runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_from_agent", state, "agent-runtime")
    assert runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_dataset_count", dataset) == state["trace"]["count"]
    assert runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_dataset_has_next", dataset) is True

    first = runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_dataset_next", dataset)
    assert first["ok"] is True
    assert first["sample"]["step"] == 1
    assert first["sample"]["goal"] == "solve task"
    assert first["sample"]["task"] == "analyze"
    assert first["sample"]["input"] == "context"
    assert first["sample"]["action"] in ("search", "noop")
    assert first["sample"]["observation"] in ("analyzed", "tool_unavailable")

    rendered = runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_sample_render", first["sample"])
    assert "### Goal" in rendered
    assert "### Action" in rendered

    dataset_text = runtime.invoke_runtime_function("reasoning/data", "reasoning_trace_dataset_render", dataset)
    assert "### Goal" in dataset_text
    assert "### Current Step" in dataset_text
