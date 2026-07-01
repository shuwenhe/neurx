<!-- NeurX Training Pipeline Documentation
完整训练管道文档
Author: NeurX Team
Date: 2026-06-29 -->

# NeurX 完整训练管道文档

## 📋 概述 (Overview)

NeurX 训练管道是一个生产级的深度学习训练系统，集成了以下关键功能：

- ✅ **完整前向传播** - 从输入token到输出logits
- ✅ **Transformer反向传播** - 通过所有层的梯度计算
- ✅ **梯度缩放** (混合精度) - FP16/FP32 动态损失缩放
- ✅ **检查点系统** - 完整的模型保存和恢复
- ✅ **梯度累积** - 支持大批量训练

### 主要特性 (Key Features)

| 特性 | 描述 | 状态 |
|------|------|------|
| 前向传播 | Token嵌入 → Positional Encoding → Transformer → LM Head | ✅ |
| 反向传播 | 完整的链式求导 | ✅ |
| 梯度缩放 | 动态损失缩放 + 溢出检测 | ✅ |
| 检查点 | 训练状态持久化 | ✅ |
| 梯度累积 | 多步累积 + 同步 | ✅ |
| 混合精度 | FP16计算 + FP32主权重 | ✅ |
| 梯度裁剪 | L2范数裁剪 | ✅ |
| 学习率调度 | Warmup支持 | ✅ |

---

## 🏗️ 架构设计 (Architecture)

### 整体流程 (Overall Flow)

```
输入数据 (Input Data)
    ↓
┌─ 前向传播 (Forward Pass)
│  ├─ Token嵌入 (Token Embedding)
│  ├─ 位置编码 (Positional Encoding)
│  ├─ Transformer层堆栈 (Transformer Layers)
│  ├─ LM Head投影 (LM Head Projection)
│  └─ 交叉熵损失 (Cross-Entropy Loss)
│
├─ 反向传播 (Backward Pass)
│  ├─ 损失梯度 (Loss Gradients)
│  ├─ 层级反向传播 (Layer-wise Backprop)
│  ├─ 梯度范数计算 (Gradient Norm)
│  └─ 梯度裁剪 (Gradient Clipping)
│
├─ 梯度缩放 (Gradient Scaling)
│  ├─ 检测溢出 (Overflow Detection)
│  ├─ 缩放因子调整 (Scale Factor Adjustment)
│  └─ 损失缩放更新 (Loss Scale Update)
│
├─ 梯度累积 (Gradient Accumulation)
│  ├─ 累积梯度 (Accumulate)
│  ├─ 检查完成条件 (Check Completion)
│  └─ 同步 (Synchronize)
│
├─ 权重更新 (Weight Update)
│  ├─ 优化器步骤 (Optimizer Step)
│  └─ 权重更新 (Weight Update)
│
└─ 检查点管理 (Checkpoint Management)
   ├─ 保存状态 (Save State)
   └─ 恢复状态 (Load State)
```

### 模块交互 (Module Interaction)

```
training_pipeline.s
├─ 导入混合精度模块
├─ 导入梯度累积模块
├─ 导入向量化操作模块
└─ 导入模型和优化器模块

主要函数流程：
forward_pass() 
    → forward_pass_result (logits, loss)
backward_pass()
    → backward_pass_result (gradients, norm)
apply_gradient_scaling()
    → 缩放后的梯度 (scaled gradients)
training_step()
    → training_step_result (完整步骤结果)
training_loop_with_accumulation()
    → 完整训练循环 (full training)
```

---

## 📖 API 参考 (API Reference)

### 前向传播 (Forward Pass)

#### `forward_pass()`
执行完整的前向传播，从输入token到输出logits。

```s
func forward_pass(
    model_state: model.transformer_state,
    input_ids: []int,
    batch_size: int,
    sequence_length: int
) forward_pass_result
```

**参数：**
- `model_state`: Transformer模型状态
- `input_ids`: 输入token ID数组 [batch_size * seq_len]
- `batch_size`: 批量大小
- `sequence_length`: 序列长度

**返回值：**
```s
struct forward_pass_result {
    logits: [][]float           // [batch_size, vocab_size]
    embeddings: [][]float       // [batch_size, hidden_dim]
    attention_weights: [][]float
    loss_value: float           // 交叉熵损失
    batch_size: int
    sequence_length: int
    vocab_size: int
}
```

**示例：**
```s
var forward_result: forward_pass_result = 
    forward_pass(model_state, input_ids, 32, 512)
var loss = forward_result.loss_value        // 获取损失值
var logits = forward_result.logits          // 获取输出logits
```

### 反向传播 (Backward Pass)

#### `backward_pass()`
执行完整的反向传播，计算梯度、梯度范数和梯度裁剪。

