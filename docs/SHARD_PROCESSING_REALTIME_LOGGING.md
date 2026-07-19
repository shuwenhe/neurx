# Shard Processing English textmonitoringEnglish text

## English text

English text `minimal_train.s` trainingEnglish text shard dataEnglish text, logoutputEnglish text, English text.

### English text
```
Manifest loaded
Loading shard list file...
Shard list file loaded
(English textoutput)
```

## English text

### 1. English textlogoutput

English text `scripts/legacy/minimal_train.s`:
- English textstepEnglish text `runtime_run_command_output` English text, English textstateEnglish textoutputEnglish text stderr
- English textlogEnglish text, English text

### 2. English textstepEnglish textlogEnglish text

English textlogoutput:

| English text | English text | example |
|------|------|------|
| `[STATUS]` | mainEnglish textpipelinestate | Starting shard processing, shard 1/100 started |
| `[DEBUG]` | English textinformation | Found 100 shards, Shard 1 chunk loaded (4096 bytes) |
| `[ERROR]` | errorinformation | Shard file not found |
| `[INFO]` | informationEnglish text | Reading shard file in line chunks |
| `[TRAIN]` | trainingEnglish text | Step 10: loss=2.5432 lr=0.00012345 |
| `[COMPLETE]` | English textinformation | Training finished - step=100 docs=5000 tokens=100000 |

### 3. English textmonitoringEnglish text

English text `tools/monitor-shard-processing.sh`:
- English textlogoutput
- English text
- English textstatisticsinformation
- computeEnglish text

### 4. startEnglish text

English text `tools/run-with-shard-monitor.sh`:
- English textcompile S languageEnglish text
- startEnglish textmonitoringEnglish text
- runtrainingEnglish text
- English textmanagementlogoutput

## useEnglish text

### English text 1: English textrun(recommended)

```bash
cd /home/shuwen/shuwen/train/neurx
bash tools/run-with-shard-monitor.sh /home/shuwen/s/bin/s
```

### English text 2: English textruncompileEnglish text IR

```bash
cd /home/shuwen/shuwen/train/neurx

# compile
/home/shuwen/s/bin/s ir scripts/legacy/minimal_train.s -o artifacts/build/run_large_pretrain/minimal_train.ir

# run(English textlogoutput)
export NEURX_ROOT=/home/shuwen/shuwen/train/neurx
/home/shuwen/s/bin/s artifacts/build/run_large_pretrain/minimal_train.ir 2>&1
```

### English text 3: configurationEnglish text

```bash
export NEURX_PRETRAIN_BATCH_SIZE=64
export NEURX_PRETRAIN_SEQ_LEN=2048
export NEURX_PRETRAIN_STEPS=1000
export NEURX_PRETRAIN_SHARD_LIST_FILE=/path/to/shard_list.txt

/home/shuwen/s/bin/s artifacts/build/run_large_pretrain/minimal_train.ir 2>&1
```

## English textlogoutputexample

```
═══════════════════════════════════════════════
NeurX Shard Processing - Real-time Monitor
═══════════════════════════════════════════════

[14:25:30] ✓ Starting shard processing

[14:25:31] ▶ Processing Shard 1/100
  Path: /home/shuwen/shuwen/train/neurx/dataset/pretrain/shard/training_data-00001.jsonl

[14:25:32] 📊 Step: 1  Loss: 2.5432  LR: 0.00012345

[14:25:33] ✓ Shard complete: docs=1000 tokens=2048000

[14:25:34] ▶ Processing Shard 2/100
  Path: /home/shuwen/shuwen/train/neurx/dataset/pretrain/shard/training_data-00002.jsonl

...

[14:35:00] ✓ COMPLETE: step=100 docs=5000 tokens=100000 loss=1.2345
  Total time: 0h 9m 30s
```

## mainEnglish text

### 1. println English text

use `runtime_run_command_output` English textlogEnglish textoutputEnglish text stderr, English text println English text:

```s
runtime_run_command_output("echo '[STATUS] Starting shard processing...' >&2")
```

### 2. English textphaseEnglish textlogoutput

English textphaseEnglish textlogEnglish text:

```s
runtime_run_command_output("echo '[STATUS] Reading shard file...' >&2")
// ... English text ...
runtime_run_command_output("echo '[DEBUG] Shard loaded (" + ... + " bytes)' >&2")
```

### 3. English text

English text shard English texttraining step English textlogEnglish text

### 4. errorEnglish textinformation

English textoutputerrorstate, English text

## English textconfiguration

trainingEnglish textsupportEnglish text:

```bash
NEURX_ROOT                      # English textdirectory
NEURX_PRETRAIN_MANIFEST         # Manifest filepath
NEURX_PRETRAIN_SHARD_LIST_FILE  # Shard English textfile
NEURX_PRETRAIN_BATCH_SIZE       # English text(default 32)
NEURX_PRETRAIN_SEQ_LEN          # English text(default 2048)
NEURX_PRETRAIN_STEPS            # English textstepEnglish text(default 1000)
NEURX_PRETRAIN_LR               # learning rate(default 0.0002)
NEURX_PRETRAIN_WEIGHT_DECAY     # weightEnglish text(default 0.01)
NEURX_PRETRAIN_WARMUP_STEPS     # English textstepEnglish text(default 100)
NEURX_PRETRAIN_LOG_INTERVAL     # logEnglish text(default 10)
NEURX_PRETRAIN_MAX_DOCS         # English text(default 100000000)
NEURX_PRETRAIN_STEP_TOKENS      # English textstep token English text(default 256)
NEURX_PRETRAIN_LINE_CHUNK       # English text(default 32)
NEURX_PRETRAIN_TEXT_TOKEN_CAP   # English text token English text(default 256)
NEURX_PRETRAIN_JSON_SCAN_CAP    # JSON English text(default 4096)
NEURX_PRETRAIN_FAST_PREFIX      # quickEnglish text(default 1)
```

## English text

### English text: English text "[STATUS] Starting shard processing..." English text

**English text**: English text shard English text 0

**English text**:
```bash
# English text shard directory
ls -la /home/shuwen/shuwen/train/neurx/dataset/pretrain/shard/

# English text manifest file
cat /home/shuwen/shuwen/shuwen/train/neurx/dataset/pretrain/manifest.json | head -20

# English text shard English textfile
export NEURX_PRETRAIN_SHARD_LIST_FILE=/path/to/your/shard_list.txt
```

### English text: English text

**English text**: English text JSON English texttime

**English text**:
- English text `NEURX_PRETRAIN_FAST_PREFIX=1`(English text)
- English text `NEURX_PRETRAIN_JSON_SCAN_CAP` English text `NEURX_PRETRAIN_TEXT_TOKEN_CAP`

### English text: English textuseEnglish text

**English text**: English text

**English text**:
```bash
export NEURX_PRETRAIN_BATCH_SIZE=16
export NEURX_PRETRAIN_SEQ_LEN=1024
```

## English textfile

- `scripts/legacy/minimal_train.s` - English texttrainingEnglish text(English textlog)
- `tools/monitor-shard-processing.sh` - English textlogmonitoringEnglish text
- `tools/run-with-shard-monitor.sh` - completestartEnglish text
- `tools/cleanup-old-commits.sh` - English texttool

## English text

1. ✅ English textlogoutput
2. ✅ English textphaseEnglish text
3. English text: English text(English text, English text)
4. English text: errorEnglish textrecoverEnglish text
5. English text: English texttraininglogEnglish text

---

**English text**: 2026-07-09
**English text**: 1.0
