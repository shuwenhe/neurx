# ✅ MedMCQA SFT 训练完整就绪

## 📋 当前状态

- ✅ 数据集转换完成：182,822 个医学问题
  - 训练集：173,680 条 (95%)
  - 验证集：9,142 条 (5%)
  - 格式：JSONL (指令-输入-输出)
  - 大小：136MB 训练 + 7.2MB 验证

- ✅ NeurX 框架配置完成
  - 基础模型：Qwen2.5-0.5B-Instruct
  - 数据文件：`neurx/dataset/medmcqa_sft/train.jsonl`
  - LoRA 配置：rank=8, alpha=16

- ✅ 所有脚本就绪
  - 数据转换：`scripts/convert_medmcqa.sh`
  - 完整训练：`scripts/train_medmcqa_sft.sh`

## 🚀 立即开始训练

### 方式 1：一行命令（推荐）

```bash
cd /home/shuwen/shuwen/train/neurx && bash scripts/train_medmcqa_sft.sh
```

### 方式 2：分步执行

```bash
# 1. 仅转换数据
cd /home/shuwen/shuwen/train/neurx
bash scripts/convert_medmcqa.sh

# 2. 运行训练
make posttrain

# 3. 合并 LoRA 适配器
make posttrain-merge-lora
```

### 方式 3：试运行（不实际训练）

```bash
bash scripts/train_medmcqa_sft.sh --dry-run
```

## 📊 预期输出

| 阶段 | 时间 | 输出位置 |
|------|------|---------|
| SFT 训练 | 2-4 小时 | `artifacts/checkpoints/lora_sft/` |
| 模型合并 | 10 分钟 | `../model/base-model-posttrain/` |

## 🔍 验证数据示例

```bash
# 查看第一条训练数据
head -1 /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/train.jsonl | python3 -m json.tool

# 统计数据量
echo "Train:" && wc -l /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/train.jsonl
echo "Val:" && wc -l /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/val.jsonl
```

## 💾 关键文件位置

```
/home/shuwen/shuwen/train/
├── dataset/
│   └── medmcqa/
│       └── train.json                    [原始数据]
├── neurx/
│   ├── dataset/
│   │   └── medmcqa_sft/
│   │       ├── train.jsonl               [✓ 已生成]
│   │       └── val.jsonl                 [✓ 已生成]
│   ├── scripts/
│   │   ├── convert_medmcqa.sh            [转换脚本]
│   │   └── train_medmcqa_sft.sh          [训练脚本]
│   ├── artifacts/
│   │   ├── checkpoints/
│   │   │   ├── lora_sft/                 [SFT 适配器]
│   │   │   └── lora_adapter/             [最终适配器]
│   │   └── logs/
│   └── Makefile                          [已更新]
└── model/
    ├── Qwen2.5-0.5B-Instruct/            [基础模型]
    └── base-model-posttrain/             [合并后的模型]
```

## 🎯 下一步

### 立即执行（2-4 小时）
```bash
cd /home/shuwen/shuwen/train/neurx && bash scripts/train_medmcqa_sft.sh
```

### 然后评测
```bash
cd /home/shuwen/shuwen/train/neurx
make eval-medical
```

### 可选：继续对齐
```bash
# DPO 对齐（第2阶段）
cd /home/shuwen/shuwen/train/medical/Post_train/step2_DPO
bash lora.sh

# GRPO 优化（第3阶段）
cd /home/shuwen/shuwen/train/medical/Post_train/step3_GRPO
bash lora.sh
```

## 📝 数据转换详情

### 输入格式（MedMCQA）

```json
{
  "question": "Chronic urethral obstruction due to benign prismatic hyperplasia...",
  "opa": "Hyperplasia",
  "opb": "Hyperophy",
  "opc": "Atrophy",
  "opd": "Dyplasia",
  "cop": 3,
  "exp": "Chronic urethral obstruction because of urinary calculi...",
  "subject_name": "Anatomy",
  "topic_name": "Urinary tract"
}
```

### 输出格式（SFT）

```json
{
  "instruction": "Answer the following medical multiple-choice question accurately.",
  "input": "Chronic urethral obstruction...\n\nOptions:\nA) Hyperplasia\nB) Hyperophy\nC) Atrophy\nD) Dyplasia",
  "output": "Answer: D\n\nExplanation: Chronic urethral obstruction because of urinary calculi...\n\nSubject: Anatomy | Topic: Urinary tract"
}
```

## ⚙️ 自定义配置

编辑 `Makefile` 中的参数：

```makefile
# 改变 LoRA 大小
POSTTRAIN_LORA_RANK ?= 8        # 增大到 16 以提高表现力

# 改变批大小（在配置文件中）
# vim posttrain/sft/config.json  
```

## 🐛 故障排查

### 问题：找不到模型
```bash
ls -lh /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/
```

### 问题：找不到数据
```bash
ls -lh /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/
```

### 问题：训练卡住
```bash
# 查看日志
tail -f /home/shuwen/shuwen/train/neurx/artifacts/logs/posttrain_*.log

# 检查 GPU
nvidia-smi
```

---

**最后一步**：执行以下命令开始训练！
