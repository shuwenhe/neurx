# MMLU EvaluationframeworkCompletedocumentation

## 概述

这是为 NeurX framework构建 of Complete MMLU (Massive Multitask Language Understanding) 基准Evaluationframework.用于VerificationModel in  57  学科上 of 多任务理解能力.

**目标**: Verification Qwen 0.5B Model达 to  78%+ MMLU accuracy

## Filestructure

```
eval/
├── mmlu_data.s              # MMLU Dataloaddevice (376 line)
├── mmlu_evaluator.s         # MMLU 5-shot Evaluationpipeline (475 line)
├── run_mmlu_benchmark.s     # EvaluationRundevicescript (130 line)
├── benchmark_eval.s         # 通用基准framework (have存 in )
└── README_MMLU.md           # 此documentation
```

## module详解

### 1. MMLU Dataloaddevice (`mmlu_data.s`)

**function**: load and 管理 MMLU Dataset

**核心structure**:
```s
struct mmlu_question {
    string task_name        // 任务名 (e.g., "abstract_algebra")
    string question         // 题目文本
    string choice_a         // option A
    string choice_b         // option B
    string choice_c         // option C
    string choice_d         // option D
    string correct_answer   // 正确答案 ("A", "B", "C", "D")
    int qid                 // 唯一题目 ID
}

struct mmlu_dataset_state {
    map[string][]mmlu_question questions_by_task  // 按任务Group
    map[string][]mmlu_question dev_by_task        // Few-shot sample
    int total_questions
    int total_dev
    bool is_loaded
}
```

**任务覆盖**:
- **STEM** (19 任务): 数学、物理、化学、生物、计算机科学等
- **Social Science** (13 任务): 经济学、政治学、心理学、法律等
- **Humanities** (8 任务): 历史、文学、艺术、宗教等
- **Other** (17 任务): medical、商业道德、Clinical知识等

**总计**: 57  任务, ~14K Test题

### 2. MMLU Evaluationdevice (`mmlu_evaluator.s`)

**function**: Implementation 5-shot Evaluationprocess

**核心process**:

```
For each test question:
  1. 构建 5-shot prompt (带 5  Example)
  2. For each choice (A, B, C, D):
     - 计算 continuation log-likelihood
     - P(choice | prompt)
  3. 选择 argmax (按 token 数量归一化)
  4. 与正确答案比对
  5. 累计accuracy
```

**keyfunction**:

```s
// 构建 few-shot prompt
func build_mmlu_fewshot_prompt(
    []mmlu_question examples,
    mmlu_question test_q
) string

// Evaluation单 任务
func evaluate_mmlu_task(
    language_model model,
    string task_name,
    []mmlu_question test_questions,
    []mmlu_question dev_examples,
    mmlu_eval_config cfg
) mmlu_task_result

// RunComplete基准
func evaluate_mmlu_benchmark(
    language_model model,
    mmlu_dataset_state dataset,
    mmlu_eval_config cfg
) mmlu_eval_result
```

**Output**:
- 整体accuracy
- 按任务accuracy (57  )
- 按class别accuracy (STEM, Social Science, Humanities, Other)

### 3. EvaluationRundevice (`run_mmlu_benchmark.s`)

**function**: Complete of commandlineEvaluationtools

**Usagemethod**:

```bash
cd /Users/shuwen/shuwen/train/neurx

# setting环境变量
export NEURX_ROOT="."
export NEURX_MODEL_PATH="./model/Qwen2.5-0.5B-Instruct"
export NEURX_MMLU_DATA_ROOT="./data/mmlu"
export NEURX_MMLU_SHOTS=5
export NEURX_MMLU_BATCH_SIZE=32

# RunEvaluation
s run eval/run_mmlu_benchmark.s
```

## integrationguide

### 1. 与Trainingprocessintegration

 in  `train/` modulein定期RunEvaluation:

```s
use neurx.eval.mmlu_data
use neurx.eval.mmlu_evaluator

//  in Trainingloopin
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

### 2. 与inference服务integration

 in  `inference/` moduleinVerificationModelQuality:

```s
// 部署前Verification
func verify_model_quality(string model_path) bool {
    model = load_model(model_path)
    dataset = load_mmlu_dataset(...)
    result = evaluate_mmlu_benchmark(model, dataset, cfg)
    
    // 要求 >= 75% 才能部署
    return result.overall_accuracy >= 0.75
}
```

### 3. 与对标frameworkintegration

与其他基准组合:

```s
struct multi_benchmark_result {
    float mmlu_accuracy          // MMLU
    float gsm8k_accuracy         // 数学inference
    float humaneval_accuracy     // 代码能力
    float truthfulqa_accuracy    // 真实性
}

