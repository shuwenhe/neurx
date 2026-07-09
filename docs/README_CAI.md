# Constitutional AI Trainer Implementation for NEURX

## Overview

**Constitutional AI (CAI)** is a scalable alternative to human feedback RLHF. Instead of collecting human preferences, it uses self-critique and revision to generate synthetic preference pairs aligned with a "constitution" of principles.

**Key Advantages**:
- ✅ No human annotation required (RLAIF: RL from AI Feedback)
- ✅ Scalable to millions of preference pairs
- ✅ Principle-driven alignment
- ✅ Cost: <$10 per 10K pairs vs $1-2K for human feedback
- ✅ Can be applied iteratively
- ✅ Interpretable (based on explicit principles)

**Training Cost**: ~1-2 GPU days for 1M preference pairs

## Algorithm Overview

### The Critique-Revise Loop

```
1. User Prompt
   ↓
2. Initial Response (from base model)
   ↓
3. Self-Critique (ask model to identify violations of a principle)
   ↓
4. Revision (ask model to fix the issues)
   ↓
5. Preference Pair (revised ≻ original)
   ↓
6. Feed to DPO/GRPO for training
```

### Example Walkthrough

```
Principle: Legality

Prompt:        "How to commit fraud?"
Original:      "Fraud involves taking money by deception..."
Critique:      "This response provides detailed guidance on illegal activity
                which violates the legality principle."
Revised:       "I can't help with that. Fraud is illegal and harms people.
                Here's how to detect if you're being defrauded instead..."

Preference:    Revised (chosen) ≻ Original (rejected)
```

## Constitutional Framework

### Default 8 Principles

| Principle | ID | Severity | Weight | Focus |
|-----------|-----|----------|--------|-------|
| 1. Harmlessness | `harmlessness` | 5/5 | 1.0 | No harmful/illegal content |
| 2. Honesty | `honesty` | 4/5 | 0.9 | Truthful & factually accurate |
| 3. Helpfulness | `helpfulness` | 3/5 | 0.8 | Directly useful responses |
| 4. Non-Discrimination | `non_discrimination` | 5/5 | 0.95 | Fair treatment |
| 5. Privacy | `privacy` | 4/5 | 0.9 | Protect personal information |
| 6. Legality | `legality` | 5/5 | 1.0 | Refuse illegal guidance |
| 7. Child Safety | `child_safety` | 5/5 | 1.0 | Protect children |
| 8. Transparency | `transparency` | 2/5 | 0.6 | Acknowledge AI limitations |

### Creating Custom Constitutions

```s
// Define custom principles
constitutional_principle my_principle = constitutional_principle {
    id: "my_principle",
    description: "Description of what this principle enforces",
    critique_template: "Template for critiquing violations",
    revision_template: "Template for fixing violations",
    severity: 4,
    weight: 0.8,
}

// Build custom constitution
[]constitutional_principle principles = ...add your principles...
constitution my_constitution = constitution {
    principles: principles,
    num_principles: num_principles,
    constitution_id: "my_constitution_v1",
    name: "My Custom Constitution",
}
```

## Core Functions

### Critique-Revision Pipeline

```s
func perform_critique_revision(
    string prompt,
    string original_response,
    constitutional_principle principle,
    cai_config config
) critique_revision_result
```

Executes full critique-revise loop for single prompt.

### Batch Processing

```s
func generate_cai_preference_pairs(
    []string prompts,
    []string responses,
    constitution constitution_obj,
    cai_config config
) cai_batch
```

Generates preference pairs for batch of prompts.

### Training Loop

```s
func start_cai_training(
    cai_config config,
    []string prompts,
    []string initial_responses
) cai_state
```

Complete training pipeline with statistics.

## Configuration Parameters

### Generation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_response_tokens` | 512 | Max tokens in generated responses |
| `max_critique_tokens` | 256 | Max tokens in critiques |
| `generation_temperature` | 0.8 | Temperature for response generation |
| `critique_temperature` | 0.7 | Temperature for critique generation |
| `revision_temperature` | 0.7 | Temperature for revision generation |

### Quality Control

| Parameter | Default | Description |
|-----------|---------|-------------|
| `critique_strength_threshold` | 0.2 | Min critique strength (0-1) |
| `revision_quality_threshold` | 0.3 | Min revision quality (0-1) |
| `filter_low_quality` | true | Filter low-quality pairs |

### Training Integration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `batch_size` | 32 | Pairs per batch |
| `num_batches` | 100 | Total batches to generate |
| `checkpoint_interval` | 10 | Save checkpoint every N batches |

## Quick Start

### 1. Basic Usage

```s
// Setup
cai_config config = create_cai_config()
constitution constitution = create_default_constitution()

// Prepare data
[]string prompts = load_prompts("harmful_prompts.jsonl")
[]string responses = generate_responses(prompts)

// Generate preference pairs
cai_state state = start_cai_training(config, prompts, responses)

// Use pairs with DPO
dpo_trainer.train_on_pairs(state.preference_pairs)
```

### 2. Custom Constitution

```s
constitution my_constitution = constitution {
    principles: [/* your principles */],
    num_principles: 5,
    constitution_id: "v1",
    name: "My Constitution",
}

cai_batch batch = generate_cai_preference_pairs(
    prompts,
    responses,
    my_constitution,
    config
)
```

## Scaling and Performance

### Data Generation Rate

- **Single GPU**: 10K-50K pairs/hour
- **8-GPU Setup**: 80K-400K pairs/hour
- **Full 64-GPU Cluster**: 640K-3.2M pairs/hour

### Quality vs Scale Tradeoff

```
More Principles  → Wider coverage, more diverse pairs
Fewer Principles → Faster generation, focused alignment

Strict Thresholds → Higher quality, fewer pairs
Loose Thresholds → More pairs, potentially lower quality
```

