# 🎯 Shard Progress Logging Enhancement

## summary (Summary)
English text `minimal_train.s` English textlogoutput, English texttrainingEnglish textoutputtrainingEnglish text(shard).

---

## 📋 English text (Changes Made)

### file
- **English textfile**: `/Users/shuwen/shuwen/train/neurx/scripts/legacy/minimal_train.s`
- **English text 6 English textmainEnglish text** + **1 English textfunction**

### 1. English text `extract_filename()` function
**English text**: English text 524-535 English text

```s
func extract_filename(string path) string {
    int last_slash = -1
    int i = 0
    while i < str_len(path) {
        if path[i] == 47 {      // ASCII 47 = '/'
            last_slash = i
        }
        i = i + 1
    }
    if last_slash >= 0 && last_slash < str_len(path) - 1 {
        return substring(path, last_slash + 1, str_len(path))
    }
    path
}
```

**English text**: English textcompletepathEnglish textfileEnglish text, English textlogEnglish text.
- input: `/dataset/pretrain/shard/shard_001.jsonl`
- output: `shard_001.jsonl`

---

### 2. English text Shard startlog (Shard START)
**English text**: English text 145 English text(English text)+ English text 147-156 English text

**English text**:
```s
println("║ [Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] Processing: " + shard_path)
```

**English text**:
```s
string shard_name_start = extract_filename(shard_path)

println("║ 📥 [Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] Starting: " + shard_name_start)
println("║ Path: " + shard_path)
println("║ Progress: Total docs=" + int_to_str(docs_seen) + " tokens=" + int_to_str(tokens_seen) + " steps=" + int_to_str(step) + "/" + int_to_str(max_steps))
```

**English textlogEnglish text**: `[📥 SHARD_START] shard_index=X/Y shard_file=filename`

**outputexample**:
```
╔════════════════════════════════════════════════════════════╗
║ 📥 [Shard 1/5] Starting: shard_001.jsonl
║ Path: /dataset/pretrain/shard/shard_001.jsonl
║ Progress: Total docs=0 tokens=0 steps=0/1000
╚════════════════════════════════════════════════════════════╝
[📥 SHARD_START] shard_index=1/5 shard_file=shard_001.jsonl
```

---

### 3. English textlog (Document Progress)
**English text**: English text 230-232 English text

**English text**:
```s
if shard_docs == 1 || mod_int(shard_docs, 100) == 0 {
    println(shard_progress_line(shard_index + 1, shard_count, shard_path, shard_docs, shard_docs_target))
}
```

**English text**:
```s
if shard_docs == 1 || mod_int(shard_docs, 100) == 0 {
    string progress_msg = shard_progress_line(shard_index + 1, shard_count, shard_path, shard_docs, shard_docs_target)
    println("[📊 SHARD_PROGRESS] " + progress_msg + " | Total: docs=" + int_to_str(docs_seen) + " step=" + int_to_str(step) + "/" + int_to_str(max_steps))
    runtime_run_command_output("echo " + shell_escape("[PROGRESS] Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + ": " + extract_filename(shard_path) + " | doc=" + int_to_str(shard_docs) + " | total_step=" + int_to_str(step)) + " >&2")
}
```

**outputexample** (English text100English text):
```
[📊 SHARD_PROGRESS] Shard 1/5: [████────────────────] 500/5000 docs | Total: docs=500 step=25/1000
[PROGRESS] Shard 1/5: shard_001.jsonl | doc=500 | total_step=25
```

---

### 4. English texttrainingstepEnglish textlog - English text (Training Step Logging - Part 1)
**English text**: English text 263-267 English text

**English text**:
```s
string training_msg = "[Training] step=" + int_to_str(step) + "/" + int_to_str(max_steps) + " " + global_bar +
    " | shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " " + shard_bar +
    " | loss=" + fmt_float(last_loss, 4) + " | docs=" + int_to_str(docs_seen) + " | tokens=" + int_to_str(tokens_seen)
```

**English text**:
```s
string shard_name = extract_filename(shard_path)
string training_msg = "[Training] step=" + int_to_str(step) + "/" + int_to_str(max_steps) + " " + global_bar +
    " | 🔹 Shard [" + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] " + shard_name +
    " (docs: " + int_to_str(shard_docs) + "/" + int_to_str(shard_docs_target) + ") " + shard_bar +
    " | loss=" + fmt_float(last_loss, 4) + " | total_docs=" + int_to_str(docs_seen) + " | total_tokens=" + int_to_str(tokens_seen)
```

**outputexample**:
```
[Training] step=50/1000 [██████████████────────────────] | 🔹 Shard [1/5] shard_001.jsonl (docs: 500/5000) [██────] | loss=0.1234 | total_docs=500 | total_tokens=256000
```

---

### 5. English texttrainingstepEnglish textlog - English text (Training Step Logging - Part 2)
**English text**: English text 314-318 English text

