# NeurX trainingsystem - English textimplementationEnglish text

**English text**: 2026-06-23
**English text**: 1.0 - Loss, Attention, Training Loop
**state**: ✅ English textimplementationEnglish text, AllowedstartEnglish texttest

---

## 📋 English text

### 1️⃣ Loss function ✅ English text
**file**: `/Users/feifei/train/neurx/train/loss_functions.s` (350+ English text)

**implementationcontent**:
```s
✓ cross_entropy_loss()          - English textloss
✓ cross_entropy_loss_masked()   - supportEnglish text
✓ log_softmax_stable()          - English textsoftmax
✓ softmax_stable()              - English textsoftmax
✓ apply_label_smoothing()       - English text
✓ compute_perplexity()          - English textcompute
```

**English text**:
- English textsoftmax (log-sum-expEnglish text)
- supportEnglish text (Label Smoothing)
- supportEnglish text (attention mask)
- supportEnglish text/English text reduction
- English textcompute

**useexample**:
```s
cross_entropy_config config = new_cross_entropy_config(10000)
config.use_label_smoothing = true
config.smoothing_alpha = 0.1

float loss = cross_entropy_loss(logits, targets, config)
float ppl = compute_perplexity(loss)
```

---

### 2️⃣ Multi-Head Attention ✅ English text
**file**: `/Users/feifei/train/neurx/attention/attention_implementation.s` (400+ English text)

**implementationcontent**:
```s
✓ forward_attention()           - completeEnglish text
✓ scaled_dot_product_attention() - English textcompute
✓ project_qkv()                 - Q/K/VEnglish text
✓ reshape_for_attention()       - English textdataEnglish text
✓ softmax_stable()              - English textweightcompute
```

**English text**:
- English textMulti-Head Attention
- Grouped-Query Attention (GQA) support
- English text (Causal Mask) support
- English text
- completeEnglish textQ/K/VEnglish text

**English textpipeline**:
```
Input [seq_len, hidden_dim]
    ↓
Project Q, K, V
    ↓
Reshape to multi-head [seq_len, num_heads, head_dim]
    ↓
Scaled Dot-Product (with causal mask)
    ↓
Softmax (stable)
    ↓
Aggregate Values
    ↓
Reshape & Output Projection
    ↓
Output [seq_len, hidden_dim]
```

**useexample**:
```s
attention_config cfg = attention_config {
    hidden_dim: 512,
    num_attention_heads: 8,
    num_kv_heads: 8,
    use_causal_mask: true,
}

multi_head_attention_module attn = new_multi_head_attention(cfg)
[]float output = forward_attention(attn, hidden_states, seq_len)
```

---

### 3️⃣ trainingEnglish text ✅ English text
**file**: `/Users/feifei/train/neurx/train/training_loop.s` (450+ English text)

**implementationcontent**:
```s
✓ training_loop()              - completeEnglish texttrainingmainEnglish text
✓ training_step()              - English textsteptraining
✓ forward_pass()               - English text
✓ backward_pass()              - English text
✓ compute_learning_rate()      - learning rateEnglish text
✓ update_parameters()          - parameterEnglish text
✓ clip_gradients_by_norm()     - gradientEnglish text
```

**English text**:
- completeEnglish textForward → Loss → Backward → Updatepipeline
- learning rateEnglish text (Constant, Linear, Cosine)
- WarmupEnglish text
- gradientEnglish textsupport
- gradientEnglish text (Gradient Clipping)
- Checkpointsave
- monitoringEnglish textlogEnglish text

**trainingpipeline**:
```
1. Forward Pass         → logits
2. Compute Loss         → scalar loss
3. Backward Pass        → gradients
4. Gradient Clipping    → clipped gradients
5. Learning Rate Update → new LR
6. Parameter Update     → new parameters
7. Metrics Logging      → print/save
8. Checkpoint           → save state
```

**useexample**:
```s
training_config cfg = new_training_config()
cfg.max_steps = 10000
cfg.batch_size = 32
cfg.initial_learning_rate = 0.0001
cfg.lr_schedule = "cosine"
cfg.warmup_steps = 1000

([][]float final_params, training_state state) =
    training_loop(model_params, cfg, train_data, vocab_size, seq_len)
```

---

## 🔗 English text