```s
func backward_pass(
    forward_result: forward_pass_result,
    model_state: model.transformer_state,
    target_ids: []int,
    loss_scale: float
) backward_pass_result
```

**参数：**
- `forward_result`: 前向传播结果
- `model_state`: Transformer模型状态
- `target_ids`: 目标token ID
- `loss_scale`: 损失缩放因子

**返回值：**
```s
struct backward_pass_result {
    gradients: [][]float        // 梯度
    gradient_norm: float        // 梯度L2范数
    gradient_clipped: bool      // 是否被裁剪
    max_gradient: float         // 最大梯度值
    overflow_detected: bool     // 是否检测到溢出
}
```

**示例：**
```s
var backward_result: backward_pass_result =
    backward_pass(forward_result, model_state, target_ids, 65536.0)

if backward_result.overflow_detected {
    // 处理梯度溢出
    loss_scale = loss_scale * 0.5
}
```

### 梯度缩放 (Gradient Scaling)

#### `apply_gradient_scaling()`
应用梯度缩放，将梯度除以损失缩放因子。

```s
func apply_gradient_scaling(
    gradients: [][]float,
    loss_scale: float,
    model_state: model.transformer_state
) [][]float
```

**参数：**
- `gradients`: 原始梯度
- `loss_scale`: 损失缩放因子
- `model_state`: 模型状态

**返回值：** 缩放后的梯度

#### `update_loss_scale()`
动态更新损失缩放因子。

```s
func update_loss_scale(
    current_loss_scale: float,
    overflow_detected: bool,
    stable_steps: int
) float
```

**逻辑：**
- 如果溢出：`new_scale = current_scale * 0.5`
- 如果稳定 (>2000步)：`new_scale = current_scale * 2.0`
- 范围限制：[1.0, 65536.0]

**示例：**
```s
if overflow_detected {
    loss_scale = update_loss_scale(loss_scale, true, 0)
} else {
    loss_scale = update_loss_scale(loss_scale, false, stable_step_count)
}
```

### 检查点管理 (Checkpoint Management)

#### `save_checkpoint()`
保存训练检查点（模型权重、优化器状态、训练状态）。

```s
func save_checkpoint(
    filepath: string,
    step: int,
    epoch: int,
    model_state: model.transformer_state,
    training_state: training_state,
    config: training_config
) bool
```

**检查点包含：**
- 模型权重矩阵
- 优化器状态 (momentum, variance)
- 损失缩放值
- 梯度累积计数
- 累积损失
- 训练配置
- 时间戳

**示例：**
```s
if step % 500 == 0 {
    save_checkpoint(
        "checkpoint_step_" + string(step) + ".pt",
        step, epoch, model_state, training_state, config
    )
}
```

#### `load_checkpoint()`
加载训练检查点。

```s
func load_checkpoint(filepath: string) checkpoint_data
```

**返回值：**
```s
struct checkpoint_data {
    step: int
    epoch: int
    model_weights: [][]float
    optimizer_state: [][]float
    loss_scale: float
    accumulated_steps: int
    accumulated_loss: float
    training_config: training_config
    timestamp: int
}
```

**示例：**
```s
var checkpoint = load_checkpoint("checkpoint_step_1000.pt")
model_state.weight_matrices = checkpoint.model_weights
training_state.loss_scale = checkpoint.loss_scale
training_state.current_step = checkpoint.step
```

### 梯度累积集成 (Gradient Accumulation Integration)

在训练循环中集成梯度累积：

```s
var accumulated_grads: gradient_accumulation.accumulated_gradients
accumulated_grads.accumulation_steps = 4

// 累积步骤
for step in 0..3 {
    var loss = compute_loss(...)
    accumulated_grads.accumulated_loss += loss
    accumulated_grads.steps_accumulated += 1
}

// 当准备好时
if accumulated_grads.steps_accumulated >= accumulated_grads.accumulation_steps {
    // 执行权重更新
    update_weights(...)
    
    // 重置
    accumulated_grads.steps_accumulated = 0
    accumulated_grads.accumulated_loss = 0.0
}
```

---

## 🚀 使用指南 (Usage Guide)

### 基本训练循环

