# neurx 1T MoE training - mainEnglish text

## 📍 main() functionEnglish text
**file**: pretrain/llm/model_large_pretrain.s

### English text (20+ English text)

```
model_large_pretrain.s
│
├─ neurx.strings
│  └─ English texttool
│
├─ neurx.runtime.io
│  ├─ runtime_file_exists()
│  ├─ runtime_make_dirs()
│  ├─ runtime_read_text_file()
│  ├─ runtime_write_text_file()
│  └─ runtime_env_get()
│
├─ neurx.moe.llm_1t          ⭐ English textmodel
│  ├─ moe_1t_framework_default()
│  └─ moe_1t_summary()
│  └─ English text:
│      ├─ model_large_train.s
│      ├─ llm_moe_1t_loss.s
│      ├─ distributed/moe_all_to_all.s
│      ├─ distributed/tensor_parallel.s
│      ├─ distributed/zero_gradient_reduce.s
│      ├─ long_context_32k.s (RoPE + NTK)
│      └─ model/llm/lr_scheduler_moe_1t.s
│
├─ neurx.pretrain.llm.entry
│  └─ English texttrainingEnglish textfunction
│
├─ neurx.dl.dataloader                 ⭐ dataload
│  ├─ dataloader_state
│  ├─ dataloader_config
│  ├─ new_state()
│  ├─ with_config()
│  ├─ set_shuffle()
│  ├─ next_batch()
│  └─ English text: data/moe_1t_jsonl_loader.s
│
├─ neurx.model.llm.model_large_train     ⭐ trainingEnglish text
│  ├─ model_large_training_state
│  ├─ model_large_training_forward()
│  ├─ model_large_training_loss()
│  └─ English text:
│      ├─ nn/attention.s
│      ├─ nn/ffn.s
│      ├─ nn/embedding.s
│      ├─ tensor/ops.s
│      └─ cuda/kernels.s
│
├─ neurx.pretrain.distributed          ⭐ English texttraining
│  ├─ pretrain_ddp_state
│  ├─ new_pretrain_ddp_state_from_env()
│  ├─ pretrain_ddp_sync_tensor()
│  ├─ pretrain_ddp_step()
│  └─ English text:
│      ├─ distributed/ddp.s
│      ├─ distributed/tensor_parallel.s
│      ├─ distributed/pipeline_parallel.s
│      ├─ distributed/expert_parallel.s
│      └─ distributed/allreduce.s
│
├─ neurx.pretrain.optimizer.pretrain_adamw    ⭐ optimizeEnglish text
│  ├─ pretrain_optimizer_state
│  ├─ new_pretrain_optimizer_state()
│  ├─ pretrain_optimizer_step()
│  └─ English text:
│      ├─ distributed/zero_gradient_reduce.s
│      ├─ opt/optim/adamw.s
│      └─ tensor/ops.s
│
├─ neurx.pretrain.tokenizer.bpe        ⭐ English text
│  ├─ bpe_tokenizer_state
│  ├─ bpe_tokenized_corpus_state
│  ├─ bpe_jsonl_records_to_documents()
│  └─ English text: pretrain/tokenizer/bpe_tokenizer.s
│
├─ neurx.pretrain.checkpoint           ⭐ checkpoint
│  ├─ pretrain_checkpoint_state
│  ├─ new_pretrain_checkpoint_state()
│  ├─ mark_saved()
│  ├─ mark_best()
│  └─ English text: pretrain/checkpoint/io.s
│
├─ neurx.pretrain.config               ⭐ configuration
│  ├─ pretrain_config
│  ├─ new_pretrain_config()
│  ├─ with_max_steps()
│  ├─ with_lr()
│  └─ English text: pretrain/config/parser.s
│
├─ neurx.pretrain.data                 ⭐ dataEnglish text
│  ├─ pretrain_data_state
│  ├─ new_pretrain_data_state()
│  ├─ advance_tokens()
│  ├─ next_epoch()
│  └─ English text: data/moe_1t_data_pipeline.s
│
├─ neurx.pretrain.eval                 ⭐ evaluation
│  ├─ pretrain_eval_state
│  ├─ new_pretrain_eval_state()
│  ├─ update_pretrain_eval()
│  └─ English text: pretrain/eval/metrics.s
│
├─ neurx.pretrain.loop                 ⭐ trainingEnglish text
│  ├─ pretrain_loop_state
│  ├─ new_pretrain_loop_state()
│  ├─ pretrain_step()
│  ├─ pretrain_reset_micro_step()
│  └─ English text: training/loop.s
│
├─ neurx.checkpoint
│  ├─ save_checkpoint()
│  ├─ load_checkpoint()
│  └─ English text: pretrain/checkpoint/io.s
│
├─ neurx.nn
│  ├─ embedding_lookup()
│  ├─ transformer_forward()
│  └─ English text:
│      ├─ nn/embedding.s
│      ├─ nn/attention.s
│      ├─ nn/ffn.s
│      └─ nn/layernorm.s
│
├─ neurx.opt.optim
│  ├─ adamw_optimizer
│  └─ English text: opt/optim/adamw.s
│
├─ neurx.ops
│  └─ English text
│
├─ neurx.tensor.new
│  ├─ tensor creation functions
│  └─ English text: tensor/new.s
│
└─ neurx.tensor.tensor
   └─ tensor data structures

```

