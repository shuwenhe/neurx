package neurx.agent.perception

struct agent_perception_result {
    string kind
    string content
    string source
    bool structured
    []string keys
    []string values
    int field_count
}

func new_agent_perception_result(string kind, string content, string source) agent_perception_result {
    agent_perception_result {
        kind: kind,
        content: content,
        source: source,
        structured: false,
        keys: [],
        values: [],
        field_count: 0,
    }
}

func agent_perception_starts_with(string text, string prefix) bool {
    int tl = len(text)
    int pl = len(prefix)
    if pl > tl {
        return false
    }
    int i = 0
    while i < pl {
        if text[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func agent_perception_contains_kv(string text) bool {
    int n = len(text)
    int i = 0
    while i < n {
        if string(text[i]) == "=" {
            return true
        }
        i = i + 1
    }
    false
}

func agent_perception_detect_kind(string raw) string {
    string text = lower(trim(raw))
    if len(text) == 0 {
        return "empty"
    }
    if agent_perception_starts_with(text, "{") {
        return "json_object"
    }
    if agent_perception_starts_with(text, "[") {
        return "json_array"
    }
    if agent_perception_starts_with(text, "error:") || agent_perception_starts_with(text, "err:") {
        return "error"
    }
    if agent_perception_starts_with(text, "ok:") || agent_perception_starts_with(text, "success:") {
        return "success"
    }
    if agent_perception_contains_kv(text) {
        return "kv"
    }
    "text"
}

func agent_perception_parse_kv(string raw) agent_perception_result {
    []string keys = []string{cap: 16}
    []string values = []string{cap: 16}
    int field_count = 0
    int n = len(raw)
    string cur_key = ""
    string cur_val = ""
    bool in_val = false
    int i = 0
    while i <= n {
        bool at_end = i == n
        string ch = ""
        if !at_end {
            ch = string(raw[i])
        }
        if !in_val {
            if ch == "=" {
                in_val = true
            } else if ch == " " || ch == "\n" || at_end || ch == ";" {
                if cur_key != "" && !in_val {
                    cur_key = ""
                }
                cur_key = ""
            } else {
                cur_key = cur_key + ch
            }
        } else {
            if ch == " " || ch == "\n" || ch == ";" || at_end {
                if cur_key != "" {
                    keys[field_count] = cur_key
                    values[field_count] = cur_val
                    field_count = field_count + 1
                }
                cur_key = ""
                cur_val = ""
                in_val = false
            } else {
                cur_val = cur_val + ch
            }
        }
        i = i + 1
    }
    agent_perception_result {
        kind: "kv",
        content: raw,
        source: "observation",
        structured: true,
        keys: keys,
        values: values,
        field_count: field_count,
    }
}

func agent_perceive(string raw, string source) agent_perception_result {
    string kind = agent_perception_detect_kind(raw)
    if kind == "kv" {
        return agent_perception_parse_kv(raw)
    }
    new_agent_perception_result(kind, raw, source)
}

func agent_perception_get_field(agent_perception_result result, string key) string {
    int i = 0
    while i < result.field_count {
        if result.keys[i] == key {
            return result.values[i]
        }
        i = i + 1
    }
    ""
}

func agent_perception_summary(agent_perception_result result) string {
    "kind=" + result.kind + " structured=" + string(result.structured) + " fields=" + string(result.field_count) + " source=" + result.source
}
