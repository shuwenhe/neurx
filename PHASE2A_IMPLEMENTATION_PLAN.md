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

### Engineering Philosophy

> **Phase 2A 的成功标准不是实现了多少功能，而是每增加一个模块，都能通过 Golden 回归测试，并保持已有能力不退化。**

**Three Core Principles**:
1. **正确性优先于功能数量** - Correctness before features
2. **回归稳定性优先于开发速度** - Stability over speed
3. **模块验证优先于端到端演示** - Module verification before end-to-end demo

**Implementation Constraint**:
- 🔴 NO document without matching runnable code
- 🔴 NO new module starts until previous module PASSES
- 🔴 ALL code MUST be in S language (not Python)

### Success Criteria

```
✓ W1.1 PASS: Tokenizer 100% matches HF
✓ W1.2 PASS: Embedding numerically correct
✓ W2.1 PASS: Forward pass per-layer verified
✓ W2.2 PASS: Logits shape and range correct
✓ W3.1 PASS: CrossEntropy loss decreases
✓ W3.2 PASS: LoRA backward and update working
✓ make posttrain → Produces trained model
✓ Merged model output ≠ base model output
```

When all eight pass, **Phase 2A is complete**.

---

## 🚦 Go / No-Go Gates (Quality Control)

Each phase must fully pass before proceeding.

### W1.1 Gate: Tokenizer Complete
**Entry Criteria**: W1.1 implementation code exists in `neurx/`  
**Exit Criteria** (must ALL pass):
- [ ] S language tokenizer implementation is runnable
- [ ] `python3 tests/reference/week1_verify.py` → tokenizer test PASS
- [ ] Golden data `tests/golden/tokenizer.json` matches output 100%
- [ ] No NaN/Inf values
- [ ] Deterministic (run twice, identical output)

**Go/No-Go Decision**: IF all pass → **START W1.2** | ELSE → **STAY IN W1.1**

---

### W1.2 Gate: Embedding Complete
**Entry Criteria**: W1.1 gate PASSED  
**Exit Criteria** (must ALL pass):
- [ ] S language embedding loader is runnable
- [ ] `python3 tests/reference/week1_verify.py` → embedding test PASS
- [ ] Golden data `tests/golden/embedding.json` matches output (L2 < 0.1)
- [ ] Shape correct: (seq_len, 4096)
- [ ] No NaN/Inf values
- [ ] Deterministic output

**Go/No-Go Decision**: IF all pass → **START WEEK 2** | ELSE → **STAY IN W1.2**

---

### Week 2 Gate: Forward Pass Complete
**Entry Criteria**: W1.1 + W1.2 gates PASSED  
**Exit Criteria** (must ALL pass):
- [ ] S language transformer forward pass is runnable (24 layers)
- [ ] `python3 tests/reference/week2_verify.py` → forward pass tests PASS
- [ ] Per-layer outputs match HF reference (L2 < 0.05 per layer)
- [ ] Logits shape: (seq_len, 152064)
- [ ] No NaN/Inf values anywhere
- [ ] Deterministic output

**Go/No-Go Decision**: IF all pass → **START WEEK 3** | ELSE → **STAY IN WEEK 2**

---

### Week 3 Gate: Training Complete
**Entry Criteria**: Week 1 + Week 2 gates PASSED  
**Exit Criteria** (must ALL pass):
- [ ] S language CrossEntropy + backward pass is runnable
- [ ] `python3 tests/reference/week3_verify.py` → training tests PASS
- [ ] Loss decreases smoothly during training
- [ ] Adapter weights update (> 5% changed elements)
- [ ] Gradient norms are reasonable (not exploding/vanishing)
- [ ] Merged model output differs from base model
- [ ] `make posttrain` produces trained model

**Go/No-Go Decision**: IF all pass → **PHASE 2A COMPLETE** | ELSE → **STAY IN WEEK 3**

---

**Critical Rule**: 
> Do not proceed to next phase if current phase gate is not PASSED.  
> Do not add features if previous module is not VERIFIED.

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

## 📅 Timeline: Incremental Modules with Code-First Development

### Module 0: Golden Test Infrastructure (REQUIRED FIRST)

