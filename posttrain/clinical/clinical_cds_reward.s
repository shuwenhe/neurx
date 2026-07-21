package neurx.posttrain.clinical

// ════════════════════════════════════════════════════════════════════════════════
// Clinical Decision Support (CDS) Reward Functions for Medical LLM Alignment
//
// Four key reward signals for GRPO training with clinical objectives:
//   1. Fact Consistency (0.70 weight) - Accuracy against medical evidence
//   2. Length Penalty (0.05 weight)   - Encourages concise clinical notes
//   3. Clarification Bonus (0.05 weight) - Reward for asking clarifying questions
//   4. External Reward Model (0.20 weight) - Neural reward model feedback
//
// Architecture:
//   Medical guidance corpus (MCP) + tool evidence → Fact verification
//   Response length normalization → Conciseness scoring
//   Underspecified prompt detection → Clarification encouragement
//   Fine-tuned Qwen3.5-9B reward head → Holistic quality scoring
//
// Training Integration:
//   - Used in GRPO stage for policy gradient optimization
//   - Integrates with vLLM rollout for efficient generation
//   - DeepSpeed ZeRO-3 compatible for 3×GPU training
// ════════════════════════════════════════════════════════════════════════════════

use neurx.posttrain.reward.{reward_model, reward_train_result}

// ════════════════════════════════════════════════════════════════════════════════
// 1. Fact Consistency Reward (70% weight in GRPO)
// ════════════════════════════════════════════════════════════════════════════════

struct medical_fact {
    string entity              // Medical entity (drug, disease, symptom)
    string relation            // Relation type (contraindication, dosage, mechanism)
    string object              // Object value (dose amount, disease name)
    float confidence           // Confidence score (0-1)
    string evidence_source     // Where verified: "mcp", "guideline", "study"
}

struct fact_verification_result {
    []medical_fact extracted_facts
    []medical_fact matched_facts
    int total_verified
    int total_hallucinated
    float fact_accuracy        // (verified_count) / (extracted_count)
    float grounding_score      // -10 to +10
}

