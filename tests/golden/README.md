# Golden Data Directory

**Purpose**: Authority comparison data for regression testing

**NOT**: Verification logic (that's in `tests/reference/`)

---

## Responsibility Separation

### `tests/reference/`
> **How** to verify

```python
def test_tokenization():
    # Tokenization verification LOGIC
    hf_tokens = tokenizer.encode(TEST_TEXT)
    assert len(hf_tokens) > 0
    # ... more verification
```

### `tests/golden/` ← You are here
> **With what** to compare

```json
{
  "token_ids": [1, 2, 3, ...],
  "token_count": 20,
  "notes": "Expected output"
}
```

---

## Golden Data Structure

```
tests/golden/
├── tokenizer.json      # Token IDs from HF AutoTokenizer
├── embedding.json      # Embeddings (shape, statistics, samples)
├── logits.json         # Final logits before softmax
├── prompts.json        # Fixed test prompts
├── metrics.json        # Expected metrics and success criteria
└── README.md           # This file
```

### `tokenizer.json`
```json
{
  "text": "Input text",
  "token_ids": [1, 2, 3, ...],
  "token_count": 20,
  "vocab_size": 152064
}
```

**Use Case**: Verify your tokenizer produces same token IDs

```python
golden = load_json("tests/golden/tokenizer.json")
your_tokens = your_tokenizer.encode(golden["text"])
assert your_tokens == golden["token_ids"]
```

---

### `embedding.json`
```json
{
  "shape": [20, 4096],
  "statistics": {
    "mean": 0.0012,
    "std": 0.8934,
    "min": -3.4521,
    "max": 3.8742
  },
  "sample_values": {
    "token_0_first_5_dims": [0.123, -0.456, ...],
    "token_0_last_5_dims": [...],
    "token_19_first_5_dims": [...],
    "token_19_last_5_dims": [...]
  }
}
```

**Use Case**: Verify embedding shape and numerical range

```python
golden = load_json("tests/golden/embedding.json")
your_embedding = your_embed_layer(tokens)

assert your_embedding.shape == tuple(golden["shape"])
assert abs(your_embedding.mean() - golden["statistics"]["mean"]) < 0.01
```

---

### `logits.json`
```json
{
  "shape": [20, 152064],
  "statistics": {
    "mean": -9.234,
    "std": 1.456
  },
  "top_k_per_token": {
    "token_0_top_5_tokens": [
      {"token_id": 1234, "logit": 8.567},
      ...
    ]
  }
}
```

**Use Case**: Verify logits shape and top-k tokens

```python
golden = load_json("tests/golden/logits.json")
your_logits = your_model(tokens)

assert your_logits.shape == tuple(golden["shape"])
# Check that top-5 tokens are reasonable
top_k_you = topk(your_logits, k=5)
top_k_hf = golden["top_k_per_token"]["token_0_top_5_tokens"]
```

---

### `prompts.json`
```json
{
  "prompts": [
    {"name": "medical_qa_1", "text": "...", "tokens_count": 20},
    {"name": "medical_qa_2", "text": "...", "tokens_count": 18}
  ],
  "default_prompt": "What is the treatment...",
  "purpose": "Fixed test inputs"
}
```

**Use Case**: Ensure all tests use same inputs

```python
golden = load_json("tests/golden/prompts.json")
prompt = golden["default_prompt"]
# Use same prompt across week1, week2, week3 tests
```

---

### `metrics.json`
```json
{
  "phase_1_complete_metrics": {
    "gradient_computation": {
      "lora_b_initial": 0.0,
      "lora_b_after_training": 0.565,
      "changed_elements_pct": 40.5,
      "verdict": "Real gradient computation verified"
    },
    "export_determinism": {...},
    "merge_quality": {...}
  },
  "phase_2a_target_metrics": {
    "week_1": {...},
    "week_2": {...},
    "week_3": {...}
  }
}
```

**Use Case**: Success criteria for each phase/week

```python
golden = load_json("tests/golden/metrics.json")

# For Phase 2A Week 1
l2_threshold = golden["phase_2a_target_metrics"]["week_1"]["l2_error_threshold"]
assert embedding_l2_error < l2_threshold
```

---

## How to Generate/Update Golden Data

### Option A: Generate from HF Reference (First Time)

```bash
python3 << 'EOF'
from transformers import AutoTokenizer, AutoModel
import json

model_path = "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_path)
model = AutoModel.from_pretrained(model_path)

prompt = "What is the treatment for chronic urinary tract infection?"

# Tokenizer golden
tokens = tokenizer.encode(prompt)
with open("tests/golden/tokenizer.json", "w") as f:
    json.dump({
        "text": prompt,
        "token_ids": tokens,
        "token_count": len(tokens),
        "vocab_size": len(tokenizer)
    }, f, indent=2)

# Embedding golden
input_ids = np.array([tokens])
outputs = model(input_ids=input_ids, output_hidden_states=True)
embeddings = outputs.hidden_states[-1].detach().cpu().numpy()[0]

with open("tests/golden/embedding.json", "w") as f:
    json.dump({
        "shape": list(embeddings.shape),
        "statistics": {
            "mean": float(embeddings.mean()),
            "std": float(embeddings.std()),
            "min": float(embeddings.min()),
            "max": float(embeddings.max())
        },
        "sample_values": {
            "token_0_first_5_dims": embeddings[0, :5].tolist()
        }
    }, f, indent=2)

print("✓ Golden data updated")
EOF
```

### Option B: Manual Update

If you update any HF reference, edit the .json files directly:

```bash
# Edit tokenizer.json if tokenizer changes
# Edit embedding.json if embedding layer changes
# Edit logits.json if final layer changes
# git add tests/golden/*.json
# git commit -m "Update golden data"
```

---

## Integration with Tests

### `tests/reference/week1_verify.py`
```python
from tests.reference import load_golden

golden = load_golden("tokenizer")  # Reads tests/golden/tokenizer.json
# Compare your implementation against golden
```

### `tests/reference/week2_verify.py`
```python
golden = load_golden("embedding")
golden = load_golden("logits")
# Per-layer comparison
```

### `tests/reference/week3_verify.py`
```python
golden = load_golden("metrics")
# Check loss convergence against targets
# Check adapter weight changes
# Verify output differs from base
```

---

## Golden Data Evolution

### Week 1 (Tokenizer + Embedding)
- Update `tokenizer.json` when you implement tokenizer
- Update `embedding.json` when you load embedding layer
- Keep `prompts.json` fixed

### Week 2 (Forward Pass)
- Add per-layer outputs to `golden/`
- Update `logits.json` with realistic ranges
- Compare each layer independently

### Week 3 (Training Loop)
- Add training trajectory to `metrics.json`
- Record loss history
- Verify adapter weight changes match expectations

---

## Best Practices

1. **Lock golden data after each week**
   - Don't change golden data mid-week (you'll mask bugs)
   - Update golden data only at phase boundaries

