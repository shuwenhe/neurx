# Phase 2A Implementation Plan: Token→Logits Training

**Date**: 2026-07-27  
**Current State**: Lightweight LoRA training closure (text vectors → feature loss)  
**Target State**: Real Transformer SFT (tokens → embeddings → transformer → logits → CrossEntropy)

---

## Why Phase 2A?

Current training is working but simplified:
- ❌ No real tokenization (uses text→vector hashing)
- ❌ No embedding layer (direct vector featurization)
- ❌ No transformer forward pass (implicit in loss)
- ❌ Feature loss (not CrossEntropy)
- ❌ No logits prediction

Result: Loss decreases, weights update, but **semantics unknown**.

Phase 2A fixes this: Make training mathematically identical to real LLM fine-tuning.

---

## Implementation Roadmap

### Step 1: Load Real Tokenizer + Embeddings (Week 1)

**File**: `scripts/train_lora_with_embeddings.py`

```python
# Current
x = text_to_vector(sample["prompt"], hidden_size)
loss = mse_loss(lora_output, target_vector)

# Phase 2A
tokenizer = load_tokenizer(model_path)
tokens = tokenizer.encode(sample["prompt"])
embeddings = model.embed_tokens(tokens)  # Real embedding layer
# Forward pass through transformer
```

**Changes needed**:
1. Use Hugging Face tokenizer from model
2. Load actual embedding weights from base model
3. Pass through embedding layer before LoRA

**Verification**:
- Embedding dimension matches model (4096 for Qwen)
- Token sequences are valid
- Embeddings have expected shapes

---

### Step 2: Implement Transformer Forward Pass (Week 2)

**File**: `scripts/transformer_forward.py` (new)

```python
class TransformerInference:
    def __init__(self, model, lora_modules):
        self.model = model
        self.lora = lora_modules
    
    def forward(self, input_ids):
        # 1. Tokenize
        x = self.model.embed_tokens(input_ids)
        
        # 2. Forward through 24 layers
        for layer_idx in range(24):
            # Get layer
            layer = self.model.layers[layer_idx]
            
            # LoRA injection
            if layer_idx < len(self.lora):
                lora_module = self.lora[layer_idx]
                # q_proj = original + lora_A @ lora_B.T
                # v_proj = original + lora_A @ lora_B.T
            
            # Transformer forward
            x = layer(x, attention_mask=None)
        
        # 3. Get logits
        logits = self.model.lm_head(x)  # (seq_len, vocab_size)
        return logits
```

**Critical points**:
- All 24 layers must process
- LoRA must inject into q_proj and v_proj
- Scaling factor: alpha / rank
- Output is (seq_length, vocab_size)

**Verification**:
- Logits have correct shape
- Logits are reasonable (not NaN/Inf)
- Output probability distribution is valid

---

### Step 3: CrossEntropy Loss (Week 2)

**File**: `scripts/loss_functions.py` (new)

```python
def cross_entropy_loss(logits, target_tokens):
    """
    logits: (seq_len, vocab_size)
    target_tokens: (seq_len,)
    
    Standard LLM loss: -log(P(target))
    """
    seq_len, vocab_size = logits.shape
    loss = 0.0
    
    for i in range(seq_len):
        # Softmax
        logit_row = logits[i]
        max_logit = max(logit_row)
        exp_logits = [math.exp(l - max_logit) for l in logit_row]
        sum_exp = sum(exp_logits)
        probs = [e / sum_exp for e in exp_logits]
        
        # Cross entropy
        target_idx = target_tokens[i]
        if 0 <= target_idx < vocab_size:
            loss += -math.log(probs[target_idx] + 1e-8)
    
    return loss / seq_len
```

**Key differences from current**:
- Logit-based (not feature-based)
- Sparse target (single correct token)
- Natural probability interpretation

**Verification**:
- Loss decreases during training (real convergence)
- Loss is positive (log probability is negative)
- Loss ranges are interpretable (e.g., 2-3 for random guessing)

---

### Step 4: Backward Pass through Transformer (Week 3)

**File**: `scripts/transformer_backward.py` (new)

```python
def backward_through_lora(loss, modules, alpha, rank):
    """
    Backprop through:
    CrossEntropy Loss → Logits → Transformer → LoRA
    """
    
    # 1. dL/d(lm_head)
    dloss_dlogits = compute_softmax_gradient(logits, target_tokens)
    
    # 2. dL/d(layer_output)
    dloss_dlayer_output = lm_head.backward(dloss_dlogits)
    
    # 3. Through all 24 layers (reverse order)
    for layer_idx in range(23, -1, -1):
        layer = model.layers[layer_idx]
        
        # 3a. Layer internal gradient
        dloss_dinput = layer.backward(dloss_dlayer_output)
        
        # 3b. LoRA gradient
        if layer_idx < len(modules):
            lora = modules[layer_idx]
            
            # dL/dB = dL/doutput @ doutput/dB
            grad_B = compute_lora_b_gradient(dloss_dinput)
            
            # dL/dA = dL/doutput @ doutput/dA
            grad_A = compute_lora_a_gradient(dloss_dinput)
            
            # Update with SGD
            lora.B -= lr * grad_B
            lora.A -= lr * grad_A
        
        dloss_dlayer_output = dloss_dinput
```

