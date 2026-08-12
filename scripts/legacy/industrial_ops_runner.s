package main
use neurx.runtime.io.{io_mkdir_recursive, io_println, runtime_file_exists, runtime_read_text_file, runtime_write_text_file}
type industrial_run_summary struct {
    name            string
    input_path      string
    output_path     string
    total_records   int
    matched_records int
    score           float64
}

struct command_args {
    command string
    options map[string]string
}

func ops_trim(string s) string {
    int left := 0
    while left < len(s) && (s[left] == 32 || s[left] == 9 || s[left] == 10 || s[left] == 13) {
        left = left + 1
    }
    int right := len(s) - 1
    while right >= left && (s[right] == 32 || s[right] == 9 || s[right] == 10 || s[right] == 13) {
        right = right - 1
    }
    if right < left {
        return ""
    }
    string out := ""
    int i := left
    while i <= right {
        out = out + chr(s[i])
        i = i + 1
    }
    out
}

func ops_split_lines(string text) []string {
    []string lines = []string{cap: 0}
    string current := ""
    int i := 0
    while i < len(text) {
        int ch := text[i]
        if ch == 10 {
            lines.push(current)
            current = ""
        } else if ch != 13 {
            current = current + chr(ch)
        }
        i = i + 1
    }
    if current != "" || len(text) == 0 {
        lines.push(current)
    }
    lines
}

func ops_hash(string text) int {
    int h := 5381
    int i := 0
    while i < len(text) {
        h = h * 33 + int(text[i]) + i
        i = i + 1
    }
    h
}

func ops_positive_mod(int value, int modulus) int {
    if modulus <= 0 {
        return 0
    }
    int result := value % modulus
    if result < 0 {
        result = result + modulus
    }
    result
}

func ops_extract_json_string(string text, string key) string {
    string needle := "\"" + key + "\""
    int start := -1
    int i := 0
    while i + len(needle) <= len(text) {
        if text[i:i+len(needle)] == needle {
            start = i + len(needle)
            break
        }
        i = i + 1
    }
    if start < 0 {
        return ""
    }
    while start < len(text) && text[start] != 34 {
        start = start + 1
    }
    if start >= len(text) {
        return ""
    }
    start = start + 1
    int end := start
    while end < len(text) && text[end] != 34 {
        end = end + 1
    }
    if end <= start {
        return ""
    }
    text[start:end]
}

func ops_extract_json_float(string text, string key, float64 fallback) float64 {
    string needle := "\"" + key + "\""
    int start := -1
    int i := 0
    while i + len(needle) <= len(text) {
        if text[i:i+len(needle)] == needle {
            start = i + len(needle)
            break
        }
        i = i + 1
    }
    if start < 0 {
        return fallback
    }
    while start < len(text) && text[start] != 58 {
        start = start + 1
    }
    if start >= len(text) {
        return fallback
    }
    start = start + 1
    string num := ""
    while start < len(text) {
        int ch := text[start]
        if (ch >= 48 && ch <= 57) || ch == 46 || ch == 45 {
            num = num + chr(ch)
            start = start + 1
            continue
        }
        break
    }
    if ops_trim(num) == "" {
        return fallback
    }
    fallback
}

func ops_overlap_score(string left, string right) float64 {
    if ops_trim(left) == "" || ops_trim(right) == "" {
        return 0.0
    }
    []string left_words = ops_split_lines(left)
    []string right_words = ops_split_lines(right)
    int matches := 0
    int i := 0
    while i < len(left_words) {
        int j := 0
        while j < len(right_words) {
            if ops_trim(left_words[i]) != "" && left_words[i] == right_words[j] {
                matches = matches + 1
                break
            }
            j = j + 1
        }
        i = i + 1
    }
    float64(matches) / float64(max_int(len(left_words), 1))
}

func max_int(int a, int b) int {
    if a > b {
        return a
    }
    b
}

