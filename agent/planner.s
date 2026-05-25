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
    string replan_reason
    []string task_queue
    int replan_count
}

func agent_plan_max_replan_count() int {
    3
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
        replan_reason: "",
        task_queue: [],
        replan_count: 0,
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
        replan_reason: "",
        task_queue: state.task_queue,
        replan_count: state.replan_count,
    }
}

func agent_plan_enqueue_task(agent_plan_state state, string task) agent_plan_state {
    int size = len(state.task_queue)
    []string queue = []string{cap: size + 1}
    int i = 0
    while i < size {
        queue[i] = state.task_queue[i]
        i = i + 1
    }
    queue[size] = task
    agent_plan_state {
        goal: state.goal,
        current_task: state.current_task,
        step_budget: state.step_budget,
        step_count: state.step_count,
        needs_replan: state.needs_replan,
        finished: state.finished,
        status: state.status,
        replan_reason: state.replan_reason,
        task_queue: queue,
        replan_count: state.replan_count,
    }
}

func agent_plan_enqueue_tasks(agent_plan_state state, []string tasks) agent_plan_state {
    int old_size = len(state.task_queue)
    int add_size = len(tasks)
    []string queue = []string{cap: old_size + add_size}
    int i = 0
    while i < old_size {
        queue[i] = state.task_queue[i]
        i = i + 1
    }
    while i < old_size + add_size {
        queue[i] = tasks[i - old_size]
        i = i + 1
    }
    agent_plan_state {
        goal: state.goal,
        current_task: state.current_task,
        step_budget: state.step_budget,
        step_count: state.step_count,
        needs_replan: state.needs_replan,
        finished: state.finished,
        status: state.status,
        replan_reason: state.replan_reason,
        task_queue: queue,
        replan_count: state.replan_count,
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
    string replan_reason = ""
    []string next_queue = state.task_queue
    string route = agent_plan_route(memory)
    bool has_retrieve = agent_tool_registry_has_enabled(tools, "retrieve")
    bool has_infer = agent_tool_registry_has_enabled(tools, "infer")
    bool has_delete = agent_tool_registry_has_enabled(tools, "delete")
    bool has_write = agent_tool_registry_has_enabled(tools, "write")
    bool has_apply_patch = agent_tool_registry_has_enabled(tools, "apply_patch")
    bool has_build = agent_tool_registry_has_enabled(tools, "build")
    bool has_test = agent_tool_registry_has_enabled(tools, "test")

    if observation == "done" {
        finished = true
        status = "done"
        next_task = "complete"
    } else if observation == "tool_unavailable" || observation == "infer:rejected" || observation == "local_model_config_missing: disabled" {
        int next_replan_count_check = state.replan_count + 1
        if next_replan_count_check >= agent_plan_max_replan_count() {
            finished = true
            status = "replan_limit_reached"
            next_task = "complete"
        } else {
            needs_replan = true
            status = "replan"
            next_task = "analyze"
            replan_reason = observation
            next_queue = []
        }
    } else if !finished && !needs_replan {
        if len(next_queue) > 0 {
            next_task = next_queue[0]
            int q_size = len(next_queue) - 1
            []string trimmed = []string{cap: q_size}
            int qi = 0
            while qi < q_size {
                trimmed[qi] = next_queue[qi + 1]
                qi = qi + 1
            }
            next_queue = trimmed
            status = "queued:" + next_task
        } else if state.current_task == "analyze" {
            next_task = "plan"
            status = "planning:" + route
        } else if state.current_task == "plan" {
            if route == "delete" && has_delete {
                next_task = "delete"
                status = "deleting:" + route
            } else if route == "write" && has_write {
                next_task = "write"
                status = "writing:" + route
            } else if route == "apply_patch" && has_apply_patch {
                next_task = "apply_patch"
                status = "patching:" + route
            } else if route == "build" && has_build {
                next_task = "build"
                status = "building:" + route
            } else if route == "review" {
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
        } else if state.current_task == "delete" {
            next_task = "verify"
            status = "verifying:" + route
        } else if state.current_task == "write" {
            if has_build {
                next_task = "build"
                status = "building:" + route
            } else {
                next_task = "verify"
                status = "verifying:" + route
            }
        } else if state.current_task == "apply_patch" || state.current_task == "patch" {
            if has_build {
                next_task = "build"
                status = "building:" + route
            } else {
                next_task = "verify"
                status = "verifying:" + route
            }
        } else if state.current_task == "build" {
            if has_test {
                next_task = "test"
                status = "testing:" + route
            } else {
                next_task = "verify"
                status = "verifying:" + route
            }
        } else if state.current_task == "test" {
            next_task = "verify"
            status = "verifying:" + route
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

    int next_replan_count = state.replan_count
    if needs_replan {
        next_replan_count = state.replan_count + 1
    }

    agent_plan_state {
        goal: state.goal,
        current_task: next_task,
        step_budget: state.step_budget,
        step_count: next_count,
        needs_replan: needs_replan,
        finished: finished,
        status: status,
        replan_reason: replan_reason,
        task_queue: next_queue,
        replan_count: next_replan_count,
    }
}

func agent_plan_state_dict(agent_plan_state state) agent_plan_state {
    state
}

func agent_plan_update_goal(agent_plan_state state, string new_goal) agent_plan_state {
    agent_plan_state {
        goal: new_goal,
        current_task: "analyze",
        step_budget: state.step_budget,
        step_count: state.step_count,
        needs_replan: false,
        finished: false,
        status: "goal_updated",
        replan_reason: "",
        task_queue: [],
        replan_count: state.replan_count,
    }
}

func agent_plan_load_state_dict(agent_plan_state state, agent_plan_state other) agent_plan_state {
    other
}

func agent_plan_set_budget(agent_plan_state state, int budget) agent_plan_state {
    int b = budget
    if b <= 0 {
        b = 1
    }
    bool budget_restore = state.finished && state.status == "budget_exhausted" && state.step_count < b
    bool new_finished = state.finished
    string new_status = state.status
    if budget_restore {
        new_finished = false
        new_status = "running"
    }
    agent_plan_state {
        goal: state.goal,
        current_task: state.current_task,
        step_budget: b,
        step_count: state.step_count,
        needs_replan: state.needs_replan,
        finished: new_finished,
        status: new_status,
        replan_reason: state.replan_reason,
        task_queue: state.task_queue,
        replan_count: state.replan_count,
    }
}
