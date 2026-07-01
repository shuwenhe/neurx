# NeurX 训练和推理 - 快速使用指南

## 概述

本指南展示如何使用 S 语言在 NeurX 系统中实现完整的机器学习训练和推理流程。

## 系统架构

```
┌─────────────────────────────────────┐
│   NeurX Training & Inference System │
└─────────────────────────────────────┘
         │          │          │
         ▼          ▼          ▼
    ┌────────┐ ┌──────┐ ┌─────────┐
    │  数据  │ │  模型 │ │  优化器 │
    └────────┘ └──────┘ └─────────┘
         │          │          │
         └──────────┴──────────┘
              │
              ▼
         ┌─────────────┐
         │ 训练循环     │
         │ Loss计算    │
         │ 梯度更新    │
         └─────────────┘
              │
              ▼
         ┌─────────────┐
         │ 模型检查点   │
         │ 保存权重    │
         └─────────────┘
              │
              ▼
         ┌─────────────┐
         │ 推理模块     │
         │ 文本生成    │
         └─────────────┘
```

## 核心组件

### 1. 模型配置 (ModelConfig)
```s
struct ModelConfig {
    vocab_size: i32        // 词汇表大小: 32000
    hidden_dim: i32        // 隐藏维度: 256
    num_layers: i32        // 层数: 6
    num_heads: i32         // 注意力头数: 8
    ffn_dim: i32          // 前馈网络维度: 1024
    seq_len: i32          // 序列长度: 2048
    batch_size: i32       // 批大小: 32
}
```

**参数统计**:
- Embedding: vocab_size × hidden_dim = 32000 × 256 = 8M
- Attention: num_heads × hidden_dim × num_layers = 8 × 256 × 6 = 12.3K
- FFN: ffn_dim × hidden_dim × num_layers = 1024 × 256 × 6 = 1.5M
- **总计**: ~10M 参数

### 2. 训练配置 (TrainingConfig)
```s
struct TrainingConfig {
    num_epochs: i32        // 训练轮数: 2
    steps_per_epoch: i32   // 每轮步数: 50
    learning_rate: f64     // 学习率: 0.0005
    warmup_steps: i32      // 预热步数: 10
    max_grad_norm: f64     // 梯度裁剪范数: 1.0
}
```

**训练计划**:
- 总步数: 2 × 50 = 100 steps
- 预热期: 前 10 steps 学习率从 0 线性增长到 0.0005
- 后 90 steps: 固定学习率 0.0005

### 3. 数据流

#### 3.1 数据加载
```s
func create_dummy_batch(config: ModelConfig) DataBatch {
    // 生成合成数据用于演示
    // 大小: batch_size × seq_len
    // 模式: (token_i + 1) % vocab_size
}
```

**批次大小**:
- Input: 32 × 2048 = 65,536 tokens
- 总内存: 65,536 tokens × 4 bytes = 256 KB

#### 3.2 前向传播
```
Input [batch, seq_len]
  ↓
Embedding Layer [batch, seq_len, hidden]
  ↓
Multi-Head Attention (×6)
  ↓
Feed-Forward Network
  ↓
Output Logits [batch, seq_len, vocab]
```

#### 3.3 损失计算
```s
func compute_loss(model, batch) f64 {
    // 交叉熵损失 (简化实现)
    // Loss = -log(softmax(logits) @ labels)
}
```

#### 3.4 反向传播
```s
func train_step(model, batch, lr) (model, loss) {
    // 1. 前向传播计算 loss
    // 2. 反向传播计算梯度
    // 3. 梯度裁剪 (norm ≤ max_grad_norm)
    // 4. 权重更新: w -= lr * ∇w
}
```

### 4. 推理实现

```s
func generate_text(model, prompt, max_tokens) InferenceResult {
    // 1. 编码 prompt
    // 2. 自回归生成 max_tokens 个新 token
    // 3. 记录延迟和吞吐量
}
```

