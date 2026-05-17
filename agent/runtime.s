package neurx.agent.runtime

use neurx.agent.planner
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.agent.executor
use neurx.agent.trace

struct agent_runtime_state {
    agent_plan_state plan
    agent_memory_state memory
    agent_tool_registry_state tools
    agent_trace_state trace
    int steps
    bool finished
    string last_action
    string last_observation
}

func new_agent_runtime_state(string goal, string initial_task, int step_budget) agent_runtime_state {
    agent_tool_registry_state tools = new_agent_tool_registry_state()
    tools = agent_tool_registry_add(tools, "search", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "retrieve", true, 5000, 1)

    agent_runtime_state {
        plan: new_agent_plan_state(goal, initial_task, step_budget),
        memory: new_agent_memory_state(),
        tools: tools,
        trace: new_agent_trace_state(),
        steps: 0,
        finished: false,
        last_action: "",
        last_observation: "",
    }
}

func agent_runtime_step(agent_runtime_state state, string input) agent_runtime_state {
    if state.finished {
        return state
    }

    agent_execute_result result = agent_execute_step(state.tools, state.memory, state.plan.current_task, input)
    agent_plan_state next_plan = agent_plan_next(state.plan, result.observation)
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
