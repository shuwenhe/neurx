# NeurX Data Processing Scripts - S languagemigrationEnglish text

## English text

English textexplanationEnglish textuseEnglish text S languageimplementationEnglish text shell + Python English text.

### migrationEnglish text

- ✅ `scripts/legacy/clean_data.sh` → `scripts/legacy/data_clean.s`
- ✅ `scripts/legacy/generate_shards.sh` → `scripts/legacy/data_shard.s`
- ✅ English texttoolEnglish text → `scripts/legacy/data_utils.s`
- ✅ English text CLI English text → `scripts/legacy/scripts.s`

## compileEnglish text

### compileEnglish textdataEnglish text

```bash
# compilecompleteEnglish textdataEnglish textfile
make build-data-scripts

# English textcompile
S_COMPILER=s ./scripts/compile_data_scripts.sh
```

### compileoutput

- `artifacts/build/data_scripts/data_scripts.ir` - English text
- `artifacts/build/data_scripts/data_scripts.bin` - English text

## useEnglish text

### 1. dataclean

```bash
# useEnglish text(defaultconfiguration)
./artifacts/build/data_scripts/data_scripts.bin clean

# useEnglish textpath
./artifacts/build/data_scripts/data_scripts.bin clean \
  --raw-dir=/custom/raw \
  --cleaned-dir=/custom/cleaned \
  --output-file=/custom/cleaned.jsonl
```

**input: ** English textdatafile(JSONL, TXT, XML)
**output: **
- `dataset/pretrain/cleaned/pretrain_data_cleaned.jsonl`
- `dataset/pretrain/cleaned/train.jsonl`
- `dataset/pretrain/cleaned/val.jsonl`
- `dataset/pretrain/cleaned/test.jsonl`

### 2. dataEnglish text

```bash
# usedefaultconfiguration
./artifacts/build/data_scripts/data_scripts.bin shard

# useEnglish textconfiguration
./artifacts/build/data_scripts/data_scripts.bin shard \
  --input-file=/path/to/train.jsonl \
  --shard-dir=/path/to/shards \
  --manifest-file=/path/to/manifest.json
```

**input: ** `dataset/pretrain/cleaned/train.jsonl`
**output: **
- `dataset/pretrain/shard/shard_00000.jsonl`
- `dataset/pretrain/shard/shard_00001.jsonl`
- ...
- `dataset/pretrain/manifest.json`

### 3. completedataEnglish text(clean + English text)

```bash
./artifacts/build/data_scripts/data_scripts.bin clean-and-shard
```

## English text

### cleanEnglish text

```bash
export NEURX_HOME=/path/to/neurx          # NeurX English textdirectory
export RAW_DIR=dataset/pretrain/raw       # English textdatadirectory
export CLEANED_DIR=dataset/pretrain/cleaned # cleanoutputdirectory
export OUTPUT_FILE=...                     # cleanEnglish text JSONL file
export MANIFEST_FILE=...                   # manifest.json path
```

### English text

```bash
export DATASET_ROOT=/path/to/dataset       # dataEnglish textdirectory
export INPUT_FILE=...                      # inputfilepath
export SHARD_DIR=...                       # English textoutputdirectory
export MAX_SHARDS=128                      # English text
```

## Makefile English text

### English text

English text `Makefile` English text:

```makefile
# compiledataEnglish text
build-data-scripts: check-bash
	mkdir -p $(ARTIFACTS_DIR)/build/data_scripts
	$(S_COMPILER) scripts/legacy/scripts.s $(ARTIFACTS_DIR)/build/data_scripts/data_scripts.ir
	$(S_COMPILER) --emit-bin $(ARTIFACTS_DIR)/build/data_scripts/data_scripts.ir \
		$(ARTIFACTS_DIR)/build/data_scripts/data_scripts.bin

# dataclean (S languageEnglish text)
clean-s: build-data-scripts
	./artifacts/build/data_scripts/data_scripts.bin clean

# dataEnglish text (S languageEnglish text)
shard-s: build-data-scripts
	./artifacts/build/data_scripts/data_scripts.bin shard

# completedataEnglish text (S languageEnglish text)
data-pipeline-s: build-data-scripts
	./artifacts/build/data_scripts/data_scripts.bin clean-and-shard
```

### English text S English text

English text `train` English text:

```makefile
# English text (shell + Python)
# bash scripts/legacy/clean_data.sh
# bash scripts/legacy/generate_shards.sh

# English text (S language)
$(ARTIFACTS_DIR)/build/data_scripts/data_scripts.bin clean-and-shard
```

## English text

| English text | Shell + Python | S language |
|------|-------|--------|
| compileEnglish text | English text | ~5-10s (English text) |
| runEnglish text | English text | ~1.5-2x English text (English text) |
| English textuse | English textdataEnglish text | English text (compileoptimize) |
| English text | English text | English text S language |

## English text

### English textphase (MVP)

1. **JSON English text** - useEnglish text, English textcomplete JSON English text
   - supportEnglish text/English text
   - English textsupportEnglish text

2. **English textfunction** - useEnglish textplaceholder
   - RequiredEnglish text SHA256 English textcompletesupport

3. **timeEnglish text** - useEnglish text
   - RequiredEnglish text `time` English text

4. **English text** - English textimplementation
   - RequiredEnglish textfunction

### English textstepEnglish text

- [ ] English text S English text JSON English text
- [ ] English text SHA256 English text
- [ ] completeEnglish texttimeEnglish textsupport
- [ ] completeEnglish text
- [ ] English textoptimize(English textfile)

## English text

### compileerror: English text `neurx.script.*` English text

**English text: ** compileEnglish text S English textfile

**English text: ** English text `S_COMPILER_EMIT_CWD` English text S English textdirectory

```bash
export S_COMPILER_EMIT_CWD=/path/to/train/s
```

### runEnglish texterror: file I/O failure

**English text: ** patherrorEnglish text

**English text: ** English textconfiguration

```bash
export NEURX_HOME=$(pwd)
./artifacts/build/data_scripts/data_scripts.bin clean
```

### English text: English textfileEnglish text

**English text: ** S languageEnglish textoptimizeEnglish text

**English text: ** English textfile, English textuse Python English text, English text

## English text

- **S English text: ** 1.0
- **English text Makefile English text: ** Required `--emit-bin` support
- **English text: ** 2026-07-07

## English text

English text:

1. English text [English text](#English text) English text
2. English text `scripts/legacy/data_*.s` English text TODO English text
3. English text issue English text PR

## English textfile

- `scripts/legacy/data_utils.s` - English texttoolEnglish text
- `scripts/legacy/data_clean.s` - datacleanEnglish text
- `scripts/legacy/data_shard.s` - dataEnglish text
- `scripts/legacy/scripts.s` - English text CLI English text
- `Makefile` - compileEnglish text
