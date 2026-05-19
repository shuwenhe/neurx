package neurx.agent.runtime

use neurx.agent.planner
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.agent.executor
use neurx.agent.trace
use neurx.runtime.io.{runtime_env_get}

struct agent_runtime_state {
    agent_plan_state plan
    agent_memory_state memory
    agent_tool_registry_state tools
    agent_trace_state trace
    int steps
    bool finished
    string last_action
    string last_observation
    string model_path
}

func trim_or_empty(string value) string {
    string next = trim(value)
    next
}

func resolve_agent_model_path(string model_path) string {
    string direct = trim_or_empty(model_path)
    if direct != "" {
        return direct
    }

    string env_path = trim_or_empty(runtime_env_get("NEURX_AGENT_MODEL_PATH", ""))
    if env_path != "" {
        return env_path
    }

    string env_file = trim_or_empty(runtime_env_get("NEURX_AGENT_CHECKPOINT_FILE", ""))
    if env_file != "" {
        return env_file
    }

    string env_root = trim_or_empty(runtime_env_get("NEURX_AGENT_CHECKPOINT_ROOT", ""))
    if env_root != "" {
        return env_root
    }

    string backend_file = trim_or_empty(runtime_env_get("NEURX_BACKEND_CHECKPOINT_FILE", ""))
    if backend_file != "" {
        return backend_file
    }

    string backend_root = trim_or_empty(runtime_env_get("NEURX_BACKEND_CHECKPOINT_ROOT", ""))
    if backend_root != "" {
        return backend_root
    }

    ""
}

func new_agent_runtime_state(string goal, string initial_task, int step_budget) agent_runtime_state {
    new_agent_runtime_state_with_model(goal, initial_task, step_budget, "")
}

func new_agent_runtime_state_with_model(string goal, string initial_task, int step_budget, string model_path) agent_runtime_state {
    string resolved_model_path = resolve_agent_model_path(model_path)
    agent_tool_registry_state tools = new_agent_tool_registry_state()
    tools = agent_tool_registry_add(tools, "search", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "retrieve", true, 5000, 1)
    if resolved_model_path != "" {
        tools = agent_tool_registry_add(tools, "infer", true, 32000, 1)
    }

    agent_runtime_state {
        plan: new_agent_plan_state(goal, initial_task, step_budget),
        memory: new_agent_memory_state(),
        tools: tools,
        trace: new_agent_trace_state(),
        steps: 0,
        finished: false,
        last_action: "",
        last_observation: "",
        model_path: resolved_model_path,
    }
}

func agent_runtime_step(agent_runtime_state state, string input) agent_runtime_state {
    if state.finished {
        return state
    }

    agent_execute_result result = agent_execute_step(state.tools, state.memory, state.plan.goal, state.plan.current_task, input, state.model_path)
    agent_plan_state next_plan = agent_plan_next(state.plan, result.tools, result.memory, result.observation)
    agent_trace_state next_trace = agent_trace_append(
        state.trace,
        state.steps + 1,
        state.plan.current_task,
        input,
        result.action,
        result.observation,
        result.ok,
    )

    agent_runtime_state {
        plan: next_plan,
        memory: result.memory,
        tools: result.tools,
        trace: next_trace,
        steps: state.steps + 1,
        finished: next_plan.finished,
        last_action: result.action,
        last_observation: result.observation,
        model_path: state.model_path,
    }
}

func run_agent_steps(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    int total = max_steps
    if total < 0 {
        total = 0
    }

    agent_runtime_state current = state
    int i = 0
    while i < total {
        current = agent_runtime_step(current, input)
        if current.finished {
            return current
        }
        i = i + 1
    }

    current
}

func agent_runtime_state_dict(agent_runtime_state state) agent_runtime_state {
    state
}

func agent_runtime_load_state_dict(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    other
}
