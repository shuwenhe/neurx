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

func agent_skill_step_matches_task(string step, string task) bool {
    string s = lower(trim(step))
    string t = lower(trim(task))
    if s == "" || t == "" {
        return false
    }
    if s == t {
        return true
    }
    if s == "write_file" && (t == "write" || t == "code") {
        return true
    }
    if s == "apply_patch" && (t == "apply_patch" || t == "patch" || t == "code") {
        return true
    }
    if s == "run_build" && t == "build" {
        return true
    }
    if s == "run_test" && t == "test" {
        return true
    }
    if s == "read_file" && (t == "retrieve" || t == "read_file") {
        return true
    }
    if s == "search_files" && (t == "search" || t == "search_files") {
        return true
    }
    false
}

func agent_skill_trigger_matches_task(string trigger, string task) bool {
    string trg = lower(trim(trigger))
    string t = lower(trim(task))
    if trg == "" || t == "" {
        return false
    }
    if trg == t {
        return true
    }
    if trg == "write" && (t == "write" || t == "code") {
        return true
    }
    if trg == "apply_patch" && (t == "apply_patch" || t == "patch" || t == "code") {
        return true
    }
    if trg == "retrieve" && (t == "retrieve" || t == "read_file") {
        return true
    }
    if trg == "search" && (t == "search" || t == "search_files") {
        return true
    }
    false
}

func agent_skill_execute(agent_skill_registry_state registry, string task) agent_skill_execution_state {
    agent_skill_record active = agent_skill_registry_active(registry)
    string status = "fallback"
    if active.spec.name != "none" && active.spec.status != "retired" && active.metrics.success_rate >= 0.5 {
        int matched_step = -1
        int si = 0
        while si < len(active.spec.steps) {
            if agent_skill_step_matches_task(active.spec.steps[si], task) {
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
                if agent_skill_trigger_matches_task(active.spec.triggers[ti], task) {
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
