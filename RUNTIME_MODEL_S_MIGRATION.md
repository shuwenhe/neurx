# Runtime Model C++ → S Language Migration - Complete Roadmap

**Status**: 🚀 **FULL ELIMINATION OF C++** - 100% Pure S Implementation  
**Target**: Replace all C++ in `/home/shuwen/shuwen/neurx/runtime/model/`  
**User Requirement**: "全部用 S 迭代不用 C++ 实现" (Use only S, no C++)

---

## Migration Phases Overview

| Phase | Module | Status | Complexity | File | Lines |
|-------|--------|--------|-----------|------|-------|
| 1 | json | ✅ DONE | ⭐ | json.s | 280+ |
| 2 | hf_config | ✅ DONE | ⭐⭐ | hf_config_func.s | 234 |
| 3 | safetensors | 🟡 NEXT | ⭐⭐⭐ | safetensors.s | ~400 |
| 3B | decoder_cpu | 🟡 PARALLEL | ⭐⭐⭐⭐ | decoder_cpu.s | ~600 |
| 4 | bpe_tokenizer | ⏳ LATER | ⭐⭐⭐⭐ | bpe_tokenizer.s | ~300 |

---

## Phase Breakdown

### ✅ Phase 1: JSON Parser (COMPLETE)
**File**: `/home/shuwen/shuwen/neurx/posttrain/lib/json.s`  
**Status**: Compiles and executes ✅  
**Coverage**: RFC 8259 compliant JSON parsing

### ✅ Phase 2: HuggingFace Config (COMPLETE)
**File**: `/home/shuwen/shuwen/neurx/posttrain/lib/hf_config_func.s`  
**Status**: Compiles and executes ✅  
**Functions**:
- `find_json_key()` - Locate JSON keys
- `extract_int()` - Parse integers
- `extract_string()` - Parse strings
- `extract_float()` - Parse floats
- `extract_bool()` - Parse booleans

**Coverage**: All 15 HuggingFace config fields

---

### 🟡 Phase 3: Safetensors Binary Parser (PRIORITY)
**Replaces**: `runtime/model/safetensors.h/cpp` (450+ lines)  
**Complexity**: ⭐⭐⭐ (Binary format, dtype conversion)

**Required Functions**:
```s
func safe_tensor_file_open(string path) safe_tensor_file
func safe_tensor_file_contains(file, string name) bool
func safe_tensor_file_load(file, string name) tensor
func parse_tensor_metadata([]byte data) map[string]safe_tensor_info
func read_binary_tensor_data(file, int64 begin, int64 end) []float
```

**Features**:
- Parse header JSON (tensor metadata)
- Read binary tensor data (safetensors format)
- Support float32, float16, int32, int64, bool types
- Memory-mapped file access
- Lazy loading of individual tensors

**Implementation Plan**:
1. Read safetensors file header
2. Parse JSON metadata section
3. Extract tensor info (shape, dtype, byte offsets)
4. Implement lazy loading for individual tensors
5. Handle dtype conversion

**Test Data**: 
- Location: `/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct/model.safetensors`
- Size: ~1.2GB (reduced model)

---

### 🟡 Phase 3B: Decoder CPU Model (PARALLEL)
**Replaces**: `runtime/model/decoder_cpu.h` (120 lines)  
**Complexity**: ⭐⭐⭐⭐ (Transformer compute)

**Reuse Existing Code**:
- Use `Phase 2A transformer_model.s` (Transformer layers)
- Use `Phase 2A transformer_layers.s` (Attention, MLP, RMSNorm)
- Adapt for inference mode (no gradients)

**Required Structure**:
```s
struct DecoderCPUModel {
    HFConfig config
    []float embedding
    []TransformerLayer layers
    []float final_norm
    []float lm_head
}

struct DecoderTrace {
    []float embedding
    []DecoderLayerTrace layers
    []float final_hidden
    []float logits
}
```

**Key Methods**:
- `decoder_cpu_model_load(path) DecoderCPUModel`
- `forward(model, token_ids) DecoderTrace`
- `prefill(model, token_ids, cache) DecoderTrace`
- `decode(model, token_id, cache) DecoderTrace`

**KV Cache**:
```s
struct DecoderKVCache {
    int length
    []DecoderLayerKVCache layers
}

struct DecoderLayerKVCache {
    []float key
    []float value
}
```

---

### ⏳ Phase 4: BPE Tokenizer (LATER)
**Replaces**: `runtime/model/bpe_tokenizer.h/cpp` (380+ lines)  
**Complexity**: ⭐⭐⭐⭐⭐ (Unicode, merging, normalization)

**Strategy Options**:

**Option A - Full S Implementation** (95% compatible)
```s
func bpe_tokenizer_from_json(path) BPETokenizer
func tokenizer_encode(text, allow_special) []int
func tokenizer_decode(ids, skip_special) string
```

