package neurx.session.session

struct agent_session_turn {
    int index
    string role
    string content
}

struct agent_session_state {
    []agent_session_turn turns
    int count
    string session_id
    string system_prompt
    bool active
}

func new_agent_session_turn(int index, string role, string content) agent_session_turn {
    agent_session_turn {
        index: index,
        role: role,
        content: content,
    }
}

func new_agent_session_state(string session_id, string system_prompt) agent_session_state {
    agent_session_state {
        turns: [],
        count: 0,
        session_id: session_id,
        system_prompt: system_prompt,
        active: true,
    }
}

func agent_session_add_turn(agent_session_state state, string role, string content) agent_session_state {
    int n = state.count
    []agent_session_turn turns = []agent_session_turn{cap: n + 1}
    int i = 0
    while i < n {
        turns[i] = state.turns[i]
        i = i + 1
    }
    turns[n] = new_agent_session_turn(n, role, content)
    agent_session_state {
        turns: turns,
        count: n + 1,
        session_id: state.session_id,
        system_prompt: state.system_prompt,
        active: state.active,
    }
}

func agent_session_user(agent_session_state state, string content) agent_session_state {
    agent_session_add_turn(state, "user", content)
}

func agent_session_assistant(agent_session_state state, string content) agent_session_state {
    agent_session_add_turn(state, "assistant", content)
}

func agent_session_system(agent_session_state state, string content) agent_session_state {
    agent_session_add_turn(state, "system", content)
}

func agent_session_last_user_input(agent_session_state state) string {
    int i = state.count - 1
    while i >= 0 {
        if state.turns[i].role == "user" {
            return state.turns[i].content
        }
        i = i - 1
    }
    ""
}

func agent_session_close(agent_session_state state) agent_session_state {
    agent_session_state {
        turns: state.turns,
        count: state.count,
        session_id: state.session_id,
        system_prompt: state.system_prompt,
        active: false,
    }
}

func agent_session_to_prompt(agent_session_state state) string {
    string out = "system: " + state.system_prompt
    int i = 0
    while i < state.count {
        agent_session_turn t = state.turns[i]
        out = out + "\n" + t.role + ": " + t.content
        i = i + 1
    }
    out
}

func agent_session_summary(agent_session_state state) string {
    "session=" + state.session_id + " turns=" + string(state.count) + " active=" + string(state.active)
}
