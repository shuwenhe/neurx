package data_quality
import (
    "std/io"
    "std/json"
    "std/strings"
    "std/math"
)
struct quality_metrics {
    total_lines: i64
    valid_docs: i64
    invalid_docs: i64
    total_chars: i64
    total_tokens: i64
    avg_doc_length: f64
    avg_line_length: f64
    quality_score: f64
    dedup_hash_count: i64
    language_detected: map<string, i64>
    length_distribution: map<string, i64>
    quality_distribution: map<string, i64>
    issues: []string
}
struct quality_assessor {
    sample_size: i64
    metrics: quality_metrics
    seen_hashes: set<string>
}
func new_quality_assessor(sample_size: i64) quality_assessor {
    return quality_assessor{
        sample_size: sample_size,
        metrics: quality_metrics{
            total_lines: 0,
            valid_docs: 0,
            invalid_docs: 0,
            total_chars: 0,
            total_tokens: 0,
            language_detected: make(map<string, i64>),
            length_distribution: make(map<string, i64>),
            quality_distribution: make(map<string, i64>),
            issues: []string{},
        },
        seen_hashes: make(set<string>),
    }
}
func (qa: *quality_assessor) calculate_quality_score(text: string) f64 {
    if len(text) == 0 {
        return 0.0
    }
    score := 0.0
    doc_len := f64(len(text))
    if doc_len >= 100.0 && doc_len <= 100000.0 {
        score += 0.2
    } else if doc_len > 100.0 && doc_len < 100000.0 {
        score += 0.2 * math.Min(1.0, doc_len / 10000.0)
    }
    space_count := f64(strings.Count(text, " "))
    space_ratio := space_count / doc_len
    if space_ratio >= 0.15 && space_ratio <= 0.35 {
        score += 0.2
    } else if space_ratio > 0.0 {
        score += 0.2 * math.Min(1.0, space_ratio * 2.0)
    }
    unique_chars := count_unique_chars(text)
    diversity := f64(unique_chars) / doc_len
    if diversity > 0.3 {
        score += 0.2
    } else if diversity > 0.1 {
        score += 0.2 * (diversity / 0.3)
    }
    url_count := strings.Count(text, "http")
    url_density := f64(url_count) / (doc_len / 50.0)
    if url_density < 0.1 {
        score += 0.2
    } else if url_density < 0.5 {
        score += 0.2 * (1.0 - url_density / 0.5)
    }
    if has_natural_language_features(text) {
        score += 0.2
    }
    return score
}
func count_unique_chars(text: string) i64 {
    seen := make(set<rune>)
    for c in text {
        seen[c] = true
    }
    return i64(len(seen))
}
func has_natural_language_features(text: string) bool {
    words := strings.Split(text, " ")
    long_word_count := 0
    for word in words {
        if len(word) >= 20 {
            long_word_count += 1
        }
    }
    return long_word_count > 0 && long_word_count > len(words) / 100
}
func detect_language(text: string) string {
    if strings.Contains(text, "é") || strings.Contains(text, "à") {
        return "fr"
    }
    if strings.Contains(text, "ü") || strings.Contains(text, "ö") {
        return "de"
    }
    if strings.Contains(text, "ñ") || strings.Contains(text, "á") {
        return "es"
    }
    if strings.Contains(text, "English text") || strings.Contains(text, "English text") {
        return "zh"
    }
    if strings.Contains(text, "English text") || strings.Contains(text, "English text") {
        return "ja"
    }
    if strings.Contains(text, "한") || strings.Contains(text, "글") {
        return "ko"
    }
    return "en"
}
func (qa: *quality_assessor) assess_file(filepath: string) quality_metrics {
    println("📊 evaluationfile: " + filepath)
    file := io.Open(filepath, "r")
    defer file.Close()
    reader := io.NewBufferedReader(file)
    line_no := 0
    for {
        line := reader.ReadLine()
        if line == "" {
            break
        }
        if line_no >= qa.sample_size {
            break
        }
        qa.metrics.total_lines += 1
        doc, err := json.Unmarshal(line)
        if err != nil {
            qa.metrics.invalid_docs += 1
            qa.metrics.issues = append(qa.metrics.issues,
                "English text " + string(line_no+1) + ": JSON English textfailure")
            line_no += 1
            continue
        }
        text, ok := doc["text"].(string)
        if !ok || len(text) == 0 {
            qa.metrics.invalid_docs += 1
            qa.metrics.issues = append(qa.metrics.issues,
                "English text " + string(line_no+1) + ": English text text English text")
            line_no += 1
            continue
        }
        hash := strings.Hash(text)
        if hash in qa.seen_hashes {
            qa.metrics.issues = append(qa.metrics.issues,
                "English text " + string(line_no+1) + ": English text")
        } else {
            qa.seen_hashes[hash] = true
        }
        qa.metrics.dedup_hash_count = i64(len(qa.seen_hashes))
        qa.metrics.total_chars += i64(len(text))
        tokens := i64(len(text)) / 4
        qa.metrics.total_tokens += tokens
        quality := qa.calculate_quality_score(text)
        qa.metrics.quality_score += quality
        if len(text) < 100 {
            qa.metrics.length_distribution["too_short"] += 1
        } else if len(text) > 100000 {
            qa.metrics.length_distribution["too_long"] += 1
        } else if len(text) < 1000 {
            qa.metrics.length_distribution["100-1k"] += 1
        } else if len(text) < 10000 {
            qa.metrics.length_distribution["1k-10k"] += 1
        } else {
            qa.metrics.length_distribution["10k-100k"] += 1
        }
        quality_bucket := "low"
        if quality > 0.8 {
            quality_bucket = "high"
        } else if quality > 0.6 {
            quality_bucket = "medium"
        }
        qa.metrics.quality_distribution[quality_bucket] += 1
        lang := detect_language(text)
        qa.metrics.language_detected[lang] += 1
        qa.metrics.valid_docs += 1
        line_no += 1
    }
    if qa.metrics.valid_docs > 0 {
        qa.metrics.avg_doc_length = f64(qa.metrics.total_chars) / f64(qa.metrics.valid_docs)
        qa.metrics.quality_score = qa.metrics.quality_score / f64(qa.metrics.valid_docs)
    }
    qa.metrics.avg_line_length = f64(qa.metrics.total_chars) / f64(qa.metrics.total_lines)
    return qa.metrics
}
func (metrics: quality_metrics) print_report() {
    println("╔════════════════════════════════════════════════════════╗")
    println("║         📊 NeurX dataEnglish textevaluationEnglish text                      ║")
    println("╚════════════════════════════════════════════════════════╝")
    println("")
    println("📈 English textstatistics:")
    println("  English text:       " + string(metrics.total_lines))
    println("  English text:     " + string(metrics.valid_docs))
    println("  English text:     " + string(metrics.invalid_docs))
    println("  English text:       " + format_percent(f64(metrics.valid_docs) / f64(metrics.total_lines)))
    println("")
    println("💾 dataEnglish text:")
    println("  English text:     " + format_size(metrics.total_chars))
    println("  English text Tokens:    " + format_tokens(metrics.total_tokens))
    println("  English text:   " + string(i64(metrics.avg_doc_length)) + " English text")
    println("")
    println("✨ English text:")
    println("  English text: " + format_score(metrics.quality_score))
    println("  deduplicationEnglish text:   " + string(metrics.dedup_hash_count))
    println("  deduplicationEnglish text:       " + format_percent(f64(metrics.dedup_hash_count) / f64(metrics.valid_docs)))
    println("")
    println("📏 English text:")
    for key, count in metrics.length_distribution {
        percentage := f64(count) / f64(metrics.valid_docs) * 100.0
        println("  " + key + ":        " + string(count) + " (" + format_percent(percentage/100.0) + ")")
    }
    println("")
    println("⭐ English text:")
    for key, count in metrics.quality_distribution {
        percentage := f64(count) / f64(metrics.valid_docs) * 100.0
        println("  " + key + ":        " + string(count) + " (" + format_percent(percentage/100.0) + ")")
    }
    println("")
    println("🌍 languageEnglish text:")
    for lang, count in metrics.language_detected {
        percentage := f64(count) / f64(metrics.valid_docs) * 100.0
        println("  " + lang + ":           " + string(count) + " (" + format_percent(percentage/100.0) + ")")
    }
    println("")
    if len(metrics.issues) > 0 {
        println("⚠️  English text:")
        issue_count := 0
        for issue in metrics.issues {
            if issue_count >= 10 {
                println("  ... English text " + string(len(metrics.issues) - 10) + " English text")
                break
            }
            println("  ⚠️  " + issue)
            issue_count += 1
        }
    }
    println("")
    println("═══════════════════════════════════════════════════════════")
}
func format_size(size: i64) string {
    if size < 1024 {
        return string(size) + " B"
    }
    if size < 1024 * 1024 {
        return format_float(f64(size) / 1024.0, 1) + " KB"
    }
    if size < 1024 * 1024 * 1024 {
        return format_float(f64(size) / (1024.0 * 1024.0), 1) + " MB"
    }
    return format_float(f64(size) / (1024.0 * 1024.0 * 1024.0), 1) + " GB"
}
func format_tokens(tokens: i64) string {
    if tokens < 1000 {
        return string(tokens)
    }
    if tokens < 1000000 {
        return format_float(f64(tokens) / 1000.0, 1) + "K"
    }
    if tokens < 1000000000 {
        return format_float(f64(tokens) / 1000000.0, 1) + "M"
    }
    return format_float(f64(tokens) / 1000000000.0, 1) + "B"
}
func format_score(score: f64) string {
    return format_float(score, 2) + " / 1.0"
}
func format_percent(percent: f64) string {
    return format_float(percent * 100.0, 1) + "%"
}
func format_float(num: f64, decimals: i32) string {
    multiplier := pow(10.0, f64(decimals))
    rounded := math.Floor(num * multiplier) / multiplier
    return string(rounded)
}
func pow(base: f64, exp: f64) f64 {
    result := 1.0
    for i := 0; i < i32(exp); i += 1 {
        result *= base
    }
    return result
}
func main() {
    if len(os.Args) < 2 {
        println("English text: quality_assessor <file> [sample_size]")
        println("example: quality_assessor data.jsonl 1000")
        return
    }
    filepath := os.Args[1]
    sample_size := i64(1000)
    if len(os.Args) > 2 {
        sample_size = i64(string_to_int(os.Args[2]))
    }
    assessor := new_quality_assessor(sample_size)
    metrics := assessor.assess_file(filepath)
    metrics.print_report()
}
func string_to_int(s: string) i64 {
    result := i64(0)
    for c in s {
        if c >= '0' && c <= '9' {
            result = result * 10 + i64(c - '0')
        }
    }
    return result
}
