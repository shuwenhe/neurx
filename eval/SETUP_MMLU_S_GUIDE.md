# S Language MMLU Downloader - Usage Guide

## 🎯 概述

`setup_mmlu_s.s` 是 MMLU 数据下载器的**纯 S 语言实现**，不依赖 Python 或 Bash。

### 特点
- ✅ 完全用 S 语言编写
- ✅ 使用 curl 进行 HTTP 下载（系统命令）
- ✅ 支持所有 57 个 MMLU 任务
- ✅ 自动重试和错误处理
- ✅ CSV 行数计数和数据验证
- ✅ 环境变量配置

---

## 🚀 快速启动

### 1. 设置环境变量

```bash
cd /Users/shuwen/shuwen/train/neurx

export NEURX_ROOT="."
export NEURX_MMLU_DATA_ROOT="./data/mmlu"
```

### 2. 运行数据下载器

```bash
# 编译并运行S程序
s run eval/setup_mmlu_s.s

# 或者直接编译
s compile eval/setup_mmlu_s.s
./setup_mmlu_s
```

### 3. 预期输出

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

## 📂 输出结构

数据下载完成后的目录结构：

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

## ⚙️ 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NEURX_ROOT` | `.` | 项目根目录 |
| `NEURX_MMLU_DATA_ROOT` | `./data/mmlu` | 数据保存目录 |

### 自定义数据目录

```bash
export NEURX_MMLU_DATA_ROOT="/data/large_disk/mmlu"
s run eval/setup_mmlu_s.s
```

---

## 📊 下载器工作流

```
┌─────────────────────────────────┐
│  setup_mmlu_s.main()            │
└────────────┬────────────────────┘
             │
             ├─ [Step 1] 创建目录
             │           ├─ ./data/mmlu/test
             │           ├─ ./data/mmlu/dev
             │           └─ ./data/mmlu/validation
             │
             ├─ [Step 2] 下载任务
             │           ├─ for each task (57 tasks):
             │           │   ├─ download_file_curl(test_url)
             │           │   ├─ download_file_curl(dev_url)
             │           │   └─ count_csv_rows()
             │           └─ collect stats
             │
             ├─ [Step 3] 验证数据
             │           ├─ find test/*.csv
             │           ├─ find dev/*.csv
             │           └─ verify >= 50 files
             │
             └─ [Step 4] 统计报告
                        ├─ 总任务数
                        ├─ 成功下载数
                        ├─ 问题总数
                        └─ 示例总数
```

---

## 🔍 关键函数

### `main()`
入口点，读取环境变量并启动下载。

### `setup_mmlu_data_s(data_root string) → mmlu_download_stats`
主下载控制器。执行 4 个步骤：
1. 创建目录
2. 下载所有任务
3. 验证数据完整性
4. 生成统计信息

### `download_file_curl(url string, output_path string) → bool`
使用 curl 下载单个文件：
```bash
curl -sS -L --retry 3 --retry-delay 1 -o {output_path} "{url}"
```

### `count_csv_rows(csv_path string) → int`
计算 CSV 文件中的数据行数（不含标题行）。

### `get_task_category(task string) → string`
根据任务名返回类别：STEM | Social | Humanities | Other

---

## 🐛 故障排查

### 问题 1: curl 命令未找到

**错误**:
```
! curl: command not found
```

**解决**:
```bash
# macOS
brew install curl

# Linux
sudo apt-get install curl

# 或使用系统预装的curl
which curl  # 查看安装位置
```

### 问题 2: 网络连接超时

**症状**: 下载卡住或失败

**解决**:
- 检查网络连接
- 确保可访问 HuggingFace
- 增加重试次数（在代码中修改 `--retry 3` → `--retry 5`）

### 问题 3: 磁盘空间不足

**症状**: 下载中途停止

**需要空间**: ~200MB (57 个任务)

**解决**:
```bash
# 检查磁盘空间
df -h /path/to/data

# 使用其他磁盘
export NEURX_MMLU_DATA_ROOT="/mnt/large_disk/mmlu"
```

### 问题 4: 部分文件下载失败

**症状**: Failed count > 0