func run_all_benchmarks(...) multi_benchmark_result {
    mmlu = evaluate_mmlu_benchmark(...)
    gsm8k = evaluate_gsm8k_benchmark(...)
    humaneval = evaluate_humaneval_benchmark(...)
    truthfulqa = evaluate_truthfulqa_benchmark(...)
    
    // Generate综合report
}
```

## DataFormat

### MMLU CSV Format

**Testset** (`test/{task}.csv`):
```csv
question|choice_a|choice_b|choice_c|choice_d|answer
"What is 2+2?"|"3"|"4"|"5"|"6"|"B"
"What is the capital of France?"|"London"|"Paris"|"Berlin"|"Madrid"|"B"
```

**Verificationset** (`dev/{task}.csv`):
```csv
(same format, typically 5 examples per task)
```

### Dataload

```s
// 自动 from Directoryload
dataset = mmlu_data.load_mmlu_dataset("./data/mmlu")

// 手动load特定任务
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

## Performance指标

### expected基准

| Model | 规modulo | MMLU | 任务数 |
|------|------|------|--------|
| GPT-3.5 | 175B | 71.4% | 57 |
| Claude 3 Haiku | 15B | 75.9% | 57 |
| Claude 3 Sonnet | 200B | 88.3% | 57 |
| Qwen 0.5B | 0.5B | ? | 57 |
| **目标** | 0.5B | **78%+** | 57 |

### Evaluation成本Estimated

- 总题目数: 14,000
- 平均标记数/题: 150
- 总标记数: 2.1M
- inferenceTime (V100): ~2-3 hours
- 成本: ~$50-100 (AWS g4dn.12xlarge)

## Implementation细节

### Prompt Format

```
Question: What is the capital of France?
A) London
B) Paris
C) Berlin
D) Madrid

Answer: 
```

### 评分method

对每 option计算 log-likelihood:

```
P(answer | question) = exp(log_prob(answer_tokens))
```

**归一化**: 按 token 数量除以 token 长度

```
score = sum(log_prob) / num_tokens
```

选择分数最高 of option.

## 故障排查

### question 1: DataloadFailed

**symptom**: `FileNotFoundError: ./data/mmlu/test/abstract_algebra.csv`

**resolve方案**: 确保DataDirectorystructure:
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

### question 2: OOM (Memory溢出)

**symptom**: GPU MemoryNot足

**resolve方案**: 减小 batch_size
```bash
export NEURX_MMLU_BATCH_SIZE=8
```

### question 3: accuracy为 0%

**symptom**: all题目答案Error

**可能原因**:
- Model未正确load
- Tokenizer Error
- prompt FormatNotmatch

**Debug**: 打印ModelOutput logits

## PerformanceOptimize

### 1. 批Process

```s
// 分批Evaluation相同任务 of 题目
batch_size = 32
for batch in chunks(test_questions, batch_size) {
    evaluate_batch(model, batch)
}
```

### 2. cache

```s
// cachehaveEvaluation of 题目结果
cache: map[string]float = {}
if cache.contains(question_id) {
    return cache[question_id]
}
```

### 3. parallel化

```s
// distributedEvaluation (Not同任务 in Not同 GPU)
tasks_per_gpu = split_tasks(57, num_gpus)
parallel_evaluate(tasks_per_gpu)
```

## 生产部署

### 持续基准Test

每次ModelUpdateafter自动Run:

```bash
#  in  CI/CD processin
make eval-mmlu

# Check结果
if [ $(grep "accuracy" results.json | cut -d: -f2) -lt 0.75 ]; then
  echo "FAIL: Model accuracy below threshold"
  exit 1
fi
```

### reportGenerate

```
artifacts/eval/
├── mmlu_results_2026-07-20.json    # 详细结果
├── mmlu_results_2026-07-20.csv     # 按任务
└── mmlu_benchmark_report.md        # 可视化report
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

## Reference文献

- MMLU 论文: https://arxiv.org/abs/2009.03300
- lm-evaluation-harness: https://github.com/EleutherAI/lm-evaluation-harness
- PEFT integration: `posttrain/adapter/README_PEFT.md`

## next step

1. ✅ Implementation MMLU Dataloaddevice
2. ✅ Implementation 5-shot Evaluationpipeline
3. ✅ CreateEvaluationRundevice
4. ⏳ integration实际Modelload
5. ⏳ 添加 GSM8K 数学inferenceEvaluation
6. ⏳ 添加 HumanEval 代码能力Evaluation
7. ⏳ 构建综合基准仪表板
