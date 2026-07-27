# Phase 2A Implementation Plan

**Status**: Ready to Start  
**Start Date**: 2026-07-27  
**Estimated Duration**: 2-4 weeks  
**Last Updated**: 2026-07-27

---

## 🎯 Phase 2 Objective (Scope Lock)

### Single Clear Goal

> **Complete Transformer SFT Kernel**

### Definition

```
Token → Embedding → Transformer → Logits → CrossEntropy → LoRA Update → Merge → Verify
```

### What We Will DO:
- ✅ Real token-to-ID conversion (HF tokenizer)
- ✅ Real embedding layer weights
- ✅ Real 24-layer transformer forward pass
- ✅ Real softmax → CrossEntropy loss
- ✅ Real backward pass through LoRA adapters
- ✅ Deterministic verification

### What We Will NOT DO:
- ❌ New training algorithms (DPO, GRPO, etc.) — Phase 3
- ❌ Distributed training — Phase 3
- ❌ Inference optimization — Phase 3
- ❌ Additional LoRA variants (DoRA, QLoRA) — Phase 3
- ❌ Alternative optimizers (AdamW v2, etc.) — Phase 3

### Success Criteria

```
✓ python3 tests/reference/week1_verify.py → PASS
✓ python3 tests/reference/week2_verify.py → PASS
✓ python3 tests/reference/week3_verify.py → PASS
✓ make posttrain → Produces trained model
✓ Merged model output ≠ base model output
```

When all five pass, **Phase 2A is complete**.

---

## 🏗️ Architecture (Frozen Boundaries)

### What We Inherit from Phase 1 (FROZEN)
```
Base Model
    ↓
[We replace this:] ← Training Core (currently: lightweight feature trainer)
    ↓
Export Safetensors (FROZEN - always this format)
    ↓
Merge Integration (FROZEN - always this algorithm)
    ↓
Verification (FROZEN - always automated checks)
```

### Implementation Boundary
```
File: scripts/train_lora_with_embeddings.py (WILL CREATE)

Responsibilities:
  - Load real tokenizer
  - Load real embedding layer  ← NEW
  - Forward through 24 layers  ← NEW
  - Compute CrossEntropy loss  ← NEW
  - Backward through adapters  ← NEW
  - Update adapter weights     ← NEW
  - Export via existing merge pipeline (FROZEN)
```

### Layers That Touch Core Five
```
Token ID
   ↓
Embedding[token_id] = [d_model,]  ← NEW: Use HF embedding weights
   ↓
for layer in 24_layers:           ← NEW: Real transformer
  attention(hidden, pos)          ← NEW: RoPE + scaled-dot-product
  mlp(hidden)                     ← NEW: Feed-forward
   ↓
Logits[vocab_size]                ← NEW: lm_head
   ↓
Loss = CrossEntropy(logits, target) ← NEW: Real loss
   ↓
Backward through adapters          ← NEW: Gradient flow
   ↓
SGD update to adapter weights      ← NEW: SGD step
   ↓
Export (FROZEN - existing pipeline)
```

---

## 📅 Timeline (3 Weeks)

### Week 1: Tokenizer + Embedding ✅ Verify

**Goal**: Load HF tokenizer and embedding layer

**Implementation**:
- Load Hugging Face `AutoTokenizer` from model path
- Implement token-to-ID conversion
- Load embedding layer weights from model checkpoint
- Generate embeddings: (seq_len, 4096)
- Deterministic output (same input always produces same output)

**Acceptance Criteria**:
```
✓ Token IDs match HF tokenizer exactly
✓ Embedding shape: (seq_len, 4096)
✓ Embedding L2 distance from HF < 0.1
✓ Deterministic (run twice, identical output)
✓ No NaN/Inf values
```

**Verification**:
```bash
python3 tests/reference/week1_verify.py
# Expected output:
# ✓ Tokenization test passed
# ✓ Embedding shape test passed
# ✓ Numerical accuracy test passed
# ✓ Determinism test passed
# ✅ Week 1 verification PASSED
```

**Estimated Effort**: 3-4 days

**Golden Data**: `tests/golden/tokenizer.json`, `tests/golden/embedding.json`