```s
// Step 1: 创建配置
var config: training_config
config.batch_size = 32
config.learning_rate = 0.0001
config.gradient_accumulation_steps = 4
config.use_mixed_precision = true
config.checkpoint_interval = 500

// Step 2: 初始化模型
var model_state = initialize_model()

// Step 3: 初始化训练状态
var training_state: training_state
training_state.loss_scale = 65536.0
training_state.current_step = 0

// Step 4: 训练循环
var epoch = 0
while epoch < config.max_epochs {
    var step = 0
    while step < steps_per_epoch {
        // Forward pass
        var forward_result = forward_pass(model_state, input_ids, config.batch_size, 512)
        
        // Backward pass
        var backward_result = backward_pass(forward_result, model_state, target_ids, training_state.loss_scale)
        
        // 检测溢出
        if backward_result.overflow_detected {
            training_state.loss_scale = update_loss_scale(training_state.loss_scale, true, 0)
            step = step + 1
            continue
        }
        
        // 应用梯度缩放
        var scaled_gradients = apply_gradient_scaling(backward_result.gradients, training_state.loss_scale, model_state)
        
        // 累积梯度
        accumulated_grads.accumulated_loss += forward_result.loss_value
        accumulated_grads.steps_accumulated += 1
        
        // 权重更新
        if accumulated_grads.steps_accumulated >= config.gradient_accumulation_steps {
            update_model_weights(model_state, training_state.learning_rate)
            accumulated_grads.steps_accumulated = 0
            accumulated_grads.accumulated_loss = 0.0
        }
        
        // 保存检查点
        if should_save_checkpoint(step, config.checkpoint_interval) {
            save_checkpoint(...)
        }
        
        training_state.current_step = training_state.current_step + 1
        step = step + 1
    }
    
    epoch = epoch + 1
}
```

### 从检查点恢复

```s
// 加载检查点
var checkpoint = load_checkpoint("checkpoint_step_5000.pt")

// 恢复模型状态
model_state.weight_matrices = checkpoint.model_weights

// 恢复训练状态
training_state.current_step = checkpoint.step
training_state.current_epoch = checkpoint.epoch
training_state.loss_scale = checkpoint.loss_scale

// 继续训练
training_loop_with_accumulation(config, model_state)
```

### 混合精度配置

```s
var config: training_config
config.use_mixed_precision = true

var mp_config: mixed_precision_config
mp_config.use_mixed_precision = true
mp_config.compute_dtype = "float16"
mp_config.master_weights_dtype = "float32"
mp_config.initial_loss_scale = 65536.0
mp_config.min_loss_scale = 1.0
mp_config.max_loss_scale = 65536.0
```

### 梯度累积配置

```s
var config: training_config
config.gradient_accumulation_steps = 4  // 累积4个步骤后更新

// 有效批量大小 = 32 * 4 = 128
// 但内存占用仍然是 32 (物理批量大小)
```

---

## 📊 性能指标 (Performance Metrics)

### 关键指标

| 指标 | 计算方式 | 说明 |
|------|--------|------|
| Loss | CrossEntropy | 模型训练损失 |
| Perplexity | exp(loss) | 模型困惑度 |
| Gradient Norm | L2(gradients) | 梯度稳定性指标 |
| Throughput | tokens/sec | 训练吞吐量 |
| Loss Scale | 动态调整 | FP16/FP32混合精度指标 |

### 损失缩放策略

```
状态：正常
  ↓
[每2000步无溢出]
  ↓
损失缩放 × 2.0 (增长)
  ↓
[新的稳定周期]

状态：梯度溢出
  ↓
损失缩放 × 0.5 (回退)
  ↓
[继续训练]
```

---

## 🔧 配置参数详解 (Configuration Parameters)

### training_config

```s
struct training_config {
    batch_size: int = 32                    // 批量大小
    learning_rate: float = 0.0001           // 学习率
    max_epochs: int = 10                    // 最大轮次
    gradient_accumulation_steps: int = 1    // 梯度累积步数
    gradient_clip_norm: float = 1.0         // 梯度裁剪范数
    use_mixed_precision: bool = true        // 使用混合精度
    checkpoint_interval: int = 500          // 检查点保存间隔
    log_interval: int = 100                 // 日志打印间隔
    warmup_steps: int = 1000                // Warmup步数
    total_steps: int = 100000               // 总训练步数
}
```

### mixed_precision_config

```s
struct mixed_precision_config {
    use_mixed_precision: bool = true
    compute_dtype: string = "float16"
    master_weights_dtype: string = "float32"
    loss_scale_type: string = "dynamic"
    initial_loss_scale: float = 65536.0
    min_loss_scale: float = 1.0
    max_loss_scale: float = 65536.0
    loss_scale_window: int = 1000
    loss_scale_growth_interval: int = 2000
    loss_scale_growth_factor: float = 2.0
    loss_scale_backoff_factor: float = 0.5
}
```

### gradient_accumulation_config

```s
struct gradient_accumulation_config {
    accumulation_steps: int = 4             // 累积步数
    normalize_accumulated: bool = true      // 归一化
    reset_on_overflow: bool = true          // 溢出时重置
    log_accumulated_loss: bool = true       // 记录损失
}
```

---

## ⚙️ 超参数推荐 (Hyperparameter Recommendations)

### 小模型训练 (Small Model - ~100M params)

