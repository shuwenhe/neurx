package neurx.agent.extended_thinking
use neurx.executor.executor.{agent_execute_step, agent_text_contains}
use neurx.agent.tool_registry
use neurx.agent.memory
struct extended_thought {
    int    index
    string thought
    string conclusion
    int    token_estimate
}


struct extended_thinking_state {
    string         goal
    int            budget_steps
    int            steps_used
    int            token_budget
    int            tokens_used
    []extended_thought thoughts
    int            thought_count
    string         working_conclusion
    string         final_conclusion
    bool           finished
    bool           budget_exceeded
}


func new_extended_thinking_state(string goal, int budget_steps) extended_thinking_state {
    extended_thinking_state {
        goal:               goal,
        budget_steps:       budget_steps,
        steps_used:         0,
        token_budget:       0,
        tokens_used:        0,
        thoughts:           []extended_thought{cap: budget_steps + 1},
        thought_count:      0,
        working_conclusion: "",
        final_conclusion:   "",
        finished:           false,
        budget_exceeded:    false,
    }
}


func new_extended_thinking_state_with_token_budget(string goal, int budget_steps, int token_budget) extended_thinking_state {
    extended_thinking_state {
        goal:               goal,
        budget_steps:       budget_steps,
        steps_used:         0,
        token_budget:       token_budget,
        tokens_used:        0,
        thoughts:           []extended_thought{cap: budget_steps + 1},
        thought_count:      0,
        working_conclusion: "",
        final_conclusion:   "",
        finished:           false,
        budget_exceeded:    false,
    }
}


func extended_thinking_estimate_tokens(string text) int {
    int chars = len(text)
    int tokens = chars / 4
    if tokens < 1 && chars > 0 {
        return 1
    }
    tokens
}


func extended_thinking_append(extended_thinking_state state, string thought, string conclusion) extended_thinking_state {
    int n = state.thought_count
    []extended_thought next = []extended_thought{cap: n + 1}
    int i = 0
    while i < n {
        next[i] = state.thoughts[i]
        i = i + 1
    }
    int tok = extended_thinking_estimate_tokens(thought + conclusion)
    next[n] = extended_thought {
        index:           n,
        thought:         thought,
        conclusion:      conclusion,
        token_estimate:  tok,
    }
    extended_thinking_state {
        goal:               state.goal,
        budget_steps:       state.budget_steps,
        steps_used:         state.steps_used + 1,
        token_budget:       state.token_budget,
        tokens_used:        state.tokens_used + tok,
        thoughts:           next,
        thought_count:      n + 1,
        working_conclusion: conclusion,
        final_conclusion:   state.final_conclusion,
        finished:           state.finished,
        budget_exceeded:    state.budget_exceeded,
    }
}


func extended_thinking_over_budget(extended_thinking_state state) bool {
    if state.steps_used >= state.budget_steps {
        return true
    }
    if state.token_budget > 0 && state.tokens_used >= state.token_budget {
        return true
    }
    false
}


func extended_thinking_finalize(extended_thinking_state state) extended_thinking_state {
    string conclusion = state.working_conclusion
    if trim(conclusion) == "" && state.thought_count > 0 {
        conclusion = state.thoughts[state.thought_count - 1].conclusion
    }
    extended_thinking_state {
        goal:               state.goal,
        budget_steps:       state.budget_steps,
        steps_used:         state.steps_used,
        token_budget:       state.token_budget,
        tokens_used:        state.tokens_used,
        thoughts:           state.thoughts,
        thought_count:      state.thought_count,
        working_conclusion: state.working_conclusion,
        final_conclusion:   conclusion,
        finished:           true,
        budget_exceeded:    extended_thinking_over_budget(state),
    }
}


func extended_thinking_build_prompt(extended_thinking_state state, string input, int step) string {
    string prompt = "goal: " + state.goal + "\n"
    prompt = prompt + "input: " + input + "\n"
    prompt = prompt + "thinking_step: " + string(step) + " of " + string(state.budget_steps) + "\n"
    if trim(state.working_conclusion) != "" {
        prompt = prompt + "working_conclusion: " + state.working_conclusion + "\n"
    }
    if state.thought_count > 0 {
        int last = state.thought_count - 1
        prompt = prompt + "last_thought: " + state.thoughts[last].thought + "\n"
    }
    prompt = prompt + "instruction: Think step by step. Output a <thought> block and an updated <conclusion> block.\n"
    prompt
}


