# 🔍 English text `make pretrain` English texttimeEnglish text?

## 📊 English text

English textrun `make pretrain` English text, English textlog:

```
Compiling S training pipeline...
compiled /Users/shuwen/shuwen/train/neurx/scripts/legacy/minimal_train.s -> /Users/shuwen/shuwen/train/neurx/artifacts/build/run_large_pretrain/run_large_pretrain.ir
Running training pipeline...
compiled /Users/shuwen/shuwen/train/neurx/artifacts/build/run_large_pretrain/run_large_pretrain.ir -> /Users/shuwen/shuwen/train/neurx/artifacts/build/run_large_pretrain/run_large_pretrain.ir.runner.bin
```

**English texttimemainEnglish textphase**:

| phase | English text | English text |
|------|------|------|
| 1️⃣ S compile | 30-60 English text | compile `minimal_train.s` (500+ English text) English text |
| 2️⃣ IR English text | 5-15 English text | English text IR English text |
| 3️⃣ runtraining | English text | actualtrainingEnglish text |

---

## 🎯 English textRequiredcompile?

| English text | explanation |
|------|------|
| **English text** | S compileEnglish textcompleteEnglish text |
| **English textoptimize** | English textoptimizeEnglish text |
| **IR generate** | generateEnglish text(Intermediate Representation) |
| **English textcompile** | English text IR English text |

---

## ⚡ English text: English textcompilecache

English text `run_large_pretrain.sh`, English textsupport**English textcompile**:

### ✅ English text

```bash
# English textrun(Requiredcompile)
make pretrain
# ⏱️  English text 60+ English text(compile)

# English textrun(English text)
make pretrain
# ✨ English text 2-3 English text(usecache)
```

### 📝 English text

1. **English textfiletimeEnglish text**: English text `minimal_train.s` English text `run_large_pretrain.ir`
2. **English textfileEnglish text**: English textcompile
3. **English textfileEnglish text**: usecacheEnglish text `.ir` English text `.runner.bin`

### 🔄 logexample

```
Compiling S training pipeline...
✓ Using cached S IR: /path/to/run_large_pretrain.ir
  (source unchanged since last compilation)
✓ Using cached S IR runner binary

Running training pipeline...
Real training log: /path/to/run_large_pretrain_20260711_071105.log
Training started. Monitor progress with: tail -f ...
```

---

## 🚀 quickuseEnglish text

### English text 1: English textrun
```bash
make pretrain
# RequiredEnglish text 60+ English textcompile
```

### English text 2: English textrun(English text)
```bash
make pretrain
# usecache, English text 2-3 English text!
```

### English text 3: English texttrainingEnglish text
```bash
# English text scripts/legacy/minimal_train.s English text
make pretrain
# English textfileEnglish text, English textcompile
```

### English text 4: English textcompile
```bash
# English textcacheEnglish textcompile
rm -f artifacts/build/run_large_pretrain/run_large_pretrain.ir*
make pretrain
```

### English text 5: English textcompileEnglish textrun
```bash
NEURX_PRETRAIN_COMPILE_ONLY=1 make pretrain
# compileEnglish textstarttraining
```

---

## 📈 English text

| English text | compileEnglish text | compileEnglish text | English text |
|------|--------|--------|------|
| English textrun | 60s | 60s | 0% (English textcompile) |
| English textrun | 60s | 3s | ⚡ **95%** |
| English text | 60s | 60s | 0% (RequiredEnglish textcompile) |
| English text | 60s | 3s | ⚡ **95%** (English textcompile) |

---

## 🔧 English textoptimize

### English text 1: English textcompile
```bash
# compileEnglish text, cacheresult
NEURX_PRETRAIN_COMPILE_ONLY=1 make pretrain

# English textrunEnglish textusecache
make pretrain  # quick!
make pretrain  # quick!
```

### English text 2: English textcompile(English textScompileEnglish textsupport)
```bash
# English text
S_COMPILER_JOBS=4 make pretrain  # use 4 English text
```

### English text 3: use `ccache` English text S compile
```bash
# English text ccache
brew install ccache

# configuration ccache
export CC="ccache $(which cc)"
make pretrain
```

---

## 📊 compiletimeEnglish text

English textcompletecompileRequired 60 English text:

```
S compileEnglish text:
  ├─ English text (Lexer)        : ~5s
  ├─ English text (Parser)       : ~10s
  ├─ English text (Type Check)   : ~20s
  ├─ IR generate (Code Gen)      : ~15s
  ├─ optimize (Optimization)     : ~8s
  └─ English textfile                : ~2s

IR English text:
  ├─ IR English text                  : ~3s
  ├─ English textgenerate             : ~7s
  └─ English textoptimize               : ~5s
```

**English text**: English text + IR generate

---

## ✅ English text

fileEnglish text: `/Users/shuwen/shuwen/train/neurx/scripts/legacy/run_large_pretrain.sh`

**English text**:
- ✅ English textfiletimeEnglish text
- ✅ cachecompileresult
- ✅ compiletimeEnglish text
- ✅ English textlogexplanation
- ✅ English textcompile

---

## 💡 English text

### Q: English textrunEnglish text?
A: S compileEnglish textRequiredEnglish textcompleteEnglish textcompileEnglish text(English text/English text/English text/English textgenerate).English text.

### Q: English text, English textcache?
A: cacheEnglish textfiletimeEnglish text.English textsaveEnglish textfile.
```bash
# English textcompile
touch scripts/legacy/minimal_train.s
make pretrain
```

### Q: English textcompile, English textrun?
A: English textcompileEnglish textfileEnglish text, English textcompile.
```bash
# usecachequickrun
make pretrain
```

### Q: AllowedEnglish textcompileEnglish text?
A: English text S compileEnglish text.English text `-j` English textsupport, English text.

### Q: English textmonitoringcompileEnglish text?
A: compileEnglish texttimestatistics:
```
Compiling S source to IR (this may take 30-60 seconds on first run)...
✓ S source compiled successfully (took 58s)
```

---

## 📌 English text

| English text | English text |
|------|------|
| English text? | Requiredcompile S English text |
| English text? | English textimplementationEnglish textcompilecache, English textrunEnglish text 95% |
| English text? | English text 30-60 English text(English textconfiguration) |
| English text? | English text 2-3 English text(English textusecache) |
| English textoptimizeEnglish text? | AllowedEnglish textcompileEnglish textcompileEnglish text |

---

**English text**: 2026-07-11
**file**: `/Users/shuwen/shuwen/train/neurx/scripts/legacy/run_large_pretrain.sh`
**English text**: English textcompilecacheEnglish text
