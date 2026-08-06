# 🚀 PHASE 2 EXECUTION GUIDE - From Rule Engine to Real Model Inference

**Status**: 🎯 READY TO IMPLEMENT  
**Target Duration**: 5-8 weeks  
**Architecture**: Pure S language, no external dependencies  
**Commit**: 6fdc637f (Architecture framework complete)

---

## 📋 EXECUTIVE SUMMARY

### What We Have ✅
- ✅ Production chat system with HTTP fallback
- ✅ Medical rule engine (7 categories, 50+ topics)
- ✅ Stable, working deployment (`make chat`)
- ✅ Test suite validating keyword matching

### What We're Building 🚀
- 🚀 SafTensors binary parser (reads model weights)
- 🚀 Tokenizer (text → token IDs)
- 🚀 Real Transformer forward pass (24 layers)
- 🚀 Model inference pipeline (integrated into chat)

### Timeline
```
Week 1-2: SafTensors Loading + Embedding
Week 3-4: Single Layer Forward + Token Generation
Week 5-6: Full 24-Layer Pipeline + Chat Integration
Week 7-8: Testing, Optimization, Production Readiness
```

---

## 🎯 PHASE 2 BREAKDOWN: Detailed Steps

### STEP 1: Understand SafTensors Format

**Duration**: 1-2 days  
**File**: `safetensors_parser_phase2a.s` ✅ (Already created)  
**Status**: Planning document complete

**What You Need to Know**:
```
File Structure:
  Bytes [0-7]:    Header length N (uint64, little-endian)
  Bytes [8:8+N]:  JSON metadata
  Bytes [8+N:]:   Binary weight data

JSON Metadata Example:
{
  "model.embed_tokens.weight": {
    "dtype": "BF16",
    "shape": [151936, 896],
    "data_offsets": [8192, 272310528]
  },
  ...
}
```

**Action**:
- Read and understand the format doc
- Sketch the binary parsing flow
- No coding required yet

---

### STEP 2: Implement Binary I/O (Phase 2B)

**Duration**: 2-3 days  
**Files to Create**: 
- `safetensors_loader_phase2b.s`

**What to Implement**:
```s
// Read binary file
func read_binary_file(string path) []int {
    // Use intrinsic: __host_read_binary_file(path) → []int
    // This returns raw bytes from file
}

// Parse header
func parse_header([]int bytes) int {
    // Extract first 8 bytes
    // Convert from little-endian to integer
    // Return header length
}

// Extract JSON metadata
func extract_json_metadata([]int bytes, int header_len) string {
    // Read bytes [8:8+header_len]
    // Return as string (JSON)
}
```

**Test Success Criteria**:
```
Input: /home/shuwen/shuwen/posttrain/model.safetensors
Expected Output:
  - Header length: ~12000 bytes
  - JSON with 291 tensors listed
  - Sample: model.embed_tokens.weight → [151936, 896]
```

---

### STEP 3: Load Embedding Matrix (Phase 2C)

**Duration**: 3-4 days  
**Files to Create**: 
- `embedding_loader.s`

**What to Implement**:
```s
// Load embedding from file
func load_embedding_matrix(string model_path) [][]float {
    // Step 1: Parse file header → get offset
    // Step 2: Read bytes from file[offset:offset+size]
    // Step 3: Convert BF16 bytes → float32 values
    // Return: [151936, 896] matrix
}

// BF16 to float32 conversion
func bf16_to_float32(int bf16_value) float {
    // BF16 = 16-bit truncated float32
    // Shift left 16 bits, add 16 zero bits, interpret as float32
    float value
    value
}
```

**Test Success Criteria**:
```
func main() {
    [][]float embedding = load_embedding_matrix(model_path)
    
    // Verify shape
    assert(embedding.length == 151936)  // vocab size
    assert(embedding[0].length == 896)  // hidden size
    
    // Verify values are reasonable floats
    float first_val = embedding[0][0]
    assert(first_val > -10.0 && first_val < 10.0)
    
    print("✓ Embedding loaded successfully")
}
```

---

### STEP 4: Tokenizer Implementation (Phase 2D)

**Duration**: 3-4 days  
**Files to Create**: 
- `tokenizer_bpe.s`

**What to Implement**:
```s
// Tokenize input text
func tokenize(string text) []int {
    // Load BPE vocabulary from:
    //   /home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct/tokenizer.json
    // Apply BPE algorithm:
    //   1. Split text into characters
    //   2. Apply merge rules iteratively
    //   3. Map merged tokens to token IDs
    // Return: [token_id1, token_id2, ...]
}

// Simple version for testing:
func simple_tokenize(string text) []int {
    // For MVP: just return fixed token IDs
    // Real implementation loads tokenizer.json
    []int result
    result
}
```