func extended_thinking_parse_thought(string response) string {
    int start = 0
    int end = len(response)
    int i = 0
    bool in_tag = false
    string thought_content = ""
    while i < len(response) - 6 {
        if string(response[i]) == "<" && string(response[i+1]) == "t" && string(response[i+2]) == "h" {
            in_tag = true
            i = i + 8
        } else if in_tag && string(response[i]) == "<" && string(response[i+1]) == "/" {
            break
        } else if in_tag {
            thought_content = thought_content + string(response[i])
            i = i + 1
        } else {
            i = i + 1
        }
    }
    if trim(thought_content) != "" {
        return trim(thought_content)
    }
    if len(response) <= 200 {
        return response
    }
    string out = ""
    int j = 0
    while j < 200 {
        out = out + string(response[j])
        j = j + 1
    }
    out
}


func extended_thinking_parse_conclusion(string response) string {
    int i = 0
    bool in_tag = false
    string content = ""
    while i < len(response) - 10 {
        if string(response[i]) == "<" && string(response[i+1]) == "c" && string(response[i+2]) == "o" {
            in_tag = true
            i = i + 12
        } else if in_tag && string(response[i]) == "<" && string(response[i+1]) == "/" {
            break
        } else if in_tag {
            content = content + string(response[i])
            i = i + 1
        } else {
            i = i + 1
        }
    }
    if trim(content) != "" {
        return trim(content)
    }
    string last_line = ""
    string cur_line = ""
    int j = 0
    while j < len(response) {
        if string(response[j]) == "\n" {
            if trim(cur_line) != "" {
                last_line = trim(cur_line)
            }
            cur_line = ""
        } else {
            cur_line = cur_line + string(response[j])
        }
        j = j + 1
    }
    if trim(cur_line) != "" {
        return trim(cur_line)
    }
    last_line
}


func extended_thinking_is_done(string response) bool {
    agent_text_contains(response, "final_answer") ||
    agent_text_contains(response, "conclusion:done") ||
    agent_text_contains(response, "<done>") ||
    agent_text_contains(response, "I am confident")
}


func extended_thinking_run(extended_thinking_state state, string input, string model_path) extended_thinking_state {
    agent_tool_registry_state tools = new_agent_tool_registry_state()
    agent_memory_state memory = new_agent_memory_state()
    memory = agent_memory_write_short(memory, "goal", state.goal)
    extended_thinking_state et = state
    int step = 0
    while step < state.budget_steps {
        if extended_thinking_over_budget(et) {
            break
        }
        string prompt = extended_thinking_build_prompt(et, input, step + 1)
        memory = agent_memory_write_short(memory, "thinking_prompt", prompt)
        agent_execute_result exec = agent_execute_step(tools, memory, state.goal, "think", prompt, model_path)
        string response = exec.observation
        string thought = extended_thinking_parse_thought(response)
        string conclusion = extended_thinking_parse_conclusion(response)
        if trim(thought) == "" {
            thought = "step " + string(step + 1)
        }
        if trim(conclusion) == "" {
            conclusion = et.working_conclusion
        }
        et = extended_thinking_append(et, thought, conclusion)
        if extended_thinking_is_done(response) {
            break
        }
        step = step + 1
    }
    extended_thinking_finalize(et)
}


func extended_thinking_conclusion(extended_thinking_state state) string {
    if trim(state.final_conclusion) != "" {
        return state.final_conclusion
    }
    state.working_conclusion
}


func extended_thinking_thought_at(extended_thinking_state state, int i) string {
    if i < 0 || i >= state.thought_count {
        return ""
    }
    state.thoughts[i].thought
}


func extended_thinking_export(extended_thinking_state state) string {
    string out = "extended_thinking goal=" + state.goal + "\n"
    out = out + "steps=" + string(state.steps_used) + "/" + string(state.budget_steps) + "\n"
    out = out + "tokens_used=" + string(state.tokens_used) + "\n"
    out = out + "budget_exceeded=" + string(state.budget_exceeded) + "\n"
    int i = 0
    while i < state.thought_count {
        out = out + "[" + string(i) + "] " + state.thoughts[i].thought + "\n"
        out = out + "  -> " + state.thoughts[i].conclusion + "\n"
        i = i + 1
    }
    out + "final: " + extended_thinking_conclusion(state)
}


func extended_thinking_summary(extended_thinking_state state) string {
    string exceeded = "false"
    if state.budget_exceeded {
        exceeded = "true"
    }
    "extended_thinking steps=" + string(state.steps_used) +
    " tokens=" + string(state.tokens_used) +
    " exceeded=" + exceeded +
    " conclusion=" + agent_thinking_clip(extended_thinking_conclusion(state), 80)
}


func agent_thinking_clip(string s, int max_len) string {
    if len(s) <= max_len {
        return s
    }
    string out = ""
    int i = 0
    while i < max_len {
        out = out + string(s[i])
        i = i + 1
    }
    out + "..."
}

