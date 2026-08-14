package neurx.include.agent_protocol
string AGENT_MSG_OBSERVATION = "observation"
string AGENT_MSG_ACTION      = "action"
string AGENT_MSG_SIGNAL      = "signal"
string AGENT_MSG_RESULT      = "result"
string AGENT_MSG_TOOL_USE    = "tool_use"
string AGENT_MSG_TOOL_RESULT = "tool_result"
string AGENT_MSG_THINKING    = "thinking"
string AGENT_MSG_ERROR       = "error"
string AGENT_ROLE_USER      = "user"
string AGENT_ROLE_ASSISTANT = "assistant"
string AGENT_ROLE_SYSTEM    = "system"
string AGENT_ROLE_TOOL      = "tool"
string AGENT_STOP_END_TURN    = "end_turn"
string AGENT_STOP_TOOL_USE    = "tool_use"
string AGENT_STOP_MAX_TOKENS  = "max_tokens"
string AGENT_STOP_INTERRUPTED = "interrupted"
string AGENT_ERR_INVALID_REQUEST = "invalid_request"
string AGENT_ERR_TOOL_FAILED     = "tool_failed"
string AGENT_ERR_OVERLOADED      = "overloaded"
string AGENT_ERR_SAFETY          = "safety_block"
string AGENT_ERR_TIMEOUT         = "timeout"
struct agent_message_header {
    string session_id
    string task_id
    string message_type
    string source
    string timestamp
    int    sequence
}

struct agent_content_block {
    string block_type
    string id
    string text
    string tool_name
    string tool_input
    string tool_content
    bool   is_error
}

struct agent_protocol_message {
    agent_message_header   header
    string                 role
    []agent_content_block  content
    int                    content_count
    string                 stop_reason
    string                 model
    int                    input_tokens
    int                    output_tokens
}

struct agent_tool_use_message {
    string tool_use_id
    string name
    string input
}

struct agent_tool_result_message {
    string tool_use_id
    string content
    bool   is_error
}

struct agent_thinking_block {
    string thinking
    int    budget_tokens
}

struct agent_error_message {
    string category
    string message
    int    http_status
}

func new_agent_message_header(string session_id, string task_id, string msg_type, string source) agent_message_header {
    agent_message_header {
        session_id:   session_id,
        task_id:      task_id,
        message_type: msg_type,
        source:       source,
        timestamp:    "",
        sequence:     0,
    }
}

func new_agent_content_text(string text) agent_content_block {
    agent_content_block {
        block_type:   "text",
        id:           "",
        text:         text,
        tool_name:    "",
        tool_input:   "",
        tool_content: "",
        is_error:     false,
    }
}

func new_agent_content_tool_use(string id, string name, string input) agent_content_block {
    agent_content_block {
        block_type:   "tool_use",
        id:           id,
        text:         "",
        tool_name:    name,
        tool_input:   input,
        tool_content: "",
        is_error:     false,
    }
}

func new_agent_content_tool_result(string id, string content, bool is_error) agent_content_block {
    agent_content_block {
        block_type:   "tool_result",
        id:           id,
        text:         "",
        tool_name:    "",
        tool_input:   "",
        tool_content: content,
        is_error:     is_error,
    }
}

func new_agent_content_thinking(string thinking) agent_content_block {
    agent_content_block {
        block_type:   "thinking",
        id:           "",
        text:         thinking,
        tool_name:    "",
        tool_input:   "",
        tool_content: "",
        is_error:     false,
    }
}

func new_agent_protocol_message(agent_message_header header, string role) agent_protocol_message {
    agent_protocol_message {
        header:        header,
        role:          role,
        content:       []agent_content_block{cap: 8},
        content_count: 0,
        stop_reason:   "",
        model:         "",
        input_tokens:  0,
        output_tokens: 0,
    }
}

