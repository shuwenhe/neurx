package neurx.scripts.convert_medmcqa
use std.io.println
use neurx.runtime.io.{runtime_env_get, runtime_read_text_file, runtime_write_text_file,
                       runtime_file_exists, runtime_make_dirs, runtime_run_command_output}

struct question_data {
    string qid
    string question
    []string options
    int correct_answer
    string category
    string explanation
}

struct sft_record {
    string instruction
    string input
    string output
}

func parse_jsonl_question(string line) question_data {
    question_data q = question_data{
        qid: "",
        question: "",
        options: []string{},
        correct_answer: 0,
        category: "medical",
        explanation: ""
    }
    int qid_start = find_substring(line, "\"qid\":\"")
    if qid_start >= 0 {
        qid_start = qid_start + 8
        int qid_end = find_substring_from(line, "\"", qid_start)
        if qid_end > qid_start {
            q.qid = substring(line, qid_start, qid_end)
        }
    }
    int q_start = find_substring(line, "\"question\":\"")
    if q_start >= 0 {
        q_start = q_start + 12
        int q_end = find_substring_from(line, "\"", q_start)
        if q_end > q_start {
            q.question = substring(line, q_start, q_end)
            q.question = unescape_json_string(q.question)
        }
    }
    int ans_start = find_substring(line, "\"correct_answer\":")
    if ans_start >= 0 {
        ans_start = ans_start + 17
        int ans_end = find_char_index(line, ",", ans_start)
        if ans_end > ans_start {
            string ans_str = substring(line, ans_start, ans_end)
            q.correct_answer = parse_int(ans_str)
        }
    }
    int cat_start = find_substring(line, "\"category\":\"")
    if cat_start >= 0 {
        cat_start = cat_start + 12
        int cat_end = find_substring_from(line, "\"", cat_start)
        if cat_end > cat_start {
            q.category = substring(line, cat_start, cat_end)
        }
    }
    q.options = extract_options_from_json(line)
    q
}

func extract_options_from_json(string line) []string {
    []string opts = []string{}
    int opt_start = find_substring(line, "\"options\":[")
    if opt_start < 0 {
        opts = []string{"Option A", "Option B", "Option C", "Option D"}
        return opts
    }
    opt_start = opt_start + 11
    int opt_end = find_char_index(line, "]", opt_start)
    if opt_end > opt_start {
        string options_str = substring(line, opt_start, opt_end)
        int count = 0
        int i = 0
        string current = ""
        for i < len(options_str) && count < 4 {
            if options_str[i] == 34 {
                if len(current) > 0 {
                    opts = opts + [current]
                    current = ""
                    count = count + 1
                }
            } else if options_str[i] != 44 && options_str[i] != 91 && options_str[i] != 93 {
                current = current + options_str[i]
            }
            i = i + 1
        }
    }
    for len(opts) < 4 {
        opts = opts + ["Option placeholder"]
    }
    opts
}

func find_substring(string text, string pattern) int {
    if len(pattern) > len(text) {
        return -1
    }
    for i in 0..len(text)-len(pattern) {
        bool match = true
        for j in 0..len(pattern)-1 {
            if text[i+j] != pattern[j] {
                match = false
                break
            }
        }
        if match {
            return i
        }
    }
    -1
}

func find_substring_from(string text, string pattern, int start) int {
    if start < 0 || start >= len(text) || len(pattern) > len(text)-start {
        return -1
    }
    for i in start..len(text)-len(pattern) {
        bool match = true
        for j in 0..len(pattern)-1 {
            if text[i+j] != pattern[j] {
                match = false
                break
            }
        }
        if match {
            return i
        }
    }
    -1
}

func find_char_index(string text, string ch, int start) int {
    for i in start..len(text)-1 {
        if text[i] == ch[0] {
            return i
        }
    }
    len(text)
}

func substring(string text, int start, int end) string {
    if start < 0 || end > len(text) || start >= end {
        return ""
    }
    string result = ""
    for i in start..end-1 {
        result = result + text[i]
    }
    result
}

func unescape_json_string(string s) string {
    string result = ""
    int i = 0
    for i < len(s) {
        if s[i] == 92 && i+1 < len(s) {
            if s[i+1] == 110 {
                result = result + "\n"
                i = i + 2
            } else if s[i+1] == 116 {
                result = result + "\t"
                i = i + 2
            } else if s[i+1] == 92 {
                result = result + "\\"
                i = i + 2
            } else if s[i+1] == 34 {
                result = result + "\""
                i = i + 2
            } else {
                result = result + s[i]
                i = i + 1
            }
        } else {
            result = result + s[i]
            i = i + 1
        }
    }
    result
}

func parse_int(string s) int {
    int result = 0
    int i = 0
    bool negative = false
    if len(s) > 0 && s[0] == 45 {
        negative = true
        i = 1
    }
    for i < len(s) {
        int ch = s[i] as int
        if ch >= 48 && ch <= 57 {
            result = result * 10 + (ch - 48)
        }
        i = i + 1
    }
    if negative {
        result = 0 - result
    }
    result
}