**English text**:
```s
string training_msg_2 = "[Training] step=" + int_to_str(step) + "/" + int_to_str(max_steps) + " " + global_bar_2 +
    " | shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " " + shard_bar_2 +
    " | loss=" + fmt_float(last_loss, 4) + " | lr=" + fmt_float(last_lr, 8) + " | docs=" + int_to_str(docs_seen) +
    " | tokens=" + int_to_str(tokens_seen) + " | shard_docs=" + int_to_str(shard_docs) + " | shard_tokens=" + int_to_str(shard_tokens)
```

**English text**:
```s
string shard_name_2 = extract_filename(shard_path)
string training_msg_2 = "[Training] step=" + int_to_str(step) + "/" + int_to_str(max_steps) + " " + global_bar_2 +
    " | 🔹 Shard [" + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] " + shard_name_2 +
    " (docs: " + int_to_str(shard_docs) + "/" + int_to_str(shard_docs_target) + ") " + shard_bar_2 +
    " | loss=" + fmt_float(last_loss, 4) + " | lr=" + fmt_float(last_lr, 8) + " | total_docs=" + int_to_str(docs_seen) +
    " | total_tokens=" + int_to_str(tokens_seen) + " | shard_tokens=" + int_to_str(shard_tokens)
```

**outputexample**:
```
[Training] step=100/1000 [██████████████████──────────────] | 🔹 Shard [2/5] shard_002.jsonl (docs: 1250/5000) [██████──] | loss=0.0987 | lr=0.00015234 | total_docs=6250 | total_tokens=512000 | shard_tokens=256000
```

---

### 6. English text Shard English textlog (Shard COMPLETION)
**English text**: English text 345-352 English text

**English text**:
```s
println("║ [Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] ✓ Completed")
println("║ Docs: " + int_to_str(shard_docs) + " | Tokens: " + int_to_str(shard_tokens))
println("║ Total: docs=" + int_to_str(docs_seen) + " tokens=" + int_to_str(tokens_seen) + " steps=" + int_to_str(step) + "/" + int_to_str(max_steps))
runtime_run_command_output("echo '[STATUS] Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " complete: docs=" + int_to_str(shard_docs) + " tokens=" + int_to_str(shard_tokens) + "' >&2")
emit_heartbeat("shard-complete shard=" + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " path=" + shard_path + " ...")
println("[STATUS] shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " complete: docs=" + int_to_str(shard_docs) + " tokens=" + int_to_str(shard_tokens))
```

**English text**:
```s
string shard_name_complete = extract_filename(shard_path)
println("║ ✅ [Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] Completed: " + shard_name_complete)
println("║ This Shard: docs=" + int_to_str(shard_docs) + " tokens=" + int_to_str(shard_tokens))
println("║ Cumulative: docs=" + int_to_str(docs_seen) + " tokens=" + int_to_str(tokens_seen) + " steps=" + int_to_str(step) + "/" + int_to_str(max_steps))
runtime_run_command_output("echo '[STATUS] ✅ Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " complete: " + shard_name_complete + " | docs=" + int_to_str(shard_docs) + " | tokens=" + int_to_str(shard_tokens) + " | cumulative_step=" + int_to_str(step) + "' >&2")
emit_heartbeat("shard-complete shard=" + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " shard_name=" + shard_name_complete + " path=" + shard_path + " ...")
println("[✅ SHARD_COMPLETE] shard_index=" + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " shard_file=" + shard_name_complete + " shard_docs=" + int_to_str(shard_docs) + " step=" + int_to_str(step) + "/" + int_to_str(max_steps))
```

**outputexample**:
```
╔════════════════════════════════════════════════════════════╗
║ ✅ [Shard 1/5] Completed: shard_001.jsonl
║ This Shard: docs=5000 tokens=1024000
║ Cumulative: docs=5000 tokens=1024000 steps=250/1000
╚════════════════════════════════════════════════════════════╝
[✅ SHARD_COMPLETE] shard_index=1/5 shard_file=shard_001.jsonl shard_docs=5000 step=250/1000
```

---

### 7. English text Flush log (Final Flush)
**English text**: English text 371-373 English text

**English text**:
```s
runtime_run_command_output("echo '[TRAIN] Step " + int_to_str(step) + ": loss=" + fmt_float(last_loss, 4) + " lr=" + fmt_float(last_lr, 8) + " shard=" + last_shard + "' >&2")
println("[Training] flush shard=" + last_shard + " step=" + int_to_str(step) + " loss=" + fmt_float(last_loss, 4) + " lr=" + fmt_float(last_lr, 8))
```

**English text**:
```s
string final_shard_name = extract_filename(last_shard)
runtime_run_command_output("echo '[TRAIN] ✓ FINAL FLUSH Step " + int_to_str(step) + ": loss=" + fmt_float(last_loss, 4) + " lr=" + fmt_float(last_lr, 8) + " shard=" + final_shard_name + " (" + last_shard + ")' >&2")
println("[Training] ✓ FINAL FLUSH shard=" + final_shard_name + " step=" + int_to_str(step) + "/" + int_to_str(max_steps) + " loss=" + fmt_float(last_loss, 4) + " lr=" + fmt_float(last_lr, 8))
```

