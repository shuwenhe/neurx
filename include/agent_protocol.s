package neurx.include.agent_protocol

// Full agent protocol — MCP-compatible message envelope.
// Covers the complete request/response/tool-use/tool-result lifecycle,
// modelled on NeurX-compatible Messages API and Model Context Protocol (MCP).

// ── message type constants ────────────────────────────────────────────────────

string AGENT_MSG_OBSERVATION = "observation"
string AGENT_MSG_ACTION      = "action"
string AGENT_MSG_SIGNAL      = "signal"
string AGENT_MSG_RESULT      = "result"
string AGENT_MSG_TOOL_USE    = "tool_use"
string AGENT_MSG_TOOL_RESULT = "tool_result"
string AGENT_MSG_THINKING    = "thinking"
string AGENT_MSG_ERROR       = "error"

// ── role constants ────────────────────────────────────────────────────────────

string AGENT_ROLE_USER      = "user"
string AGENT_ROLE_ASSISTANT = "assistant"
string AGENT_ROLE_SYSTEM    = "system"
string AGENT_ROLE_TOOL      = "tool"

// ── stop reason constants ─────────────────────────────────────────────────────

string AGENT_STOP_END_TURN    = "end_turn"
string AGENT_STOP_TOOL_USE    = "tool_use"
string AGENT_STOP_MAX_TOKENS  = "max_tokens"
string AGENT_STOP_INTERRUPTED = "interrupted"

// ── error category constants ──────────────────────────────────────────────────

string AGENT_ERR_INVALID_REQUEST = "invalid_request"
string AGENT_ERR_TOOL_FAILED     = "tool_failed"
string AGENT_ERR_OVERLOADED      = "overloaded"
string AGENT_ERR_SAFETY          = "safety_block"
string AGENT_ERR_TIMEOUT         = "timeout"

// ── data structures ───────────────────────────────────────────────────────────

struct agent_message_header {
    string session_id
    string task_id
    string message_type
    string source
    string timestamp
    int    sequence
}

// A single content block inside a message (text or tool_use or tool_result).
struct agent_content_block {
    string block_type    // "text" | "tool_use" | "tool_result" | "thinking"
    string id            // tool_use_id (for tool_use and tool_result blocks)
    string text          // for "text" and "thinking" blocks
    string tool_name     // for "tool_use" blocks
    string tool_input    // for "tool_use" blocks (serialised params)
    string tool_content  // for "tool_result" blocks (serialised output)
    bool   is_error      // for "tool_result" blocks
}

// A full protocol message (request or response).
struct agent_protocol_message {
    agent_message_header   header
    string                 role           // user | assistant | system | tool
    []agent_content_block  content
    int                    content_count
    string                 stop_reason    // end_turn | tool_use | max_tokens | interrupted
    string                 model
    int                    input_tokens
    int                    output_tokens
}

// Tool use request block — sent by the assistant.
struct agent_tool_use_message {
    string tool_use_id
    string name
    string input          // serialised params (key=value pairs)
}

// Tool result block — returned to the assistant.
struct agent_tool_result_message {
    string tool_use_id
    string content        // serialised output
    bool   is_error
}

// Thinking block — private reasoning not shown to the user.
struct agent_thinking_block {
    string thinking       // raw thought text
    int    budget_tokens
}

// Error envelope.
struct agent_error_message {
    string category
    string message
    int    http_status    // 0 when not applicable
}

// ── constructors ──────────────────────────────────────────────────────────────

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

// ── convenience builders ──────────────────────────────────────────────────────

// Build a user text message.
func agent_protocol_user_text(string session_id, string task_id, string text) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_ACTION, AGENT_ROLE_USER)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_USER)
    agent_protocol_message_add_block(msg, new_agent_content_text(text))
}

// Build an assistant message that contains a tool_use block.
func agent_protocol_tool_use(string session_id, string task_id, string tool_use_id, string tool_name, string tool_input) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_TOOL_USE, AGENT_ROLE_ASSISTANT)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_ASSISTANT)
    msg = agent_protocol_message_add_block(msg, new_agent_content_tool_use(tool_use_id, tool_name, tool_input))
    agent_protocol_message_set_stop(msg, AGENT_STOP_TOOL_USE)
}

// Build a user message returning a tool result.
func agent_protocol_tool_result(string session_id, string task_id, string tool_use_id, string content, bool is_error) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_TOOL_RESULT, AGENT_ROLE_TOOL)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_USER)
    agent_protocol_message_add_block(msg, new_agent_content_tool_result(tool_use_id, content, is_error))
}

// Build a final assistant text response.
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

// Build an error message.
func agent_protocol_error(string session_id, string task_id, string category, string error_msg, int http_status) agent_protocol_message {
    agent_message_header hdr = new_agent_message_header(session_id, task_id, AGENT_MSG_ERROR, AGENT_ROLE_SYSTEM)
    agent_protocol_message msg = new_agent_protocol_message(hdr, AGENT_ROLE_SYSTEM)
    agent_protocol_message_add_block(msg, new_agent_content_text(category + ": " + error_msg))
}

// ── inspection helpers ────────────────────────────────────────────────────────

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

// ── serialisation (human-readable) ───────────────────────────────────────────

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
