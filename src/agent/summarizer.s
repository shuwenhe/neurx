package neurx.agent.summarizer
struct agent_summary_result {
    string text
    int original_len
    bool clipped
}
func agent_summary_result_make(string text, int orig_len, bool clipped) agent_summary_result {
    agent_summary_result {
        text: text,
        original_len: orig_len,
        clipped: clipped,
    }
}
func agent_summarize_to_result(string text, int max_chars) agent_summary_result {
    int n = len(text)
    if n <= max_chars {
        return agent_summary_result_make(text, n, false)
    }
    string out = ""
    int i = 0
    for i < max_chars {
        out = out + string(text[i])
        i = i + 1
    }
    agent_summary_result_make(out + "...[truncated]", n, true)
}
func agent_summarize(string text, int max_chars) string {
    agent_summary_result r = agent_summarize_to_result(text, max_chars)
    r.text
}
func agent_summarize_for_context(string text) string {
    agent_summarize(text, 1024)
}
func agent_summarize_for_memory(string text) string {
    agent_summarize(text, 256)
}
func agent_summarize_for_prompt(string text) string {
    agent_summarize(text, 512)
}
func agent_summarize_count_sentences(string text) int {
    int count = 0
    int i = 0
    int n = len(text)
    for i < n - 1 {
        if string(text[i]) == "." {
            if string(text[i + 1]) == " " {
                count = count + 1
            }
        }
        i = i + 1
    }
    count
}
func agent_summarize_first_sentence(string text) string {
    string out = ""
    int i = 0
    int n = len(text)
    bool done = false
    for i < n {
        out = out + string(text[i])
        if string(text[i]) == "." {
            done = true
            i = n
        }
        i = i + 1
    }
    if done {
        return out
    }
    out
}
func agent_summarize_keyword_line(string text, string keyword) string {
    string kw = lower(trim(keyword))
    string haystack = lower(text)
    int hl = len(haystack)
    int kl = len(kw)
    if kl <= 0 {
        return ""
    }
    int i = 0
    for i <= hl - kl {
        int j = 0
        bool match = true
        for j < kl {
            if haystack[i + j] != kw[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            int start = i - 40
            if start < 0 {
                start = 0
            }
            int end = i + kl + 40
            if end > hl {
                end = hl
            }
            string snippet = ""
            int k = start
            for k < end {
                snippet = snippet + string(text[k])
                k = k + 1
            }
            return snippet
        }
        i = i + 1
    }
    ""
}
func agent_summary_result_format(agent_summary_result result) string {
    string clipped_str = "no"
    if result.clipped {
        clipped_str = "yes"
    }
    "summary;original_len=" + string(result.original_len) + ";clipped=" + clipped_str + ";text=" + result.text
}
