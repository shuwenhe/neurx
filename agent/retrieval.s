package neurx.agent.retrieval
use neurx.agent.memory
struct agent_retrieval_result {
    []string keys
    []string values
    []int scores
    int count
}
func new_agent_retrieval_result() agent_retrieval_result {
    agent_retrieval_result {
        keys: [],
        values: [],
        scores: [],
        count: 0,
    }
}
func agent_retrieval_text_contains(string haystack, string needle) bool {
    int hl = len(haystack)
    int nl = len(needle)
    if nl <= 0 {
        return true
    }
    if hl < nl {
        return false
    }
    int i = 0
    while i <= hl - nl {
        int j = 0
        bool match = true
        while j < nl {
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
func agent_retrieval_score(string query, string text) int {
    string q = lower(trim(query))
    string t = lower(trim(text))
    if q == "" {
        return 0
    }
    if agent_retrieval_text_contains(t, q) {
        return 10
    }
    if agent_retrieval_text_contains(q, t) {
        return 5
    }
    0
}
func agent_retrieval_search(agent_memory_state memory, string query, int top_k) agent_retrieval_result {
    []string long_keys = agent_memory_long_keys(memory)
    int n = len(long_keys)
    int limit = top_k
    if limit <= 0 {
        limit = 5
    }
    int cap = limit
    if cap > n {
        cap = n
    }
    []string out_keys = []string{cap: cap}
    []string out_values = []string{cap: cap}
    []int out_scores = []int{cap: cap}
    int found = 0
    int i = 0
    while i < n {
        if found < limit {
            agent_memory_lookup_result lr = agent_memory_lookup_long(memory, long_keys[i])
            int sc = agent_retrieval_score(query, long_keys[i] + " " + lr.value)
            if sc > 0 {
                out_keys[found] = long_keys[i]
                out_values[found] = lr.value
                out_scores[found] = sc
                found = found + 1
            }
        }
        i = i + 1
    }
    agent_retrieval_result {
        keys: out_keys,
        values: out_values,
        scores: out_scores,
        count: found,
    }
}
func agent_retrieval_search_short(agent_memory_state memory, string query, int top_k) agent_retrieval_result {
    []string short_keys = agent_memory_short_keys(memory)
    int n = len(short_keys)
    int limit = top_k
    if limit <= 0 {
        limit = 5
    }
    int cap = limit
    if cap > n {
        cap = n
    }
    []string out_keys = []string{cap: cap}
    []string out_values = []string{cap: cap}
    []int out_scores = []int{cap: cap}
    int found = 0
    int i = 0
    while i < n {
        if found < limit {
            agent_memory_lookup_result lr = agent_memory_lookup_short(memory, short_keys[i])
            int sc = agent_retrieval_score(query, short_keys[i] + " " + lr.value)
            if sc > 0 {
                out_keys[found] = short_keys[i]
                out_values[found] = lr.value
                out_scores[found] = sc
                found = found + 1
            }
        }
        i = i + 1
    }
    agent_retrieval_result {
        keys: out_keys,
        values: out_values,
        scores: out_scores,
        count: found,
    }
}
func agent_retrieval_top_key(agent_retrieval_result result) string {
    if result.count <= 0 {
        return ""
    }
    result.keys[0]
}
func agent_retrieval_top_value(agent_retrieval_result result) string {
    if result.count <= 0 {
        return ""
    }
    result.values[0]
}
func agent_retrieval_export(agent_retrieval_result result) string {
    string out = "retrieval;count=" + string(result.count) + "\n"
    int i = 0
    while i < result.count {
        out = out + "hit[" + string(i) + "].key=" + result.keys[i] + ";score=" + string(result.scores[i]) + ";value=" + result.values[i] + "\n"
        i = i + 1
    }
    out
}
func agent_retrieval_summary(agent_retrieval_result result) string {
    "retrieval;hits=" + string(result.count) + ";top=" + agent_retrieval_top_key(result)
}
