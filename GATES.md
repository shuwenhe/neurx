# Phase 2A Go/No-Go Automated Gates

**Purpose**: Each milestone has an executable gate that must PASS before proceeding.

**Principle**: Gates are not "nice to have" — they are CI rules. Passing a gate is not optional.

---

## Available Gates

### W1.1: Tokenizer Gate

```bash
make gate-w1.1
```

**Checks**:
1. ✅ `neurx/inference/tokenizer_loader.s` exists and compiles
2. ✅ `neurx/tests/tokenizer_test.s` exists and runs
3. ✅ Tokenizer outputs match `tests/golden/tokenizer.json` 100%
4. ✅ Determinism: 10 runs produce identical token sequences
5. ✅ No regression: Previous capabilities still work

**Output**:
```
✓ Compilation check PASS
✓ Unit test PASS
✓ Golden test PASS
✓ Determinism check PASS
✓ Regression check PASS

🟢 GATE W1.1 PASS — Proceed to W1.2
```

OR

```
✗ Determinism check FAIL (run 5 differs from run 1)

🔴 GATE W1.1 FAIL — Fix tokenizer and retry
```

**You can proceed to W1.2 ONLY if gate shows 🟢 GATE PASS.**

---

### W1.2: Embedding Gate

```bash
make gate-w1.2
```

**Checks**:
1. ✅ W1.1 gate previously passed (prerequisite)
2. ✅ `neurx/inference/embedding_loader.s` exists and compiles
3. ✅ `neurx/tests/embedding_test.s` exists and runs
4. ✅ Embedding shape correct: (seq_len, 4096)
5. ✅ Embedding L2 error from HF < 0.1
6. ✅ Determinism: 10 runs produce byte-identical embeddings
7. ✅ No regression: W1.1 tokenizer still works

**Output**: Similar to W1.1, gate shows 🟢 or 🔴

---

### Week 2: Forward Pass Gate

```bash
make gate-w2
```

**Checks**:
1. ✅ W1.1 + W1.2 gates previously passed (prerequisites)
2. ✅ `neurx/inference/transformer.s` exists and compiles (all 24 layers)
3. ✅ `neurx/tests/forward_test.s` runs successfully
4. ✅ Per-layer L2 error from HF < 0.05
5. ✅ Final logits shape: (seq_len, 152064)
6. ✅ Determinism: 10 runs produce identical logits
7. ✅ No regression: W1.1 + W1.2 still work

---

### Week 3: Training Loop Gate

```bash
make gate-w3
```

**Checks**:
1. ✅ W1.1 + W1.2 + W2 gates previously passed (prerequisites)
2. ✅ `neurx/training/cross_entropy.s` exists and compiles
3. ✅ `neurx/training/backward.s` exists and compiles
4. ✅ `neurx/tests/training_test.s` runs successfully
5. ✅ Loss decreases during training (not NaN)
6. ✅ Adapter weights update (> 5% changed elements)
7. ✅ Merged model differs from base model
8. ✅ No regression: All prior weeks still work

---

## Gate Implementation (Makefile)

### Structure

```makefile
gate-w1.1:
	@echo "🚪 Checking W1.1 Gate..."
	@# 1. Compilation
	$(S_COMPILER) neurx/inference/tokenizer_loader.s -o /tmp/tokenizer_loader
	@# 2. Unit tests
	python3 neurx/tests/tokenizer_test.s
	@# 3. Golden test
	python3 tests/reference/week1_verify.py::test_tokenization
	@# 4. Determinism (run 10 times, verify identical)
	@# 5. Regression
	@echo "🟢 GATE W1.1 PASS"
```

### Execution Model

Each gate runs as a **deterministic script**:
- Same command always produces same result
- Either PASS (exit 0) or FAIL (exit non-zero)
- No human judgment involved
- Can be run in CI/CD pipeline

---

## Rules for Gates

### Rule 1: Prerequisites are Enforced
```bash
make gate-w1.2
# Checks: Does W1.1 gate pass? If not, FAIL immediately.
```

Cannot skip prerequisite gates.

### Rule 2: Gates are Repeatable
```bash
make gate-w1.1  # Run 1 → PASS
make gate-w1.1  # Run 2 → PASS (identical result)
make gate-w1.1  # Run 3 → PASS (identical result)
```

Same code always produces same gate result (determinism).

### Rule 3: Gates Block Progression
```
W1.1 FAIL? → STOP (don't start W1.2)
W1.2 FAIL? → STOP (don't start W2)
W2 FAIL?  → STOP (don't start W3)
```

