# S compileEnglish text

## 📋 English textDescription

English text, S compileEnglish text(English text `/opt/s/bin/s` English text).English text 1T English text S compileEnglish textfailure, English text.

## ✅ English text

English text `scripts/legacy/run_model_large_pretrain.sh` English textsupportEnglish text:

### defaultEnglish text(English text)
```bash
./scripts/legacy/run_model_large_pretrain.sh --model 1t
# result: S compileEnglish textfailure, English textprompt:
# ✗ ScompileEnglish text(1T English text)
# 💡 prompt: English text NEURX_ALLOW_DEMO=1 English text
```

### English text 1T English text
```bash
NEURX_ALLOW_DEMO=1 ./scripts/legacy/run_model_large_pretrain.sh --model 1t
# result: S compileEnglish text
# ⚠ ScompileEnglish text, 1T English textrun
#   (English texttest, completetrainingRequired S compileEnglish text)
```

`NEURX_ALLOW_FULL_1T_LOCAL=1` English text, English text `NEURX_ALLOW_DEMO=1` English text.

### English textmodelEnglish text(English text)
```bash
./scripts/legacy/run_model_large_pretrain.sh --model gpt-large
# result: S compileEnglish text(English text)
```

## 📊 English textpipeline

```
trainingEnglish textstart
  ↓
English textcompile S English text
  ↓
[compilesuccess]  →  English texttrainingEnglish text

[compilefailure]  →  English textmodelEnglish text
  ├─ 1T English text NEURX_ALLOW_DEMO ≠ 1  →  English textfailure + promptinformation
  ├─ 1T English text NEURX_ALLOW_DEMO = 1   →  English text
  └─ English textmodel                         →  English text
```

## 🔧 English text

### 1. English textcompileerrorEnglish text
```bash
# English text:
⚠ ScompileEnglish text

# English text:
⚠ ScompileEnglish text
   English text: /Users/feifei/shuwen/train/s/.local/bin/s
   explanation: English textRequired S compileEnglish text, English textuse
```

### 2. English text
```bash
# English text:
✗ ScompileEnglish text, English text  (English textfailure)

# English text:
⚠ ScompileEnglish text, English textgenerateEnglish textconfigurationEnglish textcompile
   (English textgenerateconfigurationfileEnglish text)
```

### 3. English text
```bash
# English text:
if [ "$MODEL_SIZE" = "1t" ]; then
    echo "✗ (1T English text)"
    return 1
fi

# English text:
if [ "$MODEL_SIZE" = "1t" ] && [ "${NEURX_ALLOW_DEMO:-0}" != "1" ]; then
    echo "✗ (1T English text)"
    echo "💡 prompt: English text NEURX_ALLOW_DEMO=1 English text"
    return 1
fi

if [ "$MODEL_SIZE" = "1t" ] && [ "${NEURX_ALLOW_DEMO:-0}" = "1" ]; then
    echo "⚠ (1T English textrun)"
fi
```

## 🎯 useEnglish text

### English text 1: English texttest(English textRequiredcompile)
```bash
# English texttest 1T modelconfiguration
NEURX_ALLOW_DEMO=1 make train
```

### English text 2: English textframework(English textcompile)
```bash
# use gpt-large modelEnglish text(defaultEnglish text)
./scripts/legacy/run_model_large_pretrain.sh --model gpt-large
```

### English text 3: English text(completecompileEnglish texttraining)
```bash
# English text, S compileEnglish text
sbatch scripts/legacy/submit_training_job.sh
```

### English text 4: English textconfigurationgenerate(English textcompile)
```bash
# English textgenerateEnglish textconfiguration, English textcompile
NEURX_CLUSTER_CONFIG_ONLY=1 ./scripts/legacy/run_model_large_pretrain.sh --model 1t
```

## 🚀 English text

