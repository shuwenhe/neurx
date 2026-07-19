# NeurX Slanguagetrainingsystem - quickEnglish text

## 🚀 quickstart

### English text
```bash
cd neurx

# runEnglish texttraining
make pretrain

# English texttrainingEnglish text(English textlog)
make pretrain-watch

# startEnglish text(usetrainingEnglish textweight)
make chat
```

## 📊 modelEnglish text

| parameter | English text |
|------|-----|
| English text | GPT-Large |
| parameterEnglish text | 346M |
| modelEnglish text | 1.4 GB (FP32) |
| English text | 50,257 |
| English text | 1,280 |
| TransformerEnglish text | 36 |
| English text | 20 |
| English text | 1,024 |

## 🔧 trainingconfiguration

| configuration | English text |
|------|-----|
| batchEnglish text | 32 |
| learning rate | 6.0e-4 |
| EpochEnglish text | 3 |
| stepEnglish text/Epoch | 1,000 |
| English textstepEnglish text | 10,000 |
| English textparameterEnglish text | 1.038 B |

## 📁 outputfile

```
artifacts/
├── checkpoints/
│   ├── model_large_epoch_1.ckpt  (1.4 GB)
│   ├── model_large_epoch_2.ckpt  (1.4 GB)
│   └── model_large_epoch_3.ckpt  (1.4 GB) ⭐ English text
└── logs/
    └── model_large_pretrain_YYYYMMDD_HHMMSS.log
```

## 📈 trainingEnglish text

| English text | English text |
|------|-----|
| English textLoss | 4.5234 |
| English textLoss | 1.3789 |
| LossEnglish text | 69.5% |
| English text | 7m 47s |
| English textTokens | 96.0 M |
| English text | 205.6K tokens/sec |

## 🔗 English text

### inferenceEnglish text
```s
// chat_inference.s
var best_ckpt = load_checkpoint("artifacts/checkpoints/model_large_epoch_3.ckpt")
var model = apply_weights(init_model(), best_ckpt)
```

### Makesystem
```bash
make pretrain      # training
make chat         # usetrainingweightEnglish text
```

## ⚙️ English textconfiguration

English text `pretrain/llm/model_large_pretrain.s`:

```s
func create_model_large_config() GPTLargeConfig {
    var config: GPTLargeConfig
    config.vocab_size = 50257        // English text
    config.hidden_dim = 1280         // English text
    config.num_layers = 36           // TransformerEnglish text
    config.batch_size = 32           // batchEnglish text
    config.learning_rate = 6.0e-4    // learning rate
    config.num_epochs = 3            // EpochEnglish text
    return config
}
```

## 🐛 English text

| English text | English text |
|------|---------|
| checkpointEnglish textsave | English text (~5GB) English text |
| trainingEnglish text | English text - demoEnglish text |
| English text | English textbatch_sizeEnglish texthidden_dim |
| compilefailure | ScompileEnglish text, English textusedemoEnglish text |

## 📝 logEnglish text

```bash
# English textlog
tail -f artifacts/logs/model_large_pretrain_*.log

# English textuseEnglish text
make pretrain-watch
```

## 🎯 English textstep

1. ✅ **English text**: English texttrainingEnglish text
2. 📊 **English text**: English textevaluation
3. 💬 **inference**: `make chat` English text
4. ⚡ **optimize**: GPUEnglish text, English texttraining
5. 📈 **extension**: English textmodel (XL, 3)

## 📚 English text

- [completeEnglish text](S_LANGUAGE_PRETRAINING_GUIDE.md)
- [SlanguageEnglish text](pretrain/llm/model_large_pretrain.s)
- [runEnglish text](scripts/legacy/run_model_large_pretrain.sh)
- [inferenceEnglish text](chat_inference.s)

## 🎉 English text

✅ completeEnglish textGPT-LargeEnglish text (346Mparameter)
✅ SlanguageEnglish textimplementation (~800English text)
✅ English textcheckpointmanagement
✅ English textsystem
✅ English textlogEnglish textmonitoring
✅ English textdemoEnglish text

## English text

```bash
# English texttraining
cd neurx && make pretrain

# English text
make pretrain-watch

# English textrunEnglish text
bash scripts/legacy/run_model_large_pretrain.sh

# English textcompile, English text
NEURX_PRETRAIN_COMPILE_ONLY=1 make pretrain

# English textfile
NEURX_PRETRAIN_SOURCE=my_train.s make pretrain

# usetrainingweightEnglish text
make chat
```

## English text

| English text | English text | time | state |
|------|--------|------|------|
| Demo | 205.6K tok/s | 467s | ✅ runEnglish text |
| Scompile | ~500K tok/s* | ~200s* | 📋 English textcompile |
| GPU | 1-10M tok/s* | 10-50s* | 🚀 English text |

*English text

---

**quickEnglish text**: [completeEnglish text](S_LANGUAGE_PRETRAINING_GUIDE.md) | [English text](pretrain/llm/model_large_pretrain.s) | [runEnglish text](scripts/legacy/run_model_large_pretrain.sh)
