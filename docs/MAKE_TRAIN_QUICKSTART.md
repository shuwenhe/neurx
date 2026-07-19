# make train quickEnglish text

## 🔍 English textstateEnglish text

| phase | state | English text |
|------|------|------|
| ✅ dataEnglish text | English text | 304MB English textdata |
| ✅ dataEnglish text | English text | 128English text, 1.9GB |
| ✅ Manifest | English text | 71,451English text |
| ⚠️ English text/testEnglish text | English text | valEnglish texttestfileEnglish text |
| ⏳ actualtraining | English text | English text: 09:50:00 |

## ⚠️ English textoutput?

### English text
```bash
# MakefileEnglish text:
... 2>&1 | tee -a $(LOG_DIR)/train_$(shell date +%Y%m%d_%H%M%S).log
```

**English textoutputEnglish textlogfile**.English textrunEnglish textoutput, English text.

### English text

#### 🚀 quickEnglish text1: English textlog
```bash
# English textdirectory
cd /home/shuwen/shuwen/train/neurx

# English textlog
tail -f artifacts/logs/train_*.log

# English textfile
tail -f artifacts/logs/train_20260707_094802.log
```

#### 🚀 quickEnglish text2: usemonitoringEnglish text
```bash
# English textrunmonitoringEnglish text
bash scripts/legacy/monitor_training.sh

# English textstate
bash scripts/legacy/monitor_training.sh status

# English textmonitoringlog
bash scripts/legacy/monitor_training.sh realtime
```

#### 🚀 quickEnglish text3: startEnglish textmonitoring
```bash
# English textstarttrainingEnglish textmonitoring
bash scripts/legacy/start_train.sh
```

#### 🚀 quickEnglish text4: English textstart+English textmonitoring
```bash
# English textstart
make train &

# English textlogfilegenerate
sleep 2

# English textlog
tail -f artifacts/logs/train_*.log | grep -E "Training|training|loss|Loss|step|Step"
```

## 🐛 English text

### English text1: English texttestEnglish text
**English text**:
```
val.jsonl - 0 bytes ❌
test.jsonl - 0 bytes ❌
train.jsonl - 9.8M ✅
```

**English text**: dataEnglish text

**quickEnglish text**:
```bash
# English textgeneratedata(English text24GBfile)
rm dataset/pretrain/cleaned/*
rm dataset/pretrain/shard/*
make train
```

**English text**:
English text `scripts/legacy/run_large_pretrain.sh` English text:
```bash
export NEURX_SKIP_VAL=1
export NEURX_SKIP_TEST=1
```

### English text2: English texttrainingoutput
**English text**:
- English textgeneratecheckpointfile
- logEnglish text

**English text**:
```bash
# English textScompileEnglish textsuccess
ls -lh build/training/

# English textlog
tail -50 artifacts/logs/train_*.log

# English texterror
grep -i error artifacts/logs/train_*.log

# English textstate
ps aux | grep -E "make|train|clean"
```

## 📋 completeEnglish text

### English textA: English textstart+monitoring
```bash
cd /home/shuwen/shuwen/train/neurx

# 1. starttraining(English text)
make train &

# 2. English textloginitialize
sleep 2

# 3. monitoringEnglish text(English textCtrl+CEnglish textmonitoring, trainingEnglish text)
tail -f artifacts/logs/train_*.log
```

### English textB: English textphaseEnglish text
```bash
# 1. English textdataEnglish text(English text, English text)
bash scripts/legacy/clean_data.sh
bash scripts/legacy/generate_shards.sh

# 2. runtraining
bash scripts/legacy/run_large_pretrain.sh

# 3. English textmonitoring
tail -f artifacts/logs/train_*.log
```

### English textC: English text(English textcompleteoutput)
```bash
# English textMakefile, English textteeEnglish textlogEnglish text
# English textuseEnglish textmake

cd /home/shuwen/shuwen/train/neurx
bash scripts/legacy/run_large_pretrain.sh 2>&1
```