**Testing Pattern**:
```python
# tests/reference/week1_verify.py
def test_tokenization():
    golden = load_golden("tokenizer")
    your_tokens = tokenizer.encode(golden["text"])
    assert your_tokens == golden["token_ids"]

def test_embedding():
    golden = load_golden("embedding")
    your_embeddings = embed_layer(your_tokens)
    assert your_embeddings.shape == tuple(golden["shape"])
    l2_error = compute_l2_distance(your_embeddings, golden["sample_values"])
    assert l2_error < 0.1
```

---

### Week 2: Forward Pass (24 Layers) ✅ Verify

**Goal**: Implement full transformer forward pass

**Implementation**:
- RoPE (Rotary Position Encoding)
- Self-attention with scaled dot-product
- Feed-forward (MLP) layers
- Layer normalization
- Loop through all 24 transformer layers
- Final lm_head projection to vocabulary
- Generate logits: (seq_len, 152064)

**Per-Layer Components**:
```
Layer i:
  ├─ Input normalization
  ├─ Attention:
  │  ├─ RoPE encoding
  │  ├─ Q, K, V projections
  │  ├─ Scaled dot-product
  │  └─ LoRA injection on Q, V
  ├─ Residual connection
  ├─ Output normalization
  ├─ MLP:
  │  ├─ Gate projection (gate_proj)
  │  ├─ Up projection (up_proj)
  │  ├─ SILU activation
  │  └─ Down projection (down_proj)
  └─ Residual connection
```

**Acceptance Criteria**:
```
✓ Logits shape: (seq_len, 152064)
✓ L2 distance from HF per layer < 0.05
✓ No NaN/Inf values anywhere
✓ Attention heads sum to 1.0 (softmax constraint)
✓ MLP outputs in reasonable range
✓ Deterministic output
```

**Verification**:
```bash
python3 tests/reference/week2_verify.py
# Expected output:
# ✓ Logits shape test passed
# ✓ Layer-by-layer accuracy test passed
# ✓ No NaN/Inf test passed
# ✓ Determinism test passed
# ✅ Week 2 verification PASSED
```

**Estimated Effort**: 5-6 days

**Golden Data**: `tests/golden/logits.json`, per-layer outputs

**Testing Pattern**:
```python
# tests/reference/week2_verify.py
def test_forward_pass():
    golden = load_golden("logits")
    your_logits = model.forward(tokens)
    
    assert your_logits.shape == tuple(golden["shape"])
    
    # Per-layer comparison
    for layer_idx in range(24):
        your_layer_out = your_model.layers[layer_idx](hidden_state)
        hf_layer_out = hf_model.layers[layer_idx](hidden_state)
        l2 = compute_l2_distance(your_layer_out, hf_layer_out)
        assert l2 < 0.05, f"Layer {layer_idx} error too high: {l2}"
```

---

### Week 3: Training Loop (Loss + Backward) ✅ Verify

**Goal**: Implement CrossEntropy loss and backward pass

**Implementation**:
- CrossEntropy loss computation
- Backward pass through transformer
- Gradient accumulation in LoRA adapters
- SGD weight update
- Convergence verification
- Model merge and comparison

**Training Loop**:
```python
for example in training_data:
    tokens = tokenizer(example.text)
    embeddings = embed_layer(tokens)
    
    # Forward
    logits = transformer(embeddings)
    loss = cross_entropy(logits, example.target_ids)
    
    # Backward
    gradients = backward(loss)
    adapter_grads = extract_lora_grads(gradients)
    
    # Update
    adapter_weights -= lr * adapter_grads
    
    # Track
    loss_history.append(loss.item())
```

**Acceptance Criteria**:
```
✓ Loss decreases during training (smoothly, not stochastically)
✓ Adapter weights update (L2 norm increases)
✓ Changed elements > 5% of adapter parameters
✓ Gradient norms are reasonable (not exploding/vanishing)
✓ Merged model output ≠ base model output
✓ Fixed prompt generates different tokens after training
✓ training_state.json shows all metrics
```

**Verification**:
```bash
python3 tests/reference/week3_verify.py
# Expected output:
# ✓ CrossEntropy loss test passed
# ✓ Loss convergence test passed
# ✓ Adapter weight update test passed
# ✓ Gradient statistics test passed
# ✓ Merged model differs test passed
# ✅ Week 3 verification PASSED
```

