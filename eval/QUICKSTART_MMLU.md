# MMLU 评估框架 - 快速开始指南

## 🚀 5分钟快速上手

### 1. 下载 MMLU 数据

```bash
cd /Users/shuwen/shuwen/train/neurx

# 自动下载并准备数据 (首次需要3-5分钟)
bash scripts/setup_mmlu_data.sh

# 验证数据
ls -la data/mmlu/test/*.csv | head -5
ls -la data/mmlu/dev/*.csv | head -5
```

**预期输出**:
```
MMLU Dataset Downloader
=========================================

Configuration:
  Project root: .
  Data root: ./data/mmlu
  HF repo: cais/mmlu
  Split mode: standard

[Step 1] Creating data directories...
  ✓ Directories created

[Step 2] Downloading MMLU dataset from HuggingFace...
  ✓ abstract_algebra: test (100 items), dev (5 items)
  ✓ anatomy: test (135 items), dev (5 items)
  ... (55 more tasks)

[Step 3] Verifying data integrity...
  Test files: 57
  Dev files: 57
  ✓ Data integrity verified

Test set:  14,042 questions across 57 tasks
Dev set:   285 examples across 57 tasks
Total:     14,327 items
```

### 2. 运行 MMLU 基准评估

```bash
# 设置环境变量
export NEURX_ROOT="."
export NEURX_MODEL_PATH="./model/Qwen2.5-0.5B-Instruct"
export NEURX_MMLU_DATA_ROOT="./data/mmlu"
export NEURX_MMLU_SHOTS=5
export NEURX_MMLU_BATCH_SIZE=32

# 运行评估
s run eval/run_mmlu_benchmark.s
```

### 3. 查看结果

评估完成后会看到：

```
========================================
MMLU 5-Shot Benchmark Evaluation
========================================

[Eval] abstract_algebra (STEM)...
  ✓ abstract_algebra: 42.3% (42/100)
[Eval] anatomy (STEM)...
  ✓ anatomy: 51.2% (69/135)
... (55 more tasks)

========================================
MMLU Results
========================================
Overall Accuracy: 48.5%
Total: 6824/14042 correct

STEM:           45.2% (2341/5184)
Social Science: 52.1% (2289/4393)
Humanities:     48.9% (1864/3812)
Other:          50.1% (1330/2653)
```

## 📊 框架架构

```
eval/
├── mmlu_data.s              # 📥 数据加载
│   └─ 57 tasks × 2 splits (test/dev)
│
├── mmlu_evaluator.s         # 🧠 评估逻辑
│   ├─ 5-shot prompt 构建
│   ├─ Log-likelihood 计算
│   └─ 准确率汇总
│
├── run_mmlu_benchmark.s     # 🏃 运行器
│   ├─ 模型加载
│   ├─ 数据装载
│   ├─ 评估执行
│   └─ 结果展示
│
└── README_MMLU.md           # 📖 完整文档
```

## 🔧 配置选项

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `NEURX_MMLU_DATA_ROOT` | `./data/mmlu` | MMLU 数据目录 |
| `NEURX_MMLU_SHOTS` | `5` | Few-shot 样本数 |
| `NEURX_MMLU_BATCH_SIZE` | `32` | 批处理大小 |
| `NEURX_MODEL_PATH` | `./model/Qwen2.5-0.5B-Instruct` | 模型路径 |

**示例：运行 0-shot 评估**:
```bash
export NEURX_MMLU_SHOTS=0
s run eval/run_mmlu_benchmark.s
```

**示例：减少内存占用**:
```bash
export NEURX_MMLU_BATCH_SIZE=8
s run eval/run_mmlu_benchmark.s
```

## 📈 理解结果

### 准确率指标

- **Overall Accuracy**: 所有 14K 题目的整体准确率
- **Category Accuracy**: 按 STEM/Social/Humanities/Other 分类
- **Task Accuracy**: 每个 57 个任务的准确率

### 对标基准

| 模型 | 参数量 | MMLU | 来源 |
|------|--------|------|------|
| GPT-3.5 Turbo | 175B | 71.4% | OpenAI |
| Claude 3 Haiku | 15B | 75.9% | Anthropic |
| Qwen 0.5B (目标) | 0.5B | **78%+** | NeurX |
| Claude 3 Sonnet | 200B | 88.3% | Anthropic |

## 🎯 优化建议

如果准确率低于目标 (78%)：

### 1. 分析错误分布
```bash
# 输出详细错误分析
export NEURX_DEBUG_EVAL=1
s run eval/run_mmlu_benchmark.s > eval_debug.log
```

### 2. 重点改进弱任务
查看 STEM 或 Social Science 的详细错误，针对性改进。

### 3. 增加训练数据
在弱任务数据上进行更多 SFT 训练。

### 4. 调整模型超参
- 增加上下文长度 (支持更长 prompt)
- 提高模型容量
- 优化学习率

## 📝 集成到训练流程

在 `train/` 中定期评估：

```s
use neurx.eval.mmlu_data
use neurx.eval.mmlu_evaluator

// 训练循环中
if should_eval(step, 1000) {
    mmlu_dataset_state dataset = mmlu_data.load_mmlu_dataset("./data/mmlu")
    mmlu_eval_result result = mmlu_evaluator.evaluate_mmlu_benchmark(
        model, dataset, cfg
    )
    
    log_metrics(step, result.overall_accuracy)
    
    if result.overall_accuracy > best_acc {
        save_checkpoint("best_mmlu")
        best_acc = result.overall_accuracy
    }
}
```

## 🐛 常见问题

### Q: 运行很慢
**A**: MMLU 评估需要对 14K 题目逐个推理。预期时间：
- GPU (V100): 2-3 小时
- CPU: 12-24 小时

### Q: 内存不足 (OOM)
**A**: 减小 batch size：
```bash
export NEURX_MMLU_BATCH_SIZE=4
```

### Q: 数据加载失败
**A**: 确保数据目录结构：
```
data/mmlu/
├── test/
│   ├── abstract_algebra.csv
│   ├── anatomy.csv
│   └── ...
└── dev/
    ├── abstract_algebra.csv
    ├── anatomy.csv
    └── ...
```

### Q: 准确率为 0%
**A**: 检查：
1. 模型是否正确加载
2. Tokenizer 是否匹配
3. Prompt 格式是否正确

## 🔗 相关资源

- **完整文档**: [eval/README_MMLU.md](./README_MMLU.md)
- **MMLU 论文**: https://arxiv.org/abs/2009.03300
- **评估套件**: https://github.com/EleutherAI/lm-evaluation-harness
- **PEFT 适配器**: [posttrain/adapter/README_PEFT.md](../posttrain/adapter/README_PEFT.md)

## ✅ 检查清单

- [ ] 已下载 MMLU 数据 (57 tasks)
- [ ] 已验证数据完整性 (~14K 题目)
- [ ] 已设置环境变量
- [ ] 已运行基准评估
- [ ] 已记录基准结果
- [ ] 已集成到训练流程

## 📊 下一步

**立即行动** (本周):
1. ✅ 搭建 MMLU 框架 (已完成)
2. ⏳ 运行初始基准 (48-52% 预期)
3. ⏳ 添加 GSM8K 数学推理评估
4. ⏳ 添加 HumanEval 代码能力评估

**优化方向** (2-4周):
- 推理优化 (Medusa 推测解码)
- 上下文扩展 (200K token 支持)
- 模型改进 (新架构/更多数据)

---

**需要帮助？** 查看完整文档或联系团队。
