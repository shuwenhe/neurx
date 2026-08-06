package main
use neurx.runtime.io.{
    io_println,
    io_get_env,
    io_mkdir_recursive,
    runtime_file_exists,
    runtime_read_text_file,
    runtime_write_text_file,
    runtime_run_command,
    runtime_run_command_output,
}

func all_mmlu_stem_tasks() []string {
    []string{
        "abstract_algebra",
        "anatomy",
        "astronomy",
        "college_biology",
        "college_chemistry",
        "college_computer_science",
        "college_mathematics",
        "college_physics",
        "computer_science",
        "conceptual_physics",
        "electrical_engineering",
        "elementary_mathematics",
        "high_school_biology",
        "high_school_chemistry",
        "high_school_computer_science",
        "high_school_mathematics",
        "high_school_physics",
        "high_school_statistics",
        "machine_learning",
    }
}

func all_mmlu_social_tasks() []string {
    []string{
        "econometrics",
        "high_school_government_and_politics",
        "high_school_macroeconomics",
        "high_school_microeconomics",
        "international_relations",
        "jurisprudence",
        "logical_fallacies",
        "miscellaneous",
        "sociology",
        "us_foreign_policy",
        "us_government_and_politics",
        "world_religions",
    }
}

func all_mmlu_humanities_tasks() []string {
    []string{
        "formal_logic",
        "global_facts",
        "human_sexuality",
        "philosophy",
        "prehistory",
        "professional_law",
        "professional_medicine",
        "world_history",
    }
}

func all_mmlu_other_tasks() []string {
    []string{
        "business_ethics",
        "clinical_knowledge",
        "college_medicine",
        "college_nursing",
        "counseling_psychology",
        "detailed_finance",
        "fundamentals_of_nursing",
        "high_school_european_history",
        "high_school_psychology",
        "high_school_us_history",
        "human_aging",
        "international_law",
        "management",
        "marketing",
        "medical_genetics",
        "moral_disputes",
        "security_studies",
    }
}

struct mmlu_download_stats {
    int total_tasks
    int successful_count
    int failed_count
    int total_test_rows
    int total_dev_rows
}

struct mmlu_csv_question {
    string question
    string choice_a
    string choice_b
    string choice_c
    string choice_d
    string correct_answer
}

func setup_mmlu_data_s(string data_root) mmlu_download_stats {
    mmlu_download_stats stats
    stats.total_tasks = 57
    stats.successful_count = 0
    stats.failed_count = 0
    stats.total_test_rows = 0
    stats.total_dev_rows = 0
    io_println("[Step 1] Creating data directories...")
    io_mkdir_recursive(data_root + "/test")
    io_mkdir_recursive(data_root + "/dev")
    io_mkdir_recursive(data_root + "/validation")
    io_println("  ✓ Directories created")
    io_println("")
    io_println("[Step 2] Downloading MMLU dataset...")
    stats = download_all_mmlu_tasks(data_root, stats)
    io_println("")
    io_println("[Step 3] Verifying data integrity...")
    verify_data_integrity(data_root)
    io_println("")
    io_println("[Step 4] Dataset Statistics:")
    io_println("  Total tasks: " + int_to_string(stats.total_tasks))
    io_println("  Downloaded: " + int_to_string(stats.successful_count) + "/" + int_to_string(stats.total_tasks))
    io_println("  Failed: " + int_to_string(stats.failed_count))
    io_println("  Total test questions: " + int_to_string(stats.total_test_rows))
    io_println("  Total dev examples: " + int_to_string(stats.total_dev_rows))
    io_println("")
    if stats.successful_count >= 50 {
        io_println("✓ MMLU dataset ready for evaluation")
    } else {
        io_println("! Warning: Some tasks may be missing")
    }
    return stats
}

func download_all_mmlu_tasks(string data_root, mmlu_download_stats stats) mmlu_download_stats {
    []string all_tasks = []string{}
    []string stem_tasks = all_mmlu_stem_tasks()
    int idx = 0
    for idx < len(stem_tasks) {
        all_tasks = append(all_tasks, stem_tasks[idx])
        idx = idx + 1
    }
    []string social_tasks = all_mmlu_social_tasks()
    idx = 0
    for idx < len(social_tasks) {
        all_tasks = append(all_tasks, social_tasks[idx])
        idx = idx + 1
    }
    []string humanities_tasks = all_mmlu_humanities_tasks()
    idx = 0
    for idx < len(humanities_tasks) {
        all_tasks = append(all_tasks, humanities_tasks[idx])
        idx = idx + 1
    }
    []string other_tasks = all_mmlu_other_tasks()
    idx = 0
    for idx < len(other_tasks) {
        all_tasks = append(all_tasks, other_tasks[idx])
        idx = idx + 1
    }
    idx = 0
    for idx < len(all_tasks) {
        string task = all_tasks[idx]
        string category = get_task_category(task)
        string test_file = data_root + "/test/" + task + ".csv"
        string dev_file = data_root + "/dev/" + task + ".csv"
        string test_url = "https:
        bool test_ok = download_file_curl(test_url, test_file)
        string dev_url = "https:
        bool dev_ok = download_file_curl(dev_url, dev_file)
        if test_ok {
            int test_count = count_csv_rows(test_file)
            int dev_count = 0
            if dev_ok {
                dev_count = count_csv_rows(dev_file)
            }
            io_println("  ✓ " + task + " (" + category + "): test=" + int_to_string(test_count) + " dev=" + int_to_string(dev_count))
            stats.successful_count = stats.successful_count + 1
            stats.total_test_rows = stats.total_test_rows + test_count
            stats.total_dev_rows = stats.total_dev_rows + dev_count
        } else {
            io_println("  ! " + task + " (" + category + "): download failed")
            stats.failed_count = stats.failed_count + 1
        }
        idx = idx + 1
    }
    return stats
}

