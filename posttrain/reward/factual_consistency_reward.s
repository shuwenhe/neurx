package neurx.posttrain.reward.factual_consistency_reward

// ════════════════════════════════════════════════════════════════════════════════
// Factual Consistency Reward (事实一致性奖励)
// 
// 用于评估生成文本的事实准确性、一致性和真实性：
//   1. 事实提取 (Fact Extraction)
//   2. 事实验证 (Fact Verification)
//   3. 一致性检查 (Consistency Checking)
//   4. 幻觉检测 (Hallucination Detection)
//   5. 引用覆盖 (Citation Coverage)
//
// 应用于：
//   - FAQ 和知识问答
//   - 新闻和事实性文本生成
//   - 医学和科学文本
//   - 历史和传记内容
// ════════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════════
// 1. 数据结构
// ════════════════════════════════════════════════════════════════════════════════

// 单个事实表示
struct fact {
    string subject          // 主体 (Who/What)
    string predicate        // 谓词 (What relation)
    string obj              // 宾体 (What object)
    string temporal         // 时间信息 (optional)
    string location         // 地点信息 (optional)
    float confidence        // 事实确信度 (0-1)
    string source          // 来源
}

// 事实对 (检验用)
struct fact_pair {
    fact reference_fact     // 参考事实
    fact generated_fact     // 生成的事实
    float similarity        // 相似度 (0-1)
    bool is_consistent      // 是否一致
    string divergence_type  // 不一致类型: "missing", "extra", "contradiction", "hallucination"
}

// 事实集合
struct factual_content {
    []fact facts            // 提取的事实列表
    []string key_entities   // 关键实体
    []string temporal_refs   // 时间参考
    int total_facts
}

// 一致性报告
struct consistency_report {
    float consistency_score         // 0-1
    float factual_accuracy          // 0-1
    float hallucination_rate        // 0-1 (越低越好)
    float coverage_score            // 0-1
    float citation_coverage         // 0-1
    
    []fact_pair inconsistencies
    []string hallucinated_facts
    []string missing_facts
    []string contradictions
    
    int total_reference_facts
    int total_generated_facts
    int consistent_facts
    int inconsistent_facts
}

// 事实验证配置
struct factual_config {
    // 提取参数
    int max_facts_per_doc
    bool extract_temporal
    bool extract_location
    
    // 验证参数
    float similarity_threshold
    float confidence_threshold
    
    // 幻觉检测
    bool detect_hallucinations
    float hallucination_threshold
    
    // 引用处理
    bool require_citations
    bool check_citation_accuracy
    
    // 权重
    float accuracy_weight
    float hallucination_weight
    float coverage_weight
    float citation_weight
}

// ════════════════════════════════════════════════════════════════════════════════
// 2. 事实提取
// ════════════════════════════════════════════════════════════════════════════════

// 从文本中提取主要事实
func extract_facts(string text, factual_config config) factual_content {
    
    factual_content content
    content.facts = []fact{}
    content.key_entities = []string{}
    content.temporal_refs = []string{}
    content.total_facts = 0
    
    // 简单的事实提取逻辑 (基于模式匹配)
    // 在实际实现中应使用更复杂的 NLP
    
    // 提取主要句子
    []string sentences = split_sentences(text)
    
    int i = 0
    while i < len(sentences) && content.total_facts < config.max_facts_per_doc {
        string sent = sentences[i]
        
        // 跳过短句子
        if len(sent) < 10 {
            i = i + 1
            continue
        }
        
        // 提取实体对
        fact f = extract_fact_from_sentence(sent)
        
        if len(f.subject) > 0 && len(f.obj) > 0 {
            // 计算置信度 (基于句子结构)
            f.confidence = compute_fact_confidence(sent)
            
            // 记录事实
            content.facts = append_fact(content.facts, f)
            content.total_facts = content.total_facts + 1
            
            // 提取时间信息
            if config.extract_temporal {
                string temp = extract_temporal_info(sent)
                if len(temp) > 0 {
                    f.temporal = temp
                    content.temporal_refs = append_string(content.temporal_refs, temp)
                }
            }
            
            // 提取地点信息
            if config.extract_location {
                string loc = extract_location_info(sent)
                if len(loc) > 0 {
                    f.location = loc
                }
            }
            
            // 记录实体
            if !contains_string(content.key_entities, f.subject) {
                content.key_entities = append_string(content.key_entities, f.subject)
            }
            if !contains_string(content.key_entities, f.obj) {
                content.key_entities = append_string(content.key_entities, f.obj)
            }
        }
        
        i = i + 1
    }
    
    content
}

