package neurx.posttrain.multiturn.multiturn_manager
use std.io.eprintln
enum message_role {
    SYSTEM,
    USER,
    ASSISTANT,
    TOOL,
}
struct message {
    message_role role
    string content
    int step
    int timestamp
    string tool_name
    string tool_input
}

struct conversation_turn {
    int turn_id
    []message messages
    string query
    string response
    float reward
    bool is_valid
}

struct multiturn_conversation {
    int conversation_id
    []conversation_turn turns
    int total_turns
    float cumulative_reward
    string task_type
    int start_step
    int end_step
}

struct multiturn_manager_state {
    []multiturn_conversation conversations
    int conversation_count
    int total_turns
    float avg_reward_per_conversation
    int max_turns_per_conversation
    bool enable_tool_calling
}

func new_multiturn_manager(int max_turns) multiturn_manager_state {
    multiturn_manager_state {
        conversations: []multiturn_conversation{cap: 1000},
        conversation_count: 0,
        total_turns: 0,
        avg_reward_per_conversation: 0.0,
        max_turns_per_conversation: max_turns,
        enable_tool_calling: true,
    }
}

func multiturn_enable_tool_calling(multiturn_manager_state state, bool enable) multiturn_manager_state {
    state.enable_tool_calling = enable
    eprintln("[MultiTurn] Tool calling: " + (if enable then "enabled" else "disabled"))
    state
}

func multiturn_start_conversation(multiturn_manager_state state, string task_type, int step) (multiturn_manager_state, int) {
    multiturn_conversation conv = multiturn_conversation {
        conversation_id: state.conversation_count,
        turns: []conversation_turn{cap: state.max_turns_per_conversation},
        total_turns: 0,
        cumulative_reward: 0.0,
        task_type: task_type,
        start_step: step,
        end_step: step,
    }
    state.conversations += []multiturn_conversation{conv}
    state.conversation_count = state.conversation_count + 1
    eprintln("[MultiTurn] Started conversation #" + int_to_str(state.conversation_count - 1))
    state, state.conversation_count - 1
}

func multiturn_add_message(multiturn_manager_state state, int conv_id, message_role role, string content) multiturn_manager_state {
    if conv_id >= len(state.conversations) {
        eprintln("[MultiTurn] ERROR: Invalid conversation ID")
        return state
    }
    multiturn_conversation conv = state.conversations[conv_id]
    message msg = message {
        role: role,
        content: content,
        step: 0,
        timestamp: 0,
        tool_name: "",
        tool_input: "",
    }
    if len(conv.turns) > 0 {
        conversation_turn turn = conv.turns[len(conv.turns) - 1]
        turn.messages += []message{msg}
        conv.turns[len(conv.turns) - 1] = turn
    }
    state.conversations[conv_id] = conv
    state
}

func multiturn_start_turn(multiturn_manager_state state, int conv_id, string query) multiturn_manager_state {
    if conv_id >= len(state.conversations) {
        return state
    }
    multiturn_conversation conv = state.conversations[conv_id]
    if conv.total_turns >= state.max_turns_per_conversation {
        eprintln("[MultiTurn] Max turns reached for conversation")
        return state
    }
    conversation_turn turn = conversation_turn {
        turn_id: conv.total_turns,
        messages: []message{cap: 10},
        query: query,
        response: "",
        reward: 0.0,
        is_valid: true,
    }
    message user_msg = message {
        role: USER,
        content: query,
        step: 0,
        timestamp: 0,
        tool_name: "",
        tool_input: "",
    }
    turn.messages += []message{user_msg}
    conv.turns += []conversation_turn{turn}
    conv.total_turns = conv.total_turns + 1
    state.total_turns = state.total_turns + 1
    state.conversations[conv_id] = conv
    eprintln("[MultiTurn] Started turn #" + int_to_str(conv.total_turns) + " in conversation #" + int_to_str(conv_id))
    state
}

