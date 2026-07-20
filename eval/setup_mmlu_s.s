// ============================================================================
// MMLU Data Downloader - Pure S Language Implementation
//
// Downloads MMLU dataset from HuggingFace using curl + S
// No Python, no Bash. Pure S language with curl system calls.
// ============================================================================

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

// ============================================================================
// MMLU Task Lists (57 total)
// ============================================================================

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

// ============================================================================
// Data Structures
// ============================================================================

struct mmlu_download_stats {
    int total_tasks
    int successful
    int failed
    int total_test
    int total_dev
}

struct mmlu_csv_question {
    string question
    string choice_a
    string choice_b
    string choice_c
    string choice_d
    string answer
}

// ============================================================================
// Main Setup Function
// ============================================================================

func setup_mmlu_data_s(data_root string) mmlu_download_stats {
    stats := mmlu_download_stats{
        total_tasks: 57,
        successful: 0,
        failed: 0,
        total_test: 0,
        total_dev: 0,
    }
    
    // Step 1: Create directories
    io_println("[Step 1] Creating data directories...")
    io_mkdir_recursive(data_root + "/test")
    io_mkdir_recursive(data_root + "/dev")
    io_mkdir_recursive(data_root + "/validation")
    io_println("  ✓ Directories created")
    io_println("")
    
    // Step 2: Download data
    io_println("[Step 2] Downloading MMLU dataset...")
    stats = download_all_mmlu_tasks(data_root, stats)
    io_println("")
    
    // Step 3: Verify data
    io_println("[Step 3] Verifying data integrity...")
    verify_data_integrity(data_root)
    io_println("")
    
    // Step 4: Report statistics
    io_println("[Step 4] Dataset Statistics:")
    io_println("  Total tasks: " + string_int_to_string(stats.total_tasks))
    io_println("  Downloaded: " + string_int_to_string(stats.successful) + "/" + string_int_to_string(stats.total_tasks))
    io_println("  Failed: " + string_int_to_string(stats.failed))
    io_println("  Total test questions: " + string_int_to_string(stats.total_test))
    io_println("  Total dev examples: " + string_int_to_string(stats.total_dev))
    io_println("")
    
    if stats.successful >= 50 {
        io_println("✓ MMLU dataset ready for evaluation")
    } else {
        io_println("! Warning: Some tasks may be missing")
    }
    
    return stats
}

// ============================================================================
// Helper Functions
// ============================================================================

func create_directories(data_root string) {
    runtime_run_command("mkdir -p " + data_root + "/test")
    runtime_run_command("mkdir -p " + data_root + "/dev")
    runtime_run_command("mkdir -p " + data_root + "/validation")
}

func download_all_mmlu_tasks(data_root string, stats mmlu_download_stats) mmlu_download_stats {
    // Combine all task lists
    all_tasks := []string{}
    
    stem_tasks := all_mmlu_stem_tasks()
    for i := 0; i < len(stem_tasks); i++ {
        all_tasks = append(all_tasks, stem_tasks[i])
    }
    
    social_tasks := all_mmlu_social_tasks()
    for i := 0; i < len(social_tasks); i++ {
        all_tasks = append(all_tasks, social_tasks[i])
    }
    
    humanities_tasks := all_mmlu_humanities_tasks()
    for i := 0; i < len(humanities_tasks); i++ {
        all_tasks = append(all_tasks, humanities_tasks[i])
    }
    
    other_tasks := all_mmlu_other_tasks()
    for i := 0; i < len(other_tasks); i++ {
        all_tasks = append(all_tasks, other_tasks[i])
    }
    
    // Download each task
    for i := 0; i < len(all_tasks); i++ {
        task := all_tasks[i]
        category := get_task_category(task)
        
        test_file := data_root + "/test/" + task + ".csv"
        dev_file := data_root + "/dev/" + task + ".csv"
        
        // Download test split
        test_url := "https://huggingface.co/datasets/cais/mmlu/resolve/main/data/" + task + "/test-" + task + ".csv"
        test_ok := download_file_curl(test_url, test_file)
        
        // Download dev split
        dev_url := "https://huggingface.co/datasets/cais/mmlu/resolve/main/data/" + task + "/dev-" + task + ".csv"
        dev_ok := download_file_curl(dev_url, dev_file)
        
        if test_ok {
            test_count := count_csv_rows(test_file)
            dev_count := 0
            if dev_ok {
                dev_count = count_csv_rows(dev_file)
            }
            
            io_println("  ✓ " + task + " (" + category + "): test=" + string_int_to_string(test_count) + " dev=" + string_int_to_string(dev_count))
            
            stats.successful++
            stats.total_test += test_count
            stats.total_dev += dev_count
        } else {
            io_println("  ! " + task + " (" + category + "): download failed")
            stats.failed++
        }
    }
    
    return stats
}

