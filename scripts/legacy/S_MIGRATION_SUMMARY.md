# Shell English text S language - English text

## ✅ English text

### 1. English text S languageEnglish text

| English text | English text | English text |
|------|------|------|
| `data_utils.s` | English texttoolEnglish text(file, path, English text, JSON) | ~180 English text |
| `data_clean.s` | dataclean(English textsupport, deduplication, split) | ~450 English text |
| `data_shard.s` | dataEnglish text(English text, manifest generate) | ~350 English text |
| `scripts.s` | English text CLI English text(English text) | ~200 English text |
| **English text** | completeEnglish textdataEnglish text | **~1400 English text** |

### 2. English text

✅ **dataclean**
- support JSONL, TXT, XML English text
- English textdeduplication
- generate train/val/test English text

✅ **dataEnglish text**
- English textfileEnglish text
- generate JSON manifest
- English textstatistics

✅ **CLI framework**
```bash
./data_scripts.bin clean              # cleandata
./data_scripts.bin shard              # generateEnglish text
./data_scripts.bin clean-and-shard    # completeEnglish text
./data_scripts.bin help               # English textinformation
```

### 3. Makefile English text

English text 6 English textcompileEnglish text:

```bash
make build-data-scripts   # compileEnglish text
make clean-s              # English textclean
make shard-s              # English text
make data-pipeline-s      # completeEnglish text
make help                 # English text
```

### 4. English text

- `S_MIGRATION_GUIDE.md` - English textmigrationEnglish text
- English text
- English textconfigurationexplanation
- English text

---

## 🚀 quickstart

### compileEnglish text

```bash
cd /home/shuwen/shuwen/train/neurx

# compile
make build-data-scripts

# English text
./artifacts/build/data_scripts/data_scripts.bin help
```

### rundataclean

```bash
# useEnglish textconfiguration
export NEURX_HOME=$(pwd)
export RAW_DIR=dataset/pretrain/raw
export CLEANED_DIR=dataset/pretrain/cleaned

./artifacts/build/data_scripts/data_scripts.bin clean
```

### runcompleteEnglish text

```bash
make data-pipeline-s
```

---

## 📝 English text

```
scripts/legacy/
├── data_utils.s          # toolEnglish text (file, path, English text, JSON)
│   ├── File operations
│   ├── Path manipulation
│   ├── JSON encoding/decoding
│   ├── Environment & config
│   └── Logging utilities
│
├── data_clean.s          # dataclean
│   ├── JSONL processor
│   ├── TXT processor
│   ├── XML processor
│   ├── Deduplication
│   ├── Dataset splits (train/val/test)
│   └── Manifest generation
│
├── data_shard.s          # dataEnglish text
│   ├── File splitting
│   ├── Shard numbering
│   ├── Manifest generation
│   └── Statistics
│
└── scripts.s             # CLI English text
    ├── Command parsing
    ├── Help system
    └── Command dispatch

```

---

## 🔄 English text

| English text | English text |
|------|------|
| `bash clean_data.sh` | `make clean-s` English text `./data_scripts.bin clean` |
| `bash generate_shards.sh` | `make shard-s` English text `./data_scripts.bin shard` |
| English text | `make data-pipeline-s` English text `./data_scripts.bin clean-and-shard` |

---

## 📦 compileEnglish text

```
artifacts/build/data_scripts/
├── data_scripts.ir         # English text(IR)
└── data_scripts.bin        # English text
```

---

## ⚙️ English text

### cleanEnglish text
```bash
NEURX_HOME              # NeurX English textdirectory
RAW_DIR                 # English textdatadirectory
CLEANED_DIR             # cleanoutputdirectory
OUTPUT_FILE             # cleanEnglish text JSONL file
MANIFEST_FILE           # manifest.json path
CHECKPOINT_FILE         # checkpointfile(recoverEnglish text)
```

### English text
```bash
DATASET_ROOT            # dataEnglish textdirectory
INPUT_FILE              # inputfile
SHARD_DIR               # outputdirectory
MAX_SHARDS              # English text
```

---

## ✨ English text

| English text | English text |
|------|------|
| **languageEnglish text** | English text Shell + Python English text → English text S language |
| **English text** | English text → English text |
| **English text** | English text → compileEnglish text |
| **English text** | English text → English textsafety + compileEnglish text |
| **English text** | English text → English text CLI + Makefile |

---

## 🔮 English textoptimizeEnglish text

### English text (English textimplementation)
- [ ] English text S English text JSON English text
- [ ] English text SHA256 English textdeduplication
- [ ] completeEnglish texttimeEnglish textsupport
- [ ] English textoptimize

### English text (RequiredEnglish textsupport)
- [ ] English textfile (English textloadEnglish text)
- [ ] English textfile
- [ ] English textsupport (.bz2, .gz)

### English text (English text)
- [ ] English textcompleteEnglish text Makefile migrationEnglish text S
- [ ] English text S implementation `run_large_pretrain.sh`
- [ ] completeEnglish text NeurX toolEnglish text (S only)

---

## 📚 English textfile

- migrationEnglish text: `scripts/legacy/S_MIGRATION_GUIDE.md`
- compileconfiguration: `Makefile` (English text)
- English textpreference: `/memories/repo/s_project_preferences.md`

---

## 🎯 English text

- ✅ 5 English text S English textcompleteimplementation
- ✅ English text shell English text
- ✅ Makefile English text
- ✅ English text
- ✅ English text CLI English text
- ✅ English textconfigurationEnglish text

---

**migrationstate: English text** ✓

English textstep: compiletest → English text → English textstepEnglish text shell English text
