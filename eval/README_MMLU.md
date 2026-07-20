# MMLU 评估框架完整文档

## 概述

这是为 NeurX 框架构建的完整 MMLU (Massive Multitask Language Understanding) 基准评估框架。用于验证模型在 57 个学科上的多任务理解能力。

**目标**: 验证 Qwen 0.5B 模型达到 78%+ MMLU 准确率

## 文件结构

```
eval/
├── mmlu_data.s              # MMLU 数据加载器 (376 行)
├── mmlu_evaluator.s         # MMLU 5-shot 评估管道 (475 行)
├── run_mmlu_benchmark.s     # 评估运行器脚本 (130 行)
├── benchmark_eval.s         # 通用基准框架 (已存在)
└── README_MMLU.md           # 此文档
```

## 模块详解

### 1. MMLU 数据加载器 (`mmlu_data.s`)

**功能**: 加载和管理 MMLU 数据集

**核心结构**:
```s
struct mmlu_question {
    string task_name        // 任务名 (e.g., "abstract_algebra")
    string question         // 题目文本
    string choice_a         // 选项 A
    string choice_b         // 选项 B
    string choice_c         // 选项 C
    string choice_d         // 选项 D
    string correct_answer   // 正确答案 ("A", "B", "C", "D")
    int qid                 // 唯一题目 ID
}

struct mmlu_dataset_state {
    map[string][]mmlu_question questions_by_task  // 按任务分组
    map[string][]mmlu_question dev_by_task        // Few-shot 样本
    int total_questions
    int total_dev
    bool is_loaded
}
```

**任务覆盖**:
- **STEM** (19 任务): 数学、物理、化学、生物、计算机科学等
- **Social Science** (13 任务): 经济学、政治学、心理学、法律等
- **Humanities** (8 任务): 历史、文学、艺术、宗教等
- **Other** (17 任务): 医学、商业道德、临床知识等

**总计**: 57 个任务, ~14K 测试题

### 2. MMLU 评估器 (`mmlu_evaluator.s`)

**功能**: 实现 5-shot 评估流程

**核心流程**:

```
For each test question:
  1. 构建 5-shot prompt (带 5 个示例)
  2. For each choice (A, B, C, D):
     - 计算 continuation log-likelihood
     - P(choice | prompt)
  3. 选择 argmax (按 token 数量归一化)
  4. 与正确答案比对
  5. 累计准确率
```

**关键函数**:

```s
// 构建 few-shot prompt
func build_mmlu_fewshot_prompt(
    []mmlu_question examples,
    mmlu_question test_q
) string

// 评估单个任务
func evaluate_mmlu_task(
    language_model model,
    string task_name,
    []mmlu_question test_questions,
    []mmlu_question dev_examples,
    mmlu_eval_config cfg
) mmlu_task_result

// 运行完整基准
func evaluate_mmlu_benchmark(
    language_model model,
    mmlu_dataset_state dataset,
    mmlu_eval_config cfg
) mmlu_eval_result
```

**输出**:
- 整体准确率
- 按任务准确率 (57 个)
- 按类别准确率 (STEM, Social Science, Humanities, Other)

### 3. 评估运行器 (`run_mmlu_benchmark.s`)

**功能**: 完整的命令行评估工具

**使用方法**:

```bash
cd /Users/shuwen/shuwen/train/neurx

# 设置环境变量
export NEURX_ROOT="."
export NEURX_MODEL_PATH="./model/Qwen2.5-0.5B-Instruct"
export NEURX_MMLU_DATA_ROOT="./data/mmlu"
export NEURX_MMLU_SHOTS=5
export NEURX_MMLU_BATCH_SIZE=32

# 运行评估
s run eval/run_mmlu_benchmark.s
```

## 集成指南

### 1. 与训练流程集成

在 `train/` 模块中定期运行评估:

```s
use neurx.eval.mmlu_data
use neurx.eval.mmlu_evaluator

// 在训练循环中
if should_eval(step, eval_interval) {
    mmlu_dataset_state dataset = mmlu_data.load_mmlu_dataset(data_root)
    mmlu_eval_result result = mmlu_evaluator.evaluate_mmlu_benchmark(
        model,
        dataset,
        cfg
    )
    
    if result.overall_accuracy > best_accuracy {
        save_checkpoint(model, step)
        best_accuracy = result.overall_accuracy
    }
}
```

### 2. 与推理服务集成

在 `inference/` 模块中验证模型质量:

```s
// 部署前验证
func verify_model_quality(string model_path) bool {
    model = load_model(model_path)
    dataset = load_mmlu_dataset(...)
    result = evaluate_mmlu_benchmark(model, dataset, cfg)
    
    // 要求 >= 75% 才能部署
    return result.overall_accuracy >= 0.75
}
```

### 3. 与对标框架集成

与其他基准组合:

```s
struct multi_benchmark_result {
    float mmlu_accuracy          // MMLU
    float gsm8k_accuracy         // 数学推理
    float humaneval_accuracy     // 代码能力
    float truthfulqa_accuracy    // 真实性
}

func run_all_benchmarks(...) multi_benchmark_result {
    mmlu = evaluate_mmlu_benchmark(...)
    gsm8k = evaluate_gsm8k_benchmark(...)
    humaneval = evaluate_humaneval_benchmark(...)
    truthfulqa = evaluate_truthfulqa_benchmark(...)
    
    // 生成综合报告
}
```