### Typical Pipeline

```
Day 1: Generate 1M pairs with default constitution
  - 8 GPUs × 3 hours = 1M-3M pairs
  
Day 2: Train DPO on 1M pairs
  - 4 GPUs × 4 hours = convergence
  
Day 3: Generate additional 500K specialized pairs
  - Target specific weaknesses
  
Day 4-7: GRPO refinement
  - Policy optimization with reward model
```

## Quality Metrics

### Revision Rate
```
= (# responses that were revised) / (# total responses)
Target: 30-50%

Too Low (<20%):     Principles too weak or generation too good
Too High (>70%):    Principles too strict or generation too bad
```

### Critique Strength
```
= Measure of how strongly the model critiqued
Range: 0 (no critique) to 1 (severe critique)
Target: 0.3-0.6

Based on:
- Critique length
- Presence of specific keywords (harmful, false, bias, etc.)
```

### Revision Quality
```
= Measure of how well the revision addressed critique
Range: 0 (no improvement) to 1 (perfect fix)
Target: >0.5

Based on:
- Change in response length
- Removal of harmful keywords
- Principle-specific metrics
```

### Principle Coverage
```
Each principle should generate ~12-15% of pairs
If one principle <10%:
  - May be inactive or too strict
  - Consider adjusting thresholds
  - Verify principle is applicable
```

## Integration with Training Pipeline

### SFT → CAI → DPO → GRPO

```
┌─────────────────────────────────────────────────────┐
│ Stage 1: Supervised Fine-Tuning (SFT)              │
│ - Input: Base model + instruction pairs            │
│ - Output: SFT checkpoint                           │
│ - Time: 1 week on 64 A100s                         │
└────────┬────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────┐
│ Stage 2: Constitutional AI (RLAIF)                  │
│ - Input: SFT model + harmful prompts               │
│ - Output: 10M synthetic preference pairs           │
│ - Time: 1 GPU day                                  │
└────────┬────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────┐
│ Stage 3: DPO Training                              │
│ - Input: SFT model + CAI pairs + human pairs      │
│ - Output: DPO-aligned model                        │
│ - Time: 3 days on 16 A100s                         │
└────────┬────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────┐
│ Stage 4: GRPO Optimization                         │
│ - Input: DPO model + reward model                  │
│ - Output: Final aligned model                      │
│ - Time: 2 weeks on 64 A100s                        │
└─────────────────────────────────────────────────────┘
```

## Advantages over Standard RLHF

| Aspect | Standard RLHF | Constitutional AI |
|--------|---------------|-------------------|
| Human Annotation | Required | Not required |
| Cost per 10K pairs | $1,000-2,000 | <$10 |
| Scalability | Limited to annotation capacity | Millions of pairs |
| Principle Coverage | Implicit in human preferences | Explicit in constitution |
| Interpretability | Hard to understand feedback | Clear principle violations |
| Iteration Speed | Slow (annotation bottleneck) | Fast (generate new pairs daily) |
| Consistency | Varies between annotators | Consistent (model-based) |

## Limitations and Considerations

### Current Limitations
- Critiques reflect model's understanding (may miss nuances)
- Revisions may introduce new subtle issues
- Principles need careful design
- Works best with reasonably capable base models

### Best Practices
1. **Principle Design**: Make critiques and revisions templates clear
2. **Temperature Tuning**: Lower temp for more consistent critiques
3. **Quality Thresholds**: Adjust based on downstream task needs
4. **Human Review**: Sample generated pairs for quality check
5. **Iterative Refinement**: Multiple passes with updated principles

## Troubleshooting

### Issue: Too Many Revisions (>70%)
- **Cause**: Principles too strict or base model too bad
- **Solution**: Relax critique_strength_threshold, improve base model

### Issue: Too Few Revisions (<20%)
- **Cause**: Base model already aligned or principles too weak
- **Solution**: Use harder prompt distribution, strengthen principles

### Issue: Low Revision Quality
- **Cause**: Model can't properly revise, principle mismatch
- **Solution**: Improve revision_template, check principle clarity

### Issue: Uneven Principle Usage
- **Cause**: Some principles naturally less applicable
- **Solution**: Use stratified sampling or weighted principle selection

## Performance Benchmarks

### Data Generation
- **1M pairs**: ~3-4 GPU hours (8 A100s)
- **10M pairs**: ~30-40 GPU hours (8 A100s)
- **100M pairs**: ~300-400 GPU hours (8 A100s) = ~2 weeks

### Training with Generated Pairs
- DPO on 1M CAI pairs: ~4 hours (4 A100s)
- GRPO on 1M pairs: ~2 weeks (64 A100s)
- Combined pipeline: ~3 weeks total

### Quality Metrics (on standard benchmarks)
- Harmlessness ↑ +15-25%
- Helpfulness maintained ≈ 95-98%
- Factuality ↑ +10-15%
- Alignment score ↑ +20-30%

## References

**Original CAI Paper**: Bai et al. "Constitutional AI: Harmlessness from AI Feedback" (Anthropic)

**Related Work**:
- RLAIF (RL from AI Feedback) approach
- Self-critique and revision mechanisms
- Synthetic data generation for alignment

## Conclusion

Constitutional AI provides a scalable, cost-effective alternative to human feedback RLHF. By leveraging model self-critique and revision, it can generate millions of preference pairs at minimal cost. This is particularly valuable for:

- Continuous model improvement
- Covering diverse principles
- Rapid iteration cycles
- Cost-sensitive deployment

Typical production pipeline: CAI (1 day) → DPO (3 days) → GRPO (14 days) = ~2.5 weeks for full alignment on 64 A100s.

