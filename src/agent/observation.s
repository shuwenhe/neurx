package neurx.agent.observation
struct agent_observation_state {
    string raw
    string kind
    string status
    bool terminal
    bool blocked
    bool failed
    bool no_progress
    bool ok
}
func new_agent_observation_state() agent_observation_state {
    agent_observation_state {
        raw: "",
        kind: "",
        status: "empty",
        terminal: false,
        blocked: true,
        failed: false,
        no_progress: true,
        ok: false,
    }
}
func agent_observation_contains(string text, string pattern) bool {
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
    for i <= hay_len - nee_len {
        int j = 0
        bool match = true
        for j < nee_len {
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
func agent_observation_kind(string observation) string {
    string raw = trim(observation)
    if raw == "" {
        return ""
    }
    string kind = ""
    int i = 0
    for i < len(raw) {
        string ch = string(raw[i])
        if ch == ":" || ch == ";" || ch == "\n" || ch == " " {
            break
        }
        kind = kind + ch
        i = i + 1
    }
    lower(trim(kind))
}
func agent_observation_parse(string observation) agent_observation_state {
    string raw = trim(observation)
    if raw == "" {
        return new_agent_observation_state()
    }
    string lower_raw = lower(raw)
    string kind = agent_observation_kind(raw)
    if lower_raw == "done" {
        return agent_observation_state {
            raw: raw,
            kind: "done",
            status: "done",
            terminal: true,
            blocked: false,
            failed: false,
            no_progress: false,
            ok: true,
        }
    }
    if lower_raw == "tool_unavailable" || lower_raw == "infer:rejected" || lower_raw == "local_model_config_missing: disabled" || agent_observation_contains(lower_raw, "status=blocked") {
        return agent_observation_state {
            raw: raw,
            kind: kind,
            status: "blocked",
            terminal: false,
            blocked: true,
            failed: true,
            no_progress: true,
            ok: false,
        }
    }
    if agent_observation_contains(lower_raw, ":failed") || agent_observation_contains(lower_raw, "tool_error:") || agent_observation_contains(lower_raw, "status=failed") || agent_observation_contains(lower_raw, "error=") {
        return agent_observation_state {
            raw: raw,
            kind: kind,
            status: "failed",
            terminal: false,
            blocked: false,
            failed: true,
            no_progress: true,
            ok: false,
        }
    }
    if agent_observation_contains(lower_raw, "hits=0") || agent_observation_contains(lower_raw, "status=no_progress") || lower_raw == "noop" || lower_raw == "no_result" {
        return agent_observation_state {
            raw: raw,
            kind: kind,
            status: "no_progress",
            terminal: false,
            blocked: false,
            failed: false,
            no_progress: true,
            ok: false,
        }
    }
    if agent_observation_contains(lower_raw, ":ok") || agent_observation_contains(lower_raw, "status=ok") || agent_observation_contains(lower_raw, "analysis:") || agent_observation_contains(lower_raw, "plan:") || agent_observation_contains(lower_raw, "verify:") || agent_observation_contains(lower_raw, "search:") || agent_observation_contains(lower_raw, "repo_map:") {
        return agent_observation_state {
            raw: raw,
            kind: kind,
            status: "ok",
            terminal: false,
            blocked: false,
            failed: false,
            no_progress: false,
            ok: true,
        }
    }
    agent_observation_state {
        raw: raw,
        kind: kind,
        status: "unknown",
        terminal: false,
        blocked: false,
        failed: false,
        no_progress: false,
        ok: true,
    }
}
func agent_observation_requires_replan(string observation) bool {
    agent_observation_parse(observation).blocked
}
func agent_observation_is_failed(string observation) bool {
    agent_observation_parse(observation).failed
}
func agent_observation_is_terminal(string observation) bool {
    agent_observation_parse(observation).terminal
}
func agent_observation_is_progress(string observation) bool {
    agent_observation_parse(observation).ok
}
func agent_observation_is_no_progress(string observation) bool {
    agent_observation_parse(observation).no_progress
}
