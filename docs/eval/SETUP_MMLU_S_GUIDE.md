# S Language MMLU Downloader - Usage Guide

## 🎯 概述

`setup_mmlu_s.s` 是 MMLU Datadownloaddevice of **纯 S LanguageImplementation**,Notdependency Python  or  Bash.

### 特point
- ✅ 完全用 S Language编写
- ✅ Usage curl enterline HTTP download(systemcommand)
- ✅ supportall 57   MMLU task
- ✅ 自动Retry and ErrorProcess
- ✅ CSV linenumber计number and DataVerification
- ✅ environment variableConfiguration

---

## 🚀 快速Launch

### 1. settingenvironment variable

```bash
cd /Users/shuwen/shuwen/train/neurx

export NEURX_ROOT="."
export NEURX_MMLU_DATA_ROOT="./data/mmlu"
```

### 2. RunDatadownloaddevice

```bash
# compileandRunSprogram
s run eval/setup_mmlu_s.s

#  or 者直接compile
s compile eval/setup_mmlu_s.s
./setup_mmlu_s
```

### 3. expectedOutput

```
=========================================
MMLU Dataset Downloader (S Language)
=========================================

Configuration:
  Project root: .
  Data root: ./data/mmlu
  Source: HuggingFace (cais/mmlu)

[Step 1] Creating data directories...
  ✓ Directories created

[Step 2] Downloading MMLU dataset...
  ✓ abstract_algebra (STEM): test=100 dev=5
  ✓ anatomy (STEM): test=135 dev=5
  ✓ astronomy (STEM): test=152 dev=5
  ... (54 more tasks)

[Step 3] Verifying data integrity...
  Test files: 57
  Dev files: 57
  ✓ Data integrity verified

[Step 4] Dataset Statistics:
  Total tasks: 57
  Downloaded: 57/57
  Failed: 0
  Total test questions: ~14042
  Total dev examples: ~285

✓ MMLU dataset ready for evaluation
```

---

## 📂 Outputstructure

DatadownloadAfter completion of Directorystructure:

```
data/mmlu/
├── test/
│   ├── abstract_algebra.csv      (100 rows)
│   ├── anatomy.csv               (135 rows)
│   ├── astronomy.csv             (152 rows)
│   └── ... (57 files total)
│
├── dev/
│   ├── abstract_algebra.csv      (5 rows)
│   ├── anatomy.csv               (5 rows)
│   ├── astronomy.csv             (5 rows)
│   └── ... (57 files total)
│
└── validation/
    └── ... (optional)
```

---

## ⚙️ environment variable

| variable | defaultvalue | description |
|------|--------|------|
| `NEURX_ROOT` | `.` | project根Directory |
| `NEURX_MMLU_DATA_ROOT` | `./data/mmlu` | DatasaveDirectory |

### customDataDirectory

```bash
export NEURX_MMLU_DATA_ROOT="/data/large_disk/mmlu"
s run eval/setup_mmlu_s.s
```

---

## 📊 downloaddevice工作流

```
┌─────────────────────────────────┐
│  setup_mmlu_s.main()            │
└────────────┬────────────────────┘
             │
             ├─ [Step 1] CreateDirectory
             │           ├─ ./data/mmlu/test
             │           ├─ ./data/mmlu/dev
             │           └─ ./data/mmlu/validation
             │
             ├─ [Step 2] downloadtask
             │           ├─ for each task (57 tasks):
             │           │   ├─ download_file_curl(test_url)
             │           │   ├─ download_file_curl(dev_url)
             │           │   └─ count_csv_rows()
             │           └─ collect stats
             │
             ├─ [Step 3] VerificationData
             │           ├─ find test/*.csv
             │           ├─ find dev/*.csv
             │           └─ verify >= 50 files
             │
             └─ [Step 4] statisticsreport
                        ├─ 总tasknumber
                        ├─ Successdownloadnumber
                        ├─ question总number
                        └─ Example总number
```

---

## 🔍 keyfunction

### `main()`
入口point,readenvironment variableandLaunchdownload.

### `setup_mmlu_data_s(data_root string) → mmlu_download_stats`
主downloadcontroldevice.Execute 4  Step:
1. CreateDirectory
2. downloadalltask
3. VerificationDataCompleteproperty
4. GeneratestatisticsInformation

### `download_file_curl(url string, output_path string) → bool`
Usage curl download单 File:
```bash
curl -sS -L --retry 3 --retry-delay 1 -o {output_path} "{url}"
```

### `count_csv_rows(csv_path string) → int`
calculation CSV Filein of Datalinenumber(Not含标题line).

### `get_task_category(task string) → string`
根据task名returnclass别:STEM | Social | Humanities | Other

---

## 🐛 故障排查

### question 1: curl command未找 to 

**Error**:
```
! curl: command not found
```

**resolve**:
```bash
# macOS
brew install curl

# Linux
sudo apt-get install curl

#  or Usagesystem预装 of curl
which curl  # ViewInstallationlocation
```