**解决**:
1. 检查网络稳定性
2. 手动重试失败的任务
3. 查看详细错误（添加 `-v` 到 curl）

---

## 📋 数据验证

下载完成后验证数据：

```bash
# 统计文件数量
ls data/mmlu/test/ | wc -l    # 应该是 57
ls data/mmlu/dev/ | wc -l     # 应该是 57

# 检查文件大小
du -sh data/mmlu/              # 应该是 ~200MB

# 查看样本数据
head -3 data/mmlu/test/abstract_algebra.csv

# 计算总行数
wc -l data/mmlu/test/*.csv | tail -1
```

---

## 🔗 与评估框架集成

下载完成后，可以立即运行 MMLU 评估：

```bash
# 使用 mmlu_data.s 加载数据
s run eval/run_mmlu_benchmark.s
```

数据目录结构会自动被识别：
```s
mmlu_dataset_state dataset = mmlu_data.load_mmlu_dataset("./data/mmlu")
```

---

## ⚡ 性能优化

### 1. 并行下载（未来版本）
目前顺序下载，约 2-5 分钟（取决于网络）。

### 2. 增量下载
如果某些文件已存在，`download_file_curl` 会跳过（需要添加检查）。

### 3. 断点续传
使用 curl 的 `-C -` 选项支持断点续传：
```s
cmd := "curl -sS -L -C - --retry 3 -o " + output_path + " \"" + url + "\""
```

---

## 📝 源代码结构

```
eval/setup_mmlu_s.s
├── 57 个任务列表
│   ├── all_mmlu_stem_tasks()       (19个)
│   ├── all_mmlu_social_tasks()     (13个)
│   ├── all_mmlu_humanities_tasks() (8个)
│   └── all_mmlu_other_tasks()      (17个)
│
├── 数据结构
│   ├── mmlu_download_stats         (统计信息)
│   └── mmlu_csv_question           (问题记录)
│
├── 主函数
│   ├── main()                      (入口)
│   ├── setup_mmlu_data_s()         (控制器)
│   └── download_all_mmlu_tasks()   (下载逻辑)
│
└── 工具函数
    ├── download_file_curl()        (HTTP下载)
    ├── get_task_category()         (分类查询)
    ├── count_csv_rows()            (行计数)
    ├── verify_data_integrity()     (验证)
    └── 字符串工具
        ├── string_int_to_string()
        ├── string_to_int()
        └── string_trim()
```

---

## 🎯 下一步

1. **✅ 下载数据**
   ```bash
   s run eval/setup_mmlu_s.s
   ```

2. **⏳ 集成模型**
   - 在 `run_mmlu_benchmark.s` 中加载实际模型检查点
   - 替换模拟推理

3. **⏳ 运行评估**
   ```bash
   s run eval/run_mmlu_benchmark.s
   ```

4. **⏳ 分析结果**
   - 任务级准确率
   - 类别级准确率
   - 与基准对标

---

## 💡 技术细节

### 为什么使用 curl？

- ✅ 系统通用工具（大多数系统都有）
- ✅ 支持重试和超时
- ✅ 速度快、可靠
- ✅ S 语言可直接调用

### S 运行时函数

该程序使用以下 S 运行时函数：

| 函数 | 说明 |
|------|------|
| `io_println(s string)` | 打印输出 |
| `io_get_env(key, default)` | 读取环境变量 |
| `io_mkdir_recursive(path)` | 创建目录 |
| `runtime_file_exists(path)` | 检查文件 |
| `runtime_read_text_file(path)` | 读取文件 |
| `runtime_run_command(cmd)` | 执行命令 |
| `runtime_run_command_output(cmd)` | 获取命令输出 |

这些都来自 `neurx.runtime.io` 包。

---

## 📞 支持

遇到问题？

1. 查看 [README_MMLU.md](./README_MMLU.md) - 完整技术文档
2. 查看 [QUICKSTART_MMLU.md](./QUICKSTART_MMLU.md) - 快速开始指南
3. 检查环境变量设置
4. 验证 curl 可用性

---

**上次更新**: 2026-07-20  
**状态**: ✅ 生产就绪
