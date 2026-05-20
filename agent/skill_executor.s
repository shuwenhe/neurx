package neurx.agent.skill_executor

use neurx.agent.skill_registry
use neurx.agent.skill_schema

struct agent_skill_execution_state {
    string active_skill
    string status
    int step_count
}

func new_agent_skill_execution_state() agent_skill_execution_state {
    agent_skill_execution_state {
        active_skill: "",
        status: "idle",
        step_count: 0,
    }
}

func agent_skill_execution_state_dict(agent_skill_execution_state state) agent_skill_execution_state {
    state
}

func agent_skill_execution_load_state_dict(agent_skill_execution_state state, agent_skill_execution_state other) agent_skill_execution_state {
    other
}

func agent_skill_execute(agent_skill_registry_state registry, string task) agent_skill_execution_state {
    agent_skill_record active = agent_skill_registry_active(registry)
    string status = "fallback"
    if active.spec.name != "none" && active.spec.status != "retired" {
        status = "skill:" + active.spec.name + ":" + task
    }
    agent_skill_execution_state {
        active_skill: active.spec.name,
        status: status,
        step_count: 1,
    }
}