**Test Success Criteria**:
```
Input: "糖尿病"
Output: [token_id1, token_id2, token_id3]  // 3-5 tokens

Verify:
  - Each token_id in range [0, 151643]
  - No empty results
  - Consistent output for same input
```

---

### STEP 5: Single Layer Forward Pass (Phase 2E)

**Duration**: 4-5 days  
**Files to Create**: 
- `tensor_ops.s` (basic matrix operations)
- `transformer_layer_real.s` (layer computation)

**What to Implement** (Layer 1 only):

```s
// Matrix multiplication (most critical)
func matmul([][]float a, [][]float b) [][]float {
    // Compute C = A @ B
    // Handle shapes: [M, K] @ [K, N] → [M, N]
}

// Layer normalization
func rms_norm([]float input, []float weight) []float {
    // Compute: output = input / sqrt(mean(input^2)) * weight
}

// Multi-head attention (14 heads)
func multihead_attention(
    []float hidden,
    [][]float w_q, [][]float w_k, [][]float w_v, [][]float w_o
) []float {
    // Project to Q, K, V
    // Split into 14 heads
    // Compute scaled dot-product attention
    // Merge heads and project output
}

// Feed-forward network
func feedforward(
    []float hidden,
    [][]float w_gate, [][]float w_up, [][]float w_down
) []float {
    // hidden_gated = GELU(hidden @ w_gate)
    // hidden_up = hidden_gated * (hidden @ w_up)
    // output = hidden_up @ w_down
}

// Full layer forward
func transformer_layer_forward(
    []float hidden,
    int layer_id,
    map[string][][]float weights  // Loaded layer weights
) []float {
    // Step 1: Input normalization
    // Step 2: Self-attention
    // Step 3: Residual connection
    // Step 4: Feed-forward normalization
    // Step 5: Feed-forward network
    // Step 6: Residual connection
    // Return: [896] output
}
```

**Test Success Criteria**:
```
Input: [896] hidden state
Processing: layer_1_forward(hidden)
Output: [896] transformed state

Verify:
  - Output shape matches input ✓
  - Output values are reasonable floats ✓
  - Computation doesn't crash ✓
```

---

### STEP 6: Complete Pipeline (Phase 2F)

**Duration**: 2-3 days  
**Files to Create**: 
- `model_inference_complete.s`

**What to Implement**:
```s
func generate_single_token(string prompt) string {
    // Step 1: Tokenize input
    []int token_ids = tokenize(prompt)
    
    // Step 2: Load embedding
    int first_token = token_ids[0]
    []float hidden = embedding[first_token]  // [896]
    
    // Step 3: Forward through Layer 1
    hidden = transformer_layer_forward(hidden, 0, layer_weights[0])
    
    // Step 4: Check output shape
    assert(hidden.length == 896)
    
    // For now: just return proof that computation worked
    return "Single token generation successful"
}
```

**Test Success Criteria**:
```
✓ Tokenization works
✓ Embedding lookup works
✓ Layer 1 forward works
✓ Output shape correct
→ Ready for Phase 3 (add remaining 23 layers)
```

---

## 📂 FILE ORGANIZATION

```
neurx/inference/
├── model_integration.s                    ✅ Architecture overview
├── safetensors_parser_phase2a.s           ✅ Format documentation
│
├── safetensors_loader_phase2b.s           Phase 2B
├── embedding_loader.s                     Phase 2C
├── tokenizer_bpe.s                        Phase 2D
├── tensor_ops.s                           Phase 2E
├── transformer_layer_real.s               Phase 2E
├── model_inference_complete.s             Phase 2F
│
└── tests/
    ├── test_embedding_load.s
    ├── test_tokenizer.s
    ├── test_layer_forward.s
    └── test_single_token_gen.s
```

---

## 🧩 DEPENDENCIES & DATA FILES

### Required Model Files
```
/home/shuwen/shuwen/posttrain/model.safetensors (1.9GB)
  ├─ Embedding: [151936, 896]
  ├─ 24 Transformer layers
  └─ LM Head: [896, 151936]

/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct/
  └─ tokenizer.json (BPE vocabulary, 151643 tokens)
```

### S Language Intrinsics Used
```s
__host_read_binary_file(path) → []int
  └─ Read entire file as array of bytes

__host_slice(string, start, end) → string
  └─ Extract substring (already used)

print(string) → void
  └─ Output to console (already used)
```

