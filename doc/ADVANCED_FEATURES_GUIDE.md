# Advanced Training Features - Integration Guide

## 概述

NeurX框架现已包含4个高级功能模块，用于生产级的大规模LLM训练：

1. **向量化操作** (`neurx/ops/vectorization.s`)
2. **混合精度** (`neurx/training/mixed_precision.s`)
3. **梯度累积** (`neurx/training/gradient_accumulation.s`)
4. **分布式张量并行** (`neurx/distributed/tensor_parallel.s`)

---

## 1. 向量化操作 (Vectorization)

### 概述
提供高性能的张量操作，包括批量矩阵乘法、元素级操作和归约操作。

### 关键API

#### 批量矩阵乘法
```s
// 标准批量乘法 O(batch*M*K*N)
func batch_matmul(A: [][]float, B: [][]float, batch_size: int, M: int, K: int, N: int) batch_matmul_result

// 缓存优化的阻塞乘法
func batch_matmul_blocked(A: [][]float, B: [][]float, batch_size: int, M: int, K: int, N: int, block_size: int) batch_matmul_result
```

#### 元素级操作
```s
// 逐元素加法、乘法、除法
func element_wise_add(A: []float, B: []float) []float
func element_wise_mul(A: []float, B: []float) []float
func element_wise_div(A: []float, B: []float, epsilon: float) []float

// 批量操作
func batch_element_wise_add(A: [][]float, B: [][]float, batch_size: int, size_per_batch: int) [][]float
func batch_element_wise_mul(A: [][]float, B: [][]float, batch_size: int, size_per_batch: int) [][]float
```

#### 广播操作
```s
// 向矩阵的每一行加/乘向量
func broadcast_add(A: [][]float, b: []float, rows: int, cols: int) [][]float
func broadcast_mul(A: [][]float, b: []float, rows: int, cols: int) [][]float
```

#### 归约操作
```s
// 求和、均值、最大值
func reduce_sum(A: []float) float
func reduce_mean(A: []float) float
func reduce_max(A: []float) float

// 批量归约
func reduce_sum_batch(A: [][]float, batch_size: int, size_per_batch: int) []float
```

### 使用示例

```s
// 批量矩阵乘法
let batch_result = batch_matmul_blocked(A, B, 32, 512, 768, 3072, 64)

// 元素级操作
let C = element_wise_mul(A, B)

// 广播
let result = broadcast_add(matrix, bias_vector, rows, cols)

// 归约
let total = reduce_sum(A)
let mean = reduce_mean(A)
let max_val = reduce_max(A)
```

### 性能优化

- **缓存局部性**: `block_size` 参数优化缓存使用
- **内存访问模式**: 列优先存储支持向量化
- **向量化窄循环**: 内层循环可向量化

### 配置参数

```s
struct matmul_config {
    batch_size: int
    use_blocked: bool
    block_size: int  // 推荐: 64-256
    parallel_threads: int
}
```

---

## 2. 混合精度训练 (Mixed Precision)

### 概述
支持Float16和Float32混合精度训练，减少内存占用和提升性能。

### 关键概念

- **Master Weights**: Float32权重副本（用于精度）
- **Compute Weights**: Float16权重副本（用于计算）
- **Loss Scaling**: 防止梯度下溢
- **Gradient Overflow**: 检测和恢复

### 关键API

#### 初始化
```s
func new_mixed_precision_config() mixed_precision_config
func new_mixed_precision_state(model_size: int) mixed_precision_state
```

#### 梯度缩放
```s
func scale_gradients(gradients: [][]float, loss_scale: float) [][]float
func unscale_gradients(gradients: [][]float, loss_scale: float) [][]float
```

#### 损失缩放调度
```s
func new_loss_scale_scheduler(initial_scale: float, window: int, growth_factor: float, backoff_factor: float) loss_scale_scheduler
func update_loss_scale(scheduler: loss_scale_scheduler, had_overflow: bool) loss_scale_scheduler
```

#### 溢出检测
```s
func detect_overflow(gradients: [][]float) bool
func detect_gradient_overflow(gradients: [][]float, max_grad_norm: float) (bool, float)
```

#### 完整训练步骤
```s
func mixed_precision_optimizer_step(
    state: mixed_precision_state,
    loss: float,
    gradients: [][]float,
    learning_rate: float,
    config: mixed_precision_config
) (mixed_precision_state, bool)
```

### 使用示例

```s
// 配置
let mp_config = new_mixed_precision_config()
mp_config.use_mixed_precision = true
mp_config.compute_dtype = "float32"  // 可设为"float16"

// 初始化状态
var mp_state = new_mixed_precision_state(model_size)

// 训练步骤
for step = 0; step < num_steps; step++ {
    // 前向传播
    let logits = mixed_precision_forward(inputs, weights, use_fp16)
    let loss = compute_loss(logits, targets)
    
    // 反向传播和缩放
    let gradients = backward_pass(loss)
    
    // 混合精度优化步骤
    let (new_state, had_overflow) = mixed_precision_optimizer_step(
        mp_state,
        loss,
        gradients,
        learning_rate,
        mp_config
    )
    mp_state = new_state
    
    if had_overflow {
        // 跳过此步骤的权重更新
        continue
    }
}
```

