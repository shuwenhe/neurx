package main
import (
    "fmt"
    "math"
    "strings"
)

struct safety_config {
    harmful_keywords        []string
    toxicity_threshold      float64
    safety_threshold        float64
    use_model_based         bool
    enable_logging          bool
}

struct safety_check_result {
    is_safe                 bool
    toxicity_score          float64
    safety_score            float64
    harmful_categories      []string
    confidence              float64
    reason                  string
}

struct safety_filter {
    config                  safety_config
    toxicity_model          policy_model
    safety_stats            safety_stats
    violations              []safety_violation
}

struct safety_violation {
    timestamp               int64
    text_snippet            string
    violation_type          string
    toxicity_score          float64
    category                string
}

struct safety_stats {
    total_checks            int64
    flagged_safe            int64
    flagged_unsafe          int64
    blocked_generation      int64
}

func (safety_filter* filter) detect_harmful_keywords(text string) []string {
    harmful := []string{}
    text_lower := strings.ToLower(text)
    for _, keyword := range filter.config.harmful_keywords {
        if strings.Contains(text_lower, strings.ToLower(keyword)) {
            harmful = append(harmful, keyword)
        }
    }
    return harmful
}

func (safety_filter* filter) calculate_toxicity_score(text string) float64 {
    score := 0.0
    if len(text) == 0 {
        return 0.0
    }
    uppercase_ratio := 0.0
    uppercase_count := 0
    for _, ch := range text {
        if ch >= 'A' && ch <= 'Z' {
            uppercase_count++
        }
    }
    if len(text) > 0 {
        uppercase_ratio = float64(uppercase_count) / float64(len(text))
    }
    if uppercase_ratio > 0.5 {
        score += uppercase_ratio * 0.2
    }
    punct_count := strings.Count(text, "!") + strings.Count(text, "")*2
    punct_score := math.Min(float64(punct_count)/float64(len(text)+1), 1.0)
    score += punct_score * 0.15
    harmful := filter.detect_harmful_keywords(text)
    keyword_score := float64(len(harmful)) / 10.0
    if keyword_score > 1.0 {
        keyword_score = 1.0
    }
    score += keyword_score * 0.3
    if len(text) < 5 || len(text) > 10000 {
        score += 0.1
    }
    if score > 1.0 {
        score = 1.0
    }
    if score < 0.0 {
        score = 0.0
    }
    return score
}

func (safety_filter* filter) model_based_safety_check(text string) (float64, []string) {
    logits := make([]float64, 10)
    for i := range logits {
        logits[i] = math.Sin(float64(i) + float64(len(text))/100.0)
    }
    max_logit := logits[0]
    for _, l := range logits {
        if l > max_logit {
            max_logit = l
        }
    }
    exp_sum := 0.0
    probs := make([]float64, len(logits))
    for i, l := range logits {
        exp_l := math.Exp(l - max_logit)
        probs[i] = exp_l
        exp_sum += exp_l
    }
    for i := range probs {
        probs[i] /= exp_sum
    }
    safety_score := probs[0]
    categories := []string{}
    category_names := []string{
        "hate_speech", "violence", "sexual",
        "harassment", "illegal", "self_harm",
        "deception", "privacy", "profanity", "other",
    }
    for i, prob := range probs {
        if prob > 0.3 && i < len(category_names) {
            category := category_names[i]
            seen := false
            for _, existing := range categories {
                if existing == category {
                    seen = true
                    break
                }
            }
            if !seen {
                categories = append(categories, category)
            }
        }
    }
    return safety_score, categories
}

func (safety_filter* filter) check_safety(text string) safety_check_result {
    filter.safety_stats.total_checks++
    result := safety_check_result{
        is_safe: true,
        harmful_categories: []string{},
    }
    harmful := filter.detect_harmful_keywords(text)
    if len(harmful) > 0 {
        result.harmful_categories = append(result.harmful_categories, harmful...)
    }
    toxicity := filter.calculate_toxicity_score(text)
    result.toxicity_score = toxicity
    safety_score := float64()
    var categories []string
    if filter.config.use_model_based {
        safety_score, categories = filter.model_based_safety_check(text)
        result.harmful_categories = append(result.harmful_categories, categories...)
    } else {
        safety_score = 1.0 - toxicity
    }
    result.safety_score = safety_score
    if toxicity > filter.config.toxicity_threshold {
        result.is_safe = false
        result.reason = fmt.Sprintf("High toxicity score: %.3f", toxicity)
    }
    if safety_score < filter.config.safety_threshold {
        result.is_safe = false
        result.reason = fmt.Sprintf("Low safety score: %.3f", safety_score)
    }
    result.confidence = math.Max(toxicity, 1.0-safety_score)
    if result.is_safe {
        filter.safety_stats.flagged_safe++
    } else {
        filter.safety_stats.flagged_unsafe++
        filter.safety_stats.blocked_generation++
    }
    if filter.config.enable_logging {
        filter.log_violation(text, result)
    }
    return result
}