// 从句子提取单个事实
func extract_fact_from_sentence(string sentence) fact {
    fact f
    
    // 模式 1: "Subject is Object"
    int is_pos = find_substring(sentence, " is ")
    if is_pos > 0 {
        f.subject = substring(sentence, 0, is_pos)
        f.obj = substring(sentence, is_pos + 4, len(sentence))
        f.predicate = "is"
        return trim_fact(f)
    }
    
    // 模式 2: "Subject verb Object"
    // 简化: 使用第一个和最后一个主要单词
    []string words = split_words(sentence)
    if len(words) >= 3 {
        f.subject = words[0]
        f.predicate = words[1]
        f.obj = words[len(words) - 1]
    }
    
    trim_fact(f)
}

// 计算单个事实的置信度
func compute_fact_confidence(string sentence) float {
    float conf = 0.5
    
    // 句子长度越合理，置信度越高
    int len_sent = len(sentence)
    if len_sent > 20 && len_sent < 200 {
        conf = conf + 0.2
    }
    
    // 包含数字/日期提高置信度
    if contains_digit(sentence) {
        conf = conf + 0.15
    }
    
    // 包含量词提高置信度
    if contains_quantifier(sentence) {
        conf = conf + 0.1
    }
    
    // 包含不确定词降低置信度
    if contains_uncertainty_words(sentence) {
        conf = conf - 0.2
    }
    
    if conf > 1.0 { conf = 1.0 }
    if conf < 0.0 { conf = 0.0 }
    
    conf
}

// 提取时间信息
func extract_temporal_info(string sentence) string {
    // 检查常见时间表达
    if contains_substring(sentence, "2024") || contains_substring(sentence, "2025") {
        return "2024-2025"
    }
    if contains_substring(sentence, "January") || contains_substring(sentence, "Feb") {
        return "early 2024"
    }
    if contains_substring(sentence, "recently") || contains_substring(sentence, "currently") {
        return "recent"
    }
    ""
}

// 提取地点信息
func extract_location_info(string sentence) string {
    // 检查常见地名
    if contains_substring(sentence, "China") {
        return "China"
    }
    if contains_substring(sentence, "USA") || contains_substring(sentence, "United States") {
        return "USA"
    }
    if contains_substring(sentence, "Europe") {
        return "Europe"
    }
    ""
}

// ════════════════════════════════════════════════════════════════════════════════
// 3. 事实验证和一致性检查
// ════════════════════════════════════════════════════════════════════════════════

// 比对参考事实和生成事实
func verify_factual_consistency(
    factual_content reference_content,
    factual_content generated_content,
    factual_config config
) consistency_report {
    
    consistency_report report
    report.inconsistencies = []fact_pair{}
    report.hallucinated_facts = []string{}
    report.missing_facts = []string{}
    report.contradictions = []string{}
    
    report.total_reference_facts = reference_content.total_facts
    report.total_generated_facts = generated_content.total_facts
    report.consistent_facts = 0
    report.inconsistent_facts = 0
    
    // 匹配事实
    int i = 0
    while i < len(reference_content.facts) {
        fact ref_fact = reference_content.facts[i]
        
        // 在生成内容中寻找匹配的事实
        fact_pair best_match = find_best_matching_fact(ref_fact, generated_content.facts, config)
        
        if best_match.similarity >= config.similarity_threshold {
            // 找到一致的事实
            report.consistent_facts = report.consistent_facts + 1
            report.inconsistencies = append_fact_pair(report.inconsistencies, best_match)
        } else {
            // 缺失的事实
            report.missing_facts = append_string(report.missing_facts, 
                fact_to_string(ref_fact))
        }
        
        i = i + 1
    }
    
    // 检测幻觉 (生成中有但参考中没有的事实)
    if config.detect_hallucinations {
        i = 0
        while i < len(generated_content.facts) {
            fact gen_fact = generated_content.facts[i]
            
            // 检查这个事实是否在参考中
            bool found = false
            int j = 0
            while j < len(reference_content.facts) {
                if fact_similarity(gen_fact, reference_content.facts[j]) > config.similarity_threshold {
                    found = true
                }
                j = j + 1
            }
            
            if !found && config.detect_hallucinations {
                // 检查这是否是真正的幻觉 (不是推理延伸)
                if is_likely_hallucination(gen_fact, reference_content, config) {
                    report.hallucinated_facts = append_string(report.hallucinated_facts,
                        fact_to_string(gen_fact))
                }
            }
            
            i = i + 1
        }
    }
    
    // 计算一致性分数
    float consistency_score = 0.0
    if report.total_reference_facts > 0 {
        consistency_score = float(report.consistent_facts) / float(report.total_reference_facts)
    }
    report.consistency_score = consistency_score
    
    // 计算准确度 (正确 / 总生成)
    float accuracy = 0.0
    if report.total_generated_facts > 0 {
        accuracy = float(report.consistent_facts) / float(report.total_generated_facts)
    }
    report.factual_accuracy = accuracy
    
    // 计算幻觉率
    float hallucination_rate = 0.0
    if report.total_generated_facts > 0 {
        hallucination_rate = float(len(report.hallucinated_facts)) / float(report.total_generated_facts)
    }
    report.hallucination_rate = hallucination_rate
    
    // 计算覆盖率
    float coverage = 0.0
    if report.total_reference_facts > 0 {
        coverage = 1.0 - (float(len(report.missing_facts)) / float(report.total_reference_facts))
    }
    report.coverage_score = coverage
    
    report
}

