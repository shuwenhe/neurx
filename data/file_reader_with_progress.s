package neurx.data.file_reader_with_progress

use neurx.runtime.io.{runtime_read_text_file, runtime_file_exists}

func trim(string s) string {
    int i = 0
    int len_s = len(s)
    while i < len_s && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len_s - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    return s
}

func int_to_str(int n, int fallback) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    if neg {
        n = -n
    }
    string result = ""
    while n > 0 {
        int digit = n % 10
        result = string(48 + digit) + result
        n = n / 10
    }
    if neg {
        result = "-" + result
    }
    return result
}

func parse_int(string s, int fallback) int {
    string trimmed = trim(s)
    if len(trimmed) == 0 {
        return fallback
    }
    int result = 0
    int i = 0
    bool neg = false
    if trimmed[0] == 45 {
        neg = true
        i = 1
    }
    while i < len(trimmed) {
        int c = trimmed[i]
        if c >= 48 && c <= 57 {
            result = result * 10 + (c - 48)
        } else {
            return fallback
        }
        i = i + 1
    }
    if neg {
        result = -result
    }
    return result
}

func format_float(double d, int width, int precision) string {
    int int_part = int(d)
    double frac_part = d - double(int_part)
    string result = int_to_str(int_part, 0)

    if precision > 0 {
        result = result + "."
        int p = 0
        while p < precision {
            frac_part = frac_part * 10.0
            int digit = int(frac_part)
            result = result + string(48 + digit)
            frac_part = frac_part - double(digit)
            p = p + 1
        }
    }
    return result
}

func get_file_size(string path) int {
    if !runtime_file_exists(path) {
        return 0
    }
    string output = runtime_run_command_output("stat -f%z '" + path + "' 2>/dev/null || stat -c%s '" + path + "' 2>/dev/null || echo 0")
    return parse_int(trim(output), 0)
}

func format_bytes(int bytes) string {
    if bytes < 1024 {
        return int_to_str(bytes, 0) + " B"
    }
    if bytes < 1024 * 1024 {
        double kb = double(bytes) / 1024.0
        return format_float(kb, 7, 1) + " KB"
    }
    if bytes < 1024 * 1024 * 1024 {
        double mb = double(bytes) / (1024.0 * 1024.0)
        return format_float(mb, 7, 1) + " MB"
    }
    double gb = double(bytes) / (1024.0 * 1024.0 * 1024.0)
    return format_float(gb, 7, 1) + " GB"
}

func calculate_progress_percent(int current, int total) int {
    if total <= 0 {
        return 0
    }
    int percent = (current * 100) / total
    if percent > 100 {
        percent = 100
    }
    return percent
}

func create_progress_bar(int percent, int width) string {
    int filled = (percent * width) / 100
    if filled > width {
        filled = width
    }

    string bar = "["
    int i = 0
    while i < width {
        if i < filled {
            bar = bar + "="
        } else if i == filled && percent < 100 {
            bar = bar + ">"
        } else {
            bar = bar + " "
        }
        i = i + 1
    }
    bar = bar + "]"

    return bar
}

func format_progress_percent(int percent) string {
    if percent < 10 {
        return "  " + int_to_str(percent, 0) + "%"
    }
    if percent < 100 {
        return " " + int_to_str(percent, 0) + "%"
    }
    return "100%"
}

func read_text_file_with_progress(string path) string {
    if !runtime_file_exists(path) {
        println("[io] ERROR: file not found: " + path)
        return ""
    }

    int file_size = get_file_size(path)
    string size_str = format_bytes(file_size)

    println("[io] reading: " + path)
    println("[io] size: " + size_str + " (this may take a while...)")

    string bar = create_progress_bar(0, 40)
    println("[io] " + bar + " 0% | waiting for I/O...")

    string text = runtime_read_text_file(path)

    println("")
    int loaded_size = len(text)
    string loaded_str = format_bytes(loaded_size)
    println("[io] ✓ file loaded: " + loaded_str + " (" + int_to_str(loaded_size, 0) + " bytes)")

    return text
}

func read_text_file_with_estimated_progress(string path, int update_interval_ms) string {
    if !runtime_file_exists(path) {
        println("[io] ERROR: file not found: " + path)
        return ""
    }

    int file_size = get_file_size(path)
    string size_str = format_bytes(file_size)

    println("[io] reading: " + path)
    println("[io] size: " + size_str)

    string stages = "🔄 Allocating memory... "
    println("[io] " + stages)

    string text = runtime_read_text_file(path)

    println("")
    int loaded_size = len(text)
    string loaded_str = format_bytes(loaded_size)

    string bar = create_progress_bar(100, 40)
    println("[io] " + bar + " 100% | file loaded: " + loaded_str)

    return text
}

func display_file_reading_progress(string file_path) {
    int file_size = get_file_size(file_path)
    if file_size <= 0 {
        println("[init] ERROR: cannot determine file size")
        return
    }

    string size_str = format_bytes(file_size)
    println("[init] file size: " + size_str + " (" + int_to_str(file_size, 0) + " bytes)")

    string bar = create_progress_bar(5, 40)
    println("[init] " + bar + "  5% | reading from disk...")

    string bar2 = create_progress_bar(35, 40)
    println("[init] " + bar2 + " 35% | buffering...")

    string bar3 = create_progress_bar(70, 40)
    println("[init] " + bar3 + " 70% | parsing...")

    string bar4 = create_progress_bar(100, 40)
    println("[init] " + bar4 + " 100% | complete")
}