### Data Type Definitions
```s
// Matrix/tensor types
[]float              // 1D vector
[][]float            // 2D matrix
int                  // Indices, sizes

// No structs or complex types to avoid S language limitations
```

---

## ✅ SUCCESS METRICS

### Phase 2 Completion Checklist

- [ ] **SafTensors Parser** (Phase 2B)
  - [ ] Read header successfully
  - [ ] Extract JSON metadata
  - [ ] Parse tensor offsets

- [ ] **Embedding Loader** (Phase 2C)
  - [ ] Load [151936, 896] matrix
  - [ ] Verify shape and values
  - [ ] Single embedding lookup works

- [ ] **Tokenizer** (Phase 2D)
  - [ ] Load vocabulary
  - [ ] Convert text → token IDs
  - [ ] Handle special tokens

- [ ] **Layer Forward** (Phase 2E)
  - [ ] Implement matmul
  - [ ] Implement RMSNorm
  - [ ] Implement attention
  - [ ] Implement FFN
  - [ ] Layer 1 produces correct output shape

- [ ] **Single Token** (Phase 2F)
  - [ ] End-to-end: prompt → token
  - [ ] All computations verified
  - [ ] Performance acceptable

---

## 🎓 LEARNING PATH

### Essential Concepts

1. **SafTensors Format**
   - Binary file layout
   - Little-endian encoding
   - JSON metadata parsing

2. **BF16 Floating Point**
   - 16-bit truncated float32
   - Conversion to full precision
   - Numerical stability

3. **Transformer Architecture**
   - Multi-head attention mechanism
   - Feed-forward network structure
   - Layer normalization (RMSNorm)
   - Residual connections

4. **Matrix Operations**
   - Matrix multiplication (matmul)
   - Element-wise operations
   - Tensor reshaping/slicing

### Recommended Study Order
1. Read SafTensors format documentation
2. Understand BF16 conversion
3. Study transformer layer computation
4. Review matrix operation implementations

---

## 🔧 BUILD & TEST COMMANDS

### Compilation
```bash
cd /home/shuwen/shuwen/neurx

# Compile individual module
NEURX_ROOT=$(pwd) /home/shuwen/shuwen/s/bin/s_seed \
  inference/module_name.s \
  artifacts/build/production_s_inference/module_name.ir

# Run compiled module
/home/shuwen/shuwen/neurx/artifacts/build/s_runner/s_ir_runner \
  artifacts/build/production_s_inference/module_name.ir
```

### Testing
```bash
# Run all tests
make test-model-inference

# Run specific test
make test-embedding-load
make test-layer-forward
```

---

## 📝 PROGRESS TRACKING

Use this template to track daily progress:

```markdown
## Day N Progress

### Completed
- [ ] Task 1
- [ ] Task 2

### Blockers
- Issue: ...
- Resolution: ...

### Next
- [ ] Next task

### Code Stats
- Lines written: XXX
- Files modified: X
- Errors fixed: X
```

---

## 🚨 COMMON PITFALLS

### ❌ Don't Do This
- **Structs with array fields**: S doesn't support `struct { []float data; }`
- **Tuple returns**: Can't return `(a, b, c)`
- **Complex generics**: No template support
- **String comparisons with `<`**: Use `==` or `!=`

### ✅ Do This Instead
- Use flat arrays with size metadata
- Return single values, multiple calls if needed
- Use loops and conditionals
- Compare only with `==`, `!=`, or arithmetic

---

## 📞 REFERENCE DOCUMENTATION

**Files to Review**:
- [MODEL_INFERENCE_ROADMAP.md](./MODEL_INFERENCE_ROADMAP.md) - High-level architecture
- [model_integration.s](./model_integration.s) - Complete pipeline demonstration
- [safetensors_parser_phase2a.s](./inference/safetensors_parser_phase2a.s) - Format documentation

**External Resources**:
- SafTensors Spec: https://github.com/huggingface/safetensors
- BF16 Format: IEEE 754 truncation
- Transformer Paper: "Attention Is All You Need"

---

## 🎉 PHASE 2 COMPLETE

Once you finish all phases and tests pass:

1. Commit with message: `"feat: Complete real model inference pipeline - Phase 2"`
2. Tag release: `git tag -a v2.0.0 -m "Real model inference ready"`
3. Update chat to use real model instead of rules
4. Test with production data

---

**Document Version**: 1.0  
**Last Updated**: 2026-08-06  
**Status**: 🚀 Ready to begin Phase 2B  
**Next Review**: Upon completion of Phase 2B
