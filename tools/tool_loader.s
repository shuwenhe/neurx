package neurx.agent.tool_loader
use neurx.agent.tool_registry
use neurx.runtime.io.{runtime_read_text_file, runtime_file_exists}
func agent_tool_loader_find_colon(string text, int start) int {
    int i = start
    while i < len(text) {
        if string(text[i]) == ":" {
            return i
        }
        i = i + 1
    }
    -1
}

func agent_tool_loader_substring(string text, int from, int to) string {
    string out = ""
    int i = from
    while i < to {
        if i < len(text) {
            out = out + string(text[i])
        }
        i = i + 1
    }
    out
}

func agent_tool_loader_digit_val(string text, int i) int {
    string c = string(text[i])
    int v = 0
    if c == "1" { v = 1 }
    if c == "2" { v = 2 }
    if c == "3" { v = 3 }
    if c == "4" { v = 4 }
    if c == "5" { v = 5 }
    if c == "6" { v = 6 }
    if c == "7" { v = 7 }
    if c == "8" { v = 8 }
    if c == "9" { v = 9 }
    v
}

func agent_tool_loader_parse_int(string s) int {
    string t = trim(s)
    int result = 0
    int i = 0
    while i < len(t) {
        result = result * 10 + agent_tool_loader_digit_val(t, i)
        i = i + 1
    }
    result
}

func agent_tool_loader_parse_bool(string s) bool {
    string t = lower(trim(s))
    if t == "true" {
        return true
    }
    if t == "1" {
        return true
    }
    false
}

func agent_tool_loader_identity(agent_tool_registry_state r) agent_tool_registry_state {
    r
}

func agent_tool_loader_apply_line(agent_tool_registry_state registry, string line) agent_tool_registry_state {
    string l = trim(line)
    if l == "" {
        return registry
    }
    int p0 = agent_tool_loader_find_colon(l, 0)
    if p0 < 0 {
        return registry
    }
    int p1 = agent_tool_loader_find_colon(l, p0 + 1)
    if p1 < 0 {
        return registry
    }
    int p2 = agent_tool_loader_find_colon(l, p1 + 1)
    if p2 < 0 {
        return registry
    }
    int p3 = agent_tool_loader_find_colon(l, p2 + 1)
    int p3_end = len(l)
    if p3 >= 0 {
        p3_end = p3
    }
    string name = agent_tool_loader_substring(l, 0, p0)
    string enabled_str = agent_tool_loader_substring(l, p0 + 1, p1)
    string timeout_str = agent_tool_loader_substring(l, p1 + 1, p2)
    string retries_str = agent_tool_loader_substring(l, p2 + 1, p3_end)
    string cap_str = ""
    if p3 >= 0 {
        cap_str = agent_tool_loader_substring(l, p3 + 1, len(l))
    }
    if name == "" {
        return registry
    }
    bool enabled = agent_tool_loader_parse_bool(enabled_str)
    int timeout_ms = agent_tool_loader_parse_int(timeout_str)
    int retries = agent_tool_loader_parse_int(retries_str)
    if timeout_ms <= 0 {
        timeout_ms = 5000
    }
    agent_tool_registry_add_with_capability(registry, name, enabled, timeout_ms, retries, cap_str)
}

func agent_tool_loader_load_config(agent_tool_registry_state init_reg, string config) agent_tool_registry_state {
    agent_tool_registry_state current = agent_tool_loader_identity(init_reg)
    string line = ""
    int i = 0
    while i < len(config) {
        if string(config[i]) == "\n" {
            current = agent_tool_loader_apply_line(current, line)
            line = ""
        }
        if string(config[i]) != "\n" {
            line = line + string(config[i])
        }
        i = i + 1
    }
    if line != "" {
        current = agent_tool_loader_apply_line(current, line)
    }
    current
}

func agent_tool_loader_load_from_file(string path) agent_tool_registry_state {
    agent_tool_registry_state base = new_agent_tool_registry_state()
    if !runtime_file_exists(path) {
        return base
    }
    string config = runtime_read_text_file(path)
    agent_tool_loader_load_config(base, config)
}

func agent_tool_loader_summary(agent_tool_registry_state registry, string source) string {
    "tool_loader;source=" + source + ";count=" + string(agent_tool_registry_count(registry))
}