func (safety_filter* filter) log_violation(text string, result safety_check_result) {
    if len(text) > 120 {
        text = text[:120] + "..."
    }
    violation := safety_violation{
        timestamp: 0,
        text_snippet: text,
        violation_type: "content_safety",
        toxicity_score: result.toxicity_score,
        category: strings.Join(result.harmful_categories, ","),
    }
    filter.violations = append(filter.violations, violation)
}

func (safety_filter* filter) filter_generation(text string) (string, bool) {
    result := filter.check_safety(text)
    if result.is_safe {
        return text, true
    } else {
        return "[CONTENT FILTERED: " + result.reason + "]", false
    }
}

func (safety_filter* filter) filter_batch(texts []string) ([]string, []bool) {
    results := make([]string, len(texts))
    flags := make([]bool, len(texts))
    for i, text := range texts {
        results[i], flags[i] = filter.filter_generation(text)
    }
    return results, flags
}

func (safety_filter* filter) set_safety_policy(policy string) {
    switch policy {
    case "strict":
        filter.config.toxicity_threshold = 0.3
        filter.config.safety_threshold = 0.8
    case "moderate":
        filter.config.toxicity_threshold = 0.5
        filter.config.safety_threshold = 0.6
    case "relaxed":
        filter.config.toxicity_threshold = 0.7
        filter.config.safety_threshold = 0.4
    default:
        filter.config.toxicity_threshold = 0.5
        filter.config.safety_threshold = 0.6
    }
}

func (safety_filter* filter) print_stats() {
    fmt.Println("\n╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Safety Filter - Statistics and Report                ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝")
    fmt.Printf("\nChecks Performed: %d\n", filter.safety_stats.total_checks)
    safe_rate := 0.0
    unsafe_rate := 0.0
    if filter.safety_stats.total_checks > 0 {
        denom := float64(filter.safety_stats.total_checks)
        safe_rate = float64(filter.safety_stats.flagged_safe) / denom * 100.0
        unsafe_rate = float64(filter.safety_stats.flagged_unsafe) / denom * 100.0
    }
    fmt.Printf("Flagged Safe: %d (%.1f%%)\n",
        filter.safety_stats.flagged_safe,
        safe_rate)
    fmt.Printf("Flagged Unsafe: %d (%.1f%%)\n",
        filter.safety_stats.flagged_unsafe,
        unsafe_rate)
    fmt.Printf("Blocked Generation: %d\n", filter.safety_stats.blocked_generation)
    if len(filter.violations) > 0 {
        fmt.Printf("\nRecent Violations: %d\n", len(filter.violations))
        for i, v := range filter.violations {
            if i < 5 {
                fmt.Printf("  %d. %s (Toxicity: %.3f, Category: %s)\n",
                    i+1, v.text_snippet, v.toxicity_score, v.category)
            }
        }
    }
}

func new_safety_filter(model policy_model) *safety_filter {
    return *safety_filter{
        config: safety_config{
            harmful_keywords: []string{
                "violence", "illegal", "abuse",
                "hate", "harm", "dangerous",
            },
            toxicity_threshold: 0.5,
            safety_threshold: 0.6,
            use_model_based: true,
            enable_logging: true,
        },
        toxicity_model: model,
        safety_stats: safety_stats{},
        violations: []safety_violation{},
    }
}

func (safety_filter* filter) demonstrate() {
    fmt.Println("╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Safety Filter System - Content Protection            ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝\n")
    test_texts := []string{
        "I love this product! Highly recommend.",
        "This is VERY BAD and DANGEROUS!!!",
        "How to help someone in need",
        "How to cause harm",
        "Tell me about Python programming",
    }
    fmt.Println("Testing Safety Checks:")
    for i, text := range test_texts {
        result := filter.check_safety(text)
        status := "✓ Safe"
        if !result.is_safe {
            status = "✗ Unsafe"
        }
        fmt.Printf("  %d. %s - %s (Toxicity: %.3f)\n",
            i+1, text, status, result.toxicity_score)
    }
    filter.print_stats()
    fmt.Println("\n[safety_filter] Ready!")
}