### question 2: networkConnectionTimeout

**symptom**: download卡住 or Failed

**resolve**:
- ChecknetworkConnection
- 确保可访问 HuggingFace
- IncreaseRetry次number( in codeinmodification `--retry 3` → `--retry 5`)

### question 3: disk空间Not足

**symptom**: downloadin途stop

**need空间**: ~200MB (57  task)

**resolve**:
```bash
# Checkdisk空间
df -h /path/to/data

# Usage其他disk
export NEURX_MMLU_DATA_ROOT="/mnt/large_disk/mmlu"
```

### question 4: 部分FiledownloadFailed

**symptom**: Failed count > 0

**resolve**:
1. Checknetwork稳定property
2. 手动RetryFailed of task
3. ViewdetailedError(添加 `-v`  to  curl)

---

## 📋 DataVerification

downloadAfter completionVerificationData:

```bash
# statisticsFilenumber量
ls data/mmlu/test/ | wc -l    # 应该是 57
ls data/mmlu/dev/ | wc -l     # 应该是 57

# CheckFileSize
du -sh data/mmlu/              # 应该是 ~200MB

# ViewsampleData
head -3 data/mmlu/test/abstract_algebra.csv

# calculation总linenumber
wc -l data/mmlu/test/*.csv | tail -1
```

---

## 🔗 与Evaluationframeworkintegration

downloadAfter completion,可以立即Run MMLU Evaluation:

```bash
# Usage mmlu_data.s loadData
s run eval/run_mmlu_benchmark.s
```

DataDirectorystructure会自动被识别:
```s
mmlu_dataset_state dataset = mmlu_data.load_mmlu_dataset("./data/mmlu")
```

---

## ⚡ PerformanceOptimize

### 1. paralleldownload(未来Version)
目前顺序download,approximately 2-5 minutes(取决于network).

### 2. 增量download
如果某些Filehavestore in ,`download_file_curl` 会Skip(need添加Check).

### 3. 断point续传
Usage curl  of  `-C -` optionsupport断point续传:
```s
cmd := "curl -sS -L -C - --retry 3 -o " + output_path + " \"" + url + "\""
```

---

## 📝 源codestructure

```
eval/setup_mmlu_s.s
├── 57  task列table
│   ├── all_mmlu_stem_tasks()       (19 )
│   ├── all_mmlu_social_tasks()     (13 )
│   ├── all_mmlu_humanities_tasks() (8 )
│   └── all_mmlu_other_tasks()      (17 )
│
├── Datastructure
│   ├── mmlu_download_stats         (statisticsInformation)
│   └── mmlu_csv_question           (questionrecord)
│
├── Main function
│   ├── main()                      (入口)
│   ├── setup_mmlu_data_s()         (controldevice)
│   └── download_all_mmlu_tasks()   (download逻辑)
│
└── Utility functions
    ├── download_file_curl()        (HTTPdownload)
    ├── get_task_category()         (分classquery)
    ├── count_csv_rows()            (line计number)
    ├── verify_data_integrity()     (Verification)
    └── stringtools
        ├── string_int_to_string()
        ├── string_to_int()
        └── string_trim()
```

---

## 🎯 next step

1. **✅ downloadData**
   ```bash
   s run eval/setup_mmlu_s.s
   ```

2. **⏳ integrationModel**
   -  in  `run_mmlu_benchmark.s` inloadactualModelCheckpoint
   - replacemodulo拟inference

3. **⏳ RunEvaluation**
   ```bash
   s run eval/run_mmlu_benchmark.s
   ```

4. **⏳ analysisresult**
   - task级accuracy
   - class别级accuracy
   - 与benchmark对标

---

## 💡 技术细节

### 为什么Usage curl?

- ✅ systemgenerictools(大多numbersystem都有)
- ✅ supportRetry and Timeout
- ✅ Speed快、可靠
- ✅ S Language可直接call

### S Runtimefunction

该programUsage以下 S Runtimefunction:

| function | description |
|------|------|
| `io_println(s string)` | 打印Output |
| `io_get_env(key, default)` | readenvironment variable |
| `io_mkdir_recursive(path)` | CreateDirectory |
| `runtime_file_exists(path)` | CheckFile |
| `runtime_read_text_file(path)` | readFile |
| `runtime_run_command(cmd)` | Executecommand |
| `runtime_run_command_output(cmd)` | 获取commandOutput |

这些都来自 `neurx.runtime.io` package.

---

## 📞 support

遇 to question?

1. View [README_MMLU.md](./README_MMLU.md) - Complete技术documentation
2. View [QUICKSTART_MMLU.md](./QUICKSTART_MMLU.md) - Quick Startguide
3. Checkenvironment variablesetting
4. Verification curl Availability

---

**上次Update**: 2026-07-20  
**status**: ✅ 生产Ready