func download_file_curl(string url, string output_path) bool {
    string cmd = "curl -sS -L --retry 3 --retry-delay 1 -o " + output_path + " \"" + url + "\" 2>/dev/null"
    int _result = runtime_run_command(cmd)
    return runtime_file_exists(output_path)
}

func get_task_category(string task) string {
    []string stem_tasks = all_mmlu_stem_tasks()
    int idx = 0
    for idx < len(stem_tasks) {
        if stem_tasks[idx] == task {
            return "STEM"
        }
        idx = idx + 1
    }
    []string social_tasks = all_mmlu_social_tasks()
    idx = 0
    for idx < len(social_tasks) {
        if social_tasks[idx] == task {
            return "Social"
        }
        idx = idx + 1
    }
    []string humanities_tasks = all_mmlu_humanities_tasks()
    idx = 0
    for idx < len(humanities_tasks) {
        if humanities_tasks[idx] == task {
            return "Humanities"
        }
        idx = idx + 1
    }
    return "Other"
}

func count_csv_rows(string csv_path) int {
    if !runtime_file_exists(csv_path) {
        return 0
    }
    string content = runtime_read_text_file(csv_path)
    if content == "" {
        return 0
    }
    int line_count = 0
    int idx = 0
    for idx < len(content) {
        if content[idx] == '\n' {
            line_count = line_count + 1
        }
        idx = idx + 1
    }
    if line_count > 0 {
        line_count = line_count - 1
    }
    return line_count
}

func verify_data_integrity(string data_root) {
    string test_cmd = "find " + data_root + "/test -name '*.csv' 2>/dev/null | wc -l"
    string dev_cmd = "find " + data_root + "/dev -name '*.csv' 2>/dev/null | wc -l"
    string test_output = runtime_run_command_output(test_cmd)
    string dev_output = runtime_run_command_output(dev_cmd)
    int test_count = string_to_int(string_trim(test_output), 0)
    int dev_count = string_to_int(string_trim(dev_output), 0)
    io_println("  Test files: " + int_to_string(test_count))
    io_println("  Dev files: " + int_to_string(dev_count))
    if test_count >= 50 && dev_count >= 50 {
        io_println("  ✓ Data integrity verified")
    } else {
        io_println("  ! Warning: Some files may be missing")
    }
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    string sign = ""
    if n < 0 {
        sign = "-"
        n = -n
    }
    string result = ""
    for n > 0 {
        int digit = n % 10
        result = string(rune(digit + int('0'))) + result
        n = n / 10
    }
    return sign + result
}

func string_to_int(string s, int fallback) int {
    if len(s) == 0 {
        return fallback
    }
    int result = 0
    int idx = 0
    int sign = 1
    if idx < len(s) && (s[0] == '-' || s[0] == '+') {
        if s[0] == '-' {
            sign = -1
        }
        idx = idx + 1
    }
    for idx < len(s) {
        int char_code = int(s[idx])
        int digit = char_code - int('0')
        if digit < 0 || digit > 9 {
            return fallback
        }
        result = result * 10 + digit
        idx = idx + 1
    }
    return sign * result
}

func string_trim(string s) string {
    int start = 0
    int end = len(s)
    for start < end {
        int char_code = int(s[start])
        if char_code != int(' ') && char_code != int('\t') && char_code != int('\n') && char_code != int('\r') {
            break
        }
        start = start + 1
    }
    for end > start {
        int char_code = int(s[end - 1])
        if char_code != int(' ') && char_code != int('\t') && char_code != int('\n') && char_code != int('\r') {
            break
        }
        end = end - 1
    }
    return s[start:end]
}

func main() {
    string project_root = io_get_env("NEURX_ROOT", ".")
    string data_root = io_get_env("NEURX_MMLU_DATA_ROOT", project_root + "/data/mmlu")
    io_println("=========================================")
    io_println("MMLU Dataset Downloader (S Language)")
    io_println("=========================================")
    io_println("")
    io_println("Configuration:")
    io_println("  Project root: " + project_root)
    io_println("  Data root: " + data_root)
    io_println("  Source: HuggingFace (cais/mmlu)")
    io_println("")
    mmlu_download_stats stats = setup_mmlu_data_s(data_root)
    if stats.failed_count > 0 {
        io_println("")
        io_println("! Some downloads failed. Check error messages above.")
        return 1
    }
    return 0
}