### 损失缩放策略

```
初始化:
  loss_scale = 65536.0

每次溢出:
  loss_scale *= 0.5    # 退回

稳定N步后:
  loss_scale *= 2.0    # 增长
```

### 配置示例

```s
struct mixed_precision_config {
    use_mixed_precision: true
    compute_dtype: "float32"
    accumulate_dtype: "float32"
    loss_scale: 65536.0
    loss_scale_window: 2000
    loss_scale_growth_factor: 2.0
    loss_scale_backoff_factor: 0.5
    loss_scale_min: 1.0
    loss_scale_max: 65536.0
}
```

---

## 3. 梯度累积 (Gradient Accumulation)

### 概述
在多个小批次上累积梯度，然后进行一次权重更新，有效增加批大小。

### 关键概念

- **累积步数**: N步后更新权重
- **有效批大小**: batch_size × accumulation_steps
- **内存效率**: 比大批处理更节省内存

### 关键API

#### 累积器管理
```s
func new_accumulated_gradients(gradient_size: int) accumulated_gradients
func accumulate_gradients(accum: accumulated_gradients, step_gradients: [][]float, step_loss: float, scale: float) accumulated_gradients
func check_accumulation_complete(accum: accumulated_gradients, accumulation_steps: int) accumulated_gradients
func reset_accumulation(accum: accumulated_gradients) accumulated_gradients
```

#### 缓冲区管理
```s
func new_accumulation_buffer(gradient_size: int) accumulation_buffer
func add_to_buffer(buf: accumulation_buffer, gradients: [][]float, loss: float) accumulation_buffer
func normalize_buffer(buf: accumulation_buffer, steps: int) accumulation_buffer
func clip_accumulated_gradients(buf: accumulation_buffer, max_norm: float) accumulation_buffer
```

### 使用示例

```s
// 配置
let accum_config = new_gradient_accumulation_config()
accum_config.accumulation_steps = 4

// 初始化
var accumulated = new_accumulated_gradients(model_size)

// 训练循环
for step = 0; step < total_steps; step++ {
    // 前向/反向传播
    let loss = forward_backward(batch)
    let gradients = compute_gradients()
    
    // 累积梯度
    accumulated = accumulate_gradients(
        accumulated,
        gradients,
        loss,
        1.0 / float(accum_config.accumulation_steps)
    )
    
    // 检查是否准备更新
    accumulated = check_accumulation_complete(accumulated, accum_config.accumulation_steps)
    
    if accumulated.is_ready {
        // 归一化
        accumulated = normalize_accumulated_gradients(accumulated, accum_config.accumulation_steps)
        
        // 更新权重
        optimizer.step(accumulated.gradients)
        
        // 重置累积器
        accumulated = reset_accumulation(accumulated)
    }
}
```

### 有效批大小计算

```s
func effective_batch_size(batch_size: int, accumulation_steps: int) int
    // 返回: batch_size * accumulation_steps
    // 例如: 32 * 4 = 128
```

### 进度监控

```s
// 获取累积进度
let progress = get_accumulation_progress(step, accumulation_steps)
// 输出: "Accumulation Step: 2 / 4"
// 或者: "Accumulation Step: 4 / 4 [UPDATE WEIGHTS]"
```

---

## 4. 分布式张量并行 (Tensor Parallelism)

### 概述
将模型参数跨多个GPU进行分片，支持大规模模型训练。

### 关键概念

- **张量分片**: 将权重矩阵分片存储
- **列向分片**: 分片输出维度（前向传播无需通信）
- **行向分片**: 分片输入维度（需AllGather+ReduceScatter）
- **通信模式**: AllGather, ReduceScatter, AllReduce

### 关键API

#### 张量分片
```s
func column_wise_shard(weight: [][]float, cols: int, tp_rank: int, tp_size: int) tensor_shard
func row_wise_shard(activation: [][]float, rows: int, cols: int, tp_rank: int, tp_size: int) tensor_shard
```

#### 通信原语
```s
func all_gather(local_shard: [][]float, tp_size: int, tp_rank: int, shard_size_per_rank: int) [][]float
func reduce_scatter(full_data: [][]float, tp_size: int, tp_rank: int) [][]float
func all_reduce_gradients(local_gradients: [][]float, tp_size: int) [][]float
```

#### 分布式矩阵乘法
```s
func distributed_matmul(
    A_shard: [][]float,
    B_replicated: [][]float,
    M: int, K: int, N: int,
    shard_cols: int
) [][]float
```

#### 分布式状态管理
```s
func new_distributed_state(global_rank: int, world_size: int, tp_size: int) distributed_state
func new_tensor_parallel_config(tp_degree: int, tp_rank: int) tensor_parallel_config
```

### 使用示例