**Estimated Effort**: 5-6 days

**Golden Data**: Loss trajectories, adapter metrics, prompt outputs

**Testing Pattern**:
```python
# tests/reference/week3_verify.py
def test_training_loop():
    initial_loss = compute_loss(model, data)
    
    train(model, data, steps=10)
    
    final_loss = compute_loss(model, data)
    assert final_loss < initial_loss, "Loss should decrease"
    
    adapter_l2_before = compute_norm(adapter_before)
    adapter_l2_after = compute_norm(adapter_after)
    assert adapter_l2_after > adapter_l2_before, "Weights should update"
    
    merged_output = merged_model(test_tokens)
    base_output = base_model(test_tokens)
    assert not allclose(merged_output, base_output), "Output should differ"
```

---

## 🔍 Reference Test Framework

Located in: `tests/reference/` and `tests/golden/`

### Two Separate Concerns

#### `tests/reference/` - HOW TO VERIFY
- `week1_verify.py`: Tokenizer + embedding verification logic
- `week2_verify.py`: Forward pass verification logic
- `week3_verify.py`: Training loop verification logic

#### `tests/golden/` - WITH WHAT TO COMPARE
- `tokenizer.json`: Golden token IDs
- `embedding.json`: Golden embeddings
- `logits.json`: Golden logits
- `prompts.json`: Fixed test prompts
- `metrics.json`: Success criteria

### Development Flow

```
1. Write code in scripts/train_lora_with_embeddings.py

2. Run layer tests
   $ python3 your_test.py

3. Compare against golden data
   $ python3 tests/reference/week1_verify.py

4. If failed:
   - Identify which layer/metric failed
   - Debug that specific component
   - Rerun test

5. If passed:
   - Commit code
   - Update CHANGELOG.md
   - Proceed to next week
```

---

## 📊 Success Metrics

### Week 1 Success Signal
```
python3 tests/reference/week1_verify.py → all tests pass
+ Token IDs match HF exactly
+ Embedding shape correct
+ L2 error < 0.1
```

### Week 2 Success Signal
```
python3 tests/reference/week2_verify.py → all tests pass
+ Logits shape correct
+ Per-layer L2 < 0.05
+ No NaN/Inf anywhere
```

### Week 3 Success Signal
```
python3 tests/reference/week3_verify.py → all tests pass
+ Loss decreases smoothly
+ Adapter weights change > 5%
+ make posttrain → produces trained model
+ Merged model inference differs from base
```

### Phase 2A Complete Signal
```
✅ All three weeks pass
✅ make posttrain produces model with real training
✅ Inference proves training happened
✅ CHANGELOG.md updated
✅ All code committed
```

---

## 🛠️ Implementation Guidelines

### DO:
- ✅ Use HF models/utilities as authority reference
- ✅ Test each layer independently before integration
- ✅ Commit frequently (daily or twice daily)
- ✅ Update CHANGELOG.md and this file as you learn
- ✅ Use golden data for regression testing
- ✅ Document numerical differences if they appear
- ✅ Ask for help if you hit roadblocks

