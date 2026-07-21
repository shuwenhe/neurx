# MMLU Evaluationframework - Quick Startguide

## 🚀 5minutes快速上手

### 1. download MMLU Data

```bash
cd /Users/shuwen/shuwen/train/neurx

# 自动download并ReadyData (首次need3-5minutes)
bash scripts/setup_mmlu_data.sh

# VerificationData
ls -la data/mmlu/test/*.csv | head -5
ls -la data/mmlu/dev/*.csv | head -5
```

**expectedOutput**:
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

### 2. Run MMLU 基准Evaluation

```bash
# setting环境变量
export NEURX_ROOT="."
export NEURX_MODEL_PATH="./model/Qwen2.5-0.5B-Instruct"
export NEURX_MMLU_DATA_ROOT="./data/mmlu"
export NEURX_MMLU_SHOTS=5
export NEURX_MMLU_BATCH_SIZE=32

# RunEvaluation
s run eval/run_mmlu_benchmark.s
```

### 3. View结果

EvaluationAfter completion会看 to :

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

## 📊 frameworkarchitecture

```
eval/
├── mmlu_data.s              # 📥 Dataload
│   └─ 57 tasks × 2 splits (test/dev)
│
├── mmlu_evaluator.s         # 🧠 Evaluation逻辑
│   ├─ 5-shot prompt 构建
│   ├─ Log-likelihood 计算
│   └─ accuracy汇总
│
├── run_mmlu_benchmark.s     # 🏃 Rundevice
│   ├─ Modelload
│   ├─ Data装载
│   ├─ EvaluationExecute
│   └─ 结果展示
│
└── README_MMLU.md           # 📖 Completedocumentation
```

## 🔧 Configurationoption

| 环境变量 | default值 | description |
|---------|--------|------|
| `NEURX_MMLU_DATA_ROOT` | `./data/mmlu` | MMLU DataDirectory |
| `NEURX_MMLU_SHOTS` | `5` | Few-shot sample数 |
| `NEURX_MMLU_BATCH_SIZE` | `32` | 批ProcessSize |
| `NEURX_MODEL_PATH` | `./model/Qwen2.5-0.5B-Instruct` | ModelPath |

**Example:Run 0-shot Evaluation**:
```bash
export NEURX_MMLU_SHOTS=0
s run eval/run_mmlu_benchmark.s
```

**Example:减少Memory占用**:
```bash
export NEURX_MMLU_BATCH_SIZE=8
s run eval/run_mmlu_benchmark.s
```

## 📈 理解结果

### accuracy指标

- **Overall Accuracy**: all 14K 题目 of 整体accuracy
- **Category Accuracy**: 按 STEM/Social/Humanities/Other 分class
- **Task Accuracy**: 每  57  任务 of accuracy

### 对标基准

| Model | Parameter量 | MMLU | 来源 |
|------|--------|------|------|
| GPT-3.5 Turbo | 175B | 71.4% | OpenAI |
| Claude 3 Haiku | 15B | 75.9% | Anthropic |
| Qwen 0.5B (目标) | 0.5B | **78%+** | NeurX |
| Claude 3 Sonnet | 200B | 88.3% | Anthropic |

## 🎯 Optimize建议

如果accuracy低于目标 (78%):

### 1. analysisError分布
```bash
# Output详细Erroranalysis
export NEURX_DEBUG_EVAL=1
s run eval/run_mmlu_benchmark.s > eval_debug.log
```

### 2. 重pointImprove弱任务
View STEM  or  Social Science  of 详细Error,针对性Improve.

### 3. IncreaseTrainingData
 in 弱任务Data上进line更多 SFT Training.

### 4. 调整Model超参
- Increase上下文长度 (support更长 prompt)
- 提高Model容量
- Optimizelearning_rate

## 📝 integration to Trainingprocess

 in  `train/` in定期Evaluation:

```s
use neurx.eval.mmlu_data
use neurx.eval.mmlu_evaluator

// Trainingloopin
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

## 🐛 FAQ

### Q: Run很慢
**A**: MMLU Evaluationneed对 14K 题目逐 inference.expectedTime:
- GPU (V100): 2-3 hours
- CPU: 12-24 hours

### Q: MemoryNot足 (OOM)
**A**: 减小 batch size:
```bash
export NEURX_MMLU_BATCH_SIZE=4
```

### Q: DataloadFailed
**A**: 确保DataDirectorystructure:
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

### Q: accuracy为 0%
**A**: Check:
1. Model是否正确load
2. Tokenizer 是否match
3. Prompt Format是否正确

## 🔗 相关资源

- **Completedocumentation**: [eval/README_MMLU.md](./README_MMLU.md)
- **MMLU 论文**: https://arxiv.org/abs/2009.03300
- **Evaluation套件**: https://github.com/EleutherAI/lm-evaluation-harness
- **PEFT adapter**: [posttrain/adapter/README_PEFT.md](../posttrain/adapter/README_PEFT.md)

## ✅ Check清单

- [ ] havedownload MMLU Data (57 tasks)
- [ ] haveVerificationDataComplete性 (~14K 题目)
- [ ] havesetting环境变量
- [ ] haveRun基准Evaluation
- [ ] have记录基准结果
- [ ] haveintegration to Trainingprocess

## 📊 next step

**立即line动** (本周):
1. ✅ 搭建 MMLU framework (Completed)
2. ⏳ Run初始基准 (48-52% expected)
3. ⏳ 添加 GSM8K 数学inferenceEvaluation
4. ⏳ 添加 HumanEval 代码能力Evaluation

**Optimize方向** (2-4周):
- inferenceOptimize (Medusa 推测decoding)
- 上下文extension (200K token support)
- ModelImprove (新architecture/更多Data)

---

**need帮助?** ViewCompletedocumentation or 联系团队.
