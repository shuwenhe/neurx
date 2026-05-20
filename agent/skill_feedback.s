package neurx.agent.skill_feedback

use neurx.agent.trace
use neurx.agent.memory

struct agent_skill_feedback_state {
    string skill_name
    string task
    string signal
    string summary
    int step
    bool success
}

func new_agent_skill_feedback_state() agent_skill_feedback_state {
    agent_skill_feedback_state {
        skill_name: "",
        task: "",
        signal: "",
        summary: "",
        step: 0,
        success: false,
    }
}

func agent_skill_feedback_from_trace(agent_trace_state trace_state, agent_memory_state memory_state) agent_skill_feedback_state {
    string task = agent_trace_last_task(trace_state)
    string action = agent_trace_last_action(trace_state)
    string observation = agent_trace_last_observation(trace_state)
    bool success = agent_trace_last_ok(trace_state)
    string route = ""
    agent_memory_lookup_result route_result = agent_memory_lookup_short(memory_state, "route")
    if route_result.found {
        route = route_result.value
    }

    string signal = action
    if !success && observation != "" {
        signal = action + ":" + observation
    }

    agent_skill_feedback_state {
        skill_name: route,
        task: task,
        signal: signal,
        summary: "task=" + task + " action=" + action + " observation=" + observation,
        step: agent_trace_last_step(trace_state),
        success: success,
    }
}

func agent_skill_feedback_state_dict(agent_skill_feedback_state state) agent_skill_feedback_state {
    state
}

func agent_skill_feedback_load_state_dict(agent_skill_feedback_state state, agent_skill_feedback_state other) agent_skill_feedback_state {
    other
}