### DON'T:
- ❌ Change LoRA injection logic (Phase 1 is frozen)
- ❌ Modify export/merge pipeline (it works, don't touch)
- ❌ Add features outside the core five layers
- ❌ Create new directories for adapters/optimizers/etc. (Phase 3)
- ❌ Defer testing to end of week (test as you go)
- ❌ Update golden data mid-week (locks it after each week)

---

## 📁 File Structure

```
neurx/
├── MILESTONE.md                        ← Phase 1 declaration
├── CHANGELOG.md                        ← This file logs progress
├── PHASE2A_IMPLEMENTATION_PLAN.md      ← This file
│
├── scripts/
│   ├── write_lora_adapter_safetensors.py  (Phase 1, FROZEN)
│   ├── verify_posttrain_tensors.py        (Phase 1, FROZEN)
│   └── train_lora_with_embeddings.py      ← WILL CREATE THIS
│
├── tests/
│   ├── reference/
│   │   ├── __init__.py                ← Shared utilities
│   │   ├── week1_verify.py
│   │   ├── week2_verify.py
│   │   ├── week3_verify.py
│   │   └── README.md
│   └── golden/
│       ├── tokenizer.json
│       ├── embedding.json
│       ├── logits.json
│       ├── prompts.json
│       ├── metrics.json
│       └── README.md
│
└── tools/
    └── lora_merge.s                   (Phase 1, FROZEN)
```

---

## 🎓 Key Learning Checkpoints

### After Week 1
You will understand:
- How HF tokenizer works
- How embeddings are loaded from model checkpoints
- Per-token numerical accuracy requirements
- How golden data enables regression testing

### After Week 2
You will understand:
- How transformer layers compose
- What RoPE encoding does and why
- How attention and MLP interact
- Multi-layer numerical accuracy targets
- Where numerical errors accumulate

### After Week 3
You will understand:
- How loss functions drive learning
- How gradients flow backward through transformers
- How LoRA adapters capture weight updates
- How verification proves training happened
- How to merge and validate trained models

---

## ⚠️ Known Challenges

### Numerical Precision
- HF uses float32 for embeddings
- S runtime might use different precision
- Solution: Compare L2 distances, not exact equality

### Gradient Flow
- Backward pass requires tracking activations
- Easy to get gradients wrong in one layer
- Solution: Test each layer independently first

### Performance
- 24 layers of transformer = lots of computation
- Might be slow in S language initially
- Solution: Profile and optimize after correctness verified

### Integration
- Need to integrate with existing Phase 1 pipeline
- Can't break existing merge/export
- Solution: Wrap training in new script, use old merge

---

## 🚀 Ready to Start?

### Checklist Before Week 1
- [ ] Read this entire document
- [ ] Review `tests/reference/week1_verify.py`
- [ ] Check `tests/golden/tokenizer.json` structure
- [ ] Understand the 5-layer core (Token → ... → Update)
- [ ] Identify what resources you need (HF model path, etc.)

### First Command
```bash
cd neurx
python3 tests/reference/week1_verify.py
# Should run and show test results
```

### First Commit
```bash
git checkout -b phase2a/week1
# ... implement tokenizer loader ...
git add scripts/train_lora_with_embeddings.py
git commit -m "Implement tokenizer loader with HF reference

- Load AutoTokenizer from model path
- Convert text to token IDs
- Compare output to golden data
- Tests pass: tests/reference/week1_verify.py

Week 1 implementation."
```

---

## 📞 If You Get Stuck

### Common Issues

**Issue**: Embedding shape is wrong  
**Debug**: Check embedding layer dimensions in HF model
```python
from transformers import AutoModel
model = AutoModel.from_pretrained(model_path)
print(model.embed_tokens.weight.shape)  # Should be [vocab_size, hidden_size]
```

**Issue**: L2 error is too high  
**Debug**: Compare token-by-token, not global average
```python
for i in range(len(golden)):
    token_error = l2_distance(your_embedding[i], golden[i])
    if token_error > threshold:
        print(f"Token {i}: error={token_error}")
```

**Issue**: Loss doesn't decrease  
**Debug**: Check learning rate and gradient signs
```python
# Make sure gradients are flowing
assert not all_zeros(gradients), "Gradients are zero!"
assert learning_rate * gradient_norm < parameter_norm, "Update too large"
```

---

## Long-term Vision

After Phase 2A is complete:

```
Phase 1 ✅: Proven training pipeline (foundation)
     ↓
Phase 2A 🚀: Real transformer core (this sprint)
     ↓
Phase 2B ⏳: Extended kernel (if needed)
     ↓
Phase 3 🎯: Advanced capabilities (distributed, DPO, etc.)
```

Each phase builds only on the proven, stable foundation of the previous one.

---

**Start Date**: 2026-07-27  
**Week 1 Target**: Week of 2026-07-27 → 2026-08-02  
**Week 2 Target**: Week of 2026-08-03 → 2026-08-09  
**Week 3 Target**: Week of 2026-08-10 → 2026-08-16  

**Phase 2A Complete**: 2026-08-16 (optimistic), 2026-08-23 (realistic)

This is the map. The path is clear. Time to build. 🚀