// Extract medical facts from response (simplified regex-based)
func extract_medical_facts(string response) []medical_fact {
    []medical_fact facts = []
    
    // Pattern 1: Drug dosage facts
    // "给药X mg/kg" "剂量为Y单位" "用量Z"
    []string dosage_patterns = [
        "给药.*mg",
        "剂量.*单位",
        "用量.*",
        "dose.*mg",
        "每次.*毫克"
    ]
    
    // Pattern 2: Contraindication facts
    // "禁忌症" "禁用" "Not能用于"
    []string contra_patterns = [
        "禁忌.*",
        "禁用.*",
        "Not能用于.*",
        "contraindicated",
        "avoid.*"
    ]
    
    // Pattern 3: Mechanism facts
    // "Function机制" "通过" "导致"
    []string mechanism_patterns = [
        "Function机制",
        "机制是",
        "通过.*导致",
        "mechanism.*",
        "cause.*"
    ]
    
    // Simplified: detect if any medical keywords are present
    // Full implementation would use NER or medical entity linker
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

// Verify facts against MCP evidence base (simplified)
func verify_facts_against_mcp([]medical_fact extracted, string mcp_context) fact_verification_result {
    fact_verification_result result = fact_verification_result{
        extracted_facts: extracted,
        total_verified: 0,
        total_hallucinated: 0
    }
    
    // In production: query actual MCP/knowledge base
    // Here: simplified heuristic - facts with high confidence in context are verified
    int verified = 0
    for i = 0; i < len(extracted); i = i + 1 {
        // Check if fact appears in MCP context
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
    
    // Convert to [-10, +10] scale
    // Perfect grounding: +10
    // Partial: +5 - (hallucination_ratio * 10)
    // Heavy hallucination: -10
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
    // Extract medical facts from response
    []medical_fact facts = extract_medical_facts(response)
    
    // Verify against MCP evidence
    fact_verification_result verification = verify_facts_against_mcp(facts, mcp_context)
    
    // Scale to [-10, +10] for GRPO
    return verification.grounding_score
}

// ════════════════════════════════════════════════════════════════════════════════
// 2. Length Penalty Reward (5% weight in GRPO)
// ════════════════════════════════════════════════════════════════════════════════

// Clinical guidelines favor concise, actionable notes
// Penalty: -0.01 per 100 tokens (scaled to [-10, 0] range)
func cds_length_penalty_reward(
    string response,
    int approx_token_count
) float {
    // Target length: 300-500 tokens for clinical note
    int ideal_length = 400
    
    // Token penalty: -0.01 per 100 tokens over 600
    if approx_token_count > 600 {
        int excess = approx_token_count - 600
        float penalty_per_100 = 0.01
        return 0.0 - ((excess / 100.0) * penalty_per_100 * 10.0)  // Scale to [-10, 0]
    }
    
    // Bonus for well-sized response
    if approx_token_count >= 300 && approx_token_count <= 500 {
        return 0.0  // Neutral
    }
    
    if approx_token_count < 100 {
        return -5.0  // Too short, incomplete info
    }
    
    return 0.0
}

// ════════════════════════════════════════════════════════════════════════════════
// 3. Clarification Bonus Reward (5% weight in GRPO)
// ════════════════════════════════════════════════════════════════════════════════

struct clarification_analysis {
    bool has_underspecified_prompt
    int clarification_count
    float clarification_score
}

func detect_underspecified_medical_question(string prompt) bool {
    // Patterns indicating missing critical information:
    // - No patient age/sex specified
    // - No symptom duration mentioned
    // - No previous treatment history
    // - No medication allergies mentioned
    
    []string missing_indicators = [
        "患者",              // patient
        "年龄",              // age
        "性别",              // sex/gender
        "持续",              // duration
        "symptom",              // symptom
        "过敏",              // allergy
        "既往",              // history
        "并发症"             // complication
    ]
    
    int missing_count = 0
    for i = 0; i < len(missing_indicators); i = i + 1 {
        if !contains(prompt, missing_indicators[i]) {
            missing_count = missing_count + 1
        }
    }
    
    // If >50% of key indicators are missing → underspecified
    return missing_count > 4
}

func count_clarification_questions(string response) int {
    int count = 0
    []string clarification_patterns = [
        "请问",              // asking for info
        "能否",              // can you provide
        "need知道",          // need to know
        "更多Information",          // more information
        "Could you",         // English
        "Can you provide",   // English
        "I need to know"     // English
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
    
    // Reward clarification only if prompt is genuinely underspecified
    if !analysis.has_underspecified_prompt {
        return 0.0  // No bonus if prompt is already clear
    }
    
    // Bonus: +2 per clarification question (max +10)
    float bonus = (analysis.clarification_count * 2.0)
    if bonus > 10.0 {
        bonus = 10.0
    }
    
    return bonus
}

// ════════════════════════════════════════════════════════════════════════════════
// 4. External Reward Model Integration (20% weight in GRPO)
// ════════════════════════════════════════════════════════════════════════════════

struct reward_model_output {
    float score              // -1 to +1 from sigmoid
    float confidence         // 0 to 1
    []float logits           // Raw logits from classification head
}

// Call external reward model (Qwen3.5-9B SequenceClassification)
// Assumes reward model is served on port 8000 with OpenAI-compatible API
func cds_external_reward_model(
    string prompt,
    string response
) float {
    // In production: HTTP call to reward model server
    // reward_model_output result = call_reward_model_api(prompt, response)
    // return (result.score * 10.0)  // Scale from [-1, 1] to [-10, 10]
    
    // Placeholder: return neutral score
    // Full implementation requires:
    //   - FastAPI server running serve_reward_model.py
    //   - Model checkpoint: Qwen3.5-9B + SequenceClassification head
    //   - Async HTTP with retry logic
    
    return 0.0
}

// ════════════════════════════════════════════════════════════════════════════════
// 5. Aggregate CDS Reward (used in GRPO)
// ════════════════════════════════════════════════════════════════════════════════

struct cds_reward_breakdown {
    float fact_consistency      // 70% weight
    float length_penalty        // 5% weight
    float clarification_bonus   // 5% weight
    float external_model        // 20% weight
    float total_reward          // Weighted sum
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

// ════════════════════════════════════════════════════════════════════════════════
// 6. Helper functions
// ════════════════════════════════════════════════════════════════════════════════

func contains(string text, string pattern) bool {
    // Simple substring match (in production: regex or more sophisticated matching)
    if len(text) == 0 || len(pattern) == 0 {
        return false
    }
    
    // Simplified: linear search for substring
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
    // In S: array append operation
    return arr  // simplified - real implementation handles dynamic arrays
}
