package neurx.agent.planner

use neurx.agent.memory
use neurx.agent.tool_registry

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

func agent_plan_route(agent_memory_state memory) string {
    agent_memory_lookup_result route_result = agent_memory_lookup_short(memory, "route")
    if route_result.found && route_result.value != "" {
        return route_result.value
    }
    "general"
}

func agent_plan_next(agent_plan_state state, agent_tool_registry_state tools, agent_memory_state memory, string observation) agent_plan_state {
    if state.finished {
        return state
    }

    int next_count = state.step_count + 1
    bool finished = false
    bool needs_replan = false
    string status = "running"
    string next_task = state.current_task
    string route = agent_plan_route(memory)
    bool has_retrieve = agent_tool_registry_has_enabled(tools, "retrieve")
    bool has_infer = agent_tool_registry_has_enabled(tools, "infer")

    if observation == "done" {
        finished = true
        status = "done"
        next_task = "complete"
    } else if observation == "tool_unavailable" || observation == "infer:rejected" || observation == "local_model_config_missing: disabled" {
        needs_replan = true
        status = "replan"
        next_task = "analyze"
    } else if !finished && !needs_replan {
        if state.current_task == "analyze" {
            next_task = "plan"
            status = "planning:" + route
        } else if state.current_task == "plan" {
            if route == "review" {
                next_task = "verify"
                status = "verifying:" + route
            } else if route == "search" {
                if has_retrieve {
                    next_task = "retrieve"
                    status = "retrieving:" + route
                } else {
                    next_task = "verify"
                    status = "verifying:" + route
                }
            } else {
                if has_retrieve {
                    next_task = "retrieve"
                    status = "retrieving:" + route
                } else if has_infer {
                    next_task = "infer"
                    status = "reasoning:" + route
                } else {
                    next_task = "verify"
                    status = "verifying:" + route
                }
            }
        } else if state.current_task == "retrieve" {
            if has_infer {
                next_task = "infer"
                status = "reasoning:" + route
            } else {
                next_task = "verify"
                status = "verifying:" + route
            }
        } else if state.current_task == "infer" {
            next_task = "verify"
            status = "verifying:" + route
        } else if state.current_task == "verify" {
            next_task = "finalize"
            status = "finalizing:" + route
        } else if state.current_task == "finalize" {
            next_task = "complete"
            finished = true
            status = "done"
        } else if state.current_task == "complete" {
            finished = true
            status = "done"
        } else {
            next_task = "analyze"
            status = "planning:" + route
        }
    }
    if next_count >= state.step_budget && !finished {
        finished = true
        status = "budget_exhausted"
    }

    agent_plan_state {
        goal: state.goal,
        current_task: next_task,
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
