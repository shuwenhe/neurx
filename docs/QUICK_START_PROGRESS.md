# quickEnglish text: `make pretrain` English text

## English text

English text `make pretrain` English text:
```
[STARTUP][runner] waiting for the first training heartbeat
compiled .ir → .ir.runner.bin
```

English text!JIT compileEnglish text**English text**.

---

## English textoutputtimeEnglish text

### English text 0 English text - start
```
Real training log: /path/to/run_large_pretrain_20260711_080134.log
Training started. Monitor progress with: tail -f ...
[STARTUP][runner] S IR runner launching now
[STARTUP][runner] executing training pipeline from ...
[STARTUP][runner] waiting for the first training heartbeat
```

### English text 1-2 English text - compilestart(English textloadEnglish text)
```
[STARTUP][runner] ⠋ JIT compiling S IR runner binary (waiting for heartbeat)...
[STARTUP][runner] ⠙ JIT compiling S IR runner binary (waiting for heartbeat)...
```

### English text 2-4 English text - initializeEnglish text 1-2 phase
```
[STARTUP][init] 📥 phase 1: loading environment variables
[STARTUP][init] ✓ phase 1 complete: environment variables loaded
[STARTUP][init] 📥 phase 2: loading configuration...
[STARTUP][init] ✓ phase 2 complete: configuration loaded
```

### English text 4-6 English text - configurationEnglish text 3 phase
```
[CONFIG] Project Settings:
  Project root  : /Users/shuwen/shuwen/train/neurx
  Batch size    : 32
  Seq len       : 2048
  Max steps     : 1000
  Vocab size    : 50257

[STARTUP][init] 📥 phase 3: validating paths...
[STARTUP][init] ✓ phase 3 complete: paths validated
```

### English text 6-10 English text - datapathEnglish text 4 phase
```
[CONFIG] Data Paths:
  Manifest file : /path/to/manifest.json
  Shard list    : /path/to/shard_list.txt
  Shard dir     : /path/to/shard
  Output dir    : /path/to/checkpoint

[STARTUP][init] 📥 phase 4: initializing training parameters...
[STARTUP][init] ✓ phase 4 complete: training parameters ready
```

### English text 10-15 English text - compileEnglish text
```
[STARTUP][runner] ⠹ JIT compiling S IR runner binary (waiting for heartbeat)...
[STARTUP][compiler] ⚙️  JIT compiling: 2.5 MB generated
[STARTUP][runner] ⠸ JIT compiling S IR runner binary (waiting for heartbeat)...
```

### English text 15-25 English text - English textcompileEnglish text
```
[STARTUP][compiler] ⚙️  JIT compiling: 5.2 MB generated
[STARTUP][compiler] ⚙️  JIT compiling: 8.1 MB generated
[STARTUP][compiler] ⚙️  JIT compiling: 12.4 MB generated
```

### English text 25+ English text - compileEnglish text, trainingstart
```
[STARTUP][compiler] ⚙️  JIT compiling: 18.2 MB generated

========================================
📊 Stage 2: Pre-Training Data Scan
========================================

[STARTUP][manifest] ✓ manifest found
[STARTUP][shard-scan] 📋 loading pre-generated shard list
🔹 [SHARD PROCESSING] Starting shard_00000
📥 [READING] shard_00000.jsonl (doc 0-100)
```

---

## English text

| English text | English text | English text |
|--------|----|----|
| English text | 15English text | 0.5English text |
| compileEnglish text | English text | English textfileEnglish text |
| loadEnglish text | English text | Unicode English text |
| initializephase | 1English text | 4English textphase+8English text |
| English text | ❌ 30English textoutput | ✅ English text |

---

## English text

English text JIT compileEnglish text 30 English text, English text:

```
[STARTUP][compiler] ⚠️  JIT compilation taking longer than expected (~15s)
[STARTUP][compiler] This is normal for the first run; subsequent runs will use cached binary
...(English textcompile)...
```

English text 30 English text, English text:

```
[ERROR] ❌ Startup timeout: S IR runner did not start within 30 seconds
[ERROR] Check if S compiler is properly configured
[ERROR] Log file: /path/to/run_large_pretrain_20260711_080134.log
```

---

## English text

### English text?
```bash
# English textmonitoringstartEnglish text
make pretrain 2>&1 | grep "\[STARTUP\]"
```

### English textcompilephaseEnglish text 30 English text
```bash
# 1. English textlogfile
tail -100f /Users/shuwen/shuwen/train/neurx/artifacts/logs/run_large_pretrain_*.log

# 2. English textcompileEnglish textconfiguration
echo $S_COMPILER
echo $S_RUNNER_BIN
```

### English textcacheEnglish textcompile
```bash
cd /Users/shuwen/shuwen/train/neurx
rm -f artifacts/build/run_large_pretrain/*.runner.bin
make pretrain  # English textcompile, English textquick
```

---

## English text

- [JIT_COMPILATION_PROGRESS.md](JIT_COMPILATION_PROGRESS.md) - English textimplementationEnglish text
- [STARTUP_LOGGING_GUIDE.md](STARTUP_LOGGING_GUIDE.md) - completestartlogEnglish text
- [SHARD_PROGRESS_QUICK_REFERENCE.md](SHARD_PROGRESS_QUICK_REFERENCE.md) - trainingEnglish textlog

---

## quicktest

English text, run:

```bash
cd /Users/shuwen/shuwen/train/neurx
make pretrain 2>&1 | head -50
```

English text 10 English text 10-15 English textoutput.
