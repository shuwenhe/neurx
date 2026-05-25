package neurx.agent.skill_executor

use neurx.registry.skill_registry
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
    if active.spec.name != "none" && active.spec.status != "retired" && active.metrics.success_rate >= 0.5 {
        int matched_step = -1
        int si = 0
        while si < len(active.spec.steps) {
            if active.spec.steps[si] == task {
                matched_step = si
                break
            }
            si = si + 1
        }
        if matched_step >= 0 {
            status = "skill:" + active.spec.name + ":step" + string(matched_step) + ":" + task
        } else {
            int ti = 0
            bool trigger_match = false
            while ti < len(active.spec.triggers) {
                if active.spec.triggers[ti] == task {
                    trigger_match = true
                    break
                }
                ti = ti + 1
            }
            if trigger_match {
                status = "skill:" + active.spec.name + ":triggered:" + task
            } else {
                status = "skill:" + active.spec.name + ":" + task
            }
        }
    }
    agent_skill_execution_state {
        active_skill: active.spec.name,
        status: status,
        step_count: 1,
    }
}
