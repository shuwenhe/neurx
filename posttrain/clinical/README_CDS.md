# Medical Post-training Module (neurx/posttrain/clinical)

## Overview

Clinical Decision Support (CDS) reward functions for medical LLM alignment with GRPO training.

Implements 4 key reward signals for Infoxmed2.0 post-training:

| Reward Signal | Weight | Purpose | Score Range |
|---|---|---|---|
| **Fact Consistency** | 70% | Verify medical accuracy against evidence | [-10, +10] |
| **Length Penalty** | 5% | Encourage concise clinical notes | [-10, 0] |
| **Clarification Bonus** | 5% | Reward asking clarifying questions | [0, +10] |
| **External Reward Model** | 20% | Neural holistic quality scoring | [-10, +10] |

## Architecture

```
clinical_cds_reward.s
├─ fact_consistency_reward()    ← Fact extraction + verification
├─ length_penalty_reward()      ← Token count normalization
├─ clarification_bonus_reward() ← Question underspecification detection
├─ external_reward_model()      ← Qwen3.5-9B reward head
└─ compute_cds_reward()         ← Aggregation (weighted sum)
```

## Key Functions

### 1. Fact Consistency (70% weight)

```s
func cds_fact_consistency_reward(
    string prompt,
    string response,
    string mcp_context,
    []string tool_results
) float
```

- Extracts medical facts from response (drugs, dosages, contraindications)
- Verifies against MCP (Medical Content Platform) knowledge base
- Returns score: +10 (perfect) → -10 (hallucinated)

**Example**:
```
Response: "缝叶缘膏药可缓解疼痛,禁用于肝脏病患者."
Verified facts: ["缝叶缘膏药缓解疼痛", "禁用于肝脏病患者"]
→ grounding_score = +8.0 (partially verified)
```

### 2. Length Penalty (5% weight)

```s
func cds_length_penalty_reward(
    string response,
    int approx_token_count
) float
```

- Ideal length: 300-500 tokens
- Penalty: -0.01 per 100 tokens over 600
- Promotes clinical efficiency

### 3. Clarification Bonus (5% weight)

```s
func cds_clarification_bonus_reward(
    string prompt,
    string response
) float
```

- Detects underspecified medical questions (missing age, symptoms, history)
- Rewards asking clarifying questions: "+2 per question (max +10)"
- Only active when prompt is genuinely underspecified

### 4. External Reward Model (20% weight)

```s
func cds_external_reward_model(
    string prompt,
    string response
) float
```

- Calls FastAPI server on port 8000
- Uses Qwen3.5-9B SequenceClassification head
- Requires: `serve_reward_model.py` running
- Returns normalized score [-10, +10]

### 5. Aggregated Reward

```s
func compute_cds_reward(...) cds_reward_breakdown
```

Returns weighted sum:
```
total = (fact * 0.70) + (length * 0.05) + (clarify * 0.05) + (external * 0.20)
```

## Integration with GRPO

In `posttrain/alignment/grpo/train_grpo_cli_v2.sh`:

```bash
swift rlhf --rlhf_type grpo \
    --reward_funcs \
        cds_fact_consistency_reward \
        cds_length_penalty_reward \
        cds_clarification_bonus_reward \
        cds_external_reward_model \
    --reward_weights 0.70 0.05 0.05 0.20 \
    --external_plugins clinical_cds_reward.s
```

## Hardware Requirements

- External reward model: 1×GPU for inference server
- GRPO training: 3×GPU for policy optimization
- vLLM rollout: concurrent generation at 8 samples/step

## Quality Metrics

The reward signals optimize for:

1. **Medical Accuracy** - Facts grounded in evidence
2. **Conciseness** - Clinical efficiency
3. **Clarification** - Active information-seeking
4. **Overall Quality** - Comprehensive assessment

## Related Files

- `neurx/eval/six_dimension_eval.s` - 6D evaluation framework
- `neurx/posttrain/alignment/clinical_alignment.s` - Coordinator
- `train/medical_model/Post_train/step3_GRPO/clinical_cds_reward_plugin.py` - Python reference