---

## 🔄 English text (English text)

### English text llm_moe_1t English text
```
moe/llm_moe_1t.s
├─ model_large_train.s
│  ├─ nn/attention.s (English text)
│  ├─ nn/ffn.s (English text)
│  ├─ nn/layernorm.s (English text)
│  ├─ tensor/ops.s (English text)
│  └─ cuda/kernels.s (GPU compute)
│
├─ llm_moe_1t_loss.s
│  ├─ ops/math.s (English textfunction)
│  ├─ tensor/new.s (English text)
│  └─ compute CE + helperloss + KL
│
├─ distributed/moe_all_to_all.s
│  ├─ distributed/alltoall.s (All-to-All English text)
│  ├─ tensor/ops.s (English text)
│  └─ English text token English text experts
│
├─ distributed/tensor_parallel.s
│  ├─ distributed/allgather.s (English text)
│  ├─ distributed/reducescatter.s (English text)
│  ├─ tensor/ops.s
│  └─ English text QKV/FFN weight
│
├─ distributed/zero_gradient_reduce.s
│  ├─ distributed/allreduce.s (English text)
│  ├─ tensor/new.s
│  └─ ZeRO Stage 3 gradientEnglish text
│
└─ long_context_32k.s
   ├─ ops/math.s (RoPE + NTK English text)
   ├─ tensor/new.s
   └─ 32K English textsupport
```

### English texttrainingEnglish text
```
pretrain/distributed/
├─ ddp.s (dataEnglish text)
│  ├─ distributed/allreduce.s
│  └─ English textstepgradient
│
├─ tensor_parallel.s (English text)
│  ├─ distributed/allgather.s
│  ├─ distributed/reducescatter.s
│  └─ weightEnglish text
│
├─ pipeline_parallel.s (English text)
│  ├─ distributed/send_recv.s
│  └─ English text
│
└─ expert_parallel.s (English text)
   ├─ distributed/alltoall.s
   └─ 256 English text MoE experts English text
```

### English textoptimizeEnglish text
```
pretrain/optimizer/adamw.s
├─ opt/optim/adamw.s
│  ├─ tensor/ops.s (English text)
│  └─ ops/math.s (English text)
│
└─ distributed/zero_gradient_reduce.s
   └─ parameterEnglish textoptimizestepEnglish text
```

### English textdataloadEnglish text
```
data/moe_1t_jsonl_loader.s
├─ pretrain/tokenizer/bpe.s
│  └─ BPE English text (128K English text)
│
├─ tensor/new.s
│  └─ English textinput IDs, English text
│
└─ pretrain/data/
   └─ English text (DP English text)
```

---

## 📊 English textstatistics

### English text
- English text: 20+
- English text: 12 (English text ⭐)
- toolEnglish text: 8

### English text
- actualcompileEnglish text S file: ~30-40 English text
- English textcompileEnglish textfile: ~277 English text

### compileEnglish text
```
mainEnglish text model_large_pretrain.s
  ↓ compile
English text llm_moe_1t.s
  ↓ English textcompile
  English text model_large_train.s
    ↓ English textcompile
    English text nn/attention.s, nn/ffn.s
      ↓ English textcompile
      English text tensor/ops.s, cuda/kernels.s
        ↓ English textcompile
        English text ops/math.s
          ↓ English textcompile
          (English text)
```

---

## ✅ English textcompileEnglish text