**Complexity here**:
- Implement 24 layer backprop (non-trivial)
- LoRA gradient chain is A→projection→output
- Must maintain numerical stability

**Verification**:
- Gradient norms are reasonable (not exploding/vanishing)
- Loss decreases across epochs
- Gradients are specific to LoRA modules (not frozen base)

---

### Step 5: Integration & Testing (Week 3)

**File**: `scripts/train_lora_transformer.py` (new)

```python
def train_epoch(model, lora_modules, examples, alpha, rank, learning_rate):
    """Complete training loop with real transformer"""
    
    total_loss = 0.0
    for example in examples:
        # Tokenize
        prompt_tokens = tokenizer.encode(example["prompt"])
        answer_tokens = tokenizer.encode(example["answer"])
        
        # Forward
        logits = forward_pass(model, lora_modules, prompt_tokens, alpha, rank)
        
        # Loss (predict answer_tokens given prompt)
        loss = cross_entropy_loss(logits[-len(answer_tokens):], answer_tokens)
        
        # Backward
        backward_through_lora(loss, lora_modules, alpha, rank)
        
        # Update LoRA
        for module in lora_modules:
            apply_gradient_clipping(module, max_norm=1.0)
        
        total_loss += loss
    
    return total_loss / len(examples)
```

**Testing checklist**:
- [ ] Forward pass produces valid logits
- [ ] Loss is interpretable (2-3 for random guessing on 50k vocab)
- [ ] Backward pass computes gradients
- [ ] Gradients flow through LoRA only (base model frozen)
- [ ] Loss decreases over epochs
- [ ] No NaN/Inf values during training

---

## Comparison: Current vs Phase 2A

| Component | Current | Phase 2A |
|-----------|---------|----------|
| Input | Text string | Token sequence |
| Processing | text→vector hashing | tokenizer + embedding |
| Forward | Implicit feature projection | Transformer 24 layers |
| Loss | MSE on features | CrossEntropy on logits |
| Output | Feature vector | Probability distribution |
| Training semantics | Unknown | Standard LLM SFT |
| Validation | "Weights changed" | "Model predicts better" |

---

## Success Criteria

✅ **Phase 2A Complete When**:

1. **Forward Pass**:
   - Logits shape: `(seq_len, vocab_size)`
   - Logits numeric range: reasonable (-10 to +10)
   - No NaN/Inf values

2. **Loss Function**:
   - CrossEntropy implemented correctly
   - Loss ≈ 10-12 for random guessing (50k vocab)
   - Loss decreases across epochs

3. **Backward Pass**:
   - Gradients computed for all LoRA weights
   - Gradient norms: reasonable (1e-4 to 1e-2)
   - Loss changes with SGD step (not constant)

4. **Integration**:
   - Full pipeline runs without errors
   - training_state.json shows convergence
   - Weights saved as valid safetensors

5. **Verification**:
   - `make verify-posttrain` shows meaningful deltas
   - Delta statistics increase with epochs
   - Loss history is monotonic (mostly)

---

## Architecture Decisions

### Keep from Phase 1:
- ✅ Safetensors serialization (works perfectly)
- ✅ LoRA rank=8, alpha=16 configuration
- ✅ SGD optimizer with gradient clipping
- ✅ Reproducible seed-based training

### Replace in Phase 2A:
- ❌ text_to_vector → tokenizer + embedding
- ❌ Feature loss → CrossEntropy
- ❌ Implicit forward → Explicit transformer loop
- ❌ Generic gradient → Transformer-specific backward

### Keep Python Helper:
- Yes (until Phase 3 pure-S implementation)
- Will add transformer weights loading
- Better for testing/iteration

---

## Timeline

- **Week 1**: Tokenizer + embedding loading, verified shapes
- **Week 2**: Transformer forward pass, CrossEntropy loss  
- **Week 3**: Backward pass, integration, testing

**Total**: 3 weeks for production-ready Phase 2A

---

## Open Questions

1. **Sequence length**: How long should training sequences be? (Current: variable, could set to fixed 512)
2. **Batch size**: Still 1 sample? Should we group multiple examples?
3. **Gradient accumulation**: Support multiple backward passes before update?
4. **Learning rate**: Should 0.01 work for transformer, or need to scale?
5. **Loss normalization**: Per-token or per-example?

---

## Success Signal

When Phase 2A is complete, we can answer definitively:
- **"Is the model learning language?"** vs. just updating weights
- **"Can we predict the right next tokens?"** vs. generic feature loss
- **"Is this real SFT?"** Yes, mathematically identical to production training

That's the bridge from Phase 1 (proven gradients) to Phase 3 (pure S implementation).
