package neurx.posttrain.reward.factual_consistency_reward

struct fact {
    string subject
    string predicate
    string obj
    string temporal
    string location
    float confidence
    string source
}

struct fact_pair {
    fact reference_fact
    fact generated_fact
    float similarity
    bool is_consistent
    string divergence_type
}

struct factual_content {
    []fact facts
    string[] key_entities
    string[] temporal_refs
    int total_facts
}

struct consistency_report {
    float consistency_score
    float factual_accuracy
    float hallucination_rate
    float coverage_score
    float citation_coverage
    []fact_pair inconsistencies
    string[] hallucinated_facts
    string[] missing_facts
    string[] contradictions
    int total_reference_facts
    int total_generated_facts
    int consistent_facts
    int inconsistent_facts
}

struct factual_config {
    int max_facts_per_doc
    bool extract_temporal
    bool extract_location
    float similarity_threshold
    float confidence_threshold
    bool detect_hallucinations
    float hallucination_threshold
    bool require_citations
    bool check_citation_accuracy
    float accuracy_weight
    float hallucination_weight
    float coverage_weight
    float citation_weight
}

func extract_facts(string text, factual_config config) factual_content {
    factual_content content
    content.facts = []fact{}
    content.key_entities = string[]{}
    content.temporal_refs = string[]{}
    content.total_facts = 0
    string[] sentences = split_sentences(text)
    int i = 0
    for i < len(sentences) && content.total_facts < config.max_facts_per_doc {
        string sent = sentences[i]
        if len(sent) < 10 {
            i = i + 1
            continue
        }
        fact f = extract_fact_from_sentence(sent)
        if len(f.subject) > 0 && len(f.obj) > 0 {
            f.confidence = compute_fact_confidence(sent)
            content.facts = append_fact(content.facts, f)
            content.total_facts = content.total_facts + 1
            if config.extract_temporal {
                string temp = extract_temporal_info(sent)
                if len(temp) > 0 {
                    f.temporal = temp
                    content.temporal_refs = append_string(content.temporal_refs, temp)
                }
            }
            if config.extract_location {
                string loc = extract_location_info(sent)
                if len(loc) > 0 {
                    f.location = loc
                }
            }
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

func extract_fact_from_sentence(string sentence) fact {
    fact f
    int is_pos = find_substring(sentence, " is ")
    if is_pos > 0 {
        f.subject = substring(sentence, 0, is_pos)
        f.obj = substring(sentence, is_pos + 4, len(sentence))
        f.predicate = "is"
        return trim_fact(f)
    }
    string[] words = split_words(sentence)
    if len(words) >= 3 {
        f.subject = words[0]
        f.predicate = words[1]
        f.obj = words[len(words) - 1]
    }
    trim_fact(f)
}

func compute_fact_confidence(string sentence) float {
    float conf = 0.5
    int len_sent = len(sentence)
    if len_sent > 20 && len_sent < 200 {
        conf = conf + 0.2
    }
    if contains_digit(sentence) {
        conf = conf + 0.15
    }
    if contains_quantifier(sentence) {
        conf = conf + 0.1
    }
    if contains_uncertainty_words(sentence) {
        conf = conf - 0.2
    }
    if conf > 1.0 { conf = 1.0 }
    if conf < 0.0 { conf = 0.0 }
    conf
}

func extract_temporal_info(string sentence) string {
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

func extract_location_info(string sentence) string {
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

func verify_factual_consistency(
    factual_content reference_content,
    factual_content generated_content,
    factual_config config
) consistency_report {
    consistency_report report
    report.inconsistencies = []fact_pair{}
    report.hallucinated_facts = string[]{}
    report.missing_facts = string[]{}
    report.contradictions = string[]{}
    report.total_reference_facts = reference_content.total_facts
    report.total_generated_facts = generated_content.total_facts
    report.consistent_facts = 0
    report.inconsistent_facts = 0
    int i = 0
    for i < len(reference_content.facts) {
        fact ref_fact = reference_content.facts[i]
        fact_pair best_match = find_best_matching_fact(ref_fact, generated_content.facts, config)
        if best_match.similarity >= config.similarity_threshold {
            report.consistent_facts = report.consistent_facts + 1
            report.inconsistencies = append_fact_pair(report.inconsistencies, best_match)
        } else {
            report.missing_facts = append_string(report.missing_facts,
                fact_to_string(ref_fact))
        }
        i = i + 1
    }
    if config.detect_hallucinations {
        i = 0
        for i < len(generated_content.facts) {
            fact gen_fact = generated_content.facts[i]
            bool found = false
            int j = 0
            for j < len(reference_content.facts) {
                if fact_similarity(gen_fact, reference_content.facts[j]) > config.similarity_threshold {
                    found = true
                }
                j = j + 1
            }
            if !found && config.detect_hallucinations {
                if is_likely_hallucination(gen_fact, reference_content, config) {
                    report.hallucinated_facts = append_string(report.hallucinated_facts,
                        fact_to_string(gen_fact))
                }
            }
            i = i + 1
        }
    }
    float consistency_score = 0.0
    if report.total_reference_facts > 0 {
        consistency_score = float(report.consistent_facts) / float(report.total_reference_facts)
    }
    report.consistency_score = consistency_score
    float accuracy = 0.0
    if report.total_generated_facts > 0 {
        accuracy = float(report.consistent_facts) / float(report.total_generated_facts)
    }
    report.factual_accuracy = accuracy
    float hallucination_rate = 0.0
    if report.total_generated_facts > 0 {
        hallucination_rate = float(len(report.hallucinated_facts)) / float(report.total_generated_facts)
    }
    report.hallucination_rate = hallucination_rate
    float coverage = 0.0
    if report.total_reference_facts > 0 {
        coverage = 1.0 - (float(len(report.missing_facts)) / float(report.total_reference_facts))
    }
    report.coverage_score = coverage
    report
}

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
    for i < len(candidates) {
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

func fact_similarity(fact f1, fact f2) float {
    float subject_sim = string_similarity(f1.subject, f2.subject)
    float predicate_sim = string_similarity(f1.predicate, f2.predicate)
    float object_sim = string_similarity(f1.obj, f2.obj)
    float similarity = subject_sim * 0.4 + predicate_sim * 0.3 + object_sim * 0.3
    if len(f1.temporal) > 0 && len(f2.temporal) > 0 {
        if string_equals(f1.temporal, f2.temporal) {
            similarity = similarity + 0.1
        }
    }
    if similarity > 1.0 { similarity = 1.0 }
    similarity
}

func string_similarity(string s1, string s2) float {
    if len(s1) == 0 && len(s2) == 0 {
        return 1.0
    }
    if len(s1) == 0 || len(s2) == 0 {
        return 0.0
    }
    if string_equals(s1, s2) {
        return 1.0
    }
    if contains_substring(s1, s2) || contains_substring(s2, s1) {
        return 0.8
    }
    int dist = edit_distance(s1, s2)
    int max_len = len(s1)
    if len(s2) > max_len {
        max_len = len(s2)
    }
    float sim = 1.0 - float(dist) / float(max_len)
    if sim < 0.0 { sim = 0.0 }
    sim
}

func is_likely_hallucination(fact f, factual_content reference, factual_config config) bool {
    if f.confidence < 0.3 {
        return true
    }
    bool is_rare = is_rare_combination(f, reference)
    if is_rare && f.confidence < 0.7 {
        return true
    }
    if len(f.temporal) > 0 && len(reference.temporal_refs) > 0 {
        if !temporal_is_compatible(f.temporal, reference.temporal_refs) {
            return true
        }
    }
    false
}

func temporal_is_compatible(string fact_temporal, string[] reference_temporals) bool {
    int i = 0
    for i < len(reference_temporals) {
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

func compute_factual_consistency_reward(
    string reference_text,
    string generated_text,
    factual_config config
) float {
    factual_content reference_facts = extract_facts(reference_text, config)
    factual_content generated_facts = extract_facts(generated_text, config)
    consistency_report report = verify_factual_consistency(
        reference_facts,
        generated_facts,
        config
    )
    float reward = 0.0
    float accuracy_reward = report.factual_accuracy * config.accuracy_weight
    reward = reward + accuracy_reward
    float hallucination_penalty = (1.0 - report.hallucination_rate) * config.hallucination_weight
    reward = reward + hallucination_penalty
    float coverage_reward = report.coverage_score * config.coverage_weight
    reward = reward + coverage_reward
    if config.require_citations {
        float citation_reward = compute_citation_coverage(generated_text) * config.citation_weight
        reward = reward + citation_reward
    }
    float total_weight = config.accuracy_weight + config.hallucination_weight +
                        config.coverage_weight + config.citation_weight
    reward = reward / total_weight
    if reward > 1.0 { reward = 1.0 }
    if reward < 0.0 { reward = 0.0 }
    reward
}

func compute_citation_coverage(string text) float {
    int citation_count = 0
    int i = 0
    for i < len(text) {
        if contains_substring(substring(text, i, i+1), "[") {
            citation_count = citation_count + 1
        }
        i = i + 1
    }
    if citation_count > 0 {
        return 0.8
    }
    0.2
}

func generate_detailed_report(consistency_report report) string {
    string output = ""
    output = output + "════════════════════════════════════════════════════════════\n"
    output = output + "FACTUAL CONSISTENCY REPORT\n"
    output = output + "════════════════════════════════════════════════════════════\n\n"
    output = output + "[Overall Scores]\n"
    output = output + "  Consistency Score:  " + float_to_string(report.consistency_score) + "/1.0\n"
    output = output + "  Factual Accuracy:   " + float_to_string(report.factual_accuracy) + "/1.0\n"
    output = output + "  Hallucination Rate: " + float_to_string(report.hallucination_rate) + " (lower is better)\n"
    output = output + "  Coverage Score:     " + float_to_string(report.coverage_score) + "/1.0\n"
    output = output + "  Citation Coverage:  " + float_to_string(report.citation_coverage) + "/1.0\n\n"
    output = output + "[Fact Statistics]\n"
    output = output + "  Reference Facts:    " + int_to_string(report.total_reference_facts) + "\n"
    output = output + "  Generated Facts:    " + string_int(report.total_generated_facts) + "\n"
    output = output + "  Consistent Facts:   " + string_int(report.consistent_facts) + "\n"
    output = output + "  Inconsistent Facts: " + string_int(report.inconsistent_facts) + "\n\n"
    if len(report.hallucinated_facts) > 0 {
        output = output + "[⚠️ Hallucinated Facts]\n"
        int i = 0
        for i < len(report.hallucinated_facts) && i < 5 {
            output = output + "  - " + report.hallucinated_facts[i] + "\n"
            i = i + 1
        }
        output = output + "\n"
    }
    if len(report.missing_facts) > 0 {
        output = output + "[❌ Missing Facts]\n"
        int i = 0
        for i < len(report.missing_facts) && i < 5 {
            output = output + "  - " + report.missing_facts[i] + "\n"
            i = i + 1
        }
        output = output + "\n"
    }
    if len(report.contradictions) > 0 {
        output = output + "[🔄 Contradictions]\n"
        int i = 0
        for i < len(report.contradictions) && i < 5 {
            output = output + "  - " + report.contradictions[i] + "\n"
            i = i + 1
        }
        output = output + "\n"
    }
    output = output + "════════════════════════════════════════════════════════════\n"
    output
}

func split_sentences(string text) string[] {
    string[] sentences = string[]{}
    string current = ""
    int i = 0
    for i < len(text) {
        string ch = substring(text, i, i+1)
        current = current + ch
        if string_equals(ch, ".") || string_equals(ch, "!") || string_equals(ch, "") {
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

func split_words(string text) string[] {
    string[] words = string[]{}
    string current = ""
    int i = 0
    for i < len(text) {
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
    for i <= len(text) - len(substr) {
        bool match = true
        int j = 0
        for j < len(substr) {
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
    for i <= len(text) - len(substr) {
        bool match = true
        int j = 0
        for j < len(substr) {
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
    for i < end {
        result = result + substring(text, i, i+1)
        i = i + 1
    }
    result
}

func string_equals(string s1, string s2) bool {
    if len(s1) != len(s2) { return false }
    int i = 0
    for i < len(s1) {
        if !string_equals(substring(s1, i, i+1), substring(s2, i, i+1)) {
            return false
        }
        i = i + 1
    }
    true
}

func contains_string(string[] arr, string s) bool {
    int i = 0
    for i < len(arr) {
        if string_equals(arr[i], s) {
            return true
        }
        i = i + 1
    }
    false
}

func append_string(string[] arr, string s) string[] {
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
    int i = 0
    for i < len(reference.facts) {
        if string_equals(reference.facts[i].subject, f.subject) &&
           string_equals(reference.facts[i].predicate, f.predicate) {
            return false
        }
        i = i + 1
    }
    true
}

func edit_distance(string s1, string s2) int {
    int len1 = len(s1)
    int len2 = len(s2)
    if len1 > len2 {
        return len1 - len2
    }
    len2 - len1
}
