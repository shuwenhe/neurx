# 用 MedMCQA 数据集后训练 Qwen2.5-0.5B-Instruct 的完整指南

## 📚 数据集信息

- **数据来源**: `/home/shuwen/shuwen/train/dataset/medmcqa/train.json`
- **总数据量**: 182,822 医学多选题
- **格式**: JSONL (每行一个 JSON 对象)
- **数据字段**:
  - `question`: 医学问题
  - `opa`, `opb`, `opc`, `opd`: 四个选项
  - `cop`: 正确答案索引 (0-3)
  - `exp`: 详细解释
  - `subject_name`: 医学学科
  - `topic_name`: 话题

## 🚀 快速开始 (3步)

### 1️⃣ 转换数据集到 SFT 格式

```bash
cd /home/shuwen/shuwen/train/neurx

# 运行转换脚本
bash scripts/convert_medmcqa.sh

# 或设置自定义路径
export MEDMCQA_INPUT=/path/to/train.json
export MEDMCQA_OUTPUT_DIR=/path/to/output
bash scripts/convert_medmcqa.sh
```

**输出**:
```
/home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/
├── train.jsonl    (173,680 examples, 95%)
└── val.jsonl      (9,142 examples, 5%)
```

### 2️⃣ 更新 Makefile 配置

编辑 `/home/shuwen/shuwen/train/neurx/Makefile`，修改第 107 行：

```makefile
# 旧配置
POSTTRAIN_DATA_FILE ?= $(CURDIR_UNIX)/dataset/posttrain/instruction_data.jsonl

# 新配置（使用 MedMCQA 数据）
POSTTRAIN_DATA_FILE ?= $(CURDIR_UNIX)/dataset/medmcqa_sft/train.jsonl
```

### 3️⃣ 启动后训练

```bash
cd /home/shuwen/shuwen/train/neurx

# 运行 SFT 训练
make posttrain

# 或者查看日志
tail -f artifacts/logs/posttrain_*.log
```

## 📊 预期结果

| 阶段 | 时间 | 输出 |
|------|------|------|
| **数据转换** | ~5分钟 | `dataset/medmcqa_sft/` |
| **SFT 训练** | ~2-4小时 | `artifacts/checkpoints/lora_sft/` |
| **模型合并** | ~10分钟 | `/home/shuwen/shuwen/train/model/base-model-posttrain/` |

## 🔧 自定义配置

### 调整超参数

编辑 Makefile 中的：

```makefile
POSTTRAIN_LORA_ALPHA ?= 16      # LoRA alpha
POSTTRAIN_LORA_RANK ?= 8        # LoRA rank
```

### 修改训练数据量

```bash
# 只使用前 5000 条数据测试
head -5000 dataset/medmcqa_sft/train.jsonl > dataset/medmcqa_sft/train_mini.jsonl
export POSTTRAIN_DATA_FILE=$(pwd)/dataset/medmcqa_sft/train_mini.jsonl
make posttrain
```

### 仅验证数据转换

```bash
# 查看转换后的数据格式
head -3 /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/train.jsonl | \
  python3 -m json.tool

# 统计数据集大小
echo "Train examples:" && wc -l dataset/medmcqa_sft/train.jsonl
echo "Val examples:" && wc -l dataset/medmcqa_sft/val.jsonl
```

## 📈 监控训练进度

```bash
# 查看训练日志
tail -f artifacts/logs/posttrain_*.log

# 监控检查点
watch -n 10 'ls -lh artifacts/checkpoints/lora_sft/ | tail -5'

# 监控最终模型
watch -n 5 'ls -lh /home/shuwen/shuwen/train/model/base-model-posttrain/'
```

## ✅ 完整工作流脚本

```bash
#!/bin/bash
set -e

cd /home/shuwen/shuwen/train/neurx

echo "Step 1: Converting MedMCQA dataset..."
bash scripts/convert_medmcqa.sh

echo ""
echo "Step 2: Starting SFT training..."
make posttrain

echo ""
echo "✅ Training complete!"
echo "Model saved to: /home/shuwen/shuwen/train/model/base-model-posttrain/"
```

## 🐛 常见问题

### 问题1: 数据转换失败
```bash
# 检查输入文件
ls -lh /home/shuwen/shuwen/train/dataset/medmcqa/train.json

# 验证格式
head -1 /home/shuwen/shuwen/train/dataset/medmcqa/train.json | python3 -m json.tool
```

### 问题2: 训练报错 "数据文件不存在"
```bash
# 确认输出目录存在
ls -lh /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/

# 重新转换数据
rm -rf /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/
bash scripts/convert_medmcqa.sh
```

### 问题3: GPU 显存不足
```bash
# 减少 batch size (在 Makefile 中)
# 或减少训练数据量
head -50000 dataset/medmcqa_sft/train.jsonl > dataset/medmcqa_sft/train_reduced.jsonl
```

## 📝 数据格式对应关系

```
MedMCQA 原始格式:
{
  "question": "问题文本",
  "opa": "选项A",
  "opb": "选项B",
  "opc": "选项C",
  "opd": "选项D",
  "cop": 0,              // 正确答案(0-3)
  "exp": "解释文本",
  "subject_name": "学科"
}

↓ 转换后 ↓

SFT 格式:
{
  "instruction": "Answer the following medical multiple-choice question accurately.",
  "input": "问题\n\nOptions:\nA) 选项A\nB) 选项B\nC) 选项C\nD) 选项D",
  "output": "Answer: A\n\nExplanation: 解释文本\n\nSubject: 学科"
}
```

## 🔄 后续步骤（可选）

训练完成后，你可以继续：

1. **DPO 对齐** (Step 2)
   ```bash
   cd /home/shuwen/shuwen/train/medical/Post_train/step2_DPO
   bash lora.sh
   ```

2. **GRPO 优化** (Step 3)
   - 需要独立的奖励模型
   - 使用 vLLM 进行回滚生成

3. **模型评测**
   ```bash
   cd /home/shuwen/shuwen/train/neurx
   make eval-medical
   ```

## 📚 相关文档

- NeurX SFT 框架: `posttrain/sft/README_SFT.md`
- MedMCQA 详细说明: `posttrain/adapter/README_PEFT.md`
- 医学评测框架: `eval/README_MEDICAL_EVAL.md`
- 后训练完整指南: `posttrain/MEDICAL_INTEGRATION_GUIDE.md`

---

**开始训练**:
```bash
cd /home/shuwen/shuwen/train/neurx && bash scripts/convert_medmcqa.sh && make posttrain
```
