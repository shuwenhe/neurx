# make train English text

## English text
`make train` English textoutputlogEnglish text, English text.

## English text

### 1️⃣ logEnglish text
```bash
# MakefileEnglish text:
cd '$(CURDIR_UNIX)' && ( ... ) 2>&1 | tee -a $(LOG_DIR)/train_$(shell date +%Y%m%d_%H%M%S).log
```
English textoutputEnglish text **logfile** English text, English text `tee` outputEnglish text.English textoutput, English text:
- English textoutput
- English textinput
- English textI/OEnglish text

### 2️⃣ actualEnglish text
English textfilesystemEnglish text, `make train` actualEnglish text:

✅ **dataclean** - English text
- English text24GBEnglish textWikipedia XML.bz2file
- generateEnglish text304MBEnglish textdata: `pretrain_data_cleaned.jsonl`
- trainingEnglish text: `train.jsonl` (9.8M)
- English text: `val.jsonl` (0B - English textRequiredEnglish text)
- testEnglish text: `test.jsonl` (0B - English textRequiredEnglish text)

✅ **dataEnglish text** - English text
- generateEnglish text128English text(English text20MBEnglish text)
- English text: 1.9GB
- English text: 71,451

✅ **Manifestgenerate** - English text
- `dataset/pretrain/manifest.json` English textgenerate
- English textdata

⏳ **actualtraining** - English text(English text)
- `run_large_pretrain.sh` English text
- English textcompileSEnglish textruntraining
- English textfilesystemEnglish textstate

## English textmonitoringEnglish text

### English text1: English textlog
```bash
# English texttraininglog
tail -f artifacts/logs/train_*.log | grep "training\|Training\|TRAIN\|epoch\|loss"

# English textlogfile
tail -f artifacts/logs/train_20260707_094802.log
```

### English text2: monitoringScompileEnglish text
```bash
# English textScompileEnglish textrun
ps aux | grep -i "s.*compile\|s.*ir\|neurx_train"

# English textScompileoutput
watch -n 1 'ls -lh build/training/ 2>/dev/null || echo "No output yet"'
```

### English text3: English texttrainingoutput
```bash
# English textgenerateEnglish textcheckpoint
ls -lh artifacts/checkpoints/

# monitoringfileEnglish text
watch -n 2 'du -sh artifacts/checkpoints/*'
```

## English text: dataEnglish texttestEnglish text

fileEnglish text:
- `train.jsonl`: 9.8M ✅
- `val.jsonl`: 0B ❌ (English textcontent)
- `test.jsonl`: 0B ❌ (English textcontent)

**English text**: `clean_data.sh` English text.

### English textstepEnglish text

English text `scripts/legacy/clean_data.sh`, English text:

```bash
# English text:
total = sum(1 for _ in output_file.open("r", encoding="utf-8"))
train_size = total * 8 // 10
val_size = total // 10
test_size = total - train_size - val_size
```

English textcomputeEnglish text.English textinformation:

```python
total = sum(1 for _ in output_file.open("r", encoding="utf-8"))
train_size = total * 8 // 10
val_size = total // 10
test_size = total - train_size - val_size

print(f"DEBUG: total={total}, train_size={train_size}, val_size={val_size}, test_size={test_size}")
```

## English text

### quickEnglish text1: English textlogoutput
English text Makefile English text train English text, English textlogEnglish text `tee` English textoutput:

```bash
# English text:
cd '$(CURDIR_UNIX)' && ... 2>&1 | tee -a $(LOG_DIR)/train_...

# English text:
cd '$(CURDIR_UNIX)' && ... 2>&1
```

### quickEnglish text2: English textrunEnglish textmonitoring
```bash
# starttrainingpipeline(English text)
make train &

# English text1English textstart
sleep 1

# English textlog
tail -f artifacts/logs/train_*.log

# RequiredEnglish text Ctrl+C English textlogEnglish text(English texttraining)
```

### quickEnglish text3: English textphaserun
```bash
# English textrundataEnglish text(English text, AllowedEnglish text)
bash scripts/legacy/clean_data.sh

# English textrunEnglish textmodelEnglish texttraining
bash scripts/legacy/run_large_pretrain.sh
```

## run_large_pretrain.sh English text

English textMakefile, English text:
1. compile `trainer/industrial_1t_training.s` English textfileEnglish textIR
2. generateEnglish textfile
3. runtrainingEnglish text
4. generatecheckpointfileEnglish text `artifacts/checkpoints/`

## English text

- [ ] English text train_*.log fileEnglish text
- [ ] English text `training/` directoryEnglish text `.ir` file
- [ ] English text `artifacts/checkpoints/` English textfile
- [ ] run `ps aux | grep make` English textmakeEnglish text
- [ ] run `ps aux | grep s` English textScompileEnglish textrun
- [ ] English texttestEnglish text

## logfileEnglish text
```
artifacts/logs/train_20260707_094802.log  # English texttraininglog
artifacts/logs/train_20260707_094321.log  # English text
...
```

## fileEnglish textstateEnglish text
| phase | state | file |
|------|------|------|
| English textdata | ✅ | dataset/pretrain/raw/*.bz2 (24GB) |
| English textdata | ✅ | dataset/pretrain/cleaned/*.jsonl (304MB) |
| dataEnglish text | ✅ | dataset/pretrain/shard/*.jsonl (1.9GB) |
| Manifest | ✅ | dataset/pretrain/manifest.json |
| Scompile | ? | build/training/*.ir |
| trainingrun | ? | artifacts/checkpoints/* |