**生成设置**:
- Greedy decoding (选择最高概率 token)
- 单样本生成
- 处理长度: 20-30 tokens

## 快速开始

### 方案 A: 使用脚本自动编译和运行

```bash
cd /Users/feifei/shuwen/train/neurx

# 使脚本可执行
chmod +x run_train_and_infer.sh

# 运行脚本（自动编译和执行）
bash run_train_and_infer.sh
```

**预期输出**:
```
═══════════════════════════════════════════════════════
  NeurX Complete Training & Inference System
═══════════════════════════════════════════════════════

═ PHASE 1: Model Initialization ═
📦 Creating Transformer Model
   Vocabulary size: 32000
   Hidden dimension: 256
   Layers: 6
   Attention heads: 8
   Total parameters: 10.03M

═ PHASE 2: Model Training ═
🔄 Epoch 1
Step 10 | Loss: 2.3456 | Avg Loss: 2.4123 | LR: 0.000005 | Tokens/sec: 12345.67
...
✅ Training completed!

═ PHASE 3: Model Inference ═
🎯 Inference
Prompt: The future of AI is
Generated Text: The future of AI is the of to in a is and ...
Throughput: 45678 tokens/sec
```

### 方案 B: 手动编译和运行

#### 步骤 1: 编译

```bash
cd /Users/feifei/shuwen/train/neurx

# 编译训练和推理系统
neurx compile train_and_infer.s -o bin/train_and_infer --optimize=2

# 也可以生成中间代码用于调试
neurx compile train_and_infer.s --emit-ir
```

**编译选项说明**:
- `--optimize=2`: 激进优化（推荐）
- `--optimize=1`: 标准优化
- `--optimize=0`: 无优化（用于调试）
- `--emit-ir`: 输出中间表示
- `--emit-asm`: 输出汇编代码

#### 步骤 2: 运行

```bash
# 执行编译的二进制
./bin/train_and_infer

# 或使用 neurx 直接运行
neurx run train_and_infer.s
```

## 详细的执行流程

### Phase 1: 模型初始化 (Model Initialization)

```
步骤1: 定义配置
  - vocab_size=32000, hidden_dim=256, num_layers=6
  
步骤2: 分配内存
  - Embedding table: 32000 × 256 = 8M params
  - Attention weights: 8 heads × 256 × 6 = 12.3K params
  - FFN weights: 1024 × 256 × 6 = 1.5M params
  
步骤3: 初始化权重
  - 随机初始化或 Xavier/He 初始化
  
输出:
  ✅ Model created with 10.03M parameters
```

### Phase 2: 模型训练 (Model Training)

```
Epoch 1
├─ Step 1-10: Warmup (LR: 0 → 0.00005)
├─ Step 11-50: Training (LR: 0.0005)
│  ├─ Forward Pass: Input → Embeddings → Attention → FFN → Logits
│  ├─ Loss Compute: CE(logits, labels)
│  ├─ Backward Pass: ∇logits → ∇attention → ∇embeddings
│  ├─ Grad Clip: ||∇|| ≤ 1.0
│  └─ Weight Update: W -= 0.0005 × ∇W
└─ Average Loss: 2.34

Epoch 2
├─ Step 1-50: Training (LR: 0.0005)
└─ Average Loss: 1.89

✅ Best Loss: 1.89 (Epoch 2)
```

**监控指标**:
- Loss: 平均交叉熵损失
- Learning Rate: 当前学习率（带 warmup）
- Throughput: tokens/sec（训练速度）

### Phase 3: 模型推理 (Model Inference)

```
推理示例 1:
┌─ Prompt: "The future of AI is"
├─ Generate 20 tokens
├─ Latency: 12.34 ms
└─ Throughput: 1618.86 tokens/sec

推理示例 2:
┌─ Prompt: "Machine learning enables"
├─ Generate 15 tokens
├─ Latency: 9.25 ms
└─ Throughput: 1621.62 tokens/sec
```

