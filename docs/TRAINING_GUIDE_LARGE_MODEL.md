# NeurX 大模型训练 - 快速开始指南

## 📚 目录

1. [快速开始](#快速开始)
2. [配置详解](#配置详解)
3. [完整功能](#完整功能)
4. [训练脚本说明](#训练脚本说明)
5. [进阶用法](#进阶用法)
6. [故障排除](#故障排除)

---

## 快速开始

### 一行命令启动训练

```bash
cd /Users/feifei/shuwen/neurx
bash run_train_large_model.sh
```

这将自动完成以下操作：
- ✓ 检查S编译器环境
- ✓ 创建所需的目录结构
- ✓ 生成示例训练数据
- ✓ 编译训练脚本
- ✓ 启动训练过程

### 输出和检查点

训练完成后，你将在以下位置找到：

```
./checkpoints/large_model/    # 保存的模型检查点
./output/large_model/         # 训练日志和输出
./data/large_model/           # 训练数据
  ├── train.jsonl             # 训练集
  └── val.jsonl               # 验证集
```

---

## 配置详解

### 模型配置

```json
{
  "model": {
    "vocab_size": 128000,      // 词表大小
    "hidden_dim": 768,         // 隐藏层维度
    "num_layers": 12,          // Transformer层数
    "num_heads": 12,           // 注意力头数
    "ffn_dim": 3072,           // 前馈网络维度 (4 × hidden_dim)
    "max_seq_len": 4096,       // 最大序列长度
    "dropout_prob": 0.1        // Dropout率
  }
}
```

**说明：**
- `vocab_size`: 越大越好（现代LLM多为100K+）
- `hidden_dim`: 模型容量的关键参数
- `num_heads`: 必须整除 `hidden_dim`（建议 hidden_dim/head_dim = 64）
- `num_layers`: 模型深度，越深越强但计算更贵

### 训练超参数

```json
{
  "training": {
    "batch_size": 32,                        // 全局批大小
    "micro_batch_size": 8,                   // 单卡批大小
    "gradient_accumulation_steps": 4,        // 梯度累积步数
    "max_steps": 100000,                     // 最大训练步数
    "warmup_steps": 1000,                    // 学习率预热步数
    "eval_steps": 500,                       // 评估间隔
    "save_steps": 1000,                      // 保存检查点间隔
    "log_steps": 10                          // 日志间隔
  }
}
```

**关键参数说明：**

| 参数 | 含义 | 建议值 |
|------|------|------|
| batch_size | 每次迭代的总样本数 | 32-256 |
| warmup_steps | 学习率从0线性增加到peak的步数 | 总步数的1-10% |
| max_grad_norm | 梯度剪裁阈值 | 1.0-2.0 |

### 优化器配置

```json
{
  "optimizer": {
    "name": "adamw",           // 优化器类型
    "learning_rate": 5e-4,     // 初始学习率
    "beta1": 0.9,              // Adam β₁ (一阶矩指数衰减)
    "beta2": 0.999,            // Adam β₂ (二阶矩指数衰减)
    "epsilon": 1e-8,           // 数值稳定性
    "weight_decay": 0.01,      // L2正则化系数
    "max_grad_norm": 1.0,      // 梯度剪裁
    "lr_schedule": "cosine"    // 学习率调度："linear", "cosine", "constant"
  }
}
```

**AdamW 更新规则：**

$$m_t = \beta_1 m_{t-1} + (1-\beta_1) g_t$$
$$v_t = \beta_2 v_{t-1} + (1-\beta_2) g_t^2$$
$$\hat{m}_t = \frac{m_t}{1-\beta_1^t}, \quad \hat{v}_t = \frac{v_t}{1-\beta_2^t}$$
$$\theta_t = \theta_{t-1} - \alpha \left(\frac{\hat{m}_t}{\sqrt{\hat{v}_t}+\epsilon} + \lambda \theta_{t-1}\right)$$

---

## 完整功能

### 1️⃣ 多头注意力 (Multi-Head Attention)

来自 `ml/attention_complete.s`:

- ✓ Query/Key/Value 投影权重
- ✓ 缩放点积注意力机制
- ✓ 多头分解和合并
- ✓ 完整的前向和反向传播

**公式：**
```
Attention(Q, K, V) = softmax(QK^T / √d_k)V
```

### 2️⃣ 自动微分 (Automatic Differentiation)

来自 `ml/autodiff_complete.s`:

- ✓ 动态计算图构建
- ✓ 7种操作支持（add, mul, matmul, relu, softmax, layer_norm）
- ✓ 拓扑排序反向传播
- ✓ 梯度累积和管理

**支持的操作和梯度规则：**

| 操作 | 前向 | 反向 |
|------|------|------|
| add(a,b) | a+b | ∂L/∂a=∂L/∂y, ∂L/∂b=∂L/∂y |
| mul(a,b) | a×b | ∂L/∂a=b·∂L/∂y, ∂L/∂b=a·∂L/∂y |
| matmul(a,b) | a@b | ∂L/∂a=∂L/∂y@b^T, ∂L/∂b=a^T@∂L/∂y |
| softmax(x) | exp(x)/Σexp(x) | ∂L/∂x = p·(∂L/∂y - (p·∂L/∂y).sum()) |
| relu(x) | max(0,x) | ∂L/∂x = ∂L/∂y if x>0 else 0 |

### 3️⃣ AdamW 优化器

来自 `ml/optimizer_adamw.s`:

- ✓ 一阶和二阶矩估计（Adaptive Learning Rate）
- ✓ 偏差修正（Bias Correction）
- ✓ 权重衰减（L2正则化）
- ✓ 梯度剪裁（Gradient Clipping）
- ✓ 学习率调度（3种方式）

**学习率调度：**

1. **线性衰减 (Linear Decay)**
   ```
   lr(t) = lr_base × (1 - t/T)
   ```

2. **余弦退火 (Cosine Annealing)**
   ```
   lr(t) = lr_base × (1 + cos(πt/T)) / 2
   ```

3. **预热 (Warmup)**
   ```
   if t < warmup_steps:
       lr(t) = lr_base × t / warmup_steps
   else:
       lr(t) = schedule(t - warmup_steps)
   ```

### 4️⃣ 完整训练循环

来自 `train/train_large_model.s`:

- ✓ Transformer块实现
- ✓ 前向/反向传播集成
- ✓ 多epoch训练
- ✓ 参数更新（AdamW）
- ✓ 检查点保存/加载
- ✓ 模型评估

### 5️⃣ 数据加载管理

- ✓ JSONL格式数据读取
- ✓ 批次处理和打包
- ✓ 洗牌（Shuffling）
- ✓ 序列填充
- ✓ 分布式数据加载框架

---

## 训练脚本说明

### train_large_model.s 结构

```
┌─ 第1部分: 配置管理
│  ├─ TrainingConfig 结构体
│  └─ default_config() 函数
│
├─ 第2部分: 模型状态管理
│  ├─ ModelWeights (参数)
│  ├─ ModelState (状态)
│  └─ init_model_state() 函数
│
├─ 第3部分: 数据加载
│  ├─ DataBatch 结构体
│  ├─ DataLoader 结构体
│  └─ load_batch() 函数
│
├─ 第4部分: 前向传播
│  ├─ 词嵌入
│  ├─ Transformer层 (Attention + FFN)
│  ├─ 输出投影
│  └─ forward_pass() 函数
│
├─ 第5部分: 反向传播
│  └─ backward_pass() 函数
│
├─ 第6部分: 优化器步骤
│  ├─ 学习率调度
│  ├─ 梯度剪裁
│  └─ optimizer_step() 函数
│
├─ 第7部分: 检查点管理
│  ├─ save_checkpoint()
│  └─ load_checkpoint()
│
├─ 第8部分: 评估指标
│  └─ evaluate() 函数
│
├─ 第9部分: 完整训练循环
│  └─ train_large_model() 函数
│
└─ 第10部分: 主函数
   └─ main() 函数
```

### 关键函数详解

#### forward_pass()
```s
func forward_pass(
    ModelState model,
    DataBatch batch,
    TrainingConfig cfg
) ForwardOutput
```

执行一个前向传播：
1. 词嵌入: input_ids → embeddings
2. 通过 num_layers Transformer块
3. 输出投影: hidden_states → logits
4. 计算交叉熵损失

#### backward_pass()
```s
func backward_pass(
    ModelState model,
    ForwardOutput fwd_output,
    DataBatch batch,
    TrainingConfig cfg
) BackwardOutput
```

反向传播计算梯度：
1. 使用自动微分计算计算图
2. 拓扑排序节点
3. 链式法则反向传播
4. 累积所有参数的梯度

#### optimizer_step()
```s
func optimizer_step(
    ModelState model,
    BackwardOutput bwd_output,
    TrainingConfig cfg,
    int step
) ModelState
```

优化器更新：
1. 梯度剪裁
2. 计算自适应学习率
3. 更新一/二阶矩
4. 偏差修正
5. 参数更新（含权重衰减）

---

## 进阶用法

### 1️⃣ 从检查点恢复训练

```bash
# 编辑 train_large_model.s
# 修改 load_checkpoint() 调用以加载现有模型

checkpoint_path := "./checkpoints/large_model/model_step_50000.ckpt"
model := load_checkpoint(checkpoint_path, cfg)

# 然后继续训练
model := train_large_model(cfg)
```

### 2️⃣ 调整模型大小

编辑 `config_large_model.json`:

```json
{
  "model": {
    "hidden_dim": 1024,    // 增大隐藏层维度
    "num_layers": 24,      // 增加层数
    "num_heads": 16,       // 增加注意力头数
    "ffn_dim": 4096        // 按比例增加FFN维度
  }
}
```

**参数估计：**
- 总参数 ≈ 12 × L × H × (H + 4H) + V×H
- 其中 L=层数, H=隐藏维, V=词表大小

### 3️⃣ 分布式训练配置

编辑 `config_large_model.json`:

```json
{
  "distributed": {
    "enabled": true,
    "backend": "nccl",
    "world_size": 8,       // 8个GPU
    "rank": 0,             // 当前进程秩
    "data_parallel": true  // 数据并行
  }
}
```

启动分布式训练：

```bash
# 使用 torch.distributed.launch
python -m torch.distributed.launch \
    --nproc_per_node=8 \
    run_train_large_model.sh
```

### 4️⃣ 混合精度训练

编辑 `config_large_model.json`:

```json
{
  "mixed_precision": {
    "enabled": true,
    "precision": "float16",  // 或 "bfloat16"
    "loss_scale": 1024,
    "loss_scale_type": "dynamic"
  }
}
```

### 5️⃣ 梯度累积

使用梯度累积来模拟更大的批大小：

```json
{
  "training": {
    "batch_size": 256,                  // 有效批大小
    "micro_batch_size": 32,             // GPU内存容纳的大小
    "gradient_accumulation_steps": 8    // 累积8步
  }
}
```

每8步进行一次参数更新，效果等同于每次迭代256的批大小。

---

## 故障排除

### 问题1: 内存不足 (OOM)

**症状：** 编译或执行时出现内存错误

**解决方案：**
1. 减小 `batch_size`
2. 减少 `max_seq_len`
3. 启用梯度累积
4. 启用混合精度训练

```json
{
  "training": {
    "batch_size": 16,
    "micro_batch_size": 4,
    "gradient_accumulation_steps": 4
  }
}
```

### 问题2: 训练不收敛

**症状：** 损失不下降或波动很大

**解决方案：**
1. 检查学习率是否过大
2. 增加 warmup_steps
3. 检查梯度范数是否过大
4. 验证数据是否正确

```json
{
  "optimizer": {
    "learning_rate": 1e-4,      // 降低学习率
    "max_grad_norm": 0.5         // 更激进的梯度剪裁
  },
  "training": {
    "warmup_steps": 5000         // 延长预热期
  }
}
```

### 问题3: 训练速度慢

**症状：** 每步耗时很长

**解决方案：**
1. 增加 `batch_size`
2. 减少 `log_steps` (减少日志开销)
3. 启用混合精度训练
4. 使用更快的数据加载器

```json
{
  "training": {
    "batch_size": 64,
    "log_steps": 100
  },
  "mixed_precision": {
    "enabled": true,
    "precision": "bfloat16"
  }
}
```

### 问题4: S编译器找不到

**症状：** `S编译器不存在: /Users/feifei/train/s/.local/bin/s`

**解决方案：**
```bash
# 检查S编译器位置
which s
# 或
find /Users/feifei -name "s" -type f -executable

# 如果位置不同，编辑 run_train_large_model.sh
# S_COMPILER="/path/to/s"
```

---

## 性能基准

### 预期指标（单GPU V100）

| 配置 | 吞吐量(tokens/s) | 内存(GB) | 训练速度 |
|------|------------------|---------|---------|
| 基础 (L=12, H=768) | 500-800 | 24 | 快速 |
| 中等 (L=24, H=1024) | 200-400 | 30 | 中等 |
| 大型 (L=32, H=1600) | 50-100 | 40+ | 慢速 |

### 优化技巧

1. **使用Flash Attention:** 将注意力复杂度从 $O(n^2)$ 降低到 $O(n)$
2. **启用梯度检查点：** 权衡速度和内存
3. **使用混合精度：** 2倍内存节省和加速
4. **分布式训练：** 数据并行、张量并行、管道并行

---

## 输出示例

```
═══════════════════════════════════════════════════════════
🚀 NeurX 大模型训练 - 完整管道
═══════════════════════════════════════════════════════════

【步骤 1】模型初始化
─────────────────────────────────────────────────────────
✓ 模型初始化完成
  • 总参数数: 124,439,552

【步骤 2】数据加载器初始化
─────────────────────────────────────────────────────────
✓ 数据加载器初始化完成
  • 批量大小: 32
  • 序列长度: 4096

【步骤 3】开始训练
─────────────────────────────────────────────────────────

Step 0 / 100000
  • 批次损失: 5.2
  • 平均损失: 5.2
  • 梯度范数: 1.5
  • 处理 tokens: 131072

Step 10 / 100000
  • 批次损失: 4.8
  • 平均损失: 5.0
  • 梯度范数: 1.2
  • 处理 tokens: 1310720
  • 🎯 最佳损失更新!

...

【步骤 4】训练完成
─────────────────────────────────────────────────────────
✓ 训练完成
  • 总步数: 100
  • 最终损失: 4.2
  • 处理 tokens 总数: 13107200

═══════════════════════════════════════════════════════════
✅ 训练成功完成!
═══════════════════════════════════════════════════════════

📊 最终统计:
  • 总参数数: 124,439,552
  • 处理 tokens: 13,107,200
  • Adam 步数: 100

💾 检查点位置: ./checkpoints/large_model
📈 输出目录: ./output/large_model
```

---

## 下一步

1. **推理:** 加载检查点进行推理和生成
2. **评估:** 在多个基准上评估模型性能
3. **微调:** 在特定任务上进行指令微调
4. **部署:** 将模型部署到生产环境
5. **优化:** 使用量化、蒸馏等技术优化模型

---

## 参考资源

- [Attention is All You Need](https://arxiv.org/abs/1706.03762) - Transformer架构
- [An Image is Worth 16x16 Words](https://arxiv.org/abs/2010.11929) - ViT展示了Attention的通用性
- [BERT: Pre-training of Deep Bidirectional Transformers](https://arxiv.org/abs/1810.04805) - 预训练方法
- [Language Models are Unsupervised Multitask Learners](https://d4mucfpksywv.cloudfront.net/better-language-models/language_models_are_unsupervised_multitask_learners.pdf) - GPT-2论文

---

**祝你训练顺利！** 🚀

如有问题，请查看日志或运行调试模式：

```bash
DEBUG_MODE=true bash run_train_large_model.sh
```
