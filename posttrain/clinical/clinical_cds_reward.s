package neurx.posttrain.clinical
use neurx.posttrain.reward.{reward_model, reward_train_result}
struct medical_fact {
    string entity
    string relation
    string object
    float confidence
    string evidence_source
}

struct fact_verification_result {
    []medical_fact extracted_facts
    []medical_fact matched_facts
    int total_verified
    int total_hallucinated
    float fact_accuracy
    float grounding_score
}

func extract_medical_facts(string response) []medical_fact {
    []medical_fact facts = []
    []string dosage_patterns = [
        "给药.*mg",
        "剂量.*单位",
        "用量.*",
        "dose.*mg",
        "每次.*毫克"
    ]
    []string contra_patterns = [
        "禁忌.*",
        "禁用.*",
        "Not能用于.*",
        "contraindicated",
        "avoid.*"
    ]
    []string mechanism_patterns = [
        "Function机制",
        "机制是",
        "through.*导致",
        "mechanism.*",
        "cause.*"
    ]
    if contains(response, "禁忌") {
        facts = append(facts, medical_fact{
            relation: "contraindication",
            confidence: 0.7,
            evidence_source: "response"
        })
    }
    if contains(response, "mg") || contains(response, "毫克") {
        facts = append(facts, medical_fact{
            relation: "dosage",
            confidence: 0.8,
            evidence_source: "response"
        })
    }
    return facts
}

func verify_facts_against_mcp([]medical_fact extracted, string mcp_context) fact_verification_result {
    fact_verification_result result = fact_verification_result{
        extracted_facts: extracted,
        total_verified: 0,
        total_hallucinated: 0
    }
    int verified = 0
    for i = 0; i < len(extracted); i = i + 1 {
        if contains(mcp_context, extracted[i].relation) {
            verified = verified + 1
            result.matched_facts = append(result.matched_facts, extracted[i])
        }
    }
    result.total_verified = verified
    result.total_hallucinated = len(extracted) - verified
    if len(extracted) > 0 {
        result.fact_accuracy = (verified * 1.0) / (len(extracted) * 1.0)
    } else {
        result.fact_accuracy = 1.0
    }
    if result.total_hallucinated == 0 {
        result.grounding_score = 10.0
    } else if result.fact_accuracy > 0.5 {
        result.grounding_score = 5.0 - (result.total_hallucinated * 2.0)
    } else {
        result.grounding_score = -10.0
    }
    return result
}

func cds_fact_consistency_reward(
    string prompt,
    string response,
    string mcp_context,
    []string tool_results
) float {
    []medical_fact facts = extract_medical_facts(response)
    fact_verification_result verification = verify_facts_against_mcp(facts, mcp_context)
    return verification.grounding_score
}

func cds_length_penalty_reward(
    string response,
    int approx_token_count
) float {
    int ideal_length = 400
    if approx_token_count > 600 {
        int excess = approx_token_count - 600
        float penalty_per_100 = 0.01
        return 0.0 - ((excess / 100.0) * penalty_per_100 * 10.0)
    }
    if approx_token_count >= 300 && approx_token_count <= 500 {
        return 0.0
    }
    if approx_token_count < 100 {
        return -5.0
    }
    return 0.0
}

struct clarification_analysis {
    bool has_underspecified_prompt
    int clarification_count
    float clarification_score
}

func detect_underspecified_medical_question(string prompt) bool {
    []string missing_indicators = [
        "患者",
        "年龄",
        "property别",
        "持续",
        "symptom",
        "过敏",
        "既往",
        "concurrency症"
    ]
    int missing_count = 0
    for i = 0; i < len(missing_indicators); i = i + 1 {
        if !contains(prompt, missing_indicators[i]) {
            missing_count = missing_count + 1
        }
    }
    return missing_count > 4
}

func count_clarification_questions(string response) int {
    int count = 0
    []string clarification_patterns = [
        "请问",
        "能否",
        "need知道",
        "更多Information",
        "Could you",
        "Can you provide",
        "I need to know"
    ]
    for i = 0; i < len(clarification_patterns); i = i + 1 {
        if contains(response, clarification_patterns[i]) {
            count = count + 1
        }
    }
    return count
}

func cds_clarification_bonus_reward(
    string prompt,
    string response
) float {
    clarification_analysis analysis = clarification_analysis{
        has_underspecified_prompt: detect_underspecified_medical_question(prompt),
        clarification_count: count_clarification_questions(response)
    }
    if !analysis.has_underspecified_prompt {
        return 0.0
    }
    float bonus = (analysis.clarification_count * 2.0)
    if bonus > 10.0 {
        bonus = 10.0
    }
    return bonus
}

struct reward_model_output {
    float score
    float confidence
    []float logits
}

func cds_external_reward_model(
    string prompt,
    string response
) float {
    return 0.0
}

struct cds_reward_breakdown {
    float fact_consistency
    float length_penalty
    float clarification_bonus
    float external_model
    float total_reward
}

func compute_cds_reward(
    string prompt,
    string response,
    string mcp_context,
    []string tool_results,
    int approx_token_count
) cds_reward_breakdown {
    float r_fact = cds_fact_consistency_reward(prompt, response, mcp_context, tool_results)
    float r_length = cds_length_penalty_reward(response, approx_token_count)
    float r_clarify = cds_clarification_bonus_reward(prompt, response)
    float r_external = cds_external_reward_model(prompt, response)
    float total = (r_fact * 0.70) + (r_length * 0.05) + (r_clarify * 0.05) + (r_external * 0.20)
    cds_reward_breakdown breakdown = cds_reward_breakdown{
        fact_consistency: r_fact,
        length_penalty: r_length,
        clarification_bonus: r_clarify,
        external_model: r_external,
        total_reward: total
    }
    return breakdown
}

func contains(string text, string pattern) bool {
    if len(text) == 0 || len(pattern) == 0 {
        return false
    }
    int text_len = len(text)
    int pattern_len = len(pattern)
    for i = 0; i <= text_len - pattern_len; i = i + 1 {
        bool match = true
        for j = 0; j < pattern_len; j = j + 1 {
            if text[i + j] != pattern[j] {
                match = false
                break
            }
        }
        if match {
            return true
        }
    }
    return false
}

func append([]medical_fact arr, medical_fact elem) []medical_fact {
    if arr == nil {
        arr = []medical_fact{}
    }
    return arr
}