**outputexample**:
```
[TRAIN] ✓ FINAL FLUSH Step 500: loss=0.0856 lr=0.00001234 shard=shard_002.jsonl (/dataset/pretrain/shard/shard_002.jsonl)
[Training] ✓ FINAL FLUSH shard=shard_002.jsonl step=500/1000 loss=0.0856 lr=0.00001234
```

---

## 🎯 logEnglish text (Log Markers)

English textAlloweduseEnglish text/grep log:

| English text | English text | English text |
|------|------|------|
| `📥 SHARD_START` | Shard startEnglish text | `grep "📥 SHARD_START" log.txt` |
| `📊 SHARD_PROGRESS` | Shard English text | `grep "📊 SHARD_PROGRESS" log.txt` |
| `🔹 Shard [X/Y]` | trainingstepEnglish textShard | `grep "🔹 Shard" log.txt` |
| `✅ SHARD_COMPLETE` | Shard English text | `grep "✅ SHARD_COMPLETE" log.txt` |
| `✓ FINAL FLUSH` | English textgradientEnglish text | `grep "✓ FINAL FLUSH" log.txt` |

---

## 📈 logoutputexamplecompletepipeline

```
╔════════════════════════════════════════════════════════════╗
║ 📥 [Shard 1/5] Starting: shard_001.jsonl
║ Path: /dataset/pretrain/shard/shard_001.jsonl
║ Progress: Total docs=0 tokens=0 steps=0/1000
╚════════════════════════════════════════════════════════════╝
[📥 SHARD_START] shard_index=1/5 shard_file=shard_001.jsonl

[📊 SHARD_PROGRESS] Shard 1/5: [████----] 100/5000 docs | Total: docs=100 step=5/1000
[PROGRESS] Shard 1/5: shard_001.jsonl | doc=100 | total_step=5

[Training] step=10/1000 [══════--------] | 🔹 Shard [1/5] shard_001.jsonl (docs: 200/5000) [████──] | loss=0.2345 | total_docs=200 | total_tokens=51200

[📊 SHARD_PROGRESS] Shard 1/5: [████████──────────────] 500/5000 docs | Total: docs=500 step=25/1000
[PROGRESS] Shard 1/5: shard_001.jsonl | doc=500 | total_step=25

[Training] step=50/1000 [═══════════────────────] | 🔹 Shard [1/5] shard_001.jsonl (docs: 500/5000) [██──] | loss=0.1234 | total_docs=500 | total_tokens=256000

╔════════════════════════════════════════════════════════════╗
║ ✅ [Shard 1/5] Completed: shard_001.jsonl
║ This Shard: docs=5000 tokens=1024000
║ Cumulative: docs=5000 tokens=1024000 steps=250/1000
╚════════════════════════════════════════════════════════════╝
[✅ SHARD_COMPLETE] shard_index=1/5 shard_file=shard_001.jsonl shard_docs=5000 step=250/1000

╔════════════════════════════════════════════════════════════╗
║ 📥 [Shard 2/5] Starting: shard_002.jsonl
...
```

---

## ✅ English text (Verification Checklist)

- [x] `extract_filename()` functionEnglish text
- [x] Shard START logEnglish text
- [x] English textlogEnglish text (English text100English text)
- [x] trainingstepEnglish textlogEnglish text (2English text)
- [x] Shard COMPLETION logEnglish text
- [x] Final FLUSH logEnglish text
- [x] English textlogEnglish text Shard fileEnglish text
- [x] English textlogEnglish textinformation
- [x] logEnglish text

---

## 🚀 useEnglish text (Usage)

### 1. English textrun
```bash
cd /Users/shuwen/shuwen/train/neurx/script
./minimal_train.s
```

### 2. English textlog
```bash
# English text Shard English text
./minimal_train.s 2>&1 | grep -E "📥|✅"

# English texttrainingEnglish text Shard information
./minimal_train.s 2>&1 | grep "🔹 Shard"

# English text
./minimal_train.s 2>&1 | grep "📊 SHARD_PROGRESS"

# English textcompletelog(English textstderr)
./minimal_train.s 2>&1 | tee training.log
```

### 3. English textmonitoringEnglish text Shard
```bash
# monitoringEnglish text 2 English text Shard
./minimal_train.s 2>&1 | grep "Shard \[2/"

# monitoringEnglish text Shard file
./minimal_train.s 2>&1 | grep "shard_002.jsonl"
```

---

## 📝 English text

- **English text**: 7 English text + 1 English textfunction
- **English text**: English text ~30 English text
- **English text**: ✅ English text(English textlog)
- **English text**: ✅ English text(English textlogoutput)
- **English text**: ✅ English text(trainingEnglish text)

---

**generateEnglish text**: 2026-07-10
**file**: `/Users/shuwen/shuwen/train/neurx/scripts/legacy/minimal_train.s`