## 🔧 configurationEnglish text

English text `scripts/legacy/run_large_pretrain.sh` English textAllowedEnglish text:
```bash
# modelEnglish text
export MODEL_SIZE=1t

# datapath
export NEURX_PRETRAIN_MANIFEST='path/to/manifest.json'
export NEURX_TRAIN_SPLIT_PATH='path/to/train.jsonl'

# compileEnglish text
export S_COMPILER='/home/shuwen/s/bin/s'
export S_SOURCE_ROOT='/home/shuwen/s'

# English textcomplete1Tmodel
export NEURX_ALLOW_FULL_1T_LOCAL=1
```

## 📊 monitoringEnglish text

### English textdataEnglish text
```bash
# English textmonitoringfileEnglish text
watch -n 1 'ls -lh artifacts/logs/train_*.log'

# English textcheckpointgenerate
watch -n 2 'ls -lh artifacts/checkpoints/'

# monitoringEnglish text
watch -n 5 'du -sh artifacts/ dataset/'
```

### English textlogstatistics
```bash
# statisticslogEnglish textstepEnglish text
grep "step" artifacts/logs/train_*.log | wc -l

# English textlossEnglish text
grep "loss" artifacts/logs/train_*.log | tail -20

# English texterror
grep -i error artifacts/logs/train_*.log
```

## 🆘 English text

### trainingEnglish textstart
```bash
# 1. English textmakeEnglish textsuccess
make train 2>&1 | head -50

# 2. English textlogdirectoryEnglish text
ls -ld artifacts/logs

# 3. English textScompileEnglish text
which s
s --version
```

### trainingEnglish textphase
```bash
# 1. English textlogEnglish text100English text
tail -100 artifacts/logs/train_*.log

# 2. English texterror
tail -100 artifacts/logs/train_*.log | grep -i error

# 3. English text
ps aux | grep -E "s|python|train"

# 4. English textsystemEnglish text
top -b -n 1 | head -15
free -h
```

### logfileEnglish text
```bash
# 1. English textrun
ps aux | grep make
ps aux | grep -E "train|clean"

# 2. English textstart
make train

# 3. monitoringEnglish textlog
tail -f artifacts/logs/train_*.log
```

## 📝 fileEnglish text

```
English textdirectory: /home/shuwen/shuwen/train/neurx/

log:
  artifacts/logs/train_*.log              # traininglog
  artifacts/logs/train_20260707_094802.log # English textlog

data:
  dataset/pretrain/raw/                   # English textdata (24GB)
  dataset/pretrain/cleaned/               # English textdata
  dataset/pretrain/shard/                 # dataEnglish text (128English textfile)
  dataset/pretrain/manifest.json          # English textdata

model:
  training/                               # trainingEnglish text (Slanguage)
  build/training/                         # compileoutput
  artifacts/checkpoints/                  # trainingcheckpoint

monitoringtool:
  scripts/legacy/monitor_training.sh              # monitoringEnglish text
  scripts/legacy/start_train.sh                   # quickstartEnglish text
  scripts/legacy/clean_data.sh                    # dataEnglish text
  scripts/legacy/generate_shards.sh               # English textgenerateEnglish text
  scripts/legacy/run_large_pretrain.sh            # trainingEnglish text
```

## 🎯 English textstepEnglish text

### English textstep: English textstate
```bash
tail -30 artifacts/logs/train_*.log | grep -v "^$"
```

### English textstep: English text
- **English textlogoutput** → trainingEnglish text, English textmonitoring
- **logEnglish text** → English texterrorEnglish text
- **English textlogfile** → English textmakeEnglish text

### English textstep: English textmonitoring
```bash
bash scripts/legacy/monitor_training.sh
# English text
tail -f artifacts/logs/train_*.log
```

### English textstep: English text
English text**English text**English text

---

**English text**:
- `MAKE_TRAIN_DIAGNOSIS.md` - English text
- `scripts/legacy/monitor_training.sh` - monitoringEnglish text
