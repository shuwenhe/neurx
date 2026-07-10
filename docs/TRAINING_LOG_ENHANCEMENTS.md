# 训练日志增强实现文档

## 概述
为 NeurX 预训练管道添加了详细的训练日志记录功能，包括性能指标、计时信息和资源使用情况。

## 修改内容

### 1. 性能指标结构扩展
**文件**: `pretrain/pretraining_pipeline.s`

在 `pretrain_state` 结构体中的 `performance` 字段添加了新的指标：

```s
struct performance {
    float tokens_per_second          // 吞吐量
    float gpu_memory_utilization    // GPU显存占用 (GB)
    float gpu_compute_utilization   // GPU计算利用率
    float communication_overhead_pct // 通信开销百分比
    float gradient_norm              // 梯度范数 ⭐ NEW
    float forward_time_ms           // Forward pass 耗时 (毫秒) ⭐ NEW
    float backward_time_ms          // Backward pass 耗时 (毫秒) ⭐ NEW
    float optimizer_time_ms         // Optimizer step 耗时 (毫秒) ⭐ NEW
    int samples_per_step            // 当前步的样本数 ⭐ NEW
}
```

### 2. 训练步骤增强
**函数**: `train_step()`

#### 添加GPU内存采样
```s
# 获取GPU内存使用情况（每10步采样一次，减少开销）
if state.current_step % 10 == 0:
    float gpu_mem_gb = get_gpu_memory_usage() / 1024.0
    state.performance.gpu_memory_utilization = gpu_mem_gb
```

#### 梯度范数计算
```s
# 在Gradient Accumulation & Update阶段
float grad_norm = clip_grad_norm_(model.parameters(), cfg.max_grad_norm)
state.performance.gradient_norm = grad_norm
```

#### 详细计时记录
```s
# 记录各阶段耗时（转换为毫秒）
state.performance.forward_time_ms = timer.get_elapsed("forward") * 1000.0
state.performance.backward_time_ms = timer.get_elapsed("backward") * 1000.0
state.performance.optimizer_time_ms = timer.get_elapsed("optimizer") * 1000.0
```

### 3. 日志函数重写
**函数**: `log_training_progress()`

重新设计为三行分层日志格式，包含10个关键指标：

#### 第一行：基础训练指标
```
[Step     430/500000] Loss:   2.8100 | LR: 2.00e-04 | GradNorm:   4.28 | Tokens:    110,080
```
- 当前步骤 / 总步数
- 损失值
- 学习率
- 梯度范数
- 总处理tokens数

#### 第二行：性能指标
```
         Throughput: 18500 tok/s | Samples:  430 | Forward: 32.0ms | Backward: 48.0ms | Optimizer:  6.0ms | GPU Mem: 18.4GB
```
- 吞吐量（tokens/秒）
- 样本数
- Forward pass耗时
- Backward pass耗时
- Optimizer step耗时
- GPU显存使用

#### 第三行：任务和时间信息
```
         Task:    CLM | RunLoss:   2.7850 | Elapsed:    2m 15s | ETA:   45d 12h
```
- 当前任务类型
- 指数移动平均损失
- 已用时间
- 预计完成时间

### 4. 辅助函数新增
**函数**: `get_gpu_memory_usage()`

```s
func get_gpu_memory_usage() -> float {
    """
    获取当前GPU设备的内存使用量（单位：MB）
    返回值为float类型，表示已使用的GPU显存（MB）
    示例: 如果返回19353.6，表示约19.4GB
    """
    float gpu_mem_mb = 18400.0  // 示例值：18.4GB = 18400MB
    return gpu_mem_mb
}
```

**注**: 当前为示例实现，需根据实际GPU框架（PyTorch CUDA, TensorFlow等）进行具体实现。

## 示例日志输出

### 步骤 430 的完整日志
```
[Step     430/500000] Loss:   2.8100 | LR: 2.00e-04 | GradNorm:   4.28 | Tokens:    110,080
         Throughput: 18500 tok/s | Samples:  430 | Forward: 32.0ms | Backward: 48.0ms | Optimizer:  6.0ms | GPU Mem: 18.4GB
         Task:    CLM | RunLoss:   2.7850 | Elapsed:    2m 15s | ETA:   45d 12h
```

## 指标说明

| 指标 | 单位 | 说明 | 示例 |
|------|------|------|------|
| step | - | 当前训练步数 | 430 |
| loss | - | 当前步的损失值 | 2.81 |
| lr | - | 当前学习率 | 2e-4 |
| GradNorm | - | 梯度范数（梯度的L2范数） | 4.28 |
| Tokens | - | 已处理的总tokens数 | 110,080 |
| Throughput | tokens/s | 吞吐量，每秒处理的tokens数 | 18,500 |
| Samples | - | 当前步的样本数 | 430 |
| Forward | ms | Forward pass的执行时间 | 32.0 |
| Backward | ms | Backward pass的执行时间 | 48.0 |
| Optimizer | ms | Optimizer step的执行时间 | 6.0 |
| GPU Mem | GB | GPU显存使用量 | 18.4 |
| Task | - | 当前任务类型（CLM/MLM/PreLM） | CLM |
| RunLoss | - | 指数移动平均损失值 | 2.785 |
| Elapsed | - | 从训练开始到现在的时间 | 2m 15s |
| ETA | - | 预计完成时间 | 45d 12h |

## 实现特点

✅ **高效采样**: GPU内存只在每10步采样一次，减少开销
✅ **详细计时**: 分别记录forward、backward和optimizer步骤的耗时
✅ **梯度监控**: 实时跟踪梯度范数以检测梯度爆炸/消失
✅ **多层次日志**: 三行分层显示，信息丰富但不过度拥挤
✅ **易于扩展**: 结构化设计，便于添加更多指标

## 后续改进方向

1. **GPU内存查询实现**: 根据实际使用的框架（PyTorch/TensorFlow）实现 `get_gpu_memory_usage()`
2. **分布式训练指标**: 添加All-Reduce通信时间、卡间负载均衡等指标
3. **自适应采样**: 根据训练阶段动态调整采样频率
4. **指标持久化**: 将日志定期保存到文件或TensorBoard进行分析
5. **异常检测**: 根据梯度范数、损失突变等自动检测训练异常

## 文件变更统计

- **修改文件**: 1个 (`pretrain/pretraining_pipeline.s`)
- **新增函数**: 1个 (`get_gpu_memory_usage()`)
- **修改函数**: 2个 (`log_training_progress()`, `train_step()`)
- **新增字段**: 5个 (在performance结构体中)
- **代码行数**: 增加约150行

## 测试建议

1. **单元测试**: 验证新增指标的计算正确性
2. **集成测试**: 在完整训练过程中验证日志输出格式
3. **性能测试**: 确保额外的日志记录不显著影响训练速度
4. **分布式测试**: 在多GPU/多节点环境中验证指标准确性

---

**创建时间**: 2025年1月
**相关文件**: `/home/shuwen/shuwen/train/neurx/pretrain/pretraining_pipeline.s`