If gate fails, fix the module. Do not bypass.

### Rule 4: Gates Include Regression Checks
```bash
make gate-w2
# Verifies:
#   - W2 module works
#   - W1.1 + W1.2 still work (no regression)
```

---

## What "Gate Passing" Means

When you see:

```
🟢 GATE W1.1 PASS
```

It means:
- ✅ Tokenizer code compiles
- ✅ Unit tests all pass
- ✅ Golden data matches 100%
- ✅ Determinism verified
- ✅ No regression in prior modules

**Consequence**: You can now safely start W1.2.

When you see:

```
🔴 GATE W1.2 FAIL — Embedding L2 error 0.25 > 0.1 threshold
```

It means:
- ❌ Embedding does not match HF closely enough
- You need to debug embedding_loader.s
- Fix the bug
- Run `make gate-w1.2` again
- Only when gate passes, proceed

---

## Typical Workflow

```bash
# Day 1: Implement W1.1
$ cat > neurx/inference/tokenizer_loader.s << 'EOF'
... S code ...
EOF

$ cat > neurx/tests/tokenizer_test.s << 'EOF'
... unit tests ...
EOF

$ make gate-w1.1
🔴 GATE W1.1 FAIL — Compilation error in tokenizer_loader.s:10

# Fix compilation
$ # ... edit tokenizer_loader.s ...
$ make gate-w1.1
🔴 GATE W1.1 FAIL — Golden test: token_ids[5] mismatch (got 100, expected 101)

# Fix token lookup
$ # ... edit tokenizer_loader.s ...
$ make gate-w1.1
✓ Compilation check PASS
✓ Unit test PASS
✓ Golden test PASS
✓ Determinism check PASS
✓ Regression check PASS

🟢 GATE W1.1 PASS

# Commit
$ git add neurx/inference/tokenizer_loader.s neurx/tests/tokenizer_test.s
$ git commit -m "W1.1: Implement tokenizer loader in S

- Load HF tokenizer (deterministic)
- Generate token IDs for golden prompt
- Verify against tests/golden/tokenizer.json
- Determinism: 10 runs identical
- Gate: make gate-w1.1 PASS"

# Now safe to proceed
$ # Start W1.2 (Embedding)
```

---

## Troubleshooting Gates

### Problem: Gate fails intermittently
```
Run 1: make gate-w1.1 → PASS
Run 2: make gate-w1.1 → FAIL (random difference)
```

**Diagnosis**: Code is not deterministic (uses randomness, threading, or non-deterministic data structures)

**Fix**: Make code deterministic
- Remove randomness from tokenizer
- Ensure embedding uses fixed seed
- Use deterministic data structures

### Problem: Gate fails immediately on new change
```
make gate-w1.1 → 🔴 GATE W1.1 FAIL — Regression: W1.1 module broken
```

**Diagnosis**: You changed W1.1 code and broke it

**Fix**:
1. Review the change
2. Fix the bug
3. Rerun gate

### Problem: All gates suddenly fail
```
make gate-w1.1 → FAIL
make gate-w1.2 → FAIL (can't even start)
make gate-w2 → FAIL
make gate-w3 → FAIL
```

**Diagnosis**: Probably environment issue (missing S compiler, model not loaded, etc.)

**Check**:
```bash
which s_seed                                  # S compiler present?
ls /home/shuwen/shuwen/model/...             # Model present?
python3 -c "from transformers import AutoTokenizer"  # HF installed?
```

---

## CI/CD Integration (Future)

Once gates work locally, integrate into CI:

```yaml
# .github/workflows/phase2a.yml
on: [push]

jobs:
  gates:
    runs-on: linux
    steps:
      - uses: actions/checkout@v3
      - name: W1.1 Gate
        run: make gate-w1.1
      - name: W1.2 Gate
        run: make gate-w1.2
      - name: W2 Gate
        run: make gate-w2
      - name: W3 Gate
        run: make gate-w3
```

**Effect**: Every commit is checked against all gates. If gate fails, CI fails, preventing merge.

---

## Summary

**Gates are the enforcement mechanism for "Code-First + Correctness First".**

They are:
- ✅ Automated (not manual)
- ✅ Repeatable (same input → same output)
- ✅ Enforceable (no bypass option)
- ✅ Progressive (prerequisites checked)
- ✅ Regression-detecting (all prior work verified)

**When a gate passes, you have high confidence that**:
1. Your code works
2. It matches the reference
3. You haven't broken prior work
4. You can safely proceed

This is how production training frameworks maintain quality over time.

---

*"Your code is only as good as the gates it passes."*
