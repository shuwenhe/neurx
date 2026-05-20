package neurx.agent.trace

struct agent_trace_state {
    []int steps
    []string tasks
    []string inputs
    []string actions
    []string observations
    []string active_skills
    []bool ok_flags
    int count
}

func new_agent_trace_state() agent_trace_state {
    agent_trace_state {
        steps: [],
        tasks: [],
        inputs: [],
        actions: [],
        observations: [],
        active_skills: [],
        ok_flags: [],
        count: 0,
    }
}

func agent_trace_append(agent_trace_state state, int step, string task, string input, string action, string observation, string active_skill, bool ok) agent_trace_state {
    int size = len(state.steps)
    []int steps = []int{cap: size + 1}
    []string tasks = []string{cap: size + 1}
    []string inputs = []string{cap: size + 1}
    []string actions = []string{cap: size + 1}
    []string observations = []string{cap: size + 1}
    []string active_skills = []string{cap: size + 1}
    []bool ok_flags = []bool{cap: size + 1}

    int i = 0
    while i < size {
        steps[i] = state.steps[i]
        tasks[i] = state.tasks[i]
        inputs[i] = state.inputs[i]
        actions[i] = state.actions[i]
        observations[i] = state.observations[i]
        active_skills[i] = state.active_skills[i]
        ok_flags[i] = state.ok_flags[i]
        i = i + 1
    }

    steps[size] = step
    tasks[size] = task
    inputs[size] = input
    actions[size] = action
    observations[size] = observation
    active_skills[size] = active_skill
    ok_flags[size] = ok

    agent_trace_state {
        steps: steps,
        tasks: tasks,
        inputs: inputs,
        actions: actions,
        observations: observations,
        active_skills: active_skills,
        ok_flags: ok_flags,
        count: state.count + 1,
    }
}

func agent_trace_count(agent_trace_state state) int {
    state.count
}

func agent_trace_last_step(agent_trace_state state) int {
    int size = len(state.steps)
    if size <= 0 {
        return -1
    }
    state.steps[size - 1]
}

func agent_trace_last_task(agent_trace_state state) string {
    int size = len(state.tasks)
    if size <= 0 {
        return ""
    }
    state.tasks[size - 1]
}

func agent_trace_last_action(agent_trace_state state) string {
    int size = len(state.actions)
    if size <= 0 {
        return ""
    }
    state.actions[size - 1]
}

func agent_trace_last_observation(agent_trace_state state) string {
    int size = len(state.observations)
    if size <= 0 {
        return ""
    }
    state.observations[size - 1]
}

func agent_trace_last_ok(agent_trace_state state) bool {
    int size = len(state.ok_flags)
    if size <= 0 {
        return false
    }
    state.ok_flags[size - 1]
}

func agent_trace_export(agent_trace_state state) string {
    string out = "trace_count=" + string(state.count)
    int i = 0
    while i < len(state.steps) {
        out = out + "\nstep[" + string(i) + "]=" + string(state.steps[i])
        out = out + "\ntask[" + string(i) + "]=" + state.tasks[i]
        out = out + "\ninput[" + string(i) + "]=" + state.inputs[i]
        out = out + "\naction[" + string(i) + "]=" + state.actions[i]
        out = out + "\nobservation[" + string(i) + "]=" + state.observations[i]
        out = out + "\nactive_skill[" + string(i) + "]=" + state.active_skills[i]
        if state.ok_flags[i] {
            out = out + "\nok[" + string(i) + "]=true"
        } else {
            out = out + "\nok[" + string(i) + "]=false"
        }
        i = i + 1
    }
    out + "\n"
}

func agent_trace_state_dict(agent_trace_state state) agent_trace_state {
    state
}

func agent_trace_load_state_dict(agent_trace_state state, agent_trace_state other) agent_trace_state {
    other
}
