# 📊 NeurX trainingdatainformationEnglish text

## English text
English text NeurX trainingsystem, English texttrainingEnglish texttrainingEnglish texttrainingdatainformation, English text:
- English textloadEnglish texttrainingdataEnglish text
- English textfilepath
- datastatisticsinformation(English text, fileEnglish text)
- trainingEnglish textdatafile

## English textcontent

### 1. English texttrainingdatainformationEnglish text ✅
**file**: `scripts/legacy/print_training_data_info.sh`

English text:
- English textdataEnglish text(English text, trainingEnglish text, English textdata, English textdata)
- English textuseEnglish textdataEnglish text
- English textdatafileEnglish textstatisticsinformation
- English textlogEnglish textcheckpointoutputdirectory

**useEnglish text**:
```bash
bash scripts/legacy/print_training_data_info.sh
```

**outputexample**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 NeurX trainingdatainformationstatistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  dataEnglish text
✓ English textdataEnglish text (Shard Dataset)
    English textcount: 676
    English text: 55148 English text

✓ trainingEnglish text (Train Split)
    English textcount: 51312 English text
    fileEnglish text: 3.1M

✓ English text (Validation Split)
    English textcount: 6414 English text
    fileEnglish text: 385K

✓ testEnglish text (Test Split)
    English textcount: 6414 English text
    fileEnglish text: 393K

✓ English textdataEnglish text (Cleaned Dataset)
    English textcount: 64140 English text
    fileEnglish text: 3.9M

✓ English textdata (Raw Dataset)
    English textfile: 7 English text
    English text: 7.9M

2️⃣  datafileEnglish text
English textfile (Shard Files):
  [000] shard_00000.jsonl               401 English text     16K
  [001] shard_00001.jsonl               401 English text     16K
  ... English text 666 English text

3️⃣  trainingEnglish textdataEnglish text
trainingdataloadEnglish text:
  [1] English textdataEnglish text (Shard Dataset)
  [2] trainingEnglish text (Train Split)
  [3] English textdataEnglish text (Cleaned Dataset)
  [4] English textdata (Raw Dataset)

4️⃣  English text
✓ English textuse: English textdataEnglish text (Shard Dataset)
```

### 2. English texttrainingdataloadEnglish text ✅
**file**: `scripts/legacy/run_model_large_pretrain.sh`

English text:
- **English textdataEnglish text**: English text, trainingEnglish text, English textdata, English textdata
- **English textloadinformation**: English textdataEnglish text, path, English text
- **English text**: English text5English textinformation
- **English text/testEnglish text**: English text, English texttestEnglish textpath
- **logEnglish text**: English textinformationEnglish textlogfile

**outputexample**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ English textdataEnglish text
  dataEnglish textpath: /Users/feifei/shuwen/train/neurx/data/pretrain_dataset/shard
  English text:   676 English text
  English text:   55148 English text
  English text:
    - shard_00000.jsonl (  401 English text, 16K)
    - shard_00001.jsonl (  401 English text, 16K)
    - shard_00002.jsonl (  401 English text, 16K)
    ... English text 673 English text

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 trainingdataconfigurationsummary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
dataEnglish text: Shard Dataset (English textdataEnglish text)
datapath:   /Users/feifei/shuwen/train/neurx/data/pretrain_dataset/shard
English text:   55148 English text
modelconfiguration:   neurx-1t-moe (parameter: 1000000M)
batch size: 2
English text:   4096
trainingstepEnglish text:   500000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3. trainingEnglish textfileEnglish text ✅
**file**: `scripts/legacy/run_model_large_pretrain.sh` (train_epoch function)

English text:
- **English textfile**: English texttrainingstepEnglish textdatafileEnglish text
- **logEnglish text**: English texttrainingstepEnglish textlogfile, English textfileEnglish textinformation

**outputexample**:
```
Epoch 1/3 trainingEnglish text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📂 dataEnglish text: Shard Dataset (English textdataEnglish text)
📍 path:   /Users/feifei/shuwen/train/neurx/data/pretrain_dataset/shard

