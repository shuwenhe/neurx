package neurx.agent.action_schema

struct agent_action_state {
    string tool
    string path
    string content
    string query
    string command
    string old_text
    string new_text
    string raw
    bool replace_all
    bool structured
}

func new_agent_action_state() agent_action_state {
    agent_action_state {
        tool: "",
        path: "",
        content: "",
        query: "",
        command: "",
        old_text: "",
        new_text: "",
        raw: "",
        replace_all: false,
        structured: false,
    }
}

func agent_action_text_contains(string text, string pattern) bool {
    string haystack = lower(trim(text))
    string needle = lower(trim(pattern))
    int hay_len = len(haystack)
    int nee_len = len(needle)
    if nee_len <= 0 {
        return true
    }
    if hay_len < nee_len {
        return false
    }
    int i = 0
    while i <= hay_len - nee_len {
        int j = 0
        bool match = true
        while j < nee_len {
            if haystack[i + j] != needle[j] {
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

func agent_action_extract_field(string raw, string key) string {
    string marker = key + "="
    int raw_len = len(raw)
    int marker_len = len(marker)
    if marker_len <= 1 || raw_len < marker_len {
        return ""
    }

    int start = -1
    int i = 0
    while i <= raw_len - marker_len {
        int j = 0
        bool match = true
        while j < marker_len {
            if raw[i + j] != marker[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            start = i + marker_len
            break
        }
        i = i + 1
    }
    if start < 0 {
        return ""
    }

    string value = ""
    i = start
    while i < raw_len {
        if string(raw[i]) == "\n" {
            break
        }
        if string(raw[i]) == " " {
            bool next_is_field = false
            int look = i + 1
            while look < raw_len && string(raw[look]) != " " && string(raw[look]) != "\n" {
                if string(raw[look]) == "=" {
                    next_is_field = true
                    break
                }
                look = look + 1
            }
            if next_is_field {
                break
            }
        }
        value = value + string(raw[i])
        i = i + 1
    }
    trim(value)
}

func agent_action_detect_tool(string raw, string fallback) string {
    string text = lower(trim(raw))
    if agent_action_text_contains(text, "tool=show_pending_changes") || agent_action_text_contains(text, "\"tool\":\"show_pending_changes\"") {
        return "show_pending_changes"
    }
    if agent_action_text_contains(text, "tool=apply_pending_changes") || agent_action_text_contains(text, "\"tool\":\"apply_pending_changes\"") {
        return "apply_pending_changes"
    }
    if agent_action_text_contains(text, "tool=write_file") || agent_action_text_contains(text, "\"tool\":\"write_file\"") {
        return "write"
    }
    if agent_action_text_contains(text, "tool=mkdir") || agent_action_text_contains(text, "\"tool\":\"mkdir\"") || agent_action_text_contains(text, "tool=create_directory") || agent_action_text_contains(text, "\"tool\":\"create_directory\"") {
        return "mkdir"
    }
    if agent_action_text_contains(text, "tool=delete_path") || agent_action_text_contains(text, "\"tool\":\"delete_path\"") {
        return "delete"
    }
    if agent_action_text_contains(text, "tool=read_file") || agent_action_text_contains(text, "\"tool\":\"read_file\"") {
        return "retrieve"
    }
    if agent_action_text_contains(text, "tool=search_files") || agent_action_text_contains(text, "\"tool\":\"search_files\"") {
        return "search"
    }
    if agent_action_text_contains(text, "tool=run_build") || agent_action_text_contains(text, "\"tool\":\"run_build\"") {
        return "build"
    }
    if agent_action_text_contains(text, "tool=run_test") || agent_action_text_contains(text, "\"tool\":\"run_test\"") {
        return "test"
    }
    if agent_action_text_contains(text, "path=") || agent_action_text_contains(text, "content=") {
        if agent_action_text_contains(text, "delete") {
            return "delete"
        }
        if agent_action_text_contains(text, "apply_patch") || agent_action_text_contains(text, "patch") {
            return "apply_patch"
        }
        if agent_action_text_contains(text, "read") || agent_action_text_contains(text, "retrieve") {
            return "retrieve"
        }
        if agent_action_text_contains(text, "search") || agent_action_text_contains(text, "find") {
            return "search"
        }
        if agent_action_text_contains(text, "build") {
            return "build"
        }
        if agent_action_text_contains(text, "test") {
            return "test"
        }
        if agent_action_text_contains(text, "write") || agent_action_text_contains(text, "create") || agent_action_text_contains(text, "patch") {
            return "write"
        }
    }
    if agent_action_text_contains(text, "show pending") || agent_action_text_contains(text, "show_pending_changes") {
        return "show_pending_changes"
    }
    if agent_action_text_contains(text, "apply pending") || agent_action_text_contains(text, "apply_pending_changes") {
        return "apply_pending_changes"
    }
    fallback
}

func agent_action_parse(string raw, string fallback_tool) agent_action_state {
    string tool = agent_action_detect_tool(raw, fallback_tool)
    string path = agent_action_extract_field(raw, "path")
    if path == "" {
        path = agent_action_extract_field(raw, "file")
    }
    string content = agent_action_extract_field(raw, "content")
    if content == "" {
        content = agent_action_extract_field(raw, "text")
    }
    string query = agent_action_extract_field(raw, "query")
    string command = agent_action_extract_field(raw, "command")
    if command == "" {
        command = agent_action_extract_field(raw, "cmd")
    }
    string old_text = agent_action_extract_field(raw, "old_text")
    if old_text == "" {
        old_text = agent_action_extract_field(raw, "old")
    }
    string new_text = agent_action_extract_field(raw, "new_text")
    if new_text == "" {
        new_text = agent_action_extract_field(raw, "new")
    }
    string replace_all_raw = lower(trim(agent_action_extract_field(raw, "replace_all")))
    bool replace_all = replace_all_raw == "true" || replace_all_raw == "1" || replace_all_raw == "yes"
    bool structured = path != "" || content != "" || query != "" || command != "" || old_text != "" || new_text != ""
    agent_action_state {
        tool: tool,
        path: path,
        content: content,
        query: query,
        command: command,
        old_text: old_text,
        new_text: new_text,
        raw: raw,
        replace_all: replace_all,
        structured: structured,
    }
}

func agent_action_summary(agent_action_state state) string {
    string out = "tool=" + state.tool
    out = out + " path=" + state.path
    out = out + " structured=" + string(state.structured)
    if state.content != "" {
        out = out + " content_len=" + string(len(state.content))
    }
    if state.query != "" {
        out = out + " query=" + state.query
    }
    if state.command != "" {
        out = out + " command_len=" + string(len(state.command))
    }
    if state.old_text != "" {
        out = out + " old_len=" + string(len(state.old_text))
    }
    if state.new_text != "" {
        out = out + " new_len=" + string(len(state.new_text))
    }
    if state.replace_all {
        out = out + " replace_all=true"
    }
    out
}