```s
// 配置
let world_size = 8
let tp_size = 4  // 4-way tensor parallelism
let rank = get_global_rank()

// 初始化分布式状态
let dist_state = new_distributed_state(rank, world_size, tp_size)

// 创建TP配置
let tp_config = new_tensor_parallel_config(tp_size, dist_state.tp_rank)

// 分片权重矩阵
let W_shard = column_wise_shard(W_full, cols, dist_state.tp_rank, tp_size)

// 前向传播
let output_local = distributed_matmul(
    A_shard,
    B_replicated,
    M, K, N,
    W_shard.shard_shape[1]
)

// 需要完整输出时进行AllGather
let output_full = all_gather(output_local, tp_size, dist_state.tp_rank, output_local.len())

// 反向传播时AllReduce梯度
let grad_full = all_reduce_gradients(grad_local, tp_size)
```

### 通信成本估计

```s
// 计算通信量
let comm_volume = get_communication_volume(
    model_size,
    tp_degree,
    true  // forward_pass
)

// 估计通信延迟 (假设带宽: 100 GB/s)
let latency_ms = estimate_communication_time(
    comm_volume,
    100.0  // bandwidth in GB/s
)
```

### 配置示例

```s
struct tensor_parallel_config {
    tp_degree: 4
    tp_rank: 0-3
    tp_size: 4
    sharding_strategy: "column_wise"
    communication_backend: "nccl"
    overlap_communication: true
}
```

---

## 完整集成示例

### 场景：高级混合训练

```s
// 1. 初始化所有模块
let vect_config = new_vectorization_config()
let mp_config = new_mixed_precision_config()
let accum_config = new_gradient_accumulation_config()
let tp_config = new_tensor_parallel_config(4, rank)

// 设置参数
accum_config.accumulation_steps = 4
mp_config.use_mixed_precision = true

// 2. 初始化状态
var mp_state = new_mixed_precision_state(model_size)
var accumulated = new_accumulated_gradients(model_size)
var comm_stats = new_communication_stats()

// 3. 主训练循环
for epoch = 0; epoch < num_epochs; epoch++ {
    for step = 0; step < steps_per_epoch; step++ {
        // 获取批数据
        let batch = get_next_batch(batch_size)
        
        // 前向传播（使用向量化）
        let logits = batch_matmul_blocked(
            inputs,
            W_shard,
            batch_size, M, K, N,
            64  // block_size
        )
        
        let loss = compute_loss(logits, targets)
        
        // 缩放损失用于梯度累积
        let scaled_loss = scale_loss_for_accumulation(loss, accum_config.accumulation_steps)
        
        // 反向传播
        let gradients = backward_pass(scaled_loss)
        
        // 梯度累积
        accumulated = accumulate_gradients(
            accumulated,
            gradients,
            loss,
            1.0 / float(accum_config.accumulation_steps)
        )
        
        accumulated = check_accumulation_complete(accumulated, accum_config.accumulation_steps)
        
        if accumulated.is_ready {
            // 归一化梯度
            accumulated = normalize_accumulated_gradients(accumulated, accum_config.accumulation_steps)
            
            // 分布式梯度规约
            let grad_reduced = all_reduce_gradients(accumulated.gradients, tp_config.tp_size)
            
            // 混合精度优化步骤
            let (new_state, overflow) = mixed_precision_optimizer_step(
                mp_state,
                loss,
                grad_reduced,
                learning_rate,
                mp_config
            )
            mp_state = new_state
            
            if !overflow {
                // 重置累积器
                accumulated = reset_accumulation(accumulated)
            }
        }
        
        // 监控
        if step % 100 == 0 {
            print("Step: " + string(step))
            print("Loss: " + string(loss))
            print("Loss Scale: " + string(mp_state.loss_scale_scheduler.current_scale))
        }
    }
}
```

---

## 性能优化建议

### 1. 向量化操作
- 使用`batch_matmul_blocked`而非`batch_matmul`
- 调整`block_size`根据L3缓存大小（通常64-256）
- 优先使用列向存储

### 2. 混合精度
- 初始`loss_scale`设为65536
- `loss_scale_window`设为2000-5000步
- 监控溢出率（目标<1%）

### 3. 梯度累积
- 有效批大小 = 小批 × 累积步数
- 调整学习率：LR_new ≈ LR_base / √(累积步数)
- 每个GPU上减少内存占用

### 4. 张量并行
- TP度数通常为2、4或8
- 列向分片优于行向分片（减少通信）
- 与数据并行结合：总度数 = TP度数 × DP度数

---

## 文件位置

| 模块 | 文件 |
|------|------|
| 向量化 | `neurx/ops/vectorization.s` |
| 混合精度 | `neurx/training/mixed_precision.s` |
| 梯度累积 | `neurx/training/gradient_accumulation.s` |
| 张量并行 | `neurx/distributed/tensor_parallel.s` |

---

## 测试与验证

```s
// 验证各模块
func test_vectorization() { ... }
func test_mixed_precision() { ... }
func test_gradient_accumulation() { ... }
func test_tensor_parallelism() { ... }
```

---

## 总结

这4个模块提供了生产级LLM训练所需的所有高级功能：

✅ **高性能计算** - 向量化操作  
✅ **内存效率** - 混合精度 + 梯度累积  
✅ **可扩展性** - 张量并行分布式训练  
✅ **生产质量** - 完整的错误处理和监控  

现在可以在真实数据上进行大规模LLM训练！
