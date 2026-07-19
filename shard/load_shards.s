// ============================================================================
// NeurX Shard Loader
//
// S implementation for shard metadata loading / summary reporting.
// It mirrors the old load_shards.sh behavior while keeping the logic in S.
// ============================================================================

package main

use std.os.{command, getenv}

func string_char(int c) string {
    string(c)
}

func trim(string s) string {
    int begin = 0
    while begin < len(s) {
        string ch = string_char(s[begin])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            begin = begin + 1
        } else {
            break
        }
    }

    int end = len(s)
    while end > begin {
        string ch = string_char(s[end - 1])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            end = end - 1
        } else {
            break
        }
    }

    string out = ""
    int i = begin
    while i < end {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func substring(string s, int start, int end) string {
    string out = ""
    int i = start
    while i < end {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if len(text) == 0 {
        return fallback
    }

    int sign = 1
    int i = 0
    if string_char(text[0]) == "-" {
        sign = -1
        i = 1
    } else if string_char(text[0]) == "+" {
        i = 1
    }

    int value = 0
    while i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }

    sign * value
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }

    bool negative = n < 0
    if negative {
        n = 0 - n
    }

    string out = ""
    while n > 0 {
        int digit = n - (n / 10) * 10
        out = string_char(digit + 48) + out
        n = n / 10
    }

    if negative {
        out = "-" + out
    }

    out
}

func shell_escape(string s) string {
    string out = "'"
    int i = 0
    while i < len(s) {
        string ch = string_char(s[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out = out + "'"
    out
}

func main() int {
    string shard_dir = getenv("SHARD_DIR", getenv("ENWIKI_SHARD_DIR", "."))
    int max_samples_per_shard = parse_int(getenv("MAX_SAMPLES_PER_SHARD", "500"), 500)
    int max_shards = parse_int(getenv("MAX_SHARDS", "10"), 10)

    println("")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("dataloadconfiguration")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("English textdirectory: " + shard_dir)
    println("English text: " + int_to_str(max_samples_per_shard))
    println("English text: " + int_to_str(max_shards))
    println("")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("loadEnglish textdata")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    let (dir_check, dir_code) = command("test -d " + shell_escape(shard_dir))
    if dir_code != 0 {
        println("Error: Shard directory not found: " + shard_dir)
        return 1
    }

    string list_cmd = "sh -c " + shell_escape("ls -1 " + shard_dir + "/training_data-*.jsonl.gz 2>/dev/null | sort | head -n " + int_to_str(max_shards))
    let (list_output, _) = command(list_cmd)
    string shard_list = trim(list_output)

    int total_samples = 0
    int shard_count = 0
    string first_sample = ""

    int start = 0
    int pos = 0
    while pos <= len(shard_list) {
        bool at_end = pos == len(shard_list)
        bool at_newline = !at_end && string_char(shard_list[pos]) == "\n"
        if !at_end && !at_newline {
            pos = pos + 1
            continue
        }

        string shard_file = trim(substring(shard_list, start, pos))
        start = pos + 1
        pos = pos + 1
        if len(shard_file) == 0 {
            continue
        }

        shard_count = shard_count + 1
        string count_cmd = "sh -c " + shell_escape("gzip -dc " + shell_escape(shard_file) + " 2>/dev/null | wc -l")
        let (count_output, _) = command(count_cmd)
        int samples_in_shard = parse_int(count_output, 0)
        if samples_in_shard > max_samples_per_shard {
            samples_in_shard = max_samples_per_shard
        }
        total_samples = total_samples + samples_in_shard

        if len(first_sample) == 0 {
            string preview_cmd = "sh -c " + shell_escape("gzip -dc " + shell_escape(shard_file) + " 2>/dev/null | head -1 | cut -c1-80")
            let (preview_output, _) = command(preview_cmd)
            first_sample = trim(preview_output)
        }

        println("  [" + int_to_str(shard_count) + "] " + shard_file)
        println("      English textload: " + int_to_str(samples_in_shard) + " English text")
    }

    println("")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("loadstatistics")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("English text: " + int_to_str(shard_count))

    if shard_count > 0 {
        println("English text: " + int_to_str(total_samples))
        println("English text: " + int_to_str(total_samples / shard_count))
    } else {
        total_samples = 0
        println("English textdataEnglish text")
    }
    println("")

    println(total_samples)
    if len(first_sample) > 0 {
        println(first_sample + "...")
    } else {
        println("...")
    }

    0
}