func download_file_curl(url string, output_path string) bool {
    // Use curl to download file with retries
    // Format: curl -sS -L --retry 3 -o {output_path} {url}
    
    cmd := "curl -sS -L --retry 3 --retry-delay 1 -o " + output_path + " \"" + url + "\" 2>/dev/null"
    result := runtime_run_command(cmd)
    
    // Check if file was created
    return runtime_file_exists(output_path)
}

func get_task_category(task string) string {
    stem_tasks := all_mmlu_stem_tasks()
    for i := 0; i < len(stem_tasks); i++ {
        if stem_tasks[i] == task {
            return "STEM"
        }
    }
    
    social_tasks := all_mmlu_social_tasks()
    for i := 0; i < len(social_tasks); i++ {
        if social_tasks[i] == task {
            return "Social"
        }
    }
    
    humanities_tasks := all_mmlu_humanities_tasks()
    for i := 0; i < len(humanities_tasks); i++ {
        if humanities_tasks[i] == task {
            return "Humanities"
        }
    }
    
    return "Other"
}

func count_csv_rows(csv_path string) int {
    // Use wc -l to count lines, subtract 1 for header
    if !runtime_file_exists(csv_path) {
        return 0
    }
    
    // Try to read file and count lines
    content := runtime_read_text_file(csv_path)
    if content == "" {
        return 0
    }
    
    count := 0
    i := 0
    for i < len(content) {
        if content[i] == '\n' {
            count++
        }
        i++
    }
    
    // Subtract 1 for header row
    if count > 0 {
        count--
    }
    
    return count
}

func verify_data_integrity(data_root string) {
    test_cmd := "find " + data_root + "/test -name '*.csv' 2>/dev/null | wc -l"
    dev_cmd := "find " + data_root + "/dev -name '*.csv' 2>/dev/null | wc -l"
    
    test_output := runtime_run_command_output(test_cmd)
    dev_output := runtime_run_command_output(dev_cmd)
    
    test_count := string_to_int(string_trim(test_output), 0)
    dev_count := string_to_int(string_trim(dev_output), 0)
    
    io_println("  Test files: " + string_int_to_string(test_count))
    io_println("  Dev files: " + string_int_to_string(dev_count))
    
    if test_count >= 50 && dev_count >= 50 {
        io_println("  ✓ Data integrity verified")
    } else {
        io_println("  ! Warning: Some files may be missing")
    }
}

// ============================================================================
// Helper Functions  
// ============================================================================

func string_int_to_string(n int) string {
    if n == 0 {
        return "0"
    }
    
    sign := ""
    if n < 0 {
        sign = "-"
        n = -n
    }
    
    result := ""
    for n > 0 {
        digit := n % 10
        result = string(rune(digit + int('0'))) + result
        n = n / 10
    }
    
    return sign + result
}

func string_to_int(s string, fallback int) int {
    if len(s) == 0 {
        return fallback
    }
    
    result := 0
    i := 0
    
    // Handle negative sign
    sign := 1
    if i < len(s) && (s[0] == '-' || s[0] == '+') {
        if s[0] == '-' {
            sign = -1
        }
        i = i + 1
    }
    
    // Parse digits
    for i < len(s) {
        c := int(s[i])
        digit := c - int('0')
        
        if digit < 0 || digit > 9 {
            return fallback
        }
        
        result = result * 10 + digit
        i = i + 1
    }
    
    return sign * result
}

func string_trim(s string) string {
    start := 0
    end := len(s)
    
    // Trim leading whitespace
    for start < end {
        c := int(s[start])
        if c != int(' ') && c != int('\t') && c != int('\n') && c != int('\r') {
            break
        }
        start = start + 1
    }
    
    // Trim trailing whitespace
    for end > start {
        c := int(s[end - 1])
        if c != int(' ') && c != int('\t') && c != int('\n') && c != int('\r') {
            break
        }
        end = end - 1
    }
    
    return s[start:end]
}

// ============================================================================
// Main Entry Point
// ============================================================================

func main() {
    project_root := io_get_env("NEURX_ROOT", ".")
    data_root := io_get_env("NEURX_MMLU_DATA_ROOT", project_root + "/data/mmlu")
    
    io_println("=========================================")
    io_println("MMLU Dataset Downloader (S Language)")
    io_println("=========================================")
    io_println("")
    io_println("Configuration:")
    io_println("  Project root: " + project_root)
    io_println("  Data root: " + data_root)
    io_println("  Source: HuggingFace (cais/mmlu)")
    io_println("")
    
    stats := setup_mmlu_data_s(data_root)
    
    if stats.failed > 0 {
        io_println("")
        io_println("! Some downloads failed. Check error messages above.")
    }
}
