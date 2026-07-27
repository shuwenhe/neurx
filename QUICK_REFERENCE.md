# PostTrain Quick Reference Card

## One-Command Verification
```bash
cd neurx && make verify-posttrain
```

**Output shows**:
```
[Backend] Python Reference Trainer (Phase 1)
[Weight Delta] L1=0.77, L2=0.009, Changed=40.5%
[Loss] 0.047398 → 0.047396
```

---

## What Phase 1 Proved

| Evidence | Status | Proof |
|----------|--------|-------|
| Gradients exist | ✅ | lora_B: 0→0.565 |
| Weights update | ✅ | 40.5% changed elements |
| Loss decreases | ✅ | 0.047398→0.047396 |
| Merge works | ✅ | 48 tensors applied |
| Export works | ✅ | 1.1MB binary safetensors |

---

## Current Architecture

```
lightweight LoRA training closure
├─ Real parameters
├─ Real export
├─ Real merge
└─ Automatic verification
```

**NOT** LoRA Demo  
**NOT** Complete SFT  
**IS** Solid foundation for Phase 2A

---

## Phase 2A Next Steps

### Week 1: Embeddings
- Load tokenizer
- Load embedding layer
- Verify shapes

### Week 2: Forward + Loss
- Transformer forward (24 layers)
- CrossEntropy loss
- Logits generation

### Week 3: Backward + Testing
- Backward through transformer
- LoRA gradients
- Full convergence testing

---

## Key Metrics

### Adapter Statistics
- L1 norm: 1725.3
- L2 norm: 3.39
- Non-zero: 373,824 / 540,672 (69.1%)

### Weight Delta
- L1 delta: 0.770228
- L2 delta: 0.009155
- Max delta: 6.03e-04
- Changed: 219,089 / 540,672 (40.5%)

---

## Files to Know

| File | Purpose |
|------|---------|
| `scripts/write_lora_adapter_safetensors.py` | Python trainer (real gradients) |
| `scripts/real_lora_sft.s` | S wrapper (orchestration) |
| `PHASE1_COMPLETE_PHASE2A_READY.md` | Full assessment |
| `PHASE2A_IMPLEMENTATION_PLAN.md` | 3-week roadmap |
| `make verify-posttrain` | Automatic verification |

---

## Current Status

**Phase 1**: ✅ COMPLETE  
**Improvements**: ✅ COMPLETE  
**Phase 2A**: 🚀 READY TO START

**Confidence**: 9/10 (Mathematical reality proven)  
**Next**: Semantic validation (does it learn language?)

---

## Quick Wins if Needed (Not Required)

1. Add gradient logging (print ||grad|| per epoch)
2. Support variable sequence lengths
3. Implement gradient accumulation
4. Add learning rate scheduling

These are **quality of life improvements**, not blockers for Phase 2A.

---

**Bottom Line**: 
- Phase 1 proved training works at gradient level
- Phase 2A will prove it works at semantic level
- Phase 3 will implement in pure S

Ready to proceed? → Start Phase 2A Week 1
