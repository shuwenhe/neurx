from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "runtime" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_agent_runtime_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("agent/runtime", "new_agent_runtime_state"):
        return

    for module_name, function_name in (
        ("agent/tool_registry", "new_agent_tool_registry_state"),
        ("agent/tool_registry", "agent_tool_registry_add"),
        ("agent/tool_registry", "agent_tool_registry_has_enabled"),
        ("agent/memory", "new_agent_memory_state"),
        ("agent/memory", "agent_memory_write_short"),
        ("agent/planner", "new_agent_plan_state"),
        ("agent/planner", "agent_plan_next"),
        ("agent/executor", "agent_execute_step"),
        ("agent/trace", "new_agent_trace_state"),
        ("agent/trace", "agent_trace_append"),
        ("agent/trace", "agent_trace_count"),
        ("agent/runtime", "new_agent_runtime_state"),
        ("agent/runtime", "agent_runtime_step"),
        ("agent/runtime", "run_agent_steps"),
        ("agent", "new_default_agent"),
        ("agent", "run_agent_once"),
        ("agent", "run_agent"),
        ("agent", "run_agent_with_goal"),
        ("agent", "agent_status"),
        ("agent", "agent_current_task"),
        ("agent", "agent_step_count"),
        ("agent", "agent_needs_replan"),
        ("agent", "agent_trace_entry_count"),
        ("agent", "agent_trace_entry_last_step"),
        ("agent", "agent_trace_entry_last_task"),
        ("agent", "agent_trace_entry_last_action"),
        ("agent", "agent_trace_entry_last_observation"),
    ):
        assert runtime.supports_runtime_function(module_name, function_name)

    state = runtime.invoke_runtime_function("agent/runtime", "new_agent_runtime_state", "solve task", "analyze", 2)
    stepped = runtime.invoke_runtime_function("agent/runtime", "agent_runtime_step", state, "context")
    assert stepped["steps"] == 1
    assert stepped["last_action"] in ("search", "noop")
    assert stepped["plan"]["current_task"] in ("retrieve", "analyze")
    assert stepped["trace"]["count"] == 1

    if runtime.supports_runtime_function("agent", "agent_trace_entry_count"):
        assert runtime.invoke_runtime_function("agent", "agent_trace_entry_count", stepped) == 1
        assert runtime.invoke_runtime_function("agent", "agent_trace_entry_last_step", stepped) == 1
        assert runtime.invoke_runtime_function("agent", "agent_trace_entry_last_task", stepped) == "analyze"
        assert runtime.invoke_runtime_function("agent", "agent_trace_entry_last_action", stepped) in ("search", "noop")
        assert runtime.invoke_runtime_function("agent", "agent_trace_entry_last_observation", stepped) in ("analyzed", "tool_unavailable")

    if runtime.supports_runtime_function("agent", "new_default_agent") and runtime.supports_runtime_function("agent", "run_agent"):
        app = runtime.invoke_runtime_function("agent", "new_default_agent", "ship feature")
        done = runtime.invoke_runtime_function("agent", "run_agent", app, "context", 3)
        assert done["steps"] >= 1
        assert "last_observation" in done
        assert done["finished"] is True
        assert done["plan"]["status"] == "done"

    if runtime.supports_runtime_function("agent", "run_agent_with_goal"):
        result = runtime.invoke_runtime_function("agent", "run_agent_with_goal", "ship feature", "context", 3)
        assert result["plan"]["current_task"] == "complete"
        assert result["trace"]["count"] >= 1