func question_to_sft(question_data q) sft_record {
    string instruction = "Answer the following medical multiple-choice question accurately."
    string input = q.question + "\n\nOptions:\n"
    []string labels = []string{"A", "B", "C", "D"}
    for i in 0..len(q.options)-1 {
        input = input + labels[i] + ") " + q.options[i] + "\n"
    }
    string output = ""
    if q.correct_answer >= 0 && q.correct_answer < 4 {
        output = "Answer: " + labels[q.correct_answer]
    }
    if len(q.explanation) > 0 {
        output = output + "\n\nExplanation: " + q.explanation
    } else {
        output = output + "\n\nCategory: " + q.category
    }
    sft_record{
        instruction: instruction,
        input: input,
        output: output
    }
}

func escape_for_json(string s) string {
    string result = ""
    for i in 0..len(s)-1 {
        int ch = s[i] as int
        if ch == 34 {
            result = result + "\\\""
        } else if ch == 92 {
            result = result + "\\\\"
        } else if ch == 10 {
            result = result + "\\n"
        } else if ch == 13 {
            result = result + "\\r"
        } else if ch == 9 {
            result = result + "\\t"
        } else {
            result = result + s[i]
        }
    }
    result
}

func sft_to_jsonl(sft_record rec) string {
    string json = "{"
    json = json + "\"instruction\":\""
    json = json + escape_for_json(rec.instruction)
    json = json + "\",\"input\":\""
    json = json + escape_for_json(rec.input)
    json = json + "\",\"output\":\""
    json = json + escape_for_json(rec.output)
    json = json + "\"}"
    json
}

func main() {
    println("╔═══════════════════════════════════════════════════════════════╗")
    println("║ MedMCQA → SFT Dataset Converter (S Language Implementation)  ║")
    println("╚═══════════════════════════════════════════════════════════════╝")
    println("")
    string neurx_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string input_file = runtime_env_get("MEDMCQA_INPUT",
        "/home/shuwen/shuwen/train/dataset/medmcqa/train.json")
    string output_dir = runtime_env_get("MEDMCQA_OUTPUT_DIR",
        neurx_root + "/dataset/medmcqa_sft")
    println("Configuration:")
    println("  Project root:  " + neurx_root)
    println("  Input file:    " + input_file)
    println("  Output dir:    " + output_dir)
    println("")
    if !runtime_file_exists(input_file) {
        println("❌ ERROR: Input file not found")
        println("   Path: " + input_file)
        return 1
    }
    println("✓ Input file found")
    runtime_make_dirs(output_dir)
    println("✓ Output directory ready")
    println("")
    println("Reading MedMCQA data...")
    string file_content = runtime_read_text_file(input_file)
    if len(file_content) == 0 {
        println("❌ ERROR: Failed to read input file")
        return 1
    }
    println("✓ Read " + len(file_content) + " bytes")
    println("Parsing questions...")
    []string lines = []string{}
    string current_line = ""
    for i in 0..len(file_content)-1 {
        if file_content[i] == 10 {
            if len(current_line) > 0 {
                lines = lines + [current_line]
            }
            current_line = ""
        } else {
            current_line = current_line + file_content[i]
        }
    }
    if len(current_line) > 0 {
        lines = lines + [current_line]
    }
    int total_questions = len(lines)
    println("✓ Parsed " + total_questions as string + " questions")
    println("")
    println("Converting to SFT format...")
    []sft_record train_records = []sft_record{}
    []sft_record val_records = []sft_record{}
    int train_count = (total_questions * 95 / 100)
    for i in 0..total_questions-1 {
        question_data q = parse_jsonl_question(lines[i])
        sft_record rec = question_to_sft(q)
        if i < train_count {
            train_records = train_records + [rec]
        } else {
            val_records = val_records + [rec]
        }
    }
    println("✓ Converted " + total_questions as string + " questions")
    println("  Train set: " + len(train_records) as string + " examples")
    println("  Val set:   " + len(val_records) as string + " examples")
    println("")
    println("Writing train.jsonl...")
    string train_content = ""
    for i in 0..len(train_records)-1 {
        train_content = train_content + sft_to_jsonl(train_records[i]) + "\n"
    }
    string train_output = output_dir + "/train.jsonl"
    runtime_write_text_file(train_output, train_content)
    println("✓ Written to: " + train_output)
    println("Writing val.jsonl...")
    string val_content = ""
    for i in 0..len(val_records)-1 {
        val_content = val_content + sft_to_jsonl(val_records[i]) + "\n"
    }
    string val_output = output_dir + "/val.jsonl"
    runtime_write_text_file(val_output, val_content)
    println("✓ Written to: " + val_output)
    println("")
    println("╔═══════════════════════════════════════════════════════════════╗")
    println("║ Conversion Complete! ✓                                       ║")
    println("╚═══════════════════════════════════════════════════════════════╝")
    println("")
    println("Output files:")
    println("  " + train_output)
    println("  " + val_output)
    println("")
    println("Next steps:")
    println("  1. Update Makefile POSTTRAIN_DATA_FILE to:")
    println("     POSTTRAIN_DATA_FILE := " + train_output)
    println("  2. Run: make posttrain")
    println("")
    0
}
