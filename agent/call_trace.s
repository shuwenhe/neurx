package neurx.agent.call_trace
use neurx.agent.memory
use neurx.runtime.io.{runtime_write_text_file, runtime_env_get}
string CALL_TRACE_RUNTIME   = "neurx/agent/runtime.s"
string CALL_TRACE_SAFETY    = "neurx/safety/safety.s"
string CALL_TRACE_REASONING = "neurx/reasoning/reasoning.s"
string CALL_TRACE_CONTEXT   = "neurx/context/context_manager.s"
string CALL_TRACE_CTX_BUILD = "neurx/context/context_builder.s"
string CALL_TRACE_EXECUTOR  = "neurx/executor/executor.s"
string CALL_TRACE_MODEL_SEL = "neurx/executor/model_tool_select.s"
string CALL_TRACE_INFER     = "neurx/infer/infer.s"
string CALL_TRACE_TOOLS     = "neurx/tool/workspace_tools.s"
string CALL_TRACE_ACTION    = "neurx/action/action_schema.s"
string CALL_TRACE_OBSERVE   = "neurx/agent/observation.s"
string CALL_TRACE_REFLECT   = "neurx/reflection/reflection.s"
string CALL_TRACE_PERCEIVE  = "neurx/perception/perception.s"
string CALL_TRACE_PLANNER   = "neurx/task/planner.s"
string CALL_TRACE_TRACE     = "neurx/agent/trace.s"
string CALL_TRACE_SKILLS    = "neurx/registry/skill_registry.s"
string CALL_TRACE_SKILL_EX  = "neurx/agent/skill_executor.s"
string CALL_TRACE_SKILL_EV  = "neurx/agent/skill_evaluator.s"
string CALL_TRACE_SKILL_SY  = "neurx/agent/skill_synthesizer.s"
string CALL_TRACE_ANSWER    = "neurx/agent/answer_synthesizer.s"
string CALL_TRACE_SESSION   = "neurx/session/session.s"
string CALL_TRACE_MEMORY    = "neurx/memory/memory.s"
string CALL_TRACE_MEM_KEY   = "call_trace_log"
func call_trace_make_entry(int step, string phase, string module_path, string func_name, bool ok) string {
    string status = "ok"
    if !ok {
        status = "fail"
    }
    "[step=" + string(step) + " phase=" + phase + " module=" + module_path + " func=" + func_name + " status=" + status + "]"
}
func call_trace_append(agent_memory_state memory, int step, string phase, string module_path, string func_name, bool ok) agent_memory_state {
    string entry = call_trace_make_entry(step, phase, module_path, func_name, ok)
    agent_memory_lookup_result existing = agent_memory_lookup_long(memory, CALL_TRACE_MEM_KEY)
    if existing.found && trim(existing.value) != "" {
        agent_memory_write_long(existing.state, CALL_TRACE_MEM_KEY, existing.value + "\n" + entry)
    } else {
        agent_memory_write_long(memory, CALL_TRACE_MEM_KEY, entry)
    }
}
func call_trace_get_log(agent_memory_state memory) string {
    agent_memory_lookup_result r = agent_memory_lookup_long(memory, CALL_TRACE_MEM_KEY)
    if r.found {
        return r.value
    }
    ""
}
func call_trace_write_log(agent_memory_state memory, string path) string {
    string log_str = call_trace_get_log(memory)
    if trim(path) == "" || trim(log_str) == "" {
        return ""
    }
    runtime_write_text_file(path, log_str)
}
func call_trace_default_log_path() string {
    string env_path = trim(runtime_env_get("NEURX_CALL_TRACE_LOG", ""))
    if env_path != "" {
        return env_path
    }
    ".neurx_call_trace.log"
}
func call_trace_maybe_write(agent_memory_state memory) string {
    string path = call_trace_default_log_path()
    call_trace_write_log(memory, path)
}
