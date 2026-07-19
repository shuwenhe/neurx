# Real Training Implementation Guide

## English text

NeurXEnglish texttrainingimplementationEnglish text/English text, English text:
- trainingEnglish text1English text1000step(English text)
- lossEnglish text(11.245 → 5.832 → 4.123 ... → 1.934)
- compileEnglish textIRfileEnglish textstepEnglish textlossEnglish text

English texttrainingEnglish text, English texttruthfulEnglish texttraining.

## English text: English textSlanguagetruthfultrainingimplementation

### English text

#### 1. `real_training.s` - English text
English texttruthfulEnglish textoptimizeEnglish text:

**English textfunction:**
- `relu(tensor)` - ReLUEnglish textfunctionEnglish text
- `softmax_last_dim(tensor)` - English textSoftmax

**lossfunction:**
- `cross_entropy_loss(tensor, tensor)` - English textloss

**English text:**
- `matmul(tensor, tensor)` - English text
- `transpose(tensor, int, int)` - English text
- `sum_first_dim(tensor, bool)` - English text

**optimizeEnglish text:**
- `adamw_update(adamw_state)` - AdamWoptimizeEnglish textstepEnglish text

**gradientcompute:**
- `grad_logits(tensor, tensor)` - outputEnglish textgradient

**English textfunction:**
- `exp_approx(float)` - English text
- `log_approx(float)` - English text
- `sqrt_approx(float)` - English text
- `pow_approx(float, float)` - English textfunctionEnglish text

#### 2. `real_training_loop.s` - trainingEnglish textframework
English textcompleteEnglish texttrainingstepEnglish text:

**mainEnglish textfunction:**
- `init_real_training()` - initializetrainingstateEnglish textparameter
- `forward_pass()` - English text(input → English text → Attention → output)
- `compute_loss()` - losscompute
- `backward_pass()` - English text
- `update_parameters()` - parameterEnglish text
- `training_step()` - English texttrainingstepEnglish text
- `run_training_loop()` - completeEnglish texttrainingEnglish text

#### 3. `real_main_training.s` - English texttrainingmainEnglish text
English textuseEnglish texttrainingsystem:

**configuration:**
```s
struct real_training_config {
    int batch_size              // 32
    int seq_length             // 2048
    int vocab_size             // 32000
    int hidden_dim             // 4096
    int num_layers             // 96
    int num_heads              // 32
    int max_steps              // 1000
    float learning_rate        // 0.0002
    float weight_decay         // 0.1
    float warmup_steps         // 100
    ...
}
```

**learning rateEnglish text:**
- English text(0English textwarmup_steps)
- English text(warmup_stepsEnglish textmax_steps)

**trainingEnglish text:**
- truthfulEnglish text
- English textlosscompute
- AdamWparameterEnglish text
- checkpointsave
- English textlogEnglish text

## English textstepEnglish text

### stepEnglish text1: compiletruthfultrainingEnglish text

```bash
cd /home/shuwen/shuwen/train/neurx

# compiletruthfultrainingEnglish text(English textRequiredEnglish textcompile)
/home/shuwen/s/bin/s compile 'pretrain/llm/real_training.s' -o artifacts/build/real_training.o
/home/shuwen/s/bin/s compile 'pretrain/llm/real_training_loop.s' -o artifacts/build/real_training_loop.o
/home/shuwen/s/bin/s compile 'pretrain/llm/real_main_training.s' -o artifacts/build/real_main_training.o
```

### stepEnglish text2: English textmain()functionEnglish textusetruthfultraining

English text `scripts/legacy/run_large_pretrain.s` English text:

```s
package main

use neurx.pretrain.llm.real_main_training.{
    default_training_config,
    run_real_training_loop
}

// usetruthfultrainingimplementation
func main() int {
    real_training_config config = default_training_config()

    // English text: English textconfiguration
    // config.max_steps = parse_int(env("NEURX_MAX_STEPS", "1000"))
    // config.learning_rate = parse_float(env("NEURX_LR", "0.0002"))

    run_real_training_loop(config)
    0
}
```

### stepEnglish text3: English text

truthfultrainingimplementationRequiredEnglish textNeurXEnglish text.English textfunctionRequiredEnglish text:

**dataload:**
```s
// useEnglish textdataloader
use neurx.data.loader.dataloader.{next_batch, has_next}

// English texttraining_step()English text:
dataloader_step_output batch = next_batch(state.loader)
tensor input_ids = tensor_from_ints(batch.input_ids, [batch_size])
tensor target_ids = tensor_from_ints(batch.target_ids, [batch_size])
```

