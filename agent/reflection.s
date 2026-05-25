package neurx.agent.reflection

use neurx.agent.trace
use neurx.agent.memory

struct agent_reflection_state {
    string critique
    string suggestion
    bool needs_correction
    int reflection_count
    string last_goal
    string last_action
    string last_observation
}

func new_agent_reflection_state() agent_reflection_state {
    agent_reflection_state {
        critique: "",
        suggestion: "",
        needs_correction: false,
        reflection_count: 0,
        last_goal: "",
        last_action: "",
        last_observation: "",
    }
}

func agent_reflection_is_aligned(string goal, string action, string observation) bool {
    string a = lower(trim(action))
    string o = lower(trim(observation))
    if o == "tool_unavailable" || o == "no_result" || o == "" {
        return false
    }
    if a == "noop" {
        return false
    }
    true
}

func agent_reflection_critique(string goal, string action, string observation, int step) string {
    if !agent_reflection_is_aligned(goal, action, observation) {
        return "step=" + string(step) + " action=" + action + " did_not_advance goal=" + goal + " observation=" + observation
    }
    "ok"
}

func agent_reflect(agent_reflection_state state, string goal, string action, string observation, int step) agent_reflection_state {
    string critique = agent_reflection_critique(goal, action, observation, step)
    bool needs_correction = critique != "ok"
    string suggestion = ""
    if needs_correction {
        if observation == "tool_unavailable" {
            suggestion = "switch_tool"
        } else if action == "noop" {
            suggestion = "replan"
        } else if observation == "" {
            suggestion = "retry_with_context"
        } else {
            suggestion = "reassess_goal"
        }
    }
    agent_reflection_state {
        critique: critique,
        suggestion: suggestion,
        needs_correction: needs_correction,
        reflection_count: state.reflection_count + 1,
        last_goal: goal,
        last_action: action,
        last_observation: observation,
    }
}

func agent_reflection_state_dict(agent_reflection_state state) agent_reflection_state {
    state
}

func agent_reflection_load_state_dict(agent_reflection_state state, agent_reflection_state other) agent_reflection_state {
    other
}

func agent_reflection_summary(agent_reflection_state state) string {
    "reflections=" + string(state.reflection_count) + " needs_correction=" + string(state.needs_correction) + " suggestion=" + state.suggestion
}