```s
batch_size = 32
learning_rate = 0.001
gradient_accumulation_steps = 1
warmup_steps = 500
gradient_clip_norm = 1.0
loss_scale = 65536.0
```

### 中等模型训练 (Medium Model - ~500M params)

```s
batch_size = 32
learning_rate = 0.0005
gradient_accumulation_steps = 2
warmup_steps = 1000
gradient_clip_norm = 1.0
loss_scale = 65536.0
```

### 大模型训练 (Large Model - >1B params)

```s
batch_size = 16
learning_rate = 0.0001
gradient_accumulation_steps = 4
warmup_steps = 2000
gradient_clip_norm = 1.0
loss_scale = 65536.0
use_mixed_precision = true
```

---

## 🐛 故障排查 (Troubleshooting)

### 梯度溢出

**症状：** 损失变为NaN，loss_scale频繁减半

**解决方案：**
```s
// 1. 降低初始学习率
config.learning_rate = config.learning_rate * 0.5

// 2. 增加梯度累积步数
config.gradient_accumulation_steps = config.gradient_accumulation_steps * 2

// 3. 降低批量大小
config.batch_size = config.batch_size / 2

// 4. 增加梯度裁剪范数
config.gradient_clip_norm = 2.0
```

### 训练不收敛

**症状：** 损失不下降或振荡

**解决方案：**
```s
// 1. 检查学习率
config.learning_rate = 0.0001  // 降低学习率

// 2. 增加warmup步数
config.warmup_steps = 2000

// 3. 启用梯度累积
config.gradient_accumulation_steps = 4
```

### 内存不足

**症状：** OOM错误

**解决方案：**
```s
// 1. 减少批量大小
config.batch_size = 8  // 从32降低到8

// 2. 增加梯度累积
config.gradient_accumulation_steps = 8  // 保持有效批量大小

// 3. 减少序列长度
sequence_length = 256  // 从512降低到256
```

---

## 📝 测试覆盖 (Test Coverage)

### 前向传播测试
- ✅ 基本前向传播
- ✅ 不同批量大小
- ✅ Logits形状验证

### 反向传播测试
- ✅ 基本反向传播
- ✅ 梯度溢出检测
- ✅ 梯度裁剪

### 梯度缩放测试
- ✅ 基本缩放
- ✅ 溢出时更新
- ✅ 增长调度
- ✅ 边界检查

### 梯度累积测试
- ✅ 基本累积
- ✅ 就绪检查
- ✅ 重置操作

### 检查点测试
- ✅ 保存检查点
- ✅ 加载检查点
- ✅ 间隔决策

### 集成测试
- ✅ 完整训练步骤
- ✅ 混合精度集成
- ✅ 梯度累积集成

---

## 📚 相关模块 (Related Modules)

- [混合精度训练](./mixed_precision.md) - FP16/FP32训练支持
- [梯度累积](./gradient_accumulation.md) - 多步梯度累积
- [向量化操作](./vectorization.md) - 高性能张量操作
- [分布式张量并行](./tensor_parallel.md) - 模型并行支持

---

## 🎯 最佳实践 (Best Practices)

### 1. 梯度缩放策略

```s
// ✅ 推荐：动态调整
if overflow_detected {
    loss_scale = loss_scale * 0.5
} else if stable_steps > 2000 {
    loss_scale = min(loss_scale * 2.0, 65536.0)
}

// ❌ 避免：固定缩放
loss_scale = 65536.0  // 不调整
```

### 2. 梯度裁剪

```s
// ✅ 推荐：L2范数裁剪
grad_norm = compute_gradient_norm(gradients)
if grad_norm > 1.0 {
    gradients = clip_gradients(gradients, 1.0, grad_norm)
}

// ❌ 避免：逐元素裁剪
for g in gradients {
    g = max(-1.0, min(1.0, g))  // 效果较差
}
```

### 3. 检查点策略

```s
// ✅ 推荐：定期保存
if step % 500 == 0 {
    save_checkpoint(...)
}

// ✅ 推荐：保留多个检查点
checkpoint_dir/
  ├─ checkpoint_best.pt       (最佳验证性能)
  ├─ checkpoint_latest.pt     (最新检查点)
  └─ checkpoint_step_5000.pt  (历史检查点)
```

### 4. 学习率调度

```s
// ✅ 推荐：Warmup + 衰减
if current_step < warmup_steps {
    lr = base_lr * current_step / warmup_steps
} else {
    lr = base_lr * (1 - current_step / total_steps)
}
```

---

## 版本信息 (Version Info)

- **版本**: 1.0.0
- **发布日期**: 2026-06-29
- **兼容性**: NeurX Framework >= 1.0.0
- **支持**: CPU, GPU (NVIDIA CUDA)

---

*完整训练管道文档 - NeurX Team 2026*