**modelcompute:**
```s
// useEnglish textmodel
use neurx.model.llm.gpt_large.{gpt_large_state, gpt_large_forward}
use neurx.nn.{embedding_lookup, transformer_forward}

// English textforward_pass()English text:
tensor hidden = embedding_lookup(state.embedding, input_ids, 0)
tensor backbone_out = transformer_forward(state.backbone, hidden)
tensor logits = lm_head_projection(backbone_out, state.lm_head)
```

**optimizeEnglish text:**
```s
// useEnglish textAdamWimplementation
use neurx.optimizer.optim.{adamw_step_state, adamw_step_output}

// English textupdate_parameters()English text:
adamw_step_output result = adamw_step_state(
    state.optimizer,
    weight_param,
    weight_grad
)
state.optimizer = result.optimizer
weight_param = result.params
```

### stepEnglish text4: testtruthfultraining

```bash
# English textcompile
rm -rf artifacts/build/run_large_pretrain/

# compileEnglish texttruthfultrainingEnglish text
make build-train

# runtruthfultraining
make train

# monitoringoutput(English texttruthfulEnglish textlossEnglish text)
tail -f artifacts/logs/run_large_pretrain_*.log
```

## English texttruthfultrainingoutput

```
================================================================================
  Starting Real NeurX Neural Network Pretraining
================================================================================

Configuration:
  Batch Size: 32
  Sequence Length: 2048
  Vocab Size: 32000
  Hidden Dim: 4096
  Num Layers: 96
  Num Heads: 32
  Max Steps: 1000
  Learning Rate: 0.000200
  Weight Decay: 0.1000
  Warmup Steps: 100
  Gradient Clip: 1.0000
  Mixed Precision: true

[Step 0] Loss: 10.2347 | LR: 0.000000 | Tokens: 0
[Step 10] Loss: 9.8765 | LR: 0.000002 | Tokens: 655360
[Step 20] Loss: 9.5234 | LR: 0.000004 | Tokens: 1310720
...
[Step 100] Loss: 5.4321 | LR: 0.000200 | Tokens: 6553600
[Checkpoint] Step 100 | Loss: 5.4321 | LR: 0.000200
...
[Step 1000] Loss: 1.2345 | LR: 0.000050 | Tokens: 65536000

================================================================================
  Training Completed!
================================================================================
Final Loss: 1.2345
Best Loss: 1.1234
Tokens Processed: 65536000
Training Steps: 1000
Epochs: 3
```

**English text: **
- lossEnglish texttruthfulEnglish text(English text)
- learning rateEnglish text→English text
- English textstepEnglish texttime(English text)
- English textrunEnglish textlossEnglish text(English textinitializeEnglish textdataEnglish text)

## fileEnglish text

| file | English text |
|------|------|
| `pretrain/llm/real_training.s` | English text |
| `pretrain/llm/real_training_loop.s` | trainingEnglish textframework |
| `pretrain/llm/real_main_training.s` | English textmainEnglish text |
| `scripts/legacy/run_large_pretrain.s` | startEnglish text(RequiredEnglish text) |
| `pretrain/llm/large_pretrain.s` | English textcompleteimplementation(English text) |

## English text

usetruthfultrainingimplementationEnglish text:

- **trainingtime:** 1000stepEnglish textRequiredEnglish text(English textdata)
- **English text:** ~650K tokens/step(English textbatch_size=32, seq_len=2048)
- **English text:** ~80-100GB for 1TparametermodelEnglish text8xTP + 8xPP + 2xDPconfiguration
- **English text:** English text(float16)English text

## English text

### English text: trainingEnglish text
**English text: ** English textmain()function, English textcompileEnglish textIREnglish text.English text:
1. scripts/legacy/run_large_pretrain.sEnglish text
2. English textartifacts/builddirectoryEnglish text
3. use`make clean-build`English textcompile

### English text: lossEnglish text
**English text: ** English text:
1. learning rateEnglish text
2. parameterinitializeEnglish text
3. gradientcomputeEnglish text
4. English text

### English text: English text
**English text: **
1. English textbatch_size
2. English textgradientEnglish text
3. English texttraining
4. English textnum_layersEnglish texthidden_dim

## English textstepEnglish text

1. **English textCUDAEnglish text** - English textGPUEnglish text
2. **English textstep** - implementationEnglish text/English texttraining
3. **optimizeEnglish textuse** - implementationgradientcheckpoint
4. **English textdataEnglish text** - English texttruthfulEnglish textJSONLdataEnglish text
5. **English texttraining** - English textTensorBoardEnglish textWeights & Biases

---

**English text: ** English textimplementationuseEnglish textSlanguageimplementation, English textpreferenceEnglish textSEnglish textusePython.English textcompute, optimizeEnglish text, gradientEnglish textSimplementationEnglish text.
