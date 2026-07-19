# NeurX English textmodeltraining - quickstartEnglish text

## 📚 directory

1. [quickstart](#quickstart)
2. [configurationEnglish text](#configurationEnglish text)
3. [completeEnglish text](#completeEnglish text)
4. [trainingEnglish textexplanation](#trainingEnglish textexplanation)
5. [English text](#English text)
6. [English text](#English text)

---

## quickstart

### English textstarttraining

```bash
cd /Users/feifei/shuwen/neurx
bash run_train_large_model.sh
```

English text:
- ✓ English textScompileEnglish text
- ✓ English textdirectoryEnglish text
- ✓ generateexampletrainingdata
- ✓ compiletrainingEnglish text
- ✓ starttrainingEnglish text

### outputEnglish textcheckpoint

trainingEnglish text, English text:

```
./checkpoints/large_model/    # saveEnglish textmodelcheckpoint
./output/large_model/         # traininglogEnglish textoutput
./data/large_model/           # trainingdata
  ├── train.jsonl             # trainingEnglish text
  └── val.jsonl               # English text
```

---

## configurationEnglish text

### modelconfiguration

```json
{
  "model": {
    "vocab_size": 128000,      // English text
    "hidden_dim": 768,         // English text
    "num_layers": 12,          // TransformerEnglish text
    "num_heads": 12,           // English text
    "ffn_dim": 3072,           // English text (4 × hidden_dim)
    "max_seq_len": 4096,       // English text
    "dropout_prob": 0.1        // DropoutEnglish text
  }
}
```

**explanation: **
- `vocab_size`: English text(English textLLMEnglish text100K+)
- `hidden_dim`: modelEnglish textparameter
- `num_heads`: English text `hidden_dim`(English text hidden_dim/head_dim = 64)
- `num_layers`: modelEnglish text, English textcomputeEnglish text

### trainingEnglish textparameter

```json
{
  "training": {
    "batch_size": 32,                        // English text
    "micro_batch_size": 8,                   // English text
    "gradient_accumulation_steps": 4,        // gradientEnglish textstepEnglish text
    "max_steps": 100000,                     // English texttrainingstepEnglish text
    "warmup_steps": 1000,                    // learning rateEnglish textstepEnglish text
    "eval_steps": 500,                       // evaluationEnglish text
    "save_steps": 1000,                      // savecheckpointEnglish text
    "log_steps": 10                          // logEnglish text
  }
}
```

**English textparameterexplanation: **

| parameter | English text | English text |
|------|------|------|
| batch_size | English text | 32-256 |
| warmup_steps | learning rateEnglish text0English textpeakEnglish textstepEnglish text | English textstepEnglish text1-10% |
| max_grad_norm | gradientEnglish text | 1.0-2.0 |

### optimizeEnglish textconfiguration

```json
{
  "optimizer": {
    "name": "adamw",           // optimizeEnglish text
    "learning_rate": 5e-4,     // English textlearning rate
    "beta1": 0.9,              // Adam β₁ (English text)
    "beta2": 0.999,            // Adam β₂ (English text)
    "epsilon": 1e-8,           // English text
    "weight_decay": 0.01,      // L2English text
    "max_grad_norm": 1.0,      // gradientEnglish text
    "lr_schedule": "cosine"    // learning rateEnglish text: "linear", "cosine", "constant"
  }
}
```

**AdamW English text: **

$$m_t = \beta_1 m_{t-1} + (1-\beta_1) g_t$$
$$v_t = \beta_2 v_{t-1} + (1-\beta_2) g_t^2$$
$$\hat{m}_t = \frac{m_t}{1-\beta_1^t}, \quad \hat{v}_t = \frac{v_t}{1-\beta_2^t}$$
$$\theta_t = \theta_{t-1} - \alpha \left(\frac{\hat{m}_t}{\sqrt{\hat{v}_t}+\epsilon} + \lambda \theta_{t-1}\right)$$

---

## completeEnglish text

### 1️⃣ English text (Multi-Head Attention)

English text `attention/attention_complete.s`:

- ✓ Query/Key/Value English textweight
- ✓ English text
- ✓ English text
- ✓ completeEnglish text

**English text: **
```
Attention(Q, K, V) = softmax(QK^T / √d_k)V
```

### 2️⃣ English text (Automatic Differentiation)

English text `ml/autodiff_complete.s`:

- ✓ English textcomputeEnglish text
- ✓ 7English textsupport(add, mul, matmul, relu, softmax, layer_norm)
- ✓ English textrankingEnglish text
- ✓ gradientEnglish textmanagement

**supportEnglish textgradientEnglish text: **

| English text | English text | English text |
|------|------|------|
| add(a,b) | a+b | ∂L/∂a=∂L/∂y, ∂L/∂b=∂L/∂y |
| mul(a,b) | a×b | ∂L/∂a=b·∂L/∂y, ∂L/∂b=a·∂L/∂y |
| matmul(a,b) | a@b | ∂L/∂a=∂L/∂y@b^T, ∂L/∂b=a^T@∂L/∂y |
| softmax(x) | exp(x)/Σexp(x) | ∂L/∂x = p·(∂L/∂y - (p·∂L/∂y).sum()) |
| relu(x) | max(0,x) | ∂L/∂x = ∂L/∂y if x>0 else 0 |

### 3️⃣ AdamW optimizeEnglish text

English text `optimizer/optimizer_adamw.s`:

- ✓ English text(Adaptive Learning Rate)
- ✓ English text(Bias Correction)
- ✓ weightEnglish text(L2English text)
- ✓ gradientEnglish text(Gradient Clipping)
- ✓ learning rateEnglish text(3English text)

**learning rateEnglish text: **

1. **English text (Linear Decay)**
   ```
   lr(t) = lr_base × (1 - t/T)
   ```

2. **English text (Cosine Annealing)**
   ```
   lr(t) = lr_base × (1 + cos(πt/T)) / 2
   ```

3. **English text (Warmup)**
   ```
   if t < warmup_steps:
       lr(t) = lr_base × t / warmup_steps
   else:
       lr(t) = schedule(t - warmup_steps)
   ```

### 4️⃣ completetrainingEnglish text

English text `train/train_large_model.s`:

- ✓ TransformerEnglish textimplementation
- ✓ English text/English text
- ✓ English textepochtraining
- ✓ parameterEnglish text(AdamW)
- ✓ checkpointsave/load
- ✓ modelevaluation

### 5️⃣ dataloadmanagement

- ✓ JSONLEnglish textdataEnglish text
- ✓ batchEnglish text
- ✓ English text(Shuffling)
- ✓ English text
- ✓ English textdataloadframework

---

## trainingEnglish textexplanation

### train_large_model.s English text

```
┌─ English text1English text: configurationmanagement
│  ├─ TrainingConfig English text
│  └─ default_config() function
│
├─ English text2English text: modelstatemanagement
│  ├─ ModelWeights (parameter)
│  ├─ ModelState (state)
│  └─ init_model_state() function
│
├─ English text3English text: dataload
│  ├─ DataBatch English text
│  ├─ DataLoader English text
│  └─ load_batch() function
│
├─ English text4English text: English text
│  ├─ English text
│  ├─ TransformerEnglish text (Attention + FFN)
│  ├─ outputEnglish text
│  └─ forward_pass() function
│
├─ English text5English text: English text
│  └─ backward_pass() function
│
├─ English text6English text: optimizeEnglish textstepEnglish text
│  ├─ learning rateEnglish text
│  ├─ gradientEnglish text
│  └─ optimizer_step() function
│
├─ English text7English text: checkpointmanagement
│  ├─ save_checkpoint()
│  └─ load_checkpoint()
│
├─ English text8English text: evaluationEnglish text
│  └─ evaluate() function
│
├─ English text9English text: completetrainingEnglish text
│  └─ train_large_model() function
│
└─ English text10English text: mainfunction
   └─ main() function
```

### English textfunctionEnglish text

#### forward_pass()
```s
func forward_pass(
    ModelState model,
    DataBatch batch,
    TrainingConfig cfg
) ForwardOutput
```

English text:
1. English text: input_ids → embeddings
2. English text num_layers TransformerEnglish text
3. outputEnglish text: hidden_states → logits
4. computeEnglish textloss

#### backward_pass()
```s
func backward_pass(
    ModelState model,
    ForwardOutput fwd_output,
    DataBatch batch,
    TrainingConfig cfg
) BackwardOutput
```

English textcomputegradient:
1. useEnglish textcomputecomputeEnglish text
2. English textrankingEnglish text
3. English text
4. English textparameterEnglish textgradient

#### optimizer_step()
```s
func optimizer_step(
    ModelState model,
    BackwardOutput bwd_output,
    TrainingConfig cfg,
    int step
) ModelState
```

optimizeEnglish text:
1. gradientEnglish text
2. computeEnglish textlearning rate
3. English text/English text
4. English text
5. parameterEnglish text(English textweightEnglish text)

---

## English text

### 1️⃣ English textcheckpointrecovertraining

```bash
# English text train_large_model.s
# English text load_checkpoint() English textloadEnglish textmodel

checkpoint_path := "./checkpoints/large_model/model_step_50000.ckpt"
model := load_checkpoint(checkpoint_path, cfg)

# English texttraining
model := train_large_model(cfg)
```

### 2️⃣ English textmodelEnglish text

English text `config_large_model.json`:

```json
{
  "model": {
    "hidden_dim": 1024,    // English text
    "num_layers": 24,      // English text
    "num_heads": 16,       // English text
    "ffn_dim": 4096        // English textFFNEnglish text
  }
}
```

**parameterEnglish text: **
- English textparameter ≈ 12 × L × H × (H + 4H) + V×H
- English text L=English text, H=English text, V=English text

### 3️⃣ English texttrainingconfiguration

English text `config_large_model.json`:

```json
{
  "distributed": {
    "enabled": true,
    "backend": "nccl",
    "world_size": 8,       // 8English textGPU
    "rank": 0,             // English text
    "data_parallel": true  // dataEnglish text
  }
}
```

startEnglish texttraining:

```bash
# use torch.distributed.launch
python -m torch.distributed.launch \
    --nproc_per_node=8 \
    run_train_large_model.sh
```

### 4️⃣ English texttraining

English text `config_large_model.json`:

```json
{
  "mixed_precision": {
    "enabled": true,
    "precision": "float16",  // English text "bfloat16"
    "loss_scale": 1024,
    "loss_scale_type": "dynamic"
  }
}
```

### 5️⃣ gradientEnglish text

usegradientEnglish text:

```json
{
  "training": {
    "batch_size": 256,                  // English text
    "micro_batch_size": 32,             // GPUEnglish text
    "gradient_accumulation_steps": 8    // English text8step
  }
}
```

English text8stepEnglish textparameterEnglish text, English text256English text.

---

## English text

### English text1: English text (OOM)

**English text: ** compileEnglish texterror

**English text: **
1. English text `batch_size`
2. English text `max_seq_len`
3. English textgradientEnglish text
4. English texttraining

```json
{
  "training": {
    "batch_size": 16,
    "micro_batch_size": 4,
    "gradient_accumulation_steps": 4
  }
}
```

### English text2: trainingEnglish text

**English text: ** lossEnglish text

**English text: **
1. English textlearning rateEnglish text
2. English text warmup_steps
3. English textgradientEnglish text
4. English textdataEnglish text

```json
{
  "optimizer": {
    "learning_rate": 1e-4,      // English textlearning rate
    "max_grad_norm": 0.5         // English textgradientEnglish text
  },
  "training": {
    "warmup_steps": 5000         // English text
  }
}
```

### English text3: trainingEnglish text

**English text: ** English textstepEnglish text

**English text: **
1. English text `batch_size`
2. English text `log_steps` (English textlogEnglish text)
3. English texttraining
4. useEnglish textdataloadEnglish text

```json
{
  "training": {
    "batch_size": 64,
    "log_steps": 100
  },
  "mixed_precision": {
    "enabled": true,
    "precision": "bfloat16"
  }
}
```

### English text4: ScompileEnglish text

**English text: ** `ScompileEnglish text: /Users/feifei/train/s/.local/bin/s`

**English text: **
```bash
# English textScompileEnglish text
which s
# English text
find /Users/feifei -name "s" -type f -executable

# English text, English text run_train_large_model.sh
# S_COMPILER="/path/to/s"
```

---

## English text

### English text(English textGPU V100)

| configuration | English text(tokens/s) | English text(GB) | trainingEnglish text |
|------|------------------|---------|---------|
| English text (L=12, H=768) | 500-800 | 24 | quick |
| English text (L=24, H=1024) | 200-400 | 30 | English text |
| English text (L=32, H=1600) | 50-100 | 40+ | English text |

### optimizeEnglish text

1. **useFlash Attention:** English text $O(n^2)$ English text $O(n)$
2. **English textgradientcheckpoint: ** English text
3. **useEnglish text: ** 2English text
4. **English texttraining: ** dataEnglish text, English text, English text

---

## outputexample

```
═══════════════════════════════════════════════════════════
🚀 NeurX English textmodeltraining - completeEnglish text
═══════════════════════════════════════════════════════════

 stepEnglish text 1 modelinitialize
─────────────────────────────────────────────────────────
✓ modelinitializeEnglish text
  • English textparameterEnglish text: 124,439,552

 stepEnglish text 2 dataloadEnglish textinitialize
─────────────────────────────────────────────────────────
✓ dataloadEnglish textinitializeEnglish text
  • English text: 32
  • English text: 4096

 stepEnglish text 3 starttraining
─────────────────────────────────────────────────────────

Step 0 / 100000
  • batchloss: 5.2
  • English textloss: 5.2
  • gradientEnglish text: 1.5
  • English text tokens: 131072

Step 10 / 100000
  • batchloss: 4.8
  • English textloss: 5.0
  • gradientEnglish text: 1.2
  • English text tokens: 1310720
  • 🎯 English textlossEnglish text!

...

 stepEnglish text 4 trainingEnglish text
─────────────────────────────────────────────────────────
✓ trainingEnglish text
  • English textstepEnglish text: 100
  • English textloss: 4.2
  • English text tokens English text: 13107200

═══════════════════════════════════════════════════════════
✅ trainingsuccessEnglish text!
═══════════════════════════════════════════════════════════

📊 English textstatistics:
  • English textparameterEnglish text: 124,439,552
  • English text tokens: 13,107,200
  • Adam stepEnglish text: 100

💾 checkpointEnglish text: ./checkpoints/large_model
📈 outputdirectory: ./output/large_model
```

---

## English textstep

1. **inference:** loadcheckpointEnglish textinferenceEnglish textgenerate
2. **evaluation:** English textevaluationmodelEnglish text
3. **English text:** English text
4. **English text:** English textmodelEnglish text
5. **optimize:** useEnglish text, English textoptimizemodel

---

## English text

- [Attention is All You Need](https://arxiv.org/abs/1706.03762) - TransformerEnglish text
- [An Image is Worth 16x16 Words](https://arxiv.org/abs/2010.11929) - ViTEnglish textAttentionEnglish text
- [BERT: Pre-training of Deep Bidirectional Transformers](https://arxiv.org/abs/1810.04805) - English texttrainingEnglish text
- [Language Models are Unsupervised Multitask Learners](https://d4mucfpksywv.cloudfront.net/better-language-models/language_models_are_unsupervised_multitask_learners.pdf) - Model-v2English text

---

**English texttrainingEnglish text!** 🚀

English text, English textlogEnglish textrunEnglish text:

```bash
DEBUG_MODE=true bash run_train_large_model.sh
```
