# 🚀 NeurX MedMCQA 后训练快速参考

## 📋 快速命令

### 一行启动后训练
```bash
cd /home/shuwen/shuwen/train/neurx && make posttrain
```

### 合并模型
```bash
cd /home/shuwen/shuwen/train/neurx && make posttrain-merge-lora
```

### 测试模型
```bash
cd /home/shuwen/shuwen/train/neurx && make chat
```

---

## 📊 完整流程

```
Step 1: 后训练 (2-4 小时)
  $ cd /home/shuwen/shuwen/train/neurx
  $ make posttrain
  └─ 输出: artifacts/checkpoints/lora_adapter/

Step 2: 模型合并 (5-10 分钟)  
  $ make posttrain-merge-lora
  └─ 输出: ../model/base-model-posttrain/

Step 3: 交互测试
  $ make chat
  └─ 启动聊天会话，测试模型
```

---

## 📁 关键路径

| 用途 | 路径 |
|------|------|
| **数据集** | `/home/shuwen/shuwen/train/dataset/medmcqa/` |
| 训练数据 | `train.jsonl` (173,680 条) |
| 验证数据 | `val.jsonl` (9,142 条) |
| **基础模型** | `/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/` |
| **LoRA 适配器** | `/home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_adapter/` |
| **合并后模型** | `/home/shuwen/shuwen/train/model/base-model-posttrain/` |
| **日志** | `/home/shuwen/shuwen/train/neurx/artifacts/logs/posttrain_*.log` |

---

## 🔍 监控方法

### 查看实时日志
```bash
tail -f /home/shuwen/shuwen/train/neurx/artifacts/logs/posttrain_*.log
```

### 监控检查点
```bash
watch -n 10 'ls -lh /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_*/'
```

### 检查 GPU 使用
```bash
nvidia-smi
```

---

## 🎯 配置信息

```bash
# Makefile 配置
POSTTRAIN_MODEL_PATH = /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
POSTTRAIN_DATA_FILE = /home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl
POSTTRAIN_LORA_ALPHA = 16
POSTTRAIN_LORA_RANK = 8
```

---

## ✅ 验证清单

- [x] 数据集存在：`/home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl` (136MB)
- [x] 基础模型存在：`/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/`
- [x] Makefile 配置正确
- [x] NeurX 框架已初始化

---

## 🆘 常见问题

### Q1: 后训练卡住
```bash
# 查看日志
tail -f artifacts/logs/posttrain_*.log

# 检查 GPU
nvidia-smi
```

### Q2: 合并失败
```bash
# 检查输入文件
ls -lh artifacts/checkpoints/lora_adapter/
ls -lh ../model/Qwen2.5-0.5B-Instruct/
```

### Q3: 模型对话无响应
```bash
# 确认合并模型存在
ls -lh ../model/base-model-posttrain/
```

---

## 📈 预期结果

| 指标 | 值 |
|------|-----|
| 训练数据 | 173,680 条 |
| 后训练耗时 | 2-4 小时 |
| LoRA 适配器大小 | ~100-200MB |
| 合并后模型大小 | ~500MB-1GB |
| 合并耗时 | 5-10 分钟 |

---

## 🔧 自定义超参数

编辑 `Makefile` 修改：

```makefile
# LoRA 配置
POSTTRAIN_LORA_ALPHA ?= 16    # 增大提高表现力
POSTTRAIN_LORA_RANK ?= 8      # 增大提高表现力

# 训练配置（在 posttrain 子目录配置文件中）
batch_size = 4
learning_rate = 5e-4
num_epochs = 3
```

---

## 📝 完整执行流程脚本

```bash
#!/bin/bash
cd /home/shuwen/shuwen/train/neurx

echo "Step 1: 后训练..."
make posttrain || exit 1

echo "Step 2: 合并模型..."
make posttrain-merge-lora || exit 1

echo "Step 3: 测试模型..."
make chat

echo "✅ 完成！"
```

---

**快速开始**: 复制以下命令直接执行
```bash
cd /home/shuwen/shuwen/train/neurx && make posttrain && make posttrain-merge-lora && make chat
```