2. **Version golden data in git**
   ```bash
   git add tests/golden/
   git commit -m "Update golden data for Phase 2A Week 1"
   ```

3. **Include both statistics and samples**
   - Statistics: mean, std, min, max (catches distribution changes)
   - Samples: actual values from token 0 and token N (catches per-token bugs)

4. **Document generation date**
   - Each golden file has "generation_date"
   - Helps track when reference model was run

---

## Troubleshooting

### Problem: L2 error too high
```
Your embedding L2 error: 0.25 (golden threshold: 0.1)
```

**Diagnosis**:
1. Check embedding shape matches
2. Check embedding statistics (mean, std) align
3. Check sample values for individual tokens
4. Compare layer-by-layer to identify source

### Problem: Tokenizer mismatch
```
Your tokens: [1, 2, 3, 4, 5]
Golden tokens: [1, 2, 100, 4, 5]
```

**Diagnosis**:
1. Check tokenizer initialization
2. Check vocabulary size
3. Check special token handling
4. Re-run HF tokenizer to regenerate golden

---

## Future Extensions

### Add per-layer golden data
```json
{
  "layer_0": {
    "attention_output": {...},
    "mlp_output": {...},
    "layer_norm_output": {...}
  },
  // ... layers 1-23
}
```

### Add gradient golden data
```json
{
  "gradient_norms": [
    {"layer": 0, "norm": 0.234},
    {"layer": 1, "norm": 0.456},
    ...
  ]
}
```

### Add loss trajectory
```json
{
  "loss_history": [2.314, 2.276, 2.234, 2.195, ...]
}
```

---

**This directory is your "ground truth". Keep it clean, version it carefully, and regenerate it only at phase boundaries.**