### English textcompile (English text)
```
✓ pretrain/llm/model_large_pretrain.s      mainEnglish text
✓ model/llm/model_large_train.s            Transformer
✓ moe/llm_moe_1t.s                 1T MoE framework
✓ moe/llm_moe_1t_loss.s            losscompute
✓ model/llm/long_context_32k.s           English text
✓ distributed/ddp.s                      dataEnglish text
✓ distributed/tensor_parallel.s          English text
✓ distributed/pipeline_parallel.s        English text
✓ distributed/expert_parallel.s          English text
✓ distributed/moe_all_to_all.s           MoE English text
✓ distributed/zero_gradient_reduce.s     ZeRO gradient
✓ pretrain/optimizer/adamw.s             optimizeEnglish text
✓ pretrain/tokenizer/bpe.s               English text
✓ nn/attention.s                         English text
✓ nn/ffn.s                               English text
✓ nn/embedding.s                         English text
✓ nn/layernorm.s                         English text
✓ tensor/ops.s                           English text
✓ tensor/new.s                           English text
✓ cuda/kernels.s                         GPU English text
✓ ops/math.s                             English text
✓ opt/optim/adamw.s                      AdamW
✓ pretrain/data/moe_1t_data_pipeline.s   dataEnglish text
✓ pretrain/checkpoint/io.s               checkpoint I/O
✓ pretrain/config/parser.s               configurationEnglish text
✓ monitoring/moe_1t_metrics.s            monitoringEnglish text
✓ logging/logger.s                       logsystem

≈ 30-35 English text
```

### English textcompile (English text)
```
⚠ training/loop.s
⚠ pretrain/eval/metrics.s
⚠ data/moe_1t_jsonl_loader.s
⚠ tests/*.s
⚠ examples/*.s
```

### English textcompile (English text)
```
✗ inference/*                            inferencesystem (22)
✗ serving/*                              English text (2)
✗ quantization/*                         English text (2)
✗ alignment/*                            English texttrainingalignment (7)
✗ posttrain/*                            English texttraining (1)
✗ agent/*                                AI Agent (24)
✗ English text 175+ English textfile
```

---

## 🔍 English text

### English text 1: English text use English text
```bash
# English textmainEnglish textstart
grep "^use " pretrain/llm/model_large_pretrain.s

# English text
grep "^use " moe/llm_moe_1t.s

# English text...
```

### English text 2: S compileEnglish textlog
```bash
# English textrunEnglish text
/opt/s/bin/s compile pretrain/llm/model_large_pretrain.s -v

# English textoutputEnglish textcompileEnglish text
```

### English text 3: compileoutputEnglish text
```bash
# compileEnglish text
nm build/model_large_pretrain | wc -l

# English textactualuseEnglish textfunctionEnglish text
```

---

## ⏱️ compileEnglish text

```
S compileEnglish text:
├─ Phase 1: English textmainfile (model_large_pretrain.s)
│  └─ time: 1-2 English text
│
├─ Phase 2: English text use English text
│  ├─ English text: 5-6 English text
│  ├─ English text: 20+ English text
│  ├─ English textcompilefile: ~40-50 English text
│  └─ time: 8-20 English text
│
├─ Phase 3: English text
│  └─ time: 2-5 English text
│
├─ Phase 4: English textgenerate (LLVM IR → English text)
│  └─ time: 5-10 English text
│
└─ Phase 5: English textoptimize
   └─ time: 5-10 English text

English textcompiletime: 15-45 English text (English textcompile)
English textcompile: 1-5 English text (English text)
```

---

## 📈 English textstatistics

### English textcompileEnglish text
```
English text:           ~12,000 English text
English text:             ~10,000 English text
GPU English text:           ~5,000 English text
configuration/tool:          ~3,000 English text
─────────────────────────
English text:               ~30,000 English text (compile)
```

### English textcompileEnglish text
```
inferencesystem:           ~3,000 English text
English texttrainingalignment:         ~2,000 English text
AI Agent:          ~3,000 English text
test/example:         ~4,000 English text
English text:              ~9,000 English text
─────────────────────────
English text:              ~21,000 English text (English textcompile)
```

**English text**: 34,131+ English text S English text
- compileEnglish text: ~88%
- runEnglish textuseEnglish text: ~10-13% (30-40 English textfile)

---

## 🎯 English text

1. **mainEnglish textcomplete**: English text
2. **English text**: English text
3. **compileEnglish text**: English textcompileRequiredEnglish text ~40 English textfile
4. **English textextensionEnglish text**: English text
5. **English textsupport**: English textimplementation

**English texttrainingEnglish text**:
```
model_large_pretrain.s (1 entry)
  → llm_moe_1t.s (modelEnglish text)
    → model_large_train.s + distributed/* (compute)
      → nn/* + tensor/* + cuda/* (English text)
        → ops/* + opt/* (English text)
          ↓
      4-6 English texttrainingEnglish text
```
