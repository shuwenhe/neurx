package neurx.perception.perception
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
func get_key(agent_perception_result result, int index) string {
    result.keys[index]
}
func get_value(agent_perception_result result, int index) string {
    result.values[index]
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
    int i = 0
    while i < len(text) {
        if text[i] == '=' {
            return true
        }
        i = i + 1
    }
    false
}
func agent_perception_detect_kind(string raw) string {
    string text = lower(trim(raw))
    if text == "" {
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
    string text = trim(raw)
    []string keys = []
    []string values = []
    int i = 0
    string item = ""
    while i <= len(text) {
        bool split = i == len(text)
        if !split {
            string ch = string(text[i])
            split = ch == ";" || ch == "\n"
        }
        if split {
            string pair = trim(item)
            if pair != "" {
                int eq = -1
                int j = 0
                while j < len(pair) {
                    if pair[j] == '=' {
                        eq = j
                        break
                    }
                    j = j + 1
                }
                if eq >= 0 {
                    keys.push(trim(string(pair[0:eq])))
                    values.push(trim(string(pair[eq + 1:len(pair)])))
                }
            }
            item = ""
        } else {
            item = item + string(text[i])
        }
        i = i + 1
    }
    agent_perception_result {
        kind: "kv",
        content: raw,
        source: "tool",
        structured: true,
        keys: keys,
        values: values,
        field_count: len(keys),
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
        if get_key(result, i) == key {
            return get_value(result, i)
        }
        i = i + 1
    }
    ""
}
func agent_perception_summary(agent_perception_result result) string {
    "kind=" + result.kind + " source=" + result.source + " structured=" + string(result.structured) + " fields=" + string(result.field_count)
}
