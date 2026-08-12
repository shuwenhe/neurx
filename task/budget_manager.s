package neurx.agent.budget_manager
struct agent_budget_state {
    int max_tokens
    int used_tokens
    int max_cost
    int used_cost
    int cost_per_token
    int step_count
    int max_steps
}

func new_agent_budget_state(int max_tokens, int max_cost, int cost_per_token, int max_steps) agent_budget_state {
    agent_budget_state {
        max_tokens: max_tokens,
        used_tokens: 0,
        max_cost: max_cost,
        used_cost: 0,
        cost_per_token: cost_per_token,
        step_count: 0,
        max_steps: max_steps,
    }
}

func agent_budget_default() agent_budget_state {
    agent_budget_state {
        max_tokens: 65536,
        used_tokens: 0,
        max_cost: 10000,
        used_cost: 0,
        cost_per_token: 1,
        step_count: 0,
        max_steps: 64,
    }
}

func agent_budget_estimate_tokens(string text) int {
    int n = len(text)
    if n <= 0 {
        return 0
    }
    int t = n / 4
    if t <= 0 {
        return 1
    }
    t
}

func agent_budget_record_step(agent_budget_state state, string text) agent_budget_state {
    int tokens = agent_budget_estimate_tokens(text)
    int cost = tokens * state.cost_per_token
    agent_budget_state {
        max_tokens: state.max_tokens,
        used_tokens: state.used_tokens + tokens,
        max_cost: state.max_cost,
        used_cost: state.used_cost + cost,
        cost_per_token: state.cost_per_token,
        step_count: state.step_count + 1,
        max_steps: state.max_steps,
    }
}

func agent_budget_token_exhausted(agent_budget_state state) bool {
    if state.max_tokens <= 0 {
        return false
    }
    state.used_tokens >= state.max_tokens
}

func agent_budget_cost_exhausted(agent_budget_state state) bool {
    if state.max_cost <= 0 {
        return false
    }
    state.used_cost >= state.max_cost
}

func agent_budget_step_exhausted(agent_budget_state state) bool {
    if state.max_steps <= 0 {
        return false
    }
    state.step_count >= state.max_steps
}

func agent_budget_exhausted(agent_budget_state state) bool {
    if agent_budget_token_exhausted(state) {
        return true
    }
    if agent_budget_cost_exhausted(state) {
        return true
    }
    agent_budget_step_exhausted(state)
}

func agent_budget_remaining_tokens(agent_budget_state state) int {
    int r = state.max_tokens - state.used_tokens
    if r < 0 {
        return 0
    }
    r
}

func agent_budget_remaining_steps(agent_budget_state state) int {
    int r = state.max_steps - state.step_count
    if r < 0 {
        return 0
    }
    r
}

func agent_budget_export(agent_budget_state state) string {
    "budget;max_tokens=" + string(state.max_tokens) +
    ";used_tokens=" + string(state.used_tokens) +
    ";max_cost=" + string(state.max_cost) +
    ";used_cost=" + string(state.used_cost) +
    ";step_count=" + string(state.step_count) +
    ";max_steps=" + string(state.max_steps)
}

func agent_budget_summary(agent_budget_state state) string {
    "tokens=" + string(state.used_tokens) + "/" + string(state.max_tokens) +
    ";steps=" + string(state.step_count) + "/" + string(state.max_steps) +
    ";exhausted=" + string(agent_budget_exhausted(state))
}

