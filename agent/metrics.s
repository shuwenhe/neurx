package neurx.agent.metrics
struct agent_metrics_state {
    int total_steps
    int ok_steps
    int fail_steps
    int replan_count
    int skill_hit_count
    int skill_miss_count
    int safety_block_count
    int tool_fail_count
    int interrupt_count
}
func new_agent_metrics_state() agent_metrics_state {
    agent_metrics_state {
        total_steps: 0,
        ok_steps: 0,
        fail_steps: 0,
        replan_count: 0,
        skill_hit_count: 0,
        skill_miss_count: 0,
        safety_block_count: 0,
        tool_fail_count: 0,
        interrupt_count: 0,
    }
}

func agent_metrics_record_step(agent_metrics_state state, bool ok) agent_metrics_state {
    int new_ok = state.ok_steps
    int new_fail = state.fail_steps
    if ok {
        new_ok = new_ok + 1
    }
    if !ok {
        new_fail = new_fail + 1
    }
    agent_metrics_state {
        total_steps: state.total_steps + 1,
        ok_steps: new_ok,
        fail_steps: new_fail,
        replan_count: state.replan_count,
        skill_hit_count: state.skill_hit_count,
        skill_miss_count: state.skill_miss_count,
        safety_block_count: state.safety_block_count,
        tool_fail_count: state.tool_fail_count,
        interrupt_count: state.interrupt_count,
    }
}

func agent_metrics_record_replan(agent_metrics_state state) agent_metrics_state {
    agent_metrics_state {
        total_steps: state.total_steps,
        ok_steps: state.ok_steps,
        fail_steps: state.fail_steps,
        replan_count: state.replan_count + 1,
        skill_hit_count: state.skill_hit_count,
        skill_miss_count: state.skill_miss_count,
        safety_block_count: state.safety_block_count,
        tool_fail_count: state.tool_fail_count,
        interrupt_count: state.interrupt_count,
    }
}

func agent_metrics_record_skill_hit(agent_metrics_state state) agent_metrics_state {
    agent_metrics_state {
        total_steps: state.total_steps,
        ok_steps: state.ok_steps,
        fail_steps: state.fail_steps,
        replan_count: state.replan_count,
        skill_hit_count: state.skill_hit_count + 1,
        skill_miss_count: state.skill_miss_count,
        safety_block_count: state.safety_block_count,
        tool_fail_count: state.tool_fail_count,
        interrupt_count: state.interrupt_count,
    }
}

func agent_metrics_record_skill_miss(agent_metrics_state state) agent_metrics_state {
    agent_metrics_state {
        total_steps: state.total_steps,
        ok_steps: state.ok_steps,
        fail_steps: state.fail_steps,
        replan_count: state.replan_count,
        skill_hit_count: state.skill_hit_count,
        skill_miss_count: state.skill_miss_count + 1,
        safety_block_count: state.safety_block_count,
        tool_fail_count: state.tool_fail_count,
        interrupt_count: state.interrupt_count,
    }
}

func agent_metrics_record_safety_block(agent_metrics_state state) agent_metrics_state {
    agent_metrics_state {
        total_steps: state.total_steps,
        ok_steps: state.ok_steps,
        fail_steps: state.fail_steps,
        replan_count: state.replan_count,
        skill_hit_count: state.skill_hit_count,
        skill_miss_count: state.skill_miss_count,
        safety_block_count: state.safety_block_count + 1,
        tool_fail_count: state.tool_fail_count,
        interrupt_count: state.interrupt_count,
    }
}

func agent_metrics_record_tool_fail(agent_metrics_state state) agent_metrics_state {
    agent_metrics_state {
        total_steps: state.total_steps,
        ok_steps: state.ok_steps,
        fail_steps: state.fail_steps,
        replan_count: state.replan_count,
        skill_hit_count: state.skill_hit_count,
        skill_miss_count: state.skill_miss_count,
        safety_block_count: state.safety_block_count,
        tool_fail_count: state.tool_fail_count + 1,
        interrupt_count: state.interrupt_count,
    }
}

func agent_metrics_record_interrupt(agent_metrics_state state) agent_metrics_state {
    agent_metrics_state {
        total_steps: state.total_steps,
        ok_steps: state.ok_steps,
        fail_steps: state.fail_steps,
        replan_count: state.replan_count,
        skill_hit_count: state.skill_hit_count,
        skill_miss_count: state.skill_miss_count,
        safety_block_count: state.safety_block_count,
        tool_fail_count: state.tool_fail_count,
        interrupt_count: state.interrupt_count + 1,
    }
}

func agent_metrics_ok_rate_pct(agent_metrics_state state) int {
    if state.total_steps <= 0 {
        return 0
    }
    int num = state.ok_steps * 100
    num / state.total_steps
}

func agent_metrics_skill_hit_rate_pct(agent_metrics_state state) int {
    int total = state.skill_hit_count + state.skill_miss_count
    if total <= 0 {
        return 0
    }
    int num = state.skill_hit_count * 100
    num / total
}

func agent_metrics_export(agent_metrics_state state) string {
    "metrics;total=" + string(state.total_steps) +
    ";ok=" + string(state.ok_steps) +
    ";fail=" + string(state.fail_steps) +
    ";replan=" + string(state.replan_count) +
    ";skill_hit=" + string(state.skill_hit_count) +
    ";skill_miss=" + string(state.skill_miss_count) +
    ";safety_block=" + string(state.safety_block_count) +
    ";tool_fail=" + string(state.tool_fail_count) +
    ";interrupt=" + string(state.interrupt_count)
}

func agent_metrics_summary(agent_metrics_state state) string {
    "steps=" + string(state.total_steps) +
    ";ok_rate=" + string(agent_metrics_ok_rate_pct(state)) + "%" +
    ";skill_hit_rate=" + string(agent_metrics_skill_hit_rate_pct(state)) + "%" +
    ";replans=" + string(state.replan_count)
}