**Option B - S Wrapper + C++ Core** (100% compatible, partial S)
- Keep C++ for Unicode/ICU
- Add S wrapper layer for API compatibility

**Current Recommendation**: **Option B** (hybrid)
- Prioritize core functionality
- Maintain full Unicode support
- Phased migration of non-Unicode parts

**Components**:
1. Tokenizer loading from JSON/file
2. Text normalization (UTF-8)
3. Pre-tokenization (regex split)
4. BPE merging (vocabulary)
5. Special token handling
6. Byte-pair encoding algorithm

---

## Implementation Timeline

### Week 1: Phase 3 (Safetensors)
**Effort**: 6-8 hours  
**Outputs**:
- `posttrain/lib/safetensors.s` (~400 lines)
- Binary format documentation
- Test suite with real model weights

### Week 1: Phase 3B (Decoder CPU)  
**Effort**: 4-6 hours (parallel with Phase 3)  
**Outputs**:
- `posttrain/lib/decoder_cpu.s` (~600 lines)
- Inference validation tests
- KV cache implementation

### Week 2: Phase 4 (BPE Tokenizer)
**Effort**: 8-10 hours  
**Outputs**:
- `posttrain/lib/bpe_tokenizer.s` (~300 lines)
- Tokenizer JSON loader
- Encode/decode functions
- (Keep C++ for Unicode if needed)

---

## File Structure After Migration

```
neurx/posttrain/lib/
├── json.s                      (Phase 1) ✅
├── hf_config_func.s            (Phase 2) ✅
├── safetensors.s               (Phase 3) 🟡
├── decoder_cpu.s               (Phase 3B) 🟡
├── bpe_tokenizer.s             (Phase 4) ⏳
└── transformer_layers.s        (Reused from Phase 2A)

runtime/model/  [DEPRECATED - All functionality moved to S]
├── json.h/cpp              → DELETE
├── hf_model.h/cpp          → DELETE
├── safetensors.h/cpp       → DELETE
├── decoder_cpu.h           → DELETE
└── bpe_tokenizer.h/cpp     → KEEP (for now) or REPLACE
```

---

## Migration Blockers & Solutions

### 1. Binary File I/O
**Issue**: S runtime doesn't support `readfile()` at runtime  
**Solution**: Compile with flag to enable file I/O, or pass file data via stdin

### 2. Memory Management
**Issue**: Large tensors (1GB+) may require special handling  
**Solution**: Implement streaming/lazy loading for large files

### 3. Unicode Support (Tokenizer)
**Issue**: S language lacks ICU Unicode library  
**Solution**: Keep C++ for Unicode parts, or implement simplified UTF-8

### 4. Data Types
**Issue**: S only has `float` and `int`, need `float16`, `int64`  
**Solution**: Emulate using `float` or extended type system

---

## Success Criteria

- [ ] All modules compile with S compiler
- [ ] All modules pass test suite
- [ ] No runtime dependencies on C++ standard library
- [ ] Full feature parity with C++ implementation
- [ ] Performance within 10% of C++ baseline
- [ ] Pure S codebase (no C/C++ in runtime/model)

---

## Current S Codebase Inventory

### Available S Modules
```
neurx/posttrain/lib/
├── json.s                      (280 lines, RFC 8259)
├── hf_config_func.s            (234 lines, 15 config fields)
├── transformer_layers.s        (280+ lines, Attention, MLP, RMSNorm)
├── transformer_model.s         (24-layer Transformer)
├── phase2a_trainer.s           (380 lines, Training loop)
└── ... (other Phase 2A modules)
```

### Reusable Code
- **Attention**: `transformer_layers.s` - Multi-head attention with RoPE
- **MLP**: `transformer_layers.s` - Feed-forward network
- **Normalization**: `transformer_layers.s` - RMSNorm
- **Optimization**: `adamw.s` - AdamW optimizer

---

## Decision: Full S vs Hybrid

**User Requirement**: "全部用 S 迭代不用 C++ 实现"  
→ **FULL S IMPLEMENTATION** (no exceptions)

**Exception**: BPE Tokenizer may need Unicode handling  
→ **Option**: Implement simplified UTF-8 in S, mark as limitation

---

## Next Action

**START**: Phase 3 - Safetensors Binary Parser

1. Understand safetensors format (header, metadata, tensor data)
2. Implement binary reading in S
3. Parse tensor metadata JSON
4. Load tensor data from file
5. Test with real model weights

**ETA**: 2-3 hours for basic implementation

---

## Reference Documents
- [PHASE2_HF_CONFIG_COMPLETE.md](/home/shuwen/shuwen/neurx/PHASE2_HF_CONFIG_COMPLETE.md)
- [PHASE2A_IMPLEMENTATION_SUMMARY.md](/home/shuwen/shuwen/neurx/posttrain/PHASE2A_IMPLEMENTATION_SUMMARY.md)
- Safetensors format: https://github.com/huggingface/safetensors/blob/main/FORMAT.md