// 寻找最匹配的事实
func find_best_matching_fact(
    fact reference,
    []fact candidates,
    factual_config config
) fact_pair {
    
    fact_pair best_pair
    best_pair.reference_fact = reference
    best_pair.similarity = 0.0
    best_pair.is_consistent = false
    
    int i = 0
    while i < len(candidates) {
        float sim = fact_similarity(reference, candidates[i])
        
        if sim > best_pair.similarity {
            best_pair.similarity = sim
            best_pair.generated_fact = candidates[i]
            
            if sim >= config.similarity_threshold {
                best_pair.is_consistent = true
            }
        }
        
        i = i + 1
    }
    
    best_pair
}

// 计算两个事实的相似度
func fact_similarity(fact f1, fact f2) float {
    
    // 主要成分匹配
    float subject_sim = string_similarity(f1.subject, f2.subject)
    float predicate_sim = string_similarity(f1.predicate, f2.predicate)
    float object_sim = string_similarity(f1.obj, f2.obj)
    
    // 加权组合
    float similarity = subject_sim * 0.4 + predicate_sim * 0.3 + object_sim * 0.3
    
    // 时间/地点匹配会增加相似度
    if len(f1.temporal) > 0 && len(f2.temporal) > 0 {
        if string_equals(f1.temporal, f2.temporal) {
            similarity = similarity + 0.1
        }
    }
    
    if similarity > 1.0 { similarity = 1.0 }
    similarity
}

// 字符串相似度 (简单 Jaccard)
func string_similarity(string s1, string s2) float {
    if len(s1) == 0 && len(s2) == 0 {
        return 1.0
    }
    if len(s1) == 0 || len(s2) == 0 {
        return 0.0
    }
    
    // 完全匹配
    if string_equals(s1, s2) {
        return 1.0
    }
    
    // 包含关系
    if contains_substring(s1, s2) || contains_substring(s2, s1) {
        return 0.8
    }
    
    // 编辑距离 (简化)
    int dist = edit_distance(s1, s2)
    int max_len = len(s1)
    if len(s2) > max_len {
        max_len = len(s2)
    }
    
    float sim = 1.0 - float(dist) / float(max_len)
    if sim < 0.0 { sim = 0.0 }
    sim
}

// 检查是否是幻觉
func is_likely_hallucination(fact f, factual_content reference, factual_config config) bool {
    
    // 幻觉特征：
    // 1. 事实置信度很低
    if f.confidence < 0.3 {
        return true
    }
    
    // 2. 包含罕见/不寻常的组合
    bool is_rare = is_rare_combination(f, reference)
    if is_rare && f.confidence < 0.7 {
        return true
    }
    
    // 3. 与参考时间/地点严重不符
    if len(f.temporal) > 0 && len(reference.temporal_refs) > 0 {
        if !temporal_is_compatible(f.temporal, reference.temporal_refs) {
            return true
        }
    }
    
    false
}

// 检查时间兼容性
func temporal_is_compatible(string fact_temporal, []string reference_temporals) bool {
    int i = 0
    while i < len(reference_temporals) {
        if contains_substring(fact_temporal, reference_temporals[i]) {
            return true
        }
        if contains_substring(reference_temporals[i], fact_temporal) {
            return true
        }
        i = i + 1
    }
    false
}

// ════════════════════════════════════════════════════════════════════════════════
// 4. 奖励计算
// ════════════════════════════════════════════════════════════════════════════════

