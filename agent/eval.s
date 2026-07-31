package neurx.agent.eval
struct agent_eval_state {
    []string tasks
    []string actuals
    []string expecteds
    []int steps_used
    int count
    int passed
    int failed
}
func new_agent_eval_state() agent_eval_state {
    agent_eval_state {
        tasks: [],
        actuals: [],
        expecteds: [],
        steps_used: [],
        count: 0,
        passed: 0,
        failed: 0,
    }
}

func agent_eval_text_contains(string haystack, string needle) bool {
    string h = lower(trim(haystack))
    string n = lower(trim(needle))
    int hl = len(h)
    int nl = len(n)
    if nl <= 0 {
        return true
    }
    if hl < nl {
        return false
    }
    int i = 0
    while i <= hl - nl {
        int j = 0
        bool match = true
        while j < nl {
            if h[i + j] != n[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    false
}

func agent_eval_text_match(string actual, string expected) bool {
    if expected == "" {
        return true
    }
    agent_eval_text_contains(actual, expected)
}

func agent_eval_add_result(agent_eval_state state, string task, string actual, string expected, int steps) agent_eval_state {
    int n = state.count
    []string new_tasks = []string{cap: n + 1}
    []string new_actuals = []string{cap: n + 1}
    []string new_expecteds = []string{cap: n + 1}
    []int new_steps = []int{cap: n + 1}
    int i = 0
    while i < n {
        new_tasks[i] = state.tasks[i]
        new_actuals[i] = state.actuals[i]
        new_expecteds[i] = state.expecteds[i]
        new_steps[i] = state.steps_used[i]
        i = i + 1
    }
    new_tasks[n] = task
    new_actuals[n] = actual
    new_expecteds[n] = expected
    new_steps[n] = steps
    bool p = agent_eval_text_match(actual, expected)
    int new_passed = state.passed
    int new_failed = state.failed
    if p {
        new_passed = new_passed + 1
    }
    if !p {
        new_failed = new_failed + 1
    }
    agent_eval_state {
        tasks: new_tasks,
        actuals: new_actuals,
        expecteds: new_expecteds,
        steps_used: new_steps,
        count: n + 1,
        passed: new_passed,
        failed: new_failed,
    }
}

func agent_eval_pass_rate_pct(agent_eval_state state) int {
    if state.count <= 0 {
        return 0
    }
    int num = state.passed * 100
    num / state.count
}

func agent_eval_case_passed(agent_eval_state state, int idx) bool {
    if idx < 0 {
        return false
    }
    if idx >= state.count {
        return false
    }
    agent_eval_text_match(state.actuals[idx], state.expecteds[idx])
}

func agent_eval_export(agent_eval_state state) string {
    string out = "eval;count=" + string(state.count) + ";passed=" + string(state.passed) + ";failed=" + string(state.failed) + "\n"
    int i = 0
    while i < state.count {
        string pstr = "fail"
        if agent_eval_case_passed(state, i) {
            pstr = "pass"
        }
        out = out + "case[" + string(i) + "].task=" + state.tasks[i] + ";result=" + pstr + ";steps=" + string(state.steps_used[i]) + "\n"
        i = i + 1
    }
    out
}

func agent_eval_summary(agent_eval_state state) string {
    "eval;count=" + string(state.count) + ";pass_rate=" + string(agent_eval_pass_rate_pct(state)) + "%"
}
