package neurx.convert_medmcqa
use std.io.println
use neurx.runtime.io.{runtime_env_get, runtime_read_text_file, runtime_write_text_file,
                       runtime_file_exists, runtime_make_dirs}

struct sft_example {
    string instruction
    string input_text
    string output_text
}

func find_pattern(string text, string pattern) int {
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

func find_char(string text, int code, int start) int {
    for i in start..len(text)-1 {
        if text[i] as int == code {
            return i
        }
    }
    -1
}

func extract_string_value(string line, string key) string {
    string search_key = "\"" + key + "\":\""
    int start = find_pattern(line, search_key)
    if start < 0 {
        return ""
    }
    start = start + len(search_key)
    int end = find_char(line, 34, start)
    if end <= start {
        return ""
    }
    string result = ""
    for i in start..end-1 {
        result = result + line[i]
    }
    result
}

func extract_int_value(string line, string key) int {
    string search_key = "\"" + key + "\":"
    int start = find_pattern(line, search_key)
    if start < 0 {
        return 0
    }
    start = start + len(search_key)
    int end = start
    while end < len(line) && line[end] != 44 && line[end] != 125 {
        end = end + 1
    }
    int result = 0
    for i in start..end-1 {
        int ch = line[i] as int
        if ch >= 48 && ch <= 57 {
            result = result * 10 + (ch - 48)
        }
    }
    result
}

func escape_json(string s) string {
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

func medmcqa_to_sft(string line) sft_example {
    string question = extract_string_value(line, "question")
    string opt_a = extract_string_value(line, "opa")
    string opt_b = extract_string_value(line, "opb")
    string opt_c = extract_string_value(line, "opc")
    string opt_d = extract_string_value(line, "opd")
    int correct = extract_int_value(line, "cop")
    string explanation = extract_string_value(line, "exp")
    string subject = extract_string_value(line, "subject_name")
    string instruction = "Answer the following medical multiple-choice question accurately."
    string input = question + "\n\nOptions:\n"
    input = input + "A) " + opt_a + "\n"
    input = input + "B) " + opt_b + "\n"
    input = input + "C) " + opt_c + "\n"
    input = input + "D) " + opt_d
    string output = ""
    []string labels = []string{"A", "B", "C", "D"}
    if correct >= 0 && correct < 4 {
        output = "Answer: " + labels[correct]
    }
    if len(explanation) > 5 {
        output = output + "\n\nExplanation: " + explanation
    }
    if len(subject) > 0 {
        output = output + "\n\nSubject: " + subject
    }
    sft_example{
        instruction: instruction,
        input_text: input,
        output_text: output
    }
}

func sft_to_json_line(sft_example ex) string {
    string line = "{"
    line = line + "\"instruction\":\""
    line = line + escape_json(ex.instruction)
    line = line + "\",\"input\":\""
    line = line + escape_json(ex.input_text)
    line = line + "\",\"output\":\""
    line = line + escape_json(ex.output_text)
    line = line + "\"}"
    line
}

func main() int {
    println("")
    println("╔════════════════════════════════════════════════════════════════╗")
    println("║ MedMCQA → SFT Converter (S Language)                          ║")
    println("║ Input: 182,822 Medical Questions                             ║")
    println("║ Output: Train/Val split (95%/5%)                             ║")
    println("╚════════════════════════════════════════════════════════════════╝")
    println("")
    string neurx_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string input_path = runtime_env_get("MEDMCQA_INPUT",
        "/home/shuwen/shuwen/train/dataset/medmcqa/train.json")
    string output_dir = runtime_env_get("MEDMCQA_OUTPUT_DIR",
        neurx_root + "/dataset/medmcqa_sft")
    println("Input:  " + input_path)
    println("Output: " + output_dir)
    println("")
    if !runtime_file_exists(input_path) {
        println("ERROR: Input file not found")
        return 1
    }
    runtime_make_dirs(output_dir)
    println("Reading data...")
    string content = runtime_read_text_file(input_path)
    if len(content) == 0 {
        println("ERROR: Could not read file")
        return 1
    }
    println("✓ Read " + len(content) + " bytes")
    println("Parsing JSONL...")
    []string lines = []string{}
    string current = ""
    for i in 0..len(content)-1 {
        if content[i] == 10 {
            if len(current) > 0 {
                lines = lines + [current]
            }
            current = ""
        } else {
            current = current + content[i]
        }
    }
    int total = len(lines)
    println("✓ Found " + total as string + " questions")
    println("Converting to SFT format...")
    string train_output = ""
    string val_output = ""
    int train_size = (total * 95) / 100
    for i in 0..total-1 {
        sft_example ex = medmcqa_to_sft(lines[i])
        string json_line = sft_to_json_line(ex) + "\n"
        if i < train_size {
            train_output = train_output + json_line
        } else {
            val_output = val_output + json_line
        }
        if (i+1) % 20000 == 0 {
            println("  " + (i+1) as string + " / " + total as string)
        }
    }
    println("✓ Converted " + total as string + " examples")
    println("")
    println("Writing files...")
    string train_file = output_dir + "/train.jsonl"
    string val_file = output_dir + "/val.jsonl"
    runtime_write_text_file(train_file, train_output)
    println("✓ " + train_file + " (" + train_size as string + " examples)")
    runtime_write_text_file(val_file, val_output)
    println("✓ " + val_file + " (" + (total - train_size) as string + " examples)")
    println("")
    println("✅ Conversion complete!")
    println("")
    println("Next: make posttrain")
    0
}
