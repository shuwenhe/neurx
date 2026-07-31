package neurx.context.context_manager
use neurx.inference
use neurx.tool.workspace_tools.{agent_workspace_clip}
struct agent_context_state {
    int token_count
    int max_tokens
    int compression_threshold
    int compressions
    []string segments
    []int segment_tokens
    bool compressed
}
func new_agent_context_state(int max_tokens) agent_context_state {
    int threshold = max_tokens * 3 / 4
    agent_context_state {
        token_count: 0,
        max_tokens: max_tokens,
        compression_threshold: threshold,
        compressions: 0,
        segments: [],
        segment_tokens: [],
        compressed: false,
    }
}

func agent_context_default_max_tokens() int {
    8192
}

func agent_context_estimate_tokens(string text) int {
    int l = len(text)
    int t = l / 4
    if t < 1 && l > 0 {
        t = 1
    }
    t
}

func agent_context_near_limit(agent_context_state state) bool {
    state.token_count >= state.compression_threshold
}

func agent_context_is_full(agent_context_state state) bool {
    state.token_count >= state.max_tokens
}

func agent_context_append(agent_context_state state, string text) agent_context_state {
    int tokens = agent_context_estimate_tokens(text)
    int n = len(state.segments)
    []string segs = []string{cap: n + 1}
    []int seg_tokens = []int{cap: n + 1}
    int i = 0
    while i < n {
        segs[i] = state.segments[i]
        seg_tokens[i] = state.segment_tokens[i]
        i = i + 1
    }
    segs[n] = text
    seg_tokens[n] = tokens
    agent_context_state {
        token_count: state.token_count + tokens,
        max_tokens: state.max_tokens,
        compression_threshold: state.compression_threshold,
        compressions: state.compressions,
        segments: segs,
        segment_tokens: seg_tokens,
        compressed: state.compressed,
    }
}

func agent_context_compress(agent_context_state state, int keep_last) agent_context_state {
    int total = len(state.segments)
    int keep = keep_last
    if keep > total {
        keep = total
    }
    if keep < 1 {
        keep = 1
    }
    int start = total - keep
    []string segs = []string{cap: keep}
    []int seg_tokens = []int{cap: keep}
    int new_total = 0
    int i = 0
    while i < keep {
        segs[i] = state.segments[start + i]
        seg_tokens[i] = state.segment_tokens[start + i]
        new_total = new_total + seg_tokens[i]
        i = i + 1
    }
    agent_context_state {
        token_count: new_total,
        max_tokens: state.max_tokens,
        compression_threshold: state.compression_threshold,
        compressions: state.compressions + 1,
        segments: segs,
        segment_tokens: seg_tokens,
        compressed: true,
    }
}

func agent_context_maybe_compress(agent_context_state state) agent_context_state {
    if !agent_context_near_limit(state) {
        return state
    }
    int keep = len(state.segments) / 2
    if keep < 2 {
        keep = 2
    }
    agent_context_compress(state, keep)
}

func agent_context_extract_dropped(agent_context_state state, int keep_last) string {
    int total = len(state.segments)
    int keep = keep_last
    if keep >= total {
        return ""
    }
    int drop_count = total - keep
    string out = ""
    int i = 0
    while i < drop_count {
        if i > 0 {
            out = out + "\n"
        }
        out = out + state.segments[i]
        i = i + 1
    }
    out
}

func agent_context_compress_with_summary(agent_context_state state, string summary, int keep_last) agent_context_state {
    int total = len(state.segments)
    int keep = keep_last
    if keep > total {
        keep = total
    }
    if keep < 1 {
        keep = 1
    }
    string summary_seg = "[context_summary] " + trim(summary)
    int new_size = keep + 1
    []string segs = []string{cap: new_size}
    []int seg_tokens = []int{cap: new_size}
    segs[0] = summary_seg
    seg_tokens[0] = agent_context_estimate_tokens(summary_seg)
    int start = total - keep
    int new_total = seg_tokens[0]
    int i = 0
    while i < keep {
        segs[i + 1] = state.segments[start + i]
        seg_tokens[i + 1] = state.segment_tokens[start + i]
        new_total = new_total + seg_tokens[i + 1]
        i = i + 1
    }
    agent_context_state {
        token_count: new_total,
        max_tokens: state.max_tokens,
        compression_threshold: state.compression_threshold,
        compressions: state.compressions + 1,
        segments: segs,
        segment_tokens: seg_tokens,
        compressed: true,
    }
}

func agent_context_smart_compress(agent_context_state state, string model_path) agent_context_state {
    if !agent_context_near_limit(state) {
        return state
    }
    int keep = len(state.segments) / 2
    if keep < 2 {
        keep = 2
    }
    if trim(model_path) == "" {
        return agent_context_compress(state, keep)
    }
    string dropped_text = agent_context_extract_dropped(state, keep)
    if trim(dropped_text) == "" {
        return agent_context_compress(state, keep)
    }
    string prompt = "Summarize the following agent context segments into one concise paragraph (max 200 words). Preserve: goals, key decisions, completed actions, file paths, and error states. Omit redundant observations.\n\n" + agent_workspace_clip(dropped_text, 3000)
    string summary = trim(infer_run(model_path, prompt))
    if summary == "" {
        return agent_context_compress(state, keep)
    }
    agent_context_compress_with_summary(state, summary, keep)
}

func agent_context_to_string(agent_context_state state) string {
    int n = len(state.segments)
    string out = ""
    int i = 0
    while i < n {
        if i > 0 {
            out = out + "\n"
        }
        out = out + state.segments[i]
        i = i + 1
    }
    out
}

func agent_context_summary(agent_context_state state) string {
    "tokens=" + string(state.token_count) + " max=" + string(state.max_tokens) + " compressed=" + string(state.compressed) + " compressions=" + string(state.compressions)
}