**Code to Create**: None (already exists in `tests/reference/` and `tests/golden/`)  
**Verification**: 
```bash
$ python3 tests/reference/week1_verify.py 2>&1 | head -5
# Should show test framework is ready
```

**Purpose**: Baseline for all per-layer testing  
**Status**: ✅ READY

---

## Week 1: Tokenizer + Embedding (Split into 2 Milestones)

### Milestone W1.1: Tokenizer Only

**Definition**: 
```
Text → Tokenizer → Token IDs
```

**Code to Create** (in S language):
```
neurx/
├── inference/
│   └── tokenizer_loader.s    ← NEW (load HF tokenizer)
└── scripts/
    └── tokenizer_test.s      ← NEW (test tokenizer)
```

**Responsibilities**:
- Load Hugging Face `AutoTokenizer` from model path
- Convert text string to token IDs
- Return token IDs as array
- Ensure deterministic output

**Acceptance Criteria**:
```
✓ Token IDs match HF tokenizer EXACTLY (100%)
✓ Golden test tests/golden/tokenizer.json PASS
✓ Deterministic (run twice, identical output)
✓ No NaN/Inf/error values
✓ python3 tests/reference/week1_verify.py::test_tokenization → PASS
```

**Code-First Constraint**:
- Before W1.1 is complete, S implementation must exist and be runnable
- If no S code, milestone is BLOCKED

**Estimated Effort**: 2-3 days

**Exit Gate**: ALL acceptance criteria pass → Proceed to W1.2

---

### Milestone W1.2: Embedding Layer

**Definition**:
```
Token IDs → Embedding Layer → Embeddings [seq_len, 4096]
```

**Code to Create** (in S language):
```
neurx/
├── inference/
│   ├── embedding_loader.s    ← NEW (load HF embeddings)
│   └── embedding.s           ← NEW (embedding forward pass)
└── scripts/
    └── embedding_test.s      ← NEW (test embeddings)
```

**Responsibilities**:
- Load embedding layer weights from model checkpoint
- Accept token IDs and generate embeddings
- Output shape: (seq_len, 4096)
- Ensure deterministic output
- Handle batch processing

**Acceptance Criteria**:
```
✓ Embedding shape is (seq_len, 4096)
✓ Golden test tests/golden/embedding.json PASS
✓ L2 error from HF reference < 0.1
✓ Deterministic (run twice, identical output)
✓ No NaN/Inf values
✓ python3 tests/reference/week1_verify.py::test_embedding → PASS
```

**Code-First Constraint**:
- W1.2 CANNOT start until W1.1 PASSES
- S implementation must exist and be runnable
- If W1.1 not passing, W1.2 is BLOCKED

**Estimated Effort**: 2-3 days

**Exit Gate**: ALL acceptance criteria pass → Proceed to Week 2

---

### Week 1 Summary

| Milestone | Duration | Code Files | Pass Rate | Status |
|-----------|----------|-----------|-----------|--------|
| W1.1 | 2-3d | tokenizer_loader.s | 100% → Go | ⏳ |
| W1.2 | 2-3d | embedding_loader.s | 100% → Go | ⏳ |

**Total Week 1**: 4-6 days (critical path)

**Week 1 Complete When**: Both W1.1 AND W1.2 pass all criteria

---

### Week 2: Forward Pass (24 Layers) ✅ Verify

**Definition**:
```
Embeddings → 24-Layer Transformer → Logits [seq_len, 152064]
```

**Code to Create** (in S language):
```
neurx/
├── inference/
│   ├── rope.s                ← NEW (RoPE encoding)
│   ├── attention.s           ← NEW (scaled dot-product)
│   ├── mlp.s                 ← NEW (feed-forward)
│   ├── transformer_layer.s   ← NEW (single layer)
│   ├── transformer.s         ← NEW (24-layer loop)
│   └── logits.s              ← NEW (lm_head)
└── scripts/
    └── forward_test.s        ← NEW (test forward pass)
```

**Entry Gate**: W1.1 + W1.2 both PASS

**Acceptance Criteria**:
```
✓ Logits shape: (seq_len, 152064)
✓ Per-layer L2 distance from HF < 0.05
✓ Golden test tests/golden/logits.json PASS
✓ No NaN/Inf values anywhere
✓ Deterministic output
✓ python3 tests/reference/week2_verify.py → PASS
```