## 数据格式

### MMLU CSV 格式

**测试集** (`test/{task}.csv`):
```csv
question|choice_a|choice_b|choice_c|choice_d|answer
"What is 2+2?"|"3"|"4"|"5"|"6"|"B"
"What is the capital of France?"|"London"|"Paris"|"Berlin"|"Madrid"|"B"
```

**验证集** (`dev/{task}.csv`):
```csv
(same format, typically 5 examples per task)
```

### 数据加载

```s
// 自动从目录加载
dataset = mmlu_data.load_mmlu_dataset("./data/mmlu")

// 手动加载特定任务
dev_examples = mmlu_data.load_mmlu_dev_examples(
    "./data/mmlu",
    "abstract_algebra",
    5  // num_examples
)

test_questions = mmlu_data.load_mmlu_test_questions(
    "./data/mmlu",
    "abstract_algebra"
)
```

## 性能指标

### 预期基准

| 模型 | 规模 | MMLU | 任务数 |
|------|------|------|--------|
| GPT-3.5 | 175B | 71.4% | 57 |
| Claude 3 Haiku | 15B | 75.9% | 57 |
| Claude 3 Sonnet | 200B | 88.3% | 57 |
| Qwen 0.5B | 0.5B | ? | 57 |
| **目标** | 0.5B | **78%+** | 57 |

### 评估成本估计

- 总题目数: 14,000
- 平均标记数/题: 150
- 总标记数: 2.1M
- 推理时间 (V100): ~2-3 小时
- 成本: ~$50-100 (AWS g4dn.12xlarge)

## 实现细节

### Prompt 格式

```
Question: What is the capital of France?
A) London
B) Paris
C) Berlin
D) Madrid

Answer: 
```

### 评分方法

对每个选项计算 log-likelihood:

```
P(answer | question) = exp(log_prob(answer_tokens))
```

**归一化**: 按 token 数量除以 token 长度

```
score = sum(log_prob) / num_tokens
```

选择分数最高的选项。

## 故障排查

### 问题 1: 数据加载失败

**症状**: `FileNotFoundError: ./data/mmlu/test/abstract_algebra.csv`

**解决方案**: 确保数据目录结构:
```
data/
└── mmlu/
    ├── test/
    │   ├── abstract_algebra.csv
    │   ├── anatomy.csv
    │   └── ...
    └── dev/
        ├── abstract_algebra.csv
        ├── anatomy.csv
        └── ...
```

### 问题 2: OOM (内存溢出)

**症状**: GPU 内存不足

**解决方案**: 减小 batch_size
```bash
export NEURX_MMLU_BATCH_SIZE=8
```

### 问题 3: 准确率为 0%

**症状**: 所有题目答案错误

**可能原因**:
- 模型未正确加载
- Tokenizer 错误
- prompt 格式不匹配

**调试**: 打印模型输出 logits

## 性能优化

### 1. 批处理

```s
// 分批评估相同任务的题目
batch_size = 32
for batch in chunks(test_questions, batch_size) {
    evaluate_batch(model, batch)
}
```

### 2. 缓存

```s
// 缓存已评估的题目结果
cache: map[string]float = {}
if cache.contains(question_id) {
    return cache[question_id]
}
```

### 3. 并行化

```s
// 分布式评估 (不同任务在不同 GPU)
tasks_per_gpu = split_tasks(57, num_gpus)
parallel_evaluate(tasks_per_gpu)
```

## 生产部署

### 持续基准测试

每次模型更新后自动运行:

```bash
# 在 CI/CD 流程中
make eval-mmlu

# 检查结果
if [ $(grep "accuracy" results.json | cut -d: -f2) -lt 0.75 ]; then
  echo "FAIL: Model accuracy below threshold"
  exit 1
fi
```

### 报告生成

```
artifacts/eval/
├── mmlu_results_2026-07-20.json    # 详细结果
├── mmlu_results_2026-07-20.csv     # 按任务
└── mmlu_benchmark_report.md        # 可视化报告
```

### 趋势跟踪

```
MMLU Accuracy Trend:
  2026-07-15: 42.1%
  2026-07-17: 45.3% ↑ 3.2%
  2026-07-20: 48.5% ↑ 3.2%
  Target: 78.0%
  Gap: 29.5% to close
```

## 参考文献

- MMLU 论文: https://arxiv.org/abs/2009.03300
- lm-evaluation-harness: https://github.com/EleutherAI/lm-evaluation-harness
- PEFT 集成: `posttrain/adapter/README_PEFT.md`

## 下一步

1. ✅ 实现 MMLU 数据加载器
2. ✅ 实现 5-shot 评估管道
3. ✅ 创建评估运行器
4. ⏳ 集成实际模型加载
5. ⏳ 添加 GSM8K 数学推理评估
6. ⏳ 添加 HumanEval 代码能力评估
7. ⏳ 构建综合基准仪表板