func multiturn_complete_turn(multiturn_manager_state state, int conv_id, string response, float reward) multiturn_manager_state {
    if conv_id >= len(state.conversations) {
        return state
    }
    multiturn_conversation conv = state.conversations[conv_id]
    if len(conv.turns) == 0 {
        return state
    }
    conversation_turn turn = conv.turns[len(conv.turns) - 1]
    turn.response = response
    turn.reward = reward
    conv.turns[len(conv.turns) - 1] = turn
    message asst_msg = message {
        role: ASSISTANT,
        content: response,
        step: 0,
        timestamp: 0,
        tool_name: "",
        tool_input: "",
    }
    turn.messages += []message{asst_msg}
    conv.cumulative_reward = conv.cumulative_reward + reward
    state.conversations[conv_id] = conv
    eprintln("[MultiTurn] Completed turn with reward: " + (if reward > 0.0 then "+" else "") + reward_to_str(reward))
    state
}

func multiturn_add_tool_call(multiturn_manager_state state, int conv_id, string tool_name, string tool_input) multiturn_manager_state {
    if !state.enable_tool_calling || conv_id >= len(state.conversations) {
        return state
    }
    multiturn_conversation conv = state.conversations[conv_id]
    if len(conv.turns) == 0 {
        return state
    }
    conversation_turn turn = conv.turns[len(conv.turns) - 1]
    message tool_msg = message {
        role: TOOL,
        content: "Tool call: " + tool_name,
        step: 0,
        timestamp: 0,
        tool_name: tool_name,
        tool_input: tool_input,
    }
    turn.messages += []message{tool_msg}
    turn.response = tool_name
    conv.turns[len(conv.turns) - 1] = turn
    state.conversations[conv_id] = conv
    eprintln("[MultiTurn] Added tool call: " + tool_name)
    state
}

func multiturn_finish_conversation(multiturn_manager_state state, int conv_id, int step) multiturn_manager_state {
    if conv_id >= len(state.conversations) {
        return state
    }
    multiturn_conversation conv = state.conversations[conv_id]
    conv.end_step = step
    float avg_reward = 0.0
    if conv.total_turns > 0 {
        avg_reward = conv.cumulative_reward / float(conv.total_turns)
    }
    eprintln("[MultiTurn] Finished conversation #" + int_to_str(conv_id) + " with " + int_to_str(conv.total_turns) + " turns, avg reward: " + reward_to_str(avg_reward))
    state.conversations[conv_id] = conv
    state
}

func multiturn_get_stats(multiturn_manager_state state) (int, int, float) {
    int total_convs = state.conversation_count
    int total_turns = state.total_turns
    float avg_reward = 0.0
    if total_convs > 0 {
        float sum_reward = 0.0
        for i in range(len(state.conversations)) {
            multiturn_conversation conv = state.conversations[i]
            sum_reward = sum_reward + conv.cumulative_reward
        }
        avg_reward = sum_reward / float(total_convs)
    }
    total_convs, total_turns, avg_reward
}

func multiturn_get_conversation(multiturn_manager_state state, int conv_id) multiturn_conversation {
    if conv_id < len(state.conversations) {
        return state.conversations[conv_id]
    }
    multiturn_conversation{}
}

func multiturn_get_summary(multiturn_manager_state state) string {
    int convs, turns, avg_reward = multiturn_get_stats(state)
    string summary = "[MultiTurn] Conversation Summary\n"
    summary = summary + "Total Conversations: " + int_to_str(convs) + "\n"
    summary = summary + "Total Turns: " + int_to_str(turns) + "\n"
    summary = summary + "Avg Reward per Conversation: " + reward_to_str(avg_reward) + "\n"
    summary = summary + "Tool Calling Enabled: " + (if state.enable_tool_calling then "yes" else "no") + "\n"
    summary
}

func reward_to_str(float reward) string {
    if reward > 0.1 {
        return "positive"
    } else if reward < -0.1 {
        return "negative"
    }
    return "neutral"
}

func int_to_str(int n) string {
    ""
}