**Code-First Constraint**:
- ALL 24 layers + logits must be implemented in S
- Cannot start if Week 1 gate not passed
- Each layer must have independent test

**Estimated Effort**: 5-6 days

**Exit Gate**: ALL acceptance criteria pass → Proceed to Week 3

---

### Week 3: Training Loop (Loss + Backward + Update)

**Definition**:
```
Logits → CrossEntropy Loss → Backward → Adapter Update
```

**Code to Create** (in S language):
```
neurx/
├── training/
│   ├── cross_entropy.s       ← NEW (loss computation)
│   ├── backward.s            ← NEW (backward pass)
│   ├── gradient_accumulate.s ← NEW (gradient tracking)
│   └── lora_update.s         ← NEW (adapter weight update)
└── scripts/
    └── training_test.s       ← NEW (test training loop)
```

**Entry Gate**: Week 1 + Week 2 both PASS

**Acceptance Criteria**:
```
✓ Loss decreases smoothly during training
✓ Adapter weights update (> 5% changed elements)
✓ Gradient norms reasonable (not exploding/vanishing)
✓ Merged model output ≠ base model
✓ Golden test tests/golden/metrics.json PASS
✓ make posttrain → produces trained model
✓ python3 tests/reference/week3_verify.py → PASS
```

**Code-First Constraint**:
- ALL backward pass must be in S
- No Python trainer for core logic
- Integration with Phase 1 merge pipeline

**Estimated Effort**: 5-6 days

**Exit Gate**: ALL acceptance criteria pass → Phase 2A COMPLETE

---

### Phase 2A Final Gate

**Requirement**: ALL three weeks (W1.1, W1.2, W2, W3) PASS

**Final Verification**:
```bash
$ cd neurx
$ make posttrain
$ python3 tests/reference/week1_verify.py && \
  python3 tests/reference/week2_verify.py && \
  python3 tests/reference/week3_verify.py
$ # All must show ✅ PASS
```

**Success Signal**:
- 🟢 W1.1: Tokenizer PASS
- 🟢 W1.2: Embedding PASS
- 🟢 W2: Forward PASS
- 🟢 W3: Training PASS
- 🟢 Merged model works

---

## 🔴 Code-First Development Rules

**Rule 1**: Document → Code → Test (not: Document → Test → Code)

**Rule 2**: Every design document must have corresponding S implementation
```
Design → S Code → Unit Test → Golden Test → Commit
```

**Rule 3**: If S code doesn't exist, the milestone is BLOCKED
```
Week 2 blocked by: S tokenizer_loader.s not runnable
Week 3 blocked by: S embedding_loader.s not passing tests
```

**Rule 4**: No Python in training core
- ✅ Tests can use Python (for now)
- ✅ Reference comparison can use Python
- ❌ Training core logic MUST be in S
- ❌ Tokenizer/Embedding/Forward/Backward MUST be in S

**Rule 5**: Each code file must have companion test
```
tokenizer_loader.s  → tokenizer_test.s
embedding.s         → embedding_test.s
transformer.s       → forward_test.s
```


---

## 🛠️ Implementation Guidelines

### Core Principle: Code Drives Design, Not Vice Versa

> **Never write a design document that doesn't have corresponding S code.**

### DO:
- ✅ Use HF models as authority reference
- ✅ Test each layer independently before integration
- ✅ Commit frequently (daily if possible)
- ✅ Update CHANGELOG.md as you learn
- ✅ Use golden data for regression testing
- ✅ Document numerical differences if they appear
- ✅ **Write ALL core logic in S language**
- ✅ Create unit tests for each S module
- ✅ Run verification tests before each commit
- ✅ Ask for help early, not when stuck for hours