English textrun 1T model, English textAllowed:
- ✓ English textcompleteEnglish textmodelconfiguration
- ✓ English text 4D English textparameter
- ✓ testdataloadEnglish text
- ✓ generatecheckpointfile
- ✓ generateEnglish textconfiguration
- ✓ English textframeworkEnglish textcompleteEnglish text

English text:
- ✗ English textactualEnglish text S English textcompile
- ✗ runtruthfulEnglish texttrainingEnglish text(English text)
- ✗ English text GPU computeEnglish text

## ⚙️ English text

| English text | English text | explanation |
|------|-----|------|
| `NEURX_ALLOW_DEMO` | `1` | English textmodelEnglish text S compileEnglish text |
| `NEURX_ALLOW_FULL_1T_LOCAL` | `1` | English text 1T English textrunEnglish text S compileEnglish text |
| `S_COMPILER` | path | S compileEnglish text(default: `$NEURX_ROOT/../s/.local/bin/s`) |
| `NEURX_CLUSTER_DISABLE` | `1` | English text |
| `MODEL_SIZE` | `1t`, `gpt-large` | modelEnglish text |
| `NEURX_CLUSTER_CONFIG_ONLY` | `1` | English textgenerateEnglish textconfiguration, English texttraining |

## 📝 logexample

### English textlogoutput
```
════════════════════════════════════════════════════════════════
🚀 NeurX neurx-1t-moe English texttrainingsystem (Slanguageimplementation)
════════════════════════════════════════════════════════════════

▶ English textcompile S English textfile...
⚠ ScompileEnglish text
   English text: /Users/feifei/shuwen/train/s/.local/bin/s
   explanation: English textRequired S compileEnglish text, English textuse

⚠ ScompileEnglish text, 1T English textrun
   (English texttest, completetrainingRequired S compileEnglish text)

════════════════════════════════════════════════════════════════
runneurx-1t-moeEnglish texttrainingEnglish text (S Languageimplementation)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
modelconfiguration (neurx-1t-moe)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  English text:              decoder-only-transformer-moe
  English text:        128000
  English text:          12288
  TransformerEnglish text:     80
  English text:          96
  FFNEnglish text:         49152
  English text:      32768
  MoEEnglish text:         256 / layer
  Top-KEnglish text:         2

✅ neurx-1t-moeEnglish texttrainingpipelineEnglish text
```

## 🔗 English textfile

- `scripts/legacy/run_model_large_pretrain.sh` - maintrainingEnglish text(English text)
- `scripts/legacy/verify_framework.sh` - frameworkEnglish text
- `Makefile` - English textsystem

## 💡 English text

### Q: English textrun 1T modelEnglish text
A: English text `NEURX_ALLOW_DEMO=1` English text:
```bash
NEURX_ALLOW_DEMO=1 make train
```
English textAlloweduse `NEURX_ALLOW_FULL_1T_LOCAL=1 make train`, English text.

### Q: English text 1T English text S compileEnglish textfailure
A: English text `NEURX_ALLOW_DEMO` English text `0`(defaultEnglish text):
```bash
make train  # defaultEnglish text: failureEnglish textprompt
```

### Q: English textrunEnglish text
A: English textlogoutputEnglish text:
```
⚠ ScompileEnglish text, 1T English textrun
```

### Q: English textactualtrainingEnglish text
A:
- **English text**: English texttrainingpipeline, English textconfigurationEnglish textresult, English texttruthfulcompute
- **actualtraining**: compile S English text, English text GPU English texttruthfultraining

## 🎓 English text

1. **English text**: use `NEURX_ALLOW_DEMO=1` quickEnglish text
2. **English text**: English text S compileEnglish text, English textcompile
3. **CI/CD English text**: use `NEURX_ALLOW_DEMO=1` English textquickEnglish text
4. **English texttraining**: English texttruthfulEnglish textrun, usecompletecompile

---

**English text**: 2026-07-02
**English text**: v2.1
**supportEnglish textmodel**: gpt-large, 1t-moe
