# NeurX truthfultrainingimplementationEnglish text

## English text

### ✅ English textimplementationEnglish text
1. **English text** (`tensor/`)
   - `matmul2d` - English text
   - English textfunction(ReLU, GELUEnglish text)
   - English text

2. **lossfunction** (`loss/losses.s`)
   - `cross_entropy_loss` - completeEnglish textlossimplementation
   - English textlog_softmax
   - Perplexity compute

3. **modelEnglish text** (`model/llm/`)
   - `gpt_large_training_state` - trainingstatemanagement
   - `gpt_large_training_update` - completeEnglish text/English text
   - `gpt_large_training_loss` - losscompute

4. **datamanagement** (`data/dataloader.s`)
   - English textdataload
   - Token English textmanagement
   - dataEnglish text

5. **optimizeEnglish text** (`optimizer/optim.s`)
   - AdamW optimizeEnglish textimplementation
   - learning rateEnglish text

### ❌ RequiredEnglish text

1. **gradientcompute**
   - `transformer_backward` - Transformer English text
   - `embedding_apply_grad` - Embedding gradientEnglish text
   - English text
   - FFN English text

2. **English texttraining**
   - implementation DDP AllReduce
   - gradientEnglish textstep
   - modelEnglish textsupport

3. **GPU English text** (English text)
   - CUDA kernel English text
   - GPU English textmanagement
   - English texttraining

## English textimplementationstepEnglish text

### Step 1: English text
English textfunctionEnglish text:
```
- transformer_forward()
- embedding_lookup()
- cross_entropy_loss()
```

### Step 2: implementationEnglish text
English textimplementationEnglish textfunction:
```s
func transformer_backward(
    transformer backbone,
    tensor hidden,
    tensor grad_hidden,
    []transformer_layer_optimizer_state optimizers
) gpt_large_backward_result

struct gpt_large_backward_result {
    transformer updated_backbone
    tensor grad_input
    []transformer_layer_optimizer_state backbone_optimizers
}
```

### Step 3: English textgradientEnglish text
English text `adamw_step_state()` English textparameter:
```s
func adamw_step_state(
    adamw_optimizer opt,
    tensor params,
    tensor grad
) adamw_step_output
```

### Step 4: runtruthfultraining
useEnglish textstartEnglish text:
```bash
cd /home/shuwen/shuwen/train/neurx
make train-real
```

## fileEnglish text

### English texttrainingfile
- `scripts/legacy/run_real_training.s` - ✨ English texttruthfultrainingstartEnglish text(English text)
- `pretrain/llm/large_pretrain.s` - maintrainingEnglish text(RequiredEnglish text)
- `model/llm/model_large_train.s` - trainingEnglish textfunction(RequiredEnglish text)

### English textgradientfunction (Requiredimplementation/English text)
- `tensor/core.s` - `matmul_backward`, `embedding_backward`
- `model/llm/model_backward.s` - Transformer English text
- `nn/attention.s` - English text
- `nn/ffn.s` - FFN English text

## English text

### English text
- [ ] dataloadEnglish textbatch
- [ ] Embedding English textquery
- [ ] English textcomputeEnglish text NaN/Inf
- [ ] FFN English textfunctionEnglish text
- [ ] output logits English text

### English text
- [ ] lossgradientcomputeEnglish text
- [ ] gradientEnglish textparameterEnglish text
- [ ] English textgradientEnglish text/English text
- [ ] parameterEnglish text

### trainingEnglish text
- [ ] lossEnglish text(English text100step)
- [ ] gradientEnglish text [0.1, 10.0]
- [ ] English text NaN/Inf lossEnglish text
- [ ] learning rateEnglish text

## English text

### English texttrainingEnglish text
1. English textlearning rate(English text)
2. English text(English text)
3. English textgradientEnglish textcompute
4. English textgradientEnglish text (gradient clipping)

### English text NaN/Inf
1. English text(log_softmax, softmax)
2. English text embedding English text
3. English text
4. usegradientEnglish texttool

### English textoptimize
1. English textgradientEnglish textuse
2. useEnglish texttraining (BF16)
3. English textgradientcheckpoint (gradient checkpointing)
4. implementationEnglish text

## English text

- [x] English texttruthfultrainingstartEnglish text
- [ ] implementation Transformer English text
- [ ] English textgradientcomputeEnglish text
- [ ] English text GPU support (English text)
- [ ] implementationEnglish texttraining
- [ ] English textoptimize

## English text

- English text: `neurx/tensor/*.s`
- lossfunction: `neurx/loss/losses.s`
- modelEnglish text: `neurx/model/llm/*.s`
- dataEnglish text: `neurx/data/dataloader.s`