func agent_protocol_message_add_block(agent_protocol_message msg, agent_content_block block) agent_protocol_message {
    int n = msg.content_count
    []agent_content_block next = []agent_content_block{cap: n + 1}
    int i = 0
    while i < n {
        next[i] = msg.content[i]
        i = i + 1
    }
    next[n] = block
    agent_protocol_message {
        header:        msg.header,
        role:          msg.role,
        content:       next,
        content_count: n + 1,
        stop_reason:   msg.stop_reason,
        model:         msg.model,
        input_tokens:  msg.input_tokens,
        output_tokens: msg.output_tokens,
    }
}

func agent_protocol_message_set_stop(agent_protocol_message msg, string stop_reason) agent_protocol_message {
    agent_protocol_message {
        header:        msg.header,
        role:          msg.role,
        content:       msg.content,
        content_count: msg.content_count,
        stop_reason:   stop_reason,
        model:         msg.model,
        input_tokens:  msg.input_tokens,
        output_tokens: msg.output_tokens,
    }
}

func agent_protocol_user_text(string session_id, string task_id, string text) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_ACTION, AGENT_ROLE_USER)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_USER)
    agent_protocol_message_add_block(msg, new_agent_content_text(text))
}

func agent_protocol_tool_use(string session_id, string task_id, string tool_use_id, string tool_name, string tool_input) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_TOOL_USE, AGENT_ROLE_ASSISTANT)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_ASSISTANT)
    msg = agent_protocol_message_add_block(msg, new_agent_content_tool_use(tool_use_id, tool_name, tool_input))
    agent_protocol_message_set_stop(msg, AGENT_STOP_TOOL_USE)
}

func agent_protocol_tool_result(string session_id, string task_id, string tool_use_id, string content, bool is_error) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_TOOL_RESULT, AGENT_ROLE_TOOL)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_USER)
    agent_protocol_message_add_block(msg, new_agent_content_tool_result(tool_use_id, content, is_error))
}

func agent_protocol_final_response(string session_id, string task_id, string text, string model, int in_tok, int out_tok) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_RESULT, AGENT_ROLE_ASSISTANT)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_ASSISTANT)
    msg = agent_protocol_message_add_block(msg, new_agent_content_text(text))
    msg = agent_protocol_message_set_stop(msg, AGENT_STOP_END_TURN)
    agent_protocol_message {
        header:        msg.header,
        role:          msg.role,
        content:       msg.content,
        content_count: msg.content_count,
        stop_reason:   msg.stop_reason,
        model:         model,
        input_tokens:  in_tok,
        output_tokens: out_tok,
    }
}

func agent_protocol_error(string session_id, string task_id, string category, string error_msg, int http_status) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_ERROR, AGENT_ROLE_SYSTEM)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_SYSTEM)
    agent_protocol_message_add_block(msg, new_agent_content_text(category + ": " + error_msg))
}

func agent_protocol_message_has_tool_use(agent_protocol_message msg) bool {
    int i = 0
    while i < msg.content_count {
        if msg.content[i].block_type == "tool_use" {
            return true
        }
        i = i + 1
    }
    false
}

func agent_protocol_message_text(agent_protocol_message msg) string {
    string out = ""
    int i = 0
    while i < msg.content_count {
        if msg.content[i].block_type == "text" {
            if out == "" {
                out = msg.content[i].text
            } else {
                out = out + "\n" + msg.content[i].text
            }
        }
        i = i + 1
    }
    out
}

func agent_protocol_first_tool_use(agent_protocol_message msg) agent_content_block {
    int i = 0
    while i < msg.content_count {
        if msg.content[i].block_type == "tool_use" {
            return msg.content[i]
        }
        i = i + 1
    }
    new_agent_content_text("")
}

func agent_protocol_message_summary(agent_protocol_message msg) string {
    string stop = msg.stop_reason
    if stop == "" {
        stop = "none"
    }
    "msg role=" + msg.role +
    " type=" + msg.header.message_type +
    " blocks=" + string(msg.content_count) +
    " stop=" + stop +
    " in_tok=" + string(msg.input_tokens) +
    " out_tok=" + string(msg.output_tokens)
}