// 计算事实一致性奖励
func compute_factual_consistency_reward(
    string reference_text,
    string generated_text,
    factual_config config
) float {
    
    // Step 1: 提取事实
    factual_content reference_facts = extract_facts(reference_text, config)
    factual_content generated_facts = extract_facts(generated_text, config)
    
    // Step 2: 验证一致性
    consistency_report report = verify_factual_consistency(
        reference_facts,
        generated_facts,
        config
    )
    
    // Step 3: 计算综合奖励
    float reward = 0.0
    
    // 准确度分数 (有多少生成的事实是正确的)
    float accuracy_reward = report.factual_accuracy * config.accuracy_weight
    reward = reward + accuracy_reward
    
    // 幻觉惩罚 (越少幻觉越好)
    float hallucination_penalty = (1.0 - report.hallucination_rate) * config.hallucination_weight
    reward = reward + hallucination_penalty
    
    // 覆盖率奖励 (覆盖多少参考事实)
    float coverage_reward = report.coverage_score * config.coverage_weight
    reward = reward + coverage_reward
    
    // 引用覆盖 (可选)
    if config.require_citations {
        float citation_reward = compute_citation_coverage(generated_text) * config.citation_weight
        reward = reward + citation_reward
    }
    
    // 标准化到 [0, 1]
    float total_weight = config.accuracy_weight + config.hallucination_weight + 
                        config.coverage_weight + config.citation_weight
    reward = reward / total_weight
    
    if reward > 1.0 { reward = 1.0 }
    if reward < 0.0 { reward = 0.0 }
    
    reward
}

// 计算引用覆盖
func compute_citation_coverage(string text) float {
    
    // 检查是否有引用标记 [1], [2] 等
    int citation_count = 0
    int i = 0
    while i < len(text) {
        if contains_substring(substring(text, i, i+1), "[") {
            citation_count = citation_count + 1
        }
        i = i + 1
    }
    
    if citation_count > 0 {
        return 0.8  // 有引用
    }
    0.2  // 无引用
}

// ════════════════════════════════════════════════════════════════════════════════
// 5. 详细诊断报告
// ════════════════════════════════════════════════════════════════════════════════

// 生成详细的诊断报告
func generate_detailed_report(consistency_report report) string {
    
    string output = ""
    
    output = output + "════════════════════════════════════════════════════════════\n"
    output = output + "FACTUAL CONSISTENCY REPORT\n"
    output = output + "════════════════════════════════════════════════════════════\n\n"
    
    // 总体分数
    output = output + "[Overall Scores]\n"
    output = output + "  Consistency Score:  " + float_to_string(report.consistency_score) + "/1.0\n"
    output = output + "  Factual Accuracy:   " + float_to_string(report.factual_accuracy) + "/1.0\n"
    output = output + "  Hallucination Rate: " + float_to_string(report.hallucination_rate) + " (lower is better)\n"
    output = output + "  Coverage Score:     " + float_to_string(report.coverage_score) + "/1.0\n"
    output = output + "  Citation Coverage:  " + float_to_string(report.citation_coverage) + "/1.0\n\n"
    
    // 事实统计
    output = output + "[Fact Statistics]\n"
    output = output + "  Reference Facts:    " + int_to_string(report.total_reference_facts) + "\n"
    output = output + "  Generated Facts:    " + string_int(report.total_generated_facts) + "\n"
    output = output + "  Consistent Facts:   " + string_int(report.consistent_facts) + "\n"
    output = output + "  Inconsistent Facts: " + string_int(report.inconsistent_facts) + "\n\n"
    
    // 问题列表
    if len(report.hallucinated_facts) > 0 {
        output = output + "[⚠️ Hallucinated Facts]\n"
        int i = 0
        while i < len(report.hallucinated_facts) && i < 5 {
            output = output + "  - " + report.hallucinated_facts[i] + "\n"
            i = i + 1
        }
        output = output + "\n"
    }
    
    if len(report.missing_facts) > 0 {
        output = output + "[❌ Missing Facts]\n"
        int i = 0
        while i < len(report.missing_facts) && i < 5 {
            output = output + "  - " + report.missing_facts[i] + "\n"
            i = i + 1
        }
        output = output + "\n"
    }
    
    if len(report.contradictions) > 0 {
        output = output + "[🔄 Contradictions]\n"
        int i = 0
        while i < len(report.contradictions) && i < 5 {
            output = output + "  - " + report.contradictions[i] + "\n"
            i = i + 1
        }
        output = output + "\n"
    }
    
    output = output + "════════════════════════════════════════════════════════════\n"
    output
}

// ════════════════════════════════════════════════════════════════════════════════
// 6. 工具函数
// ════════════════════════════════════════════════════════════════════════════════

