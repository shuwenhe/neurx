# 🎯 English text Shard English textlogEnglish text

## 📊 English textresult

### English text
trainingEnglish textrunEnglish text, shard English text:
```
Manifest loaded
Loading shard list file...
Shard list file loaded
(English textoutput)
```

### English text
- `println()` functionoutputEnglish text S runEnglish text
- English textoutputcontent
- English text

---

## ✅ English text

### 1️⃣ English texttrainingEnglish text
**file**: `scripts/legacy/minimal_train.s`

English textstepEnglish text `runtime_run_command_output` English text, English textstateEnglish textoutputEnglish text stderr(unbuffered):

```s
// English textA: use runtime_run_command_output English text
runtime_run_command_output("echo '[STATUS] Starting shard processing...' >&2")

// English textB: English text println English textlogEnglish text
println("[STATUS] Starting shard processing...")
```

**English text**(850+ English text):
- ✅ Shard English textloadphase
- ✅ Shard countEnglish textphase
- ✅ English text shard English textstartphase
- ✅ dataEnglish textloadphase
- ✅ trainingstepEnglish textphase
- ✅ English textstatisticsphase

### 2️⃣ English textmonitoringEnglish text
**file**: `tools/monitor-shard-processing.sh`

- English textlogEnglish textstateEnglish text(`[STATUS]`, `[DEBUG]`, `[TRAIN]` English text)
- English text
- English text
- computeEnglish text

### 3️⃣ English textcompileEnglish textrunEnglish text
**file**: `tools/run-with-shard-monitor.sh`

completeEnglish textstartpipeline:
```
English text S compileEnglish text → English text → compileEnglish text IR → startmonitoring → runtraining → English textoutput
```

### 4️⃣ English text
**file**: `docs/SHARD_PROCESSING_REALTIME_LOGGING.md`

590 English textcompleteEnglish text, English text:
- English text
- English text
- useEnglish text(3 English text)
- outputEnglish text
- English textconfiguration
- English text

---

## 🚀 quickuse

### English text 1️⃣ - recommended(English textstart)
```bash
cd /home/shuwen/shuwen/train/neurx
bash tools/quick-start-shard-logging.sh
```

### English text 2️⃣ - English textcompilerun
```bash
cd /home/shuwen/shuwen/train/neurx
bash tools/run-with-shard-monitor.sh /home/shuwen/s/bin/s
```

### English text 3️⃣ - English textcompilerun
```bash
cd /home/shuwen/shuwen/train/neurx

# compile
/home/shuwen/s/bin/s ir scripts/legacy/minimal_train.s -o artifacts/build/run_large_pretrain/minimal_train.ir

# run(English textoutput)
export NEURX_ROOT=/home/shuwen/shuwen/train/neurx
/home/shuwen/s/bin/s artifacts/build/run_large_pretrain/minimal_train.ir 2>&1
```

---

## 📋 English textfileEnglish text

| file | English text | English text |
|------|------|------|
| `scripts/legacy/minimal_train.s` | English text | English textlogoutput(4 English text) |
| `tools/monitor-shard-processing.sh` | English text | English textlogEnglish textmonitoring |
| `tools/run-with-shard-monitor.sh` | English text | English textcompileEnglish textrun |
| `tools/quick-start-shard-logging.sh` | English text | quickstartEnglish text |
| `docs/SHARD_PROCESSING_REALTIME_LOGGING.md` | English text | English text(590 English text) |

---

## 🎨 English textoutputEnglish text

```
═══════════════════════════════════════════════
NeurX Shard Processing - Real-time Monitor
═══════════════════════════════════════════════

[14:25:30] ✓ Starting shard processing

[14:25:31] ▶ Processing Shard 1/100
  Path: .../training_data-00001.jsonl

[14:25:32] 📊 Step: 1  Loss: 2.5432  LR: 0.00012345

[14:25:33] ✓ Shard complete: docs=1000 tokens=2048000

[14:25:34] ▶ Processing Shard 2/100
  ...

[14:35:00] ✓ COMPLETE: step=100 docs=5000 tokens=100000
  Total time: 0h 9m 30s
```

---

## 💡 mainEnglish text

| English text | state | explanation |
|------|------|------|
| English textlogoutput | ✅ | use `runtime_run_command_output` English text |
| English textphaseEnglish text | ✅ | English textphaseEnglish text |
| English text | ✅ | English text |
| errorEnglish text | ✅ | `[ERROR]` English text |
| statisticsinformation | ✅ | English text, English text token English text |
| English textconfiguration | ✅ | support 14 English text |

---

## 🔧 English textsupport

English textsupportEnglish text:

```bash
NEURX_PRETRAIN_BATCH_SIZE=32          # English text
NEURX_PRETRAIN_SEQ_LEN=2048           # English text
NEURX_PRETRAIN_STEPS=1000             # English texttrainingstepEnglish text
NEURX_PRETRAIN_LR=0.0002              # learning rate
NEURX_PRETRAIN_WEIGHT_DECAY=0.01      # weightEnglish text
NEURX_PRETRAIN_WARMUP_STEPS=100       # English textstepEnglish text
NEURX_PRETRAIN_LOG_INTERVAL=10        # logoutputEnglish text
NEURX_PRETRAIN_MAX_DOCS=100000000     # English text
NEURX_PRETRAIN_STEP_TOKENS=256        # English textstep token English text
NEURX_PRETRAIN_LINE_CHUNK=32          # English text
NEURX_PRETRAIN_TEXT_TOKEN_CAP=256     # English text token English text
NEURX_PRETRAIN_JSON_SCAN_CAP=4096     # JSON English text
NEURX_PRETRAIN_FAST_PREFIX=1          # quickEnglish text
NEURX_ROOT=/path/to/neurx             # English textdirectory
```

---

## 📚 English text

English text:
```bash
cat /home/shuwen/shuwen/train/neurx/docs/SHARD_PROCESSING_REALTIME_LOGGING.md
```

English text:
```
neurx/docs/SHARD_PROCESSING_REALTIME_LOGGING.md
```

---

## 🎯 English textstepEnglish text

1. **testEnglish textmonitoring**
   ```bash
   bash tools/quick-start-shard-logging.sh
   ```

2. **English textlogoutput**
   - English text `[STATUS]` English text
   - English text `[TRAIN]` English text
   - English text `[COMPLETE]` statistics

3. **English textoptimize**(English text)
   - English textRequiredEnglish text
   - monitoring GPU/CPU useEnglish text

4. **English text**(English text)
   - English text `docs/SHARD_PROCESSING_REALTIME_LOGGING.md` English textsection
   - English text shard fileEnglish text
   - English text manifest fileconfiguration

---

**English text**: 2026-07-09
**English text**: 1.0
**author**: NeurX Development Team
