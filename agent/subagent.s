package neurx.agent.subagent
struct agent_subagent_task {
    string id
    string goal
    string input
    string status
    string result
    int max_steps
}

struct agent_subagent_registry_state {
    []agent_subagent_task tasks
    int count
    int completed
    int failed
}
func new_agent_subagent_task(string id, string goal, string input, int max_steps) agent_subagent_task {
    agent_subagent_task {
        id: id,
        goal: goal,
        input: input,
        status: "pending",
        result: "",
        max_steps: max_steps,
    }
}

func new_agent_subagent_registry_state() agent_subagent_registry_state {
    agent_subagent_registry_state {
        tasks: [],
        count: 0,
        completed: 0,
        failed: 0,
    }
}

func agent_subagent_spawn(agent_subagent_registry_state state, string goal, string input, int max_steps) agent_subagent_registry_state {
    string id = "sub_" + string(state.count)
    agent_subagent_task task = new_agent_subagent_task(id, goal, input, max_steps)
    int n = state.count
    []agent_subagent_task tasks = []agent_subagent_task{cap: n + 1}
    int i = 0
    while i < n {
        tasks[i] = state.tasks[i]
        i = i + 1
    }
    tasks[n] = task
    agent_subagent_registry_state {
        tasks: tasks,
        count: n + 1,
        completed: state.completed,
        failed: state.failed,
    }
}

func agent_subagent_complete(agent_subagent_registry_state state, string id, string result, bool ok) agent_subagent_registry_state {
    int n = state.count
    []agent_subagent_task tasks = []agent_subagent_task{cap: n}
    int new_completed = state.completed
    int new_failed = state.failed
    int i = 0
    while i < n {
        agent_subagent_task t = state.tasks[i]
        if t.id == id {
            string status = "failed"
            if ok {
                status = "done"
                new_completed = new_completed + 1
            } else {
                new_failed = new_failed + 1
            }
            tasks[i] = agent_subagent_task {
                id: t.id,
                goal: t.goal,
                input: t.input,
                status: status,
                result: result,
                max_steps: t.max_steps,
            }
        } else {
            tasks[i] = t
        }
        i = i + 1
    }
    agent_subagent_registry_state {
        tasks: tasks,
        count: n,
        completed: new_completed,
        failed: new_failed,
    }
}

func agent_subagent_all_done(agent_subagent_registry_state state) bool {
    state.completed + state.failed >= state.count
}

func agent_subagent_aggregate_results(agent_subagent_registry_state state) string {
    string out = ""
    int i = 0
    while i < state.count {
        agent_subagent_task t = state.tasks[i]
        if t.status == "done" {
            if out != "" {
                out = out + "\n"
            }
            out = out + t.id + ":" + t.result
        }
        i = i + 1
    }
    out
}

func agent_subagent_summary(agent_subagent_registry_state state) string {
    "subagents=" + string(state.count) + " completed=" + string(state.completed) + " failed=" + string(state.failed)
}