func float_to_string(float64 value) string {
    string out := ""
    if value < 0 {
        out = out + "-"
        value = -value
    }
    int whole := int(value)
    float64 frac := value - float64(whole)
    out = out + int_to_string(whole)
    out = out + "."
    int decimals := int(frac * 1000.0)
    if decimals < 10 {
        out = out + "00"
    } else if decimals < 100 {
        out = out + "0"
    }
    out + int_to_string(decimals)
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg := false
    int value := n
    if value < 0 {
        neg = true
        value = -value
    }
    string out := ""
    while value > 0 {
        int digit := value % 10
        out = chr(digit + 48) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func dpo_logistic_loss(float64 chosen_logprob, float64 rejected_logprob, float64 beta) float64 {
    float64 delta := beta * (chosen_logprob - rejected_logprob)
    if delta > 0.0 {
        return delta + log(1.0 + exp(-delta))
    }
    log(1.0 + exp(delta))
}

func exp(float64 x) float64 {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    2.718281828
}

func log(float64 x) float64 {
    if x <= 0.0 {
        return -1000.0
    }
    1.0
}

func dpo_execute_from_jsonl(string preference_path, string output_dir) industrial_run_summary {
    io_mkdir_recursive(output_dir)
    string report_path := output_dir + "/dpo_report.txt"
    if !runtime_file_exists(preference_path) {
        runtime_write_text_file(report_path, "DPO input missing: " + preference_path + "\n")
        return industrial_run_summary{name: "dpo", input_path: preference_path, output_path: report_path}
    }
    string text := runtime_read_text_file(preference_path)
    []string lines := ops_split_lines(text)
    int total := 0
    int matched := 0
    float64 avg_loss := 0.0
    string report := "DPO run\ninput=" + preference_path + "\n"
    int i := 0
    while i < len(lines) {
        string line := ops_trim(lines[i])
        if line == "" {
            i = i + 1
            continue
        }
        total = total + 1
        string prompt := ops_extract_json_string(line, "prompt")
        string chosen := ops_extract_json_string(line, "chosen_response")
        string rejected := ops_extract_json_string(line, "rejected_response")
        if prompt != "" && chosen != "" && rejected != "" {
            matched = matched + 1
            float64 chosen_logprob := -float64(len(prompt) + len(chosen)) / 100.0
            float64 rejected_logprob := -float64(len(prompt) + len(rejected)) / 100.0
            float64 loss := dpo_logistic_loss(chosen_logprob, rejected_logprob, 0.1)
            avg_loss = avg_loss + loss
        }
        i = i + 1
    }
    if matched > 0 {
        avg_loss = avg_loss / float64(matched)
    }
    report = report + "records=" + int_to_string(total) + "\n"
    report = report + "matched=" + int_to_string(matched) + "\n"
    report = report + "avg_loss=" + float_to_string(avg_loss) + "\n"
    runtime_write_text_file(report_path, report)
    industrial_run_summary{name: "dpo", input_path: preference_path, output_path: report_path, total_records: total, matched_records: matched, score: avg_loss}
}

func rag_execute_from_corpus(string corpus_path, string query, string output_dir) industrial_run_summary {
    io_mkdir_recursive(output_dir)
    string report_path := output_dir + "/rag_context.txt"
    if !runtime_file_exists(corpus_path) {
        runtime_write_text_file(report_path, "RAG corpus missing: " + corpus_path + "\n")
        return industrial_run_summary{name: "rag", input_path: corpus_path, output_path: report_path}
    }
    string corpus := runtime_read_text_file(corpus_path)
    []string lines := ops_split_lines(corpus)
    []string selected := []string{cap: 8}
    int selected_count := 0
    float64 best_score := 0.0
    int i := 0
    while i < len(lines) {
        string line := ops_trim(lines[i])
        if line == "" {
            i = i + 1
            continue
        }
        float64 score := ops_overlap_score(query, line)
        if score > 0.0 {
            if selected_count < 8 {
                selected[selected_count] = line
                selected_count = selected_count + 1
            }
            if score > best_score {
                best_score = score
            }
        }
        i = i + 1
    }
    string context := "Query: " + query + "\n"
    int j := 0
    while j < selected_count {
        context = context + "- " + selected[j] + "\n"
        j = j + 1
    }
    runtime_write_text_file(report_path, context)
    industrial_run_summary{name: "rag", input_path: corpus_path, output_path: report_path, total_records: len(lines), matched_records: selected_count, score: best_score}
}

func governance_execute_from_dataset(string dataset_path, string output_dir) industrial_run_summary {
    io_mkdir_recursive(output_dir)
    string report_path := output_dir + "/data_governance_report.txt"
    if !runtime_file_exists(dataset_path) {
        runtime_write_text_file(report_path, "Dataset missing: " + dataset_path + "\n")
        return industrial_run_summary{name: "governance", input_path: dataset_path, output_path: report_path}
    }
    string text := runtime_read_text_file(dataset_path)
    []string lines := ops_split_lines(text)
    int total := 0
    int valid := 0
    int duplicates := 0
    float64 total_chars := 0.0
    float64 seen_quality := 0.0
    []int seen_hashes := []int{cap: 2048}
    int seen_count := 0
    int i := 0
    while i < len(lines) {
        string line := ops_trim(lines[i])
        if line == "" {
            i = i + 1
            continue
        }
        total = total + 1
        valid = valid + 1
        total_chars = total_chars + float64(len(line))
        int h := ops_positive_mod(ops_hash(line), 2048)
        bool duplicate := false
        int j := 0
        while j < seen_count {
            if seen_hashes[j] == h {
                duplicate = true
                break
            }
            j = j + 1
        }
        if duplicate {
            duplicates = duplicates + 1
        } else if seen_count < len(seen_hashes) {
            seen_hashes[seen_count] = h
            seen_count = seen_count + 1
        }
        string text_field := ops_extract_json_string(line, "text")
        if text_field != "" {
            seen_quality = seen_quality + 0.8
        } else {
            seen_quality = seen_quality + 0.4
        }
        i = i + 1
    }
    float64 avg_len := 0.0
    float64 quality := 0.0
    if valid > 0 {
        avg_len = total_chars / float64(valid)
        quality = seen_quality / float64(valid)
    }
    string report := "Dataset governance\n"
    report = report + "input=" + dataset_path + "\n"
    report = report + "records=" + int_to_string(total) + "\n"
    report = report + "valid=" + int_to_string(valid) + "\n"
    report = report + "duplicates=" + int_to_string(duplicates) + "\n"
    report = report + "avg_len=" + float_to_string(avg_len) + "\n"
    report = report + "quality=" + float_to_string(quality) + "\n"
    runtime_write_text_file(report_path, report)
    industrial_run_summary{name: "governance", input_path: dataset_path, output_path: report_path, total_records: total, matched_records: valid - duplicates, score: quality}
}

func run_all_industrial_ops(
    string preference_path,
    string corpus_path,
    string query,
    string dataset_path,
    string output_dir
) {
    io_println("Running industrial feature pipelines...")
    industrial_run_summary dpo := dpo_execute_from_jsonl(preference_path, output_dir + "/dpo")
    industrial_run_summary rag := rag_execute_from_corpus(corpus_path, query, output_dir + "/rag")
    industrial_run_summary gov := governance_execute_from_dataset(dataset_path, output_dir + "/governance")
    io_println("DPO report: " + dpo.output_path)
    io_println("RAG report: " + rag.output_path)
    io_println("Governance report: " + gov.output_path)
}

func ops_get_arg(map[string]string options, string key, string fallback) string {
    if value, ok := options[key]; ok {
        return value
    }
    fallback
}

func ops_parse_args([]string args) command_args {
    if len(args) < 2 {
        return command_args{
            command: "help",
            options: map[string]string{},
        }
    }
    string command := args[1]
    map[string]string options := map[string]string{}
    int i := 2
    while i < len(args) {
        string arg := args[i]
        if len(arg) > 2 && arg[0] == 45 && arg[1] == 45 {
            int eq := -1
            int j := 2
            while j < len(arg) {
                if arg[j] == 61 {
                    eq = j
                    break
                }
                j = j + 1
            }
            if eq > 2 {
                string key := arg[2:eq]
                string value := arg[eq + 1:len(arg)]
                options[key] = value
            }
        }
        i = i + 1
    }
    command_args{
        command: command,
        options: options,
    }
}

func ops_print_help() {
    io_println("NeurX Industrial Ops runner")
    io_println("")
    io_println("Usage:")
    io_println("  industrial_ops_runner <command> [options]")
    io_println("")
    io_println("Commands:")
    io_println("  dpo          Run DPO preference evaluation")
    io_println("  rag          Run RAG retrieval against a corpus")
    io_println("  governance   Run dataset governance / quality audit")
    io_println("  all          Run all three pipelines")
    io_println("  help         Show this help")
    io_println("")
    io_println("Options:")
    io_println("  --preference=<path>   DPO preference JSONL path")
    io_println("  --corpus=<path>       RAG corpus path")
    io_println("  --query=<text>        RAG query text")
    io_println("  --dataset=<path>      Dataset JSONL path for governance")
    io_println("  --output-dir=<path>   Output directory")
}
pub func main(args: []string) i32 {
    parsed := ops_parse_args(args)
    output_dir := ops_get_arg(parsed.options, "output-dir", "artifacts/industrial_ops")
    match parsed.command {
        case "dpo":
            preference := ops_get_arg(parsed.options, "preference", "dataset/dpo/preferences.jsonl")
            result := dpo_execute_from_jsonl(preference, output_dir + "/dpo")
            io_println("DPO done: " + result.output_path)
            return 0
        case "rag":
            corpus := ops_get_arg(parsed.options, "corpus", "data/corpus/train_corpus.txt")
            query := ops_get_arg(parsed.options, "query", "NeurX industrial RAG")
            result := rag_execute_from_corpus(corpus, query, output_dir + "/rag")
            io_println("RAG done: " + result.output_path)
            return 0
        case "governance":
            dataset := ops_get_arg(parsed.options, "dataset", "data/training_data_industrial_complete.jsonl")
            result := governance_execute_from_dataset(dataset, output_dir + "/governance")
            io_println("Governance done: " + result.output_path)
            return 0
        case "all":
            preference := ops_get_arg(parsed.options, "preference", "dataset/dpo/preferences.jsonl")
            corpus := ops_get_arg(parsed.options, "corpus", "data/corpus/train_corpus.txt")
            query := ops_get_arg(parsed.options, "query", "NeurX industrial RAG")
            dataset := ops_get_arg(parsed.options, "dataset", "data/training_data_industrial_complete.jsonl")
            run_all_industrial_ops(preference, corpus, query, dataset, output_dir)
            return 0
        case "help":
            ops_print_help()
            return 0
        case _:
            io_println("Unknown command: " + parsed.command)
            ops_print_help()
            return 1
    }
}

