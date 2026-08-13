package neurx.dataset_text
use neurx.strings

struct text_corpus_state {
    string path
    string raw_text
    []string lines
    []string vocab
    []int token_ids
    int line_count
    int char_count
    int token_count
}

func copy_ints([]int values) []int {
    []int out = []int{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func has_string([]string values, string target) bool {
    int i = 0
    while i < len(values) {
        if strings_eq(string_at(values, i), target) {
            return true
        }
        i = i + 1
    }
    false
}

func count_lines(string text) int {
    int n = len(text)
    int lines = 0
    int i = 0
    bool has_content = false
    while i < n {
        string ch = substring(text, i, i + 1)
        if strings_eq(ch, "\n") {
            lines = lines + 1
            has_content = false
        } else if !strings_eq(ch, "\r") {
            has_content = true
        }
        i = i + 1
    }
    if has_content {
        lines = lines + 1
    }
    lines
}

func split_lines(string text) []string {
    int n = len(text)
    int lines_cap = count_lines(text)
    if lines_cap <= 0 {
        lines_cap = 1
    }
    []string lines = []string{cap: lines_cap}
    string current = ""
    int i = 0
    int line_idx = 0
    while i < n {
        string ch = substring(text, i, i + 1)
        if strings_eq(ch, "\n") {
            string cleaned = trim(current)
            if !strings_eq(cleaned, "") {
                string_set(lines, line_idx, cleaned)
                line_idx = line_idx + 1
            }
            current = ""
        } else if !strings_eq(ch, "\r") {
            current = concat2(current, ch)
        }
        i = i + 1
    }
    string cleaned_tail = trim(current)
    if !strings_eq(cleaned_tail, "") {
        string_set(lines, line_idx, cleaned_tail)
        line_idx = line_idx + 1
    }
    if line_idx == 0 {
        []string empty = []string{cap: 0}
        return empty
    }
    if line_idx == lines_cap {
        return lines
    }
    []string out = []string{cap: line_idx}
    int j = 0
    while j < line_idx {
        string_set(out, j, string_at(lines, j))
        j = j + 1
    }
    out
}

func build_vocab(string text) []string {
    int n = len(text)
    []string vocab = []string{cap: n}
    int i = 0
    int vocab_len = 0
    while i < n {
        string ch = substring(text, i, i + 1)
        if !strings_eq(ch, "\r") && !has_string(vocab, ch) {
            vocab[vocab_len] = ch
            vocab_len = vocab_len + 1
        }
        i = i + 1
    }
    vocab
}

func vocab_index([]string vocab, string ch) int {
    int i = 0
    while i < len(vocab) {
        if strings_eq(string_at(vocab, i), ch) {
            return i
        }
        i = i + 1
    }
    -1
}

func encode_text(string text, []string vocab) []int {
    int n = len(text)
    []int token_ids = []int{cap: n}
    int i = 0
    int token_idx = 0
    while i < n {
        string ch = substring(text, i, i + 1)
        if !strings_eq(ch, "\r") {
            int idx = vocab_index(vocab, ch)
            if idx < 0 {
                idx = 0
            }
            token_ids[token_idx] = idx
            token_idx = token_idx + 1
        }
        i = i + 1
    }
    token_ids
}

func load_text_corpus(string path) text_corpus_state {
    if !neurx.runtime.io.runtime_file_exists(path) {
        text_corpus_state empty_state = text_corpus_state {
            path: path,
            raw_text: "",
            lines: []string{cap: 0},
            vocab: []string{cap: 0},
            token_ids: []int{cap: 0},
            line_count: 0,
            char_count: 0,
            token_count: 0,
        }
        text_corpus_state state = empty_state
        state
    }
    string raw = neurx.runtime.io.runtime_read_text_file(path)
    []string lines = split_lines(raw)
    []string vocab = build_vocab(raw)
    []int token_ids = encode_text(raw, vocab)
    text_corpus_state state = text_corpus_state {
        path: path,
        raw_text: raw,
        lines: lines,
        vocab: vocab,
        token_ids: token_ids,
        line_count: len(lines),
        char_count: len(raw),
        token_count: len(token_ids),
    }
    state
}

func text_corpus_state_dict(text_corpus_state state) text_corpus_state {
    text_corpus_state {
        path: state.path,
        raw_text: state.raw_text,
        lines: copy_strings(state.lines),
        vocab: copy_strings(state.vocab),
        token_ids: copy_ints(state.token_ids),
        line_count: state.line_count,
        char_count: state.char_count,
        token_count: state.token_count,
    }
}

func text_corpus_load_state_dict(text_corpus_state state, text_corpus_state other) text_corpus_state {
    text_corpus_state {
        path: other.path,
        raw_text: other.raw_text,
        lines: copy_strings(other.lines),
        vocab: copy_strings(other.vocab),
        token_ids: copy_ints(other.token_ids),
        line_count: other.line_count,
        char_count: other.char_count,
        token_count: other.token_count,
    }
}