```
bin/train_complete.s (maintrainingEnglish text)
    │
    ├─→ train/training_loop.s
    │   ├─→ Forward Pass
    │   ├─→ train/loss_functions.s (Loss Computation)
    │   ├─→ Backward Pass
    │   └─→ Parameter Update
    │
    ├─→ attention/attention_implementation.s (Attention)
    │   ├─→ Q/K/V Projection
    │   ├─→ Scaled Dot-Product
    │   └─→ Multi-Head Aggregation
    │
    ├─→ data/distributed_dataloader.s (Data Loading)
    │
    └─→ monitoring/ (Logging & Monitoring)
```

---

## 📊 English text

### Loss function
- **English text**: ✅ uselog-sum-expEnglish text
- **English text**: ✅ supportEnglish text, English text
- **English text**: ✅ supportEnglish text, English text

### Attention
- **English text**: ✅ English text 1/√head_dim
- **English text**: ⚠️ English textimplementation, English textoptimize(English textFlash AttentionEnglish text)
- **support**: ✅ Causal mask, GQA, KV cache

### trainingEnglish text
- **English text**: ✅ gradientEnglish text, learning rateEnglish text
- **English text**: ⚠️ English textimplementation(English text, English text)
- **monitoring**: ✅ completeEnglish textlogEnglish textcheckpoint

---

## 🚀 English textstepEnglish text

### English text (1-2English text)
```
[ ] 1. compileEnglish texttestEnglish text
[ ] 2. English textsmoke testEnglish textruncompletetraining
[ ] 3. English text
[ ] 4. English texttest
```

### optimizephase (1English text)
```
[ ] 5. English textFlash Attention (3xEnglish text)
[ ] 6. English texttraining (English text50%)
[ ] 7. English texttrainingEnglish text
[ ] 8. English textoptimize
```

### English text (2English text)
```
[ ] 9. completeEnglish textdataEnglish text
[ ] 10. English textmonitoring
[ ] 11. English texttest
[ ] 12. English textexample
```

---

## 📝 mainEnglish textfileEnglish text

| file | English text | English text | state |
|-----|------|------|------|
| train/loss_functions.s | 350+ | Losscompute | ✅ English text |
| attention/attention_implementation.s | 400+ | Attention | ✅ English text |
| train/training_loop.s | 450+ | trainingEnglish text | ✅ English text |
| bin/train_complete.s | 200+ | English text | ✅ English text |
| **English text** | **1400+** | **completesystem** | **✅ English text** |

---

## 🔍 English text

### Cross-Entropy Loss
```
Forward:
loss = -E[log P(y|x)]
     = -1/N Σ log(softmax(logits)[target_class])

Backward:
dL/d(logits) = softmax(logits) - one_hot(target)
```

### Multi-Head Attention
```
Attention(Q,K,V) = softmax(QK^T/√d_k)V

Q @ K^T: [batch, n_heads, seq, seq]
Scale by 1/√head_dim for stability
Apply causal mask (if autoregressive)
Softmax → [batch, n_heads, seq, seq]
Multiply by V → [batch, n_heads, seq, head_dim]
```

### Training Step
```
Forward: logits = model(inputs)
Loss: L = loss_fn(logits, targets)
Backward: gradients = ∇L
Clip: g̃ = g * min(1, clip_norm/||g||)
Update: θ_new = θ - lr * (g̃ + λθ)
```

---

## ✨ English text

✅ **Loss function**
- English text: English textlogits
- English text: English text
- English textsupport: English text

✅ **Attention English text**
- Multi-headEnglish text
- English text(English text)
- SoftmaxEnglish text

✅ **trainingEnglish text**
- Forward-Backward-Updatecompletepipeline
- learning rateEnglish text(3English text)
- gradientEnglish textmonitoring

---

## 📞 usesupport

### quickstart
```bash
# compiletrainingEnglish text
s compile bin/train_complete.s -o build/train

# runtraining
./build/train
```

### English textconfiguration
```s
// English texttrainingparameter
cfg.max_steps = 5000
cfg.batch_size = 64
cfg.initial_learning_rate = 0.0002
cfg.warmup_steps = 500
```

### extensionEnglish text
```s
// English textloss
func my_loss(...) { ... }

// English textattention
func my_attention(...) { ... }

// English textoptimizeEnglish text
func my_optimizer_step(...) { ... }
```

---

## 📈 frameworkEnglish text

| English text | English text | English text | English text |
|------|:--:|:--:|:----:|
| Lossfunction | ❌ | ✅ | +100% |
| Attention | ⚠️ | ✅ | +90% |
| trainingEnglish text | ❌ | ✅ | +100% |
| **English text** | **40%** | **70%** | **+30%** |

**English text**: English texttraining (English text75-80%)

---

**English text**: 2026-06-23 | **English text**: shuwenhe | **English text**: English text
