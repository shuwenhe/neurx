# Reference Test Framework

**Purpose**: Validate NeurX implementation against Hugging Face reference model, layer by layer

**Design Philosophy**:
- Fixed inputs for reproducibility
- Per-layer comparison for fast debugging
- Regression detection (which layer broke?)
- Deterministic verification

---

## Structure

```
tests/reference/
├── __init__.py                 # Shared utilities (load_golden, save_golden, etc.)
├── fixtures/
│   ├── sample_text.txt        # Fixed test input
│   └── sample_tokens.json     # Pre-tokenized version
├── src/inference/extensions/tokenizer/
│   └── golden_output.json     # Golden: token IDs from HF
├── embedding/
│   └── golden_output.json     # Golden: embeddings from HF
├── rope/
│   └── golden_output.json     # Golden: RoPE encodings
├── src/inference/extensions/attention/
│   └── golden_output.json     # Golden: attention layer outputs
├── mlp/
│   └── golden_output.json     # Golden: MLP layer outputs
├── logits/
│   └── golden_output.json     # Golden: final logits
├── week1_verify.py            # Week 1 integration tests
├── week2_verify.py            # Week 2 integration tests
└── week3_verify.py            # Week 3 integration tests
```

---

## How to Use

### Step 1: Run Week 1 Verification
```bash
cd neurx
python3 tests/reference/week1_verify.py
```

**Output**:
- Generates `tests/reference/tokenizer/golden_output.json`
- Generates `tests/reference/embedding/golden_output.json`
- Verifies your tokenizer+embedding against reference

### Step 2: Implement NeurX Tokenizer + Embedding
```python

from transformers import AutoTokenizer

def tokenize_and_embed(text, model_path):
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    tokens = tokenizer.encode(text)
    embeddings = model.embed_tokens(tokens)  # Your implementation
    return tokens, embeddings
```

### Step 3: Compare Against Golden
```python

from tests.reference import load_golden, compute_l2_distance

golden = load_golden("embedding")
your_embedding = tokenize_and_embed(TEST_TEXT, model_path)[1]
error = compute_l2_distance(your_embedding, golden["sample_values"])

assert error < 0.1, f"Embedding mismatch: {error}"
```

---

## Week 1: Tokenizer + Embedding

**Input**: Fixed text (medical QA question)
**Output**:
- Token IDs (integers)
- Embeddings (4096-dim vectors)

**Golden Data**:
```json
{
  "text": "What is the treatment for chronic urinary tract infection?",
  "token_ids": [1234, 5678, ...],  // From Hugging Face tokenizer
  "embeddings_shape": [42, 4096],   // 42 tokens, 4096 hidden size
  "mean": 0.0012,
  "std": 0.8934
}
```

**Test Points**:
- [ ] Token IDs match HF tokenizer exactly
- [ ] Embedding shape is (seq_len, 4096)
- [ ] Embedding L2 distance from HF < 0.1
- [ ] Run twice, get identical embeddings

---

## Week 2: Forward Pass (24 Layers) + Logits

**Input**: Embeddings from Week 1
**Output**: Logits (52 x 152064)

**Per-Layer Golden Data**:
```json
{
  "layer_0": {
    "attention_output": [...],
    "mlp_output": [...],
    "layer_norm_output": [...]
  },

  "final_logits": [52, 152064]
}
```

**Test Points**:
- [ ] Each layer output within tolerance of HF
- [ ] No NaN/Inf values
- [ ] Logits in reasonable range (-10 to +10)
- [ ] Deterministic (run twice, get identical)

---

## Week 3: Training Loop (Loss + Backward + Update)

**Input**: Model + LoRA adapters + training data
**Output**: Updated adapters, loss history

**Golden Data** (for regression testing):
```json
{
  "initial_loss": 2.314,
  "final_loss": 2.156,  // Should decrease
  "adapter_l2_before": 0.0,
  "adapter_l2_after": 1.725,  // Should increase
  "changed_elements": 219089,
  "changed_pct": 40.5
}
```

**Test Points**:
- [ ] Loss decreases during training
- [ ] Adapter weights actually change
- [ ] > 5% of weights updated
- [ ] Model output changes on test prompt

---

## Running All Tests

```bash

python3 tests/reference/week1_verify.py
python3 tests/reference/week2_verify.py
python3 tests/reference/week3_verify.py

for week in 1 2 3; do
  python3 tests/reference/week${week}_verify.py
  if [ $? -ne 0 ]; then
    echo "Week $week failed!"
    exit 1
  fi
done
echo "All weeks passed!"
```

---

## Golden Data Regeneration

If you update the reference model or test input:

```bash
python3 tests/reference/generate_reference.py --update
```

This will:
1. Load current Hugging Face model
2. Generate embeddings/logits/attention on test input
3. Save as new golden data
4. All future comparisons use this baseline

---

## Integration with make

Add to Makefile:

```makefile
test-reference:
	@echo "Running reference tests..."
	@python3 tests/reference/week1_verify.py && \
	 python3 tests/reference/week2_verify.py && \
	 python3 tests/reference/week3_verify.py
	@echo "✓ All reference tests passed"
```

Then: `make test-reference`

---

## Design Rationale

### Why per-layer testing?
- **Speed**: Identify which layer broke in seconds
- **Isolation**: Fix layer independently
- **Regression**: Ensure refactoring didn't break prior layer

### Why golden data?
- **Reproducibility**: Same data forever
- **Offline**: Test without running HF model each time
- **Regression**: Can detect tiny numerical drift

### Why Hugging Face reference?
- **Authority**: HF is production standard
- **Maintainability**: HF updates, we stay in sync
- **Trust**: Benchmarks against proven implementation

---

## Future Extensions

### Add to CI/CD pipeline
```yaml
test:
  script:
    - python3 tests/reference/week1_verify.py
    - python3 tests/reference/week2_verify.py
    - python3 tests/reference/week3_verify.py
  only:
    - branches
```

### Add performance benchmarking
```python
import time
start = time.time()
result = forward_pass(tokens)
elapsed = time.time() - start
print(f"Forward pass: {elapsed:.3f}s")
```

### Add ablation tests
```python

result_no_lora = forward_pass(tokens, lora=False)

```

---

**Status**: Week 1 test framework ready. Implement Week 2/3 after Week 1 passes.