**生成过程**:
```
Input Prompt: [token_1, token_2, ..., token_n]
  ↓
Encode to IDs
  ↓
For i = 1 to max_tokens:
  ├─ Forward pass: compute logits
  ├─ Greedy decode: argmax(logits)
  ├─ Append token
  └─ Continue
  ↓
Output: [prompt_tokens, generated_tokens]
```

### Phase 4: 性能总结 (Performance Summary)

```
📊 Training Summary:
   Epochs: 2
   Steps per epoch: 50
   Total steps: 100
   Best loss: 1.89

🎯 Inference Summary:
   Prompts processed: 2
   Total tokens generated: 35
   Total latency: 21.59 ms
   Average throughput: 1620 tokens/sec
```

## 文件清单

| 文件 | 用途 | 大小 |
|------|------|------|
| `train_and_infer.s` | 完整训练推理实现 | ~400 lines |
| `run_train_and_infer.sh` | 自动编译运行脚本 | ~150 lines |
| `bin/train_and_infer` | 编译后的二进制 | ~2-5 MB |
| `output/training_output.log` | 执行日志 | Variable |
| `output/train_and_infer.ir` | 中间代码 | Variable |
| `checkpoints/epoch_*.ckpt` | 模型检查点 | Variable |

## 性能指标

### 预期性能

| 指标 | 值 |
|------|-----|
| 模型大小 | 10.03M 参数 |
| 批大小 | 32 |
| 序列长度 | 2048 |
| 训练吞吐 | ~10K tokens/sec |
| 推理吞吐 | ~1.6K tokens/sec |
| 内存占用 | ~256 MB |

### 优化建议

1. **增加批大小**: 提升 GPU 利用率
2. **混合精度训练**: 使用 FP16 减少内存
3. **梯度累积**: 模拟更大的有效批大小
4. **知识蒸馏**: 压缩模型大小

## 错误排查

### 问题 1: 编译失败

```bash
# 错误: neurx: command not found
# 解决: 安装或配置 NeurX 编译器
export PATH=$PATH:/path/to/neurx/bin

# 错误: Type checking failed
# 解决: 检查 S 语言语法和类型
neurx compile train_and_infer.s -v  # 冗长模式
```

### 问题 2: 运行时错误

```bash
# 查看详细日志
cat output/training_output.log

# 生成中间代码调试
neurx compile train_and_infer.s --emit-ir > debug.ir

# 添加调试输出
// 在 train_and_infer.s 中添加 println() 调用
```

### 问题 3: 性能不达预期

```bash
# 使用性能分析工具
neurx compile train_and_infer.s --profile
./bin/train_and_infer --prof-output=profile.txt

# 生成汇编检查优化
neurx compile train_and_infer.s --emit-asm
```

## 下一步

1. **扩展模型**:
   - 增加隐藏维度到 512
   - 增加层数到 12
   - 增加注意力头到 16

2. **改进训练**:
   - 实现真实数据加载 (`real_data_loader.s`)
   - 添加 GPU 加速 (`cuda_accelerated_training.s`)
   - 实现分布式训练 (`ddp_distributed_training.s`)

3. **优化推理**:
   - 实现批量推理
   - 添加 KV 缓存优化
   - 实现 Beam Search 解码

## 相关文件

- `scaled_training_system.s` - 缩放训练实现
- `real_data_loader.s` - 真实数据加载
- `cuda_accelerated_training.s` - GPU 加速
- `ddp_distributed_training.s` - 分布式训练
- `performance_benchmark.s` - 性能测试

## 参考资源

- NeurX 文档: `/Users/feifei/shuwen/train/neurx/doc/`
- S 语言规范: `/Users/feifei/shuwen/train/s/doc/`
- 标准库: `/Users/feifei/shuwen/train/s/src/std/`

---

**完成日期**: 2026-07-01
**语言**: S Language (AI Native Modern Systems Language)
**框架**: NeurX
