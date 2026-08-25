package neurx.scheduler.agent_scheduler

struct agent_scheduler_state {
    []string tasks
    []int priorities
    []string statuses
    int count
}

func new_agent_scheduler_state() agent_scheduler_state {
    agent_scheduler_state {
        tasks: [],
        priorities: [],
        statuses: [],
        count: 0,
    }
}

func get_task(agent_scheduler_state state, int index) string {
    state.tasks[index]
}

func get_priority(agent_scheduler_state state, int index) int {
    state.priorities[index]
}

func get_status(agent_scheduler_state state, int index) string {
    state.statuses[index]
}

func agent_scheduler_enqueue(agent_scheduler_state state, string task, int priority) agent_scheduler_state {
    int n = state.count
    []string new_tasks = []string{cap: n + 1}
    []int new_priorities = []int{cap: n + 1}
    []string new_statuses = []string{cap: n + 1}
    int i = 0
    for i < n {
        new_tasks[i] = state.tasks[i]
        new_priorities[i] = state.priorities[i]
        new_statuses[i] = state.statuses[i]
        i = i + 1
    }
    new_tasks[n] = task
    new_priorities[n] = priority
    new_statuses[n] = "pending"
    agent_scheduler_state {
        tasks: new_tasks,
        priorities: new_priorities,
        statuses: new_statuses,
        count: n + 1,
    }
}

func agent_scheduler_find_task(agent_scheduler_state state, string task) int {
    int i = 0
    bool found = false
    int idx = -1
    for i < state.count {
        if get_task(state, i) == task {
            found = true
            idx = i
            i = state.count
        }
        i = i + 1
    }
    idx
}

func agent_scheduler_mark_status(agent_scheduler_state state, string task, string status) agent_scheduler_state {
    int idx = agent_scheduler_find_task(state, task)
    []string new_statuses = []string{cap: state.count}
    int i = 0
    for i < state.count {
        new_statuses[i] = get_status(state, i)
        i = i + 1
    }
    if idx >= 0 {
        new_statuses[idx] = status
    }
    agent_scheduler_state {
        tasks: state.tasks,
        priorities: state.priorities,
        statuses: new_statuses,
        count: state.count,
    }
}

func agent_scheduler_mark_done(agent_scheduler_state state, string task) agent_scheduler_state {
    agent_scheduler_mark_status(state, task, "done")
}

func agent_scheduler_mark_failed(agent_scheduler_state state, string task) agent_scheduler_state {
    agent_scheduler_mark_status(state, task, "failed")
}

func agent_scheduler_next_task(agent_scheduler_state state) string {
    string best = ""
    int best_pri = -999999
    int i = 0
    for i < state.count {
        if get_status(state, i) == "pending" {
            if get_priority(state, i) > best_pri {
                best = get_task(state, i)
                best_pri = get_priority(state, i)
            }
        }
        i = i + 1
    }
    best
}

func agent_scheduler_has_pending(agent_scheduler_state state) bool {
    int i = 0
    for i < state.count {
        if get_status(state, i) == "pending" {
            return true
        }
        i = i + 1
    }
    false
}

func agent_scheduler_pending_count(agent_scheduler_state state) int {
    int total = 0
    int i = 0
    for i < state.count {
        if get_status(state, i) == "pending" {
            total = total + 1
        }
        i = i + 1
    }
    total
}

func agent_scheduler_export(agent_scheduler_state state) string {
    string out = "scheduler;count=" + string(state.count) + "\n"
    int i = 0
    for i < state.count {
        out = out + "task[" + string(i) + "]=" + get_task(state, i) + ";priority=" + string(get_priority(state, i)) + ";status=" + get_status(state, i) + "\n"
        i = i + 1
    }
    out
}

func agent_scheduler_summary(agent_scheduler_state state) string {
    "scheduler;total=" + string(state.count) + ";pending=" + string(agent_scheduler_pending_count(state)) + ";next=" + agent_scheduler_next_task(state)
}