### DON'T:
- ❌ Change LoRA injection logic (Phase 1 is frozen)
- ❌ Modify export/merge pipeline (it works, don't touch)
- ❌ Add features outside the core five layers
- ❌ Create new directories for features not in this plan
- ❌ Defer testing to end of week (test as you go)
- ❌ Update golden data mid-week (lock it, don't change)
- ❌ **Use Python for tokenizer/embedding/forward/backward/loss/gradient**
- ❌ Skip unit tests to save time
- ❌ Proceed to next milestone if previous one didn't fully pass

### Language Requirement (Hard Constraint)

**S Language MUST be used for**:
- Tokenizer loading and token ID conversion
- Embedding layer forward pass
- 24-layer transformer forward pass
- RoPE encoding
- Attention mechanism
- MLP feed-forward
- CrossEntropy loss computation
- Backward pass through adapters
- Gradient accumulation
- Weight updates

**Python MAY be used for**:
- Test harnesses (for now, Phase 3 will replace)
- Reference comparison against HF
- Golden data loading/comparison
- Metrics computation
- Logging/visualization

### Commit Pattern for Each Module

```bash
git checkout -b phase2a/<module_name>

# 1. Create S code
cat > neurx/inference/tokenizer_loader.s << 'EOF'
// S implementation
EOF

# 2. Create unit test
cat > neurx/tests/tokenizer_test.s << 'EOF'
// Test the module
EOF

# 3. Run tests
python3 tests/reference/week1_verify.py

# 4. Only if passing, commit
git add neurx/inference/tokenizer_loader.s neurx/tests/tokenizer_test.s
git commit -m "Implement tokenizer loader in S

- S code: tokenizer_loader.s (load HF tokenizer)
- Tests: tokenizer_test.s (unit test)
- Verification: tests/reference/week1_verify.py PASS
- Golden: tests/golden/tokenizer.json match

Module: W1.1 Tokenizer"
```

### Red Flag Indicators

🚩 **STOP and re-evaluate if**:
- Code exists but tests don't pass
- Tests pass but golden verification fails
- Previous milestone was modified
- Code is not in S language
- Multiple features added without individual testing
- Design document updated without code
- Gate criteria not fully met but proceeding anyway

---

## 📋 Checklist: Start Phase 2A

Before writing any code, verify:

- [ ] `tests/reference/week1_verify.py` exists and is readable
- [ ] `tests/golden/tokenizer.json` exists and is readable
- [ ] `tests/golden/embedding.json` exists and is readable
- [ ] `tests/golden/logits.json` exists and is readable
- [ ] `tests/golden/metrics.json` exists and is readable
- [ ] S compiler is available: `which s_seed`
- [ ] HF model is available: `/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`
- [ ] Medical dataset is available: `/home/shuwen/shuwen/dataset/medical/`
- [ ] You understand the Go/No-Go gates
- [ ] You understand Phase 1 code is FROZEN

---

## 🔥 What "Done" Means

**W1.1 Tokenizer is DONE when**:
```
✅ S code: tokenizer_loader.s exists and compiles
✅ Unit test: tokenizer_test.s exists and PASSES
✅ Golden test: tests/reference/week1_verify.py::test_tokenization PASSES
✅ Code committed with clear message
✅ CHANGELOG.md updated
✅ Next milestone NOT started
```

**W1.2 Embedding is DONE when**:
```
✅ S code: embedding_loader.s exists and compiles
✅ Unit test: embedding_test.s exists and PASSES
✅ Golden test: tests/reference/week1_verify.py::test_embedding PASSES
✅ Code committed with clear message
✅ CHANGELOG.md updated
✅ Week 2 can NOW start
```

Similar pattern for Week 2 and Week 3.

**Phase 2A is DONE when**:
```
✅ All gate tests PASS
✅ make posttrain produces model
✅ Model is different from base
✅ All CHANGELOG.md entries written
✅ All code committed
✅ Git history is clean
✅ No uncommitted changes
```

---

## 🎯 Remember

This project succeeds not by moving fast, but by moving correctly.

**Correctness > Speed**

Every module verified before the next one starts.
Every test passed before the next milestone begins.
Every line of code tracked in git.

This is how production training frameworks are built.

---

**Last Updated**: 2026-07-27  
**Next**: Start W1.1 Tokenizer implementation in S

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

**Last Updated**: 2026-07-27  
**Next**: Start W1.1 Tokenizer implementation in S

---

*"先把核心打磨扎实，再扩展能力边界" - Build the core right, then expand capabilities.*
