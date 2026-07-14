// ============================================================================
// NeurX 数据质量评估工具 (S 语言实现)
// 用于高效评估训练数据的质量
// ============================================================================

package data_quality

import (
    "std/io"
    "std/json"
    "std/strings"
    "std/math"
)

// QualityMetrics 质量指标结构
struct QualityMetrics {
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

// QualityAssessor 质量评估器
struct QualityAssessor {
    sample_size: i64
    metrics: QualityMetrics
    seen_hashes: set<string>
}

// NewQualityAssessor 创建新的质量评估器
func NewQualityAssessor(sample_size: i64) QualityAssessor {
    return QualityAssessor{
        sample_size: sample_size,
        metrics: QualityMetrics{
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

// calculateQualityScore 计算单个文档的质量评分
func (qa: *QualityAssessor) calculateQualityScore(text: string) f64 {
    if len(text) == 0 {
        return 0.0
    }
    
    score := 0.0
    
    // 1. 长度评分 (0.2)
    doc_len := f64(len(text))
    if doc_len >= 100.0 && doc_len <= 100000.0 {
        score += 0.2
    } else if doc_len > 100.0 && doc_len < 100000.0 {
        score += 0.2 * math.Min(1.0, doc_len / 10000.0)
    }
    
    // 2. 空格比例 (0.2)
    space_count := f64(strings.Count(text, " "))
    space_ratio := space_count / doc_len
    if space_ratio >= 0.15 && space_ratio <= 0.35 {
        score += 0.2
    } else if space_ratio > 0.0 {
        score += 0.2 * math.Min(1.0, space_ratio * 2.0)
    }
    
    // 3. 多样性 (0.2)
    unique_chars := countUniqueChars(text)
    diversity := f64(unique_chars) / doc_len
    if diversity > 0.3 {
        score += 0.2
    } else if diversity > 0.1 {
        score += 0.2 * (diversity / 0.3)
    }
    
    // 4. URL 密度 (0.2)
    url_count := strings.Count(text, "http")
    url_density := f64(url_count) / (doc_len / 50.0)
    if url_density < 0.1 {
        score += 0.2
    } else if url_density < 0.5 {
        score += 0.2 * (1.0 - url_density / 0.5)
    }
    
    // 5. 自然语言特征 (0.2)
    if hasNaturalLanguageFeatures(text) {
        score += 0.2
    }
    
    return score
}

// countUniqueChars 计数唯一字符
func countUniqueChars(text: string) i64 {
    seen := make(set<rune>)
    for c in text {
        seen[c] = true
    }
    return i64(len(seen))
}

// hasNaturalLanguageFeatures 检查是否有自然语言特征
func hasNaturalLanguageFeatures(text: string) bool {
    // 检查是否有连续的长单词 (自然语言指标)
    words := strings.Split(text, " ")
    long_word_count := 0
    
    for word in words {
        if len(word) >= 20 {
            long_word_count += 1
        }
    }
    
    return long_word_count > 0 && long_word_count > len(words) / 100
}

// detectLanguage 检测语言 (简化版本)
func detectLanguage(text: string) string {
    // 简单的启发式语言检测
    if strings.Contains(text, "é") || strings.Contains(text, "à") {
        return "fr"
    }
    if strings.Contains(text, "ü") || strings.Contains(text, "ö") {
        return "de"
    }
    if strings.Contains(text, "ñ") || strings.Contains(text, "á") {
        return "es"
    }
    if strings.Contains(text, "中") || strings.Contains(text, "国") {
        return "zh"
    }
    if strings.Contains(text, "日") || strings.Contains(text, "本") {
        return "ja"
    }
    if strings.Contains(text, "한") || strings.Contains(text, "글") {
        return "ko"
    }
    return "en"
}

// AssessFile 评估文件
func (qa: *QualityAssessor) AssessFile(filepath: string) QualityMetrics {
    println("📊 评估文件: " + filepath)
    
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
        
        // 解析 JSON
        doc, err := json.Unmarshal(line)
        if err != nil {
            qa.metrics.invalid_docs += 1
            qa.metrics.issues = append(qa.metrics.issues, 
                "行 " + string(line_no+1) + ": JSON 解析失败")
            line_no += 1
            continue
        }
        
        // 提取文本
        text, ok := doc["text"].(string)
        if !ok || len(text) == 0 {
            qa.metrics.invalid_docs += 1
            qa.metrics.issues = append(qa.metrics.issues,
                "行 " + string(line_no+1) + ": 缺少 text 字段")
            line_no += 1
            continue
        }
        
        // 计算哈希值 (用于去重检测)
        hash := strings.Hash(text)
        if hash in qa.seen_hashes {
            qa.metrics.issues = append(qa.metrics.issues,
                "行 " + string(line_no+1) + ": 重复文档")
        } else {
            qa.seen_hashes[hash] = true
        }
        qa.metrics.dedup_hash_count = i64(len(qa.seen_hashes))
        
        // 统计字符
        qa.metrics.total_chars += i64(len(text))
        
        // 估算 tokens (4 个字符约等于 1 token)
        tokens := i64(len(text)) / 4
        qa.metrics.total_tokens += tokens
        
        // 计算质量评分
        quality := qa.calculateQualityScore(text)
        qa.metrics.quality_score += quality
        
        // 长度分布
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
        
        // 质量分布
        quality_bucket := "low"
        if quality > 0.8 {
            quality_bucket = "high"
        } else if quality > 0.6 {
            quality_bucket = "medium"
        }
        qa.metrics.quality_distribution[quality_bucket] += 1
        
        // 语言检测
        lang := detectLanguage(text)
        qa.metrics.language_detected[lang] += 1
        
        qa.metrics.valid_docs += 1
        line_no += 1
    }
    
    // 计算平均值
    if qa.metrics.valid_docs > 0 {
        qa.metrics.avg_doc_length = f64(qa.metrics.total_chars) / f64(qa.metrics.valid_docs)
        qa.metrics.quality_score = qa.metrics.quality_score / f64(qa.metrics.valid_docs)
    }
    qa.metrics.avg_line_length = f64(qa.metrics.total_chars) / f64(qa.metrics.total_lines)
    
    return qa.metrics
}

// PrintReport 打印报告
func (metrics: QualityMetrics) PrintReport() {
    println("╔════════════════════════════════════════════════════════╗")
    println("║         📊 NeurX 数据质量评估报告                      ║")
    println("╚════════════════════════════════════════════════════════╝")
    println("")
    
    println("📈 基础统计:")
    println("  总行数:       " + string(metrics.total_lines))
    println("  有效文档:     " + string(metrics.valid_docs))
    println("  无效文档:     " + string(metrics.invalid_docs))
    println("  有效率:       " + formatPercent(f64(metrics.valid_docs) / f64(metrics.total_lines)))
    println("")
    
    println("💾 数据规模:")
    println("  总字符数:     " + formatSize(metrics.total_chars))
    println("  总 Tokens:    " + formatTokens(metrics.total_tokens))
    println("  平均文档长:   " + string(i64(metrics.avg_doc_length)) + " 字符")
    println("")
    
    println("✨ 质量指标:")
    println("  平均质量评分: " + formatScore(metrics.quality_score))
    println("  去重哈希数:   " + string(metrics.dedup_hash_count))
    println("  去重率:       " + formatPercent(f64(metrics.dedup_hash_count) / f64(metrics.valid_docs)))
    println("")
    
    println("📏 长度分布:")
    for key, count in metrics.length_distribution {
        percentage := f64(count) / f64(metrics.valid_docs) * 100.0
        println("  " + key + ":        " + string(count) + " (" + formatPercent(percentage/100.0) + ")")
    }
    println("")
    
    println("⭐ 质量分布:")
    for key, count in metrics.quality_distribution {
        percentage := f64(count) / f64(metrics.valid_docs) * 100.0
        println("  " + key + ":        " + string(count) + " (" + formatPercent(percentage/100.0) + ")")
    }
    println("")
    
    println("🌍 语言分布:")
    for lang, count in metrics.language_detected {
        percentage := f64(count) / f64(metrics.valid_docs) * 100.0
        println("  " + lang + ":           " + string(count) + " (" + formatPercent(percentage/100.0) + ")")
    }
    println("")
    
    if len(metrics.issues) > 0 {
        println("⚠️  问题检测:")
        issue_count := 0
        for issue in metrics.issues {
            if issue_count >= 10 {
                println("  ... 以及 " + string(len(metrics.issues) - 10) + " 个其他问题")
                break
            }
            println("  ⚠️  " + issue)
            issue_count += 1
        }
    }
    
    println("")
    println("═══════════════════════════════════════════════════════════")
}

// 辅助函数

func formatSize(size: i64) string {
    if size < 1024 {
        return string(size) + " B"
    }
    if size < 1024 * 1024 {
        return formatFloat(f64(size) / 1024.0, 1) + " KB"
    }
    if size < 1024 * 1024 * 1024 {
        return formatFloat(f64(size) / (1024.0 * 1024.0), 1) + " MB"
    }
    return formatFloat(f64(size) / (1024.0 * 1024.0 * 1024.0), 1) + " GB"
}

func formatTokens(tokens: i64) string {
    if tokens < 1000 {
        return string(tokens)
    }
    if tokens < 1000000 {
        return formatFloat(f64(tokens) / 1000.0, 1) + "K"
    }
    if tokens < 1000000000 {
        return formatFloat(f64(tokens) / 1000000.0, 1) + "M"
    }
    return formatFloat(f64(tokens) / 1000000000.0, 1) + "B"
}

func formatScore(score: f64) string {
    return formatFloat(score, 2) + " / 1.0"
}

func formatPercent(percent: f64) string {
    return formatFloat(percent * 100.0, 1) + "%"
}

func formatFloat(num: f64, decimals: i32) string {
    // 格式化浮点数 (简化版本)
    multiplier := pow(10.0, f64(decimals))
    rounded := math.Floor(num * multiplier) / multiplier
    return string(rounded)
}

func pow(base: f64, exp: f64) f64 {
    // 简单的幂函数实现
    result := 1.0
    for i := 0; i < i32(exp); i += 1 {
        result *= base
    }
    return result
}

// Main 主函数
func main() {
    if len(os.Args) < 2 {
        println("用法: quality_assessor <file> [sample_size]")
        println("示例: quality_assessor data.jsonl 1000")
        return
    }
    
    filepath := os.Args[1]
    sample_size := i64(1000)
    
    if len(os.Args) > 2 {
        sample_size = i64(string_to_int(os.Args[2]))
    }
    
    assessor := NewQualityAssessor(sample_size)
    metrics := assessor.AssessFile(filepath)
    metrics.PrintReport()
}

func string_to_int(s: string) i64 {
    // 字符串转整数 (简化版本)
    result := i64(0)
    for c in s {
        if c >= '0' && c <= '9' {
            result = result * 10 + i64(c - '0')
        }
    }
    return result
}
