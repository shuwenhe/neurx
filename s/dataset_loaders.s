package neurx.data
struct error {
    string message
}
func load_text_dataset(dataset ds) (dataset, error) {
    if len(ds.config.path) == 0 {
        return ds, error{message: "No path specified for text dataset"}
    }
    []string lines = read_lines(ds.config.path)
    int max_samples = ds.config.max_samples
    if max_samples <= 0 || max_samples > len(lines) {
        max_samples = len(lines)
    }
    int total_tokens = 0
    int min_len = 999999
    int max_len = 0
    for i in 0..max_samples {
        string line = trim_whitespace(lines[i])
        if len(line) == 0 {
            continue
        }
        []int tokens = tokenize_text(line)
        if ds.config.max_length > 0  len(tokens) > ds.config.max_length {
            tokens = truncate(tokens, ds.config.max_length)
        }
        sample s {
            token_ids: tokens,
            text: line if ds.config.include_text else "",
            label: -1,
            weight: 1.0,
            metadata: {},
        }
        ds.samples.push(s)
        total_tokens = total_tokens + len(tokens)
        if len(tokens) < min_len { min_len = len(tokens) }
        if len(tokens) > max_len { max_len = len(tokens) }
    }
    int n = len(ds.samples)
    ds.stats = dataset_stats {
        total_samples: n,
        total_tokens: total_tokens,
        avg_length: float(total_tokens / n) if n > 0 else 0.0,
        min_length: min_len if n > 0 else 0,
        max_length: max_len,
        length_distribution: compute_length_distribution(ds),
    }
    ds.is_loaded = true
    (ds, nil)
}

func tokenize_text(string text) []int {
    []int tokens = []int{cap: len(text)}
    for i in 0..len(text) {
        tokens[i] = int(text[i])
    }
    tokens
}

func truncate([]int tokens, int max_len) []int {
    []int result = []int{cap: max_len}
    for i in 0..min(max_len, len(tokens)) {
        result[i] = tokens[i]
    }
    result
}

func trim_whitespace(string s) string {
    int start = 0
    int end = len(s) - 1
    while start <= end  is_space(s[start]) { start = start + 1 }
    while end >= start  is_space(s[end]) { end = end - 1 }
    if start > end { return "" }
    substring(s, start, end - start + 1)
}

func is_space(byte c) bool {
    c == 32 || c == 9 || c == 10 || c == 13
}

func read_lines(string path) []string {
    []string{
        "Hello world",
        "This is a sample sentence",
        "Machine learning is fascinating",
        "Neural networks process data",
        "Training models requires data",
        "Deep learning has many applications",
    }
}