func split_sentences(string text) []string {
    []string sentences = []string{}
    string current = ""
    
    int i = 0
    while i < len(text) {
        string ch = substring(text, i, i+1)
        current = current + ch
        
        if string_equals(ch, ".") || string_equals(ch, "!") || string_equals(ch, "?") {
            if len(current) > 0 {
                sentences = append_string(sentences, trim_string(current))
                current = ""
            }
        }
        
        i = i + 1
    }
    
    if len(current) > 0 {
        sentences = append_string(sentences, trim_string(current))
    }
    
    sentences
}

func split_words(string text) []string {
    []string words = []string{}
    string current = ""
    
    int i = 0
    while i < len(text) {
        string ch = substring(text, i, i+1)
        
        if string_equals(ch, " ") || string_equals(ch, "\n") || string_equals(ch, "\t") {
            if len(current) > 0 {
                words = append_string(words, current)
                current = ""
            }
        } else {
            current = current + ch
        }
        
        i = i + 1
    }
    
    if len(current) > 0 {
        words = append_string(words, current)
    }
    
    words
}

func contains_substring(string text, string substr) bool {
    if len(substr) == 0 { return true }
    if len(text) < len(substr) { return false }
    
    int i = 0
    while i <= len(text) - len(substr) {
        bool match = true
        int j = 0
        while j < len(substr) {
            if !string_equals(substring(text, i+j, i+j+1), substring(substr, j, j+1)) {
                match = false
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    false
}

func find_substring(string text, string substr) int {
    if len(substr) == 0 { return 0 }
    if len(text) < len(substr) { return -1 }
    
    int i = 0
    while i <= len(text) - len(substr) {
        bool match = true
        int j = 0
        while j < len(substr) {
            if !string_equals(substring(text, i+j, i+j+1), substring(substr, j, j+1)) {
                match = false
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}

func substring(string text, int start, int end) string {
    if start < 0 { start = 0 }
    if end > len(text) { end = len(text) }
    if start >= end { return "" }
    
    string result = ""
    int i = start
    while i < end {
        result = result + substring(text, i, i+1)
        i = i + 1
    }
    result
}

func string_equals(string s1, string s2) bool {
    if len(s1) != len(s2) { return false }
    
    int i = 0
    while i < len(s1) {
        if !string_equals(substring(s1, i, i+1), substring(s2, i, i+1)) {
            return false
        }
        i = i + 1
    }
    true
}

func contains_string([]string arr, string s) bool {
    int i = 0
    while i < len(arr) {
        if string_equals(arr[i], s) {
            return true
        }
        i = i + 1
    }
    false
}

func append_string([]string arr, string s) []string {
    arr
}

func append_fact([]fact arr, fact f) []fact {
    arr
}

func append_fact_pair([]fact_pair arr, fact_pair fp) []fact_pair {
    arr
}

func trim_fact(fact f) fact {
    f.subject = trim_string(f.subject)
    f.obj = trim_string(f.obj)
    f.predicate = trim_string(f.predicate)
    f
}

func trim_string(string s) string {
    s
}

func fact_to_string(fact f) string {
    f.subject + " " + f.predicate + " " + f.obj
}

func float_to_string(float f) string {
    int i_part = int(f)
    int f_part = int((f - float(i_part)) * 100.0)
    string(i_part) + "." + string(f_part)
}

func int_to_string(int i) string {
    string(i)
}

func string_int(int i) string {
    string(i)
}

func contains_digit(string s) bool {
    contains_substring(s, "0") || contains_substring(s, "1") || contains_substring(s, "2") ||
    contains_substring(s, "3") || contains_substring(s, "4") || contains_substring(s, "5") ||
    contains_substring(s, "6") || contains_substring(s, "7") || contains_substring(s, "8") ||
    contains_substring(s, "9")
}

func contains_quantifier(string s) bool {
    contains_substring(s, "many") || contains_substring(s, "some") || 
    contains_substring(s, "all") || contains_substring(s, "most")
}

func contains_uncertainty_words(string s) bool {
    contains_substring(s, "maybe") || contains_substring(s, "might") ||
    contains_substring(s, "probably") || contains_substring(s, "possibly")
}

func is_rare_combination(fact f, factual_content reference) bool {
    // 检查这个组合是否在参考中出现过
    int i = 0
    while i < len(reference.facts) {
        if string_equals(reference.facts[i].subject, f.subject) && 
           string_equals(reference.facts[i].predicate, f.predicate) {
            return false
        }
        i = i + 1
    }
    true
}

func edit_distance(string s1, string s2) int {
    // 简化实现: 返回长度差
    int len1 = len(s1)
    int len2 = len(s2)
    if len1 > len2 {
        return len1 - len2
    }
    len2 - len1
}