Step 0/100 [░░░░░░░░░░░░░░░░░░░░] 📄 shard_00000.jsonl | Loss: 2.4123 LR: 6.00e-04 | Tokens: 0K
Step 10/100 [██░░░░░░░░░░░░░░░░░░] 📄 shard_00001.jsonl | Loss: 2.3421 LR: 5.88e-04 | Tokens: 327680K
Step 20/100 [████░░░░░░░░░░░░░░░░] 📄 shard_00002.jsonl | Loss: 2.2718 LR: 5.76e-04 | Tokens: 655360K
Step 30/100 [██████░░░░░░░░░░░░░░] 📄 shard_00000.jsonl | Loss: 2.2015 LR: 5.64e-04 | Tokens: 983040K
```

### 4. Makefile English text ✅
**file**: `Makefile`

English text:
- `make print-data-info`: English texttrainingdatainformation
- `make train` English text `print-data-info` English texttrainingEnglish textdatainformation

**useEnglish text**:
```bash
# English textdatainformation
make print-data-info

# training(English textdatainformation)
make train
```

### 5. .gitignore English text ✅
**file**: `.gitignore`

English text:
- `data/pretrain_dataset/raw/` - English textdata
- `data/pretrain_dataset/cleaned/` - English textdata
- `data/pretrain_dataset/shard/` - English textdata
- `data/training_data_splits/` - trainingEnglish text
- `artifacts/logs/` - traininglog
- `artifacts/checkpoints/` - modelcheckpoint
- `*.jsonl` - English text JSONL datafile

English textdatafileEnglish text git English text.

## fileEnglish text

| file | English text | English text |
|------|------|------|
| `scripts/legacy/print_training_data_info.sh` | English text | 📊 trainingdatainformationstatisticsEnglish text |
| `scripts/legacy/run_model_large_pretrain.sh` | English text | English textdataloadEnglish texttrainingEnglish text |
| `Makefile` | English text | English text `print-data-info` English text |
| `.gitignore` | English text | English textdatadirectoryEnglish text |

## logEnglish textinformation

English texttraininginformationEnglish textlogfile:
```
/Users/feifei/shuwen/train/neurx/artifacts/logs/model_large_pretrain_TIMESTAMP.log
```

**logEnglish textexample**:
```
[data] English textdataEnglish text
[data] English text: 676 English text
[data] English text: 55148 English text
[train] Step 0 - File: shard_00000.jsonl - Loss: 2.4123 - Tokens: 0K
[train] Step 10 - File: shard_00001.jsonl - Loss: 2.3421 - Tokens: 327680K
[train] Step 100 - File: shard_00010.jsonl - Loss: 2.1234 - Tokens: 3276800K
[epoch] Epoch 1 completed - Loss: 2.4123 → 1.5734 - Throughput: 32000 tokens/sec
```

## useEnglish text

### English texttrainingdatainformation
```bash
cd /Users/feifei/shuwen/train/neurx
make print-data-info
```

### starttraining(English textdatainformation)
```bash
make train
```

### English texttraininglog
```bash
tail -f artifacts/logs/model_large_pretrain_*.log
```

### quickEnglish textdatafile
```bash
# English text
ls -lh data/pretrain_dataset/shard/shard_*.jsonl | head -20

# statisticsEnglish text
wc -l data/pretrain_dataset/shard/shard_*.jsonl | tail -1

# English texttrainingEnglish textinformation
wc -l data/pretrain_dataset/cleaned/train.jsonl
du -h data/pretrain_dataset/cleaned/train.jsonl
```

## English text

✅ **English textdataEnglish text**: English texttrainingdata
✅ **English textinformationEnglish text**: English textdataEnglish text, path, English text, fileEnglish text
✅ **English textfileEnglish text**: trainingEnglish textfileEnglish text
✅ **logEnglish text**: English textinformationEnglish textlogfileEnglish text
✅ **English textmanagement**: English textdataEnglish textloadEnglish text
✅ **English textsupport**: completesupportEnglish textdataEnglish textload
✅ **testEnglish textsupport**: English texttraining/English text/testEnglish textcompleteinformation

## English textstep

English textuseEnglish text:
1. **English texttrainingEnglish text**: quickEnglish textuseEnglish textdataEnglish text
2. **English text**: English textlogEnglish textdataloadEnglish textinformation
3. **datamanagement**: English texttrainingdata
4. **English text**: English texttrainingEnglish textfileEnglish text
