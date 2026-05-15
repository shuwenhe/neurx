package neurx.agent.planner

struct agent_plan_state {
    string goal
    string current_task
    int step_budget
    int step_count
    bool needs_replan
    bool finished
    string status
}

func new_agent_plan_state(string goal, string current_task, int step_budget) agent_plan_state {
    int budget = step_budget
    if budget <= 0 {
        budget = 1
    }
    agent_plan_state {
        goal: goal,
        current_task: current_task,
        step_budget: budget,
        step_count: 0,
        needs_replan: false,
        finished: false,
        status: "idle",
    }
}

func agent_plan_set_task(agent_plan_state state, string current_task) agent_plan_state {
    agent_plan_state {
        goal: state.goal,
        current_task: current_task,
        step_budget: state.step_budget,
        step_count: state.step_count,
        needs_replan: false,
        finished: state.finished,
        status: "running",
    }
}

func agent_plan_next(agent_plan_state state, string observation) agent_plan_state {
    if state.finished {
        return state
    }

    int next_count = state.step_count + 1
    bool finished = false
    bool needs_replan = false
    string status = "running"

    if observation == "done" {
        finished = true
        status = "done"
    }
    if observation == "tool_unavailable" {
        needs_replan = true
        status = "replan"
    }
    if next_count >= state.step_budget && !finished {
        finished = true
        status = "budget_exhausted"
    }

    agent_plan_state {
        goal: state.goal,
        current_task: state.current_task,
        step_budget: state.step_budget,
        step_count: next_count,
        needs_replan: needs_replan,
        finished: finished,
        status: status,
    }
}

func agent_plan_state_dict(agent_plan_state state) agent_plan_state {
    state
}

func agent_plan_load_state_dict(agent_plan_state state, agent_plan_state other) agent_plan_state {
    other
}
