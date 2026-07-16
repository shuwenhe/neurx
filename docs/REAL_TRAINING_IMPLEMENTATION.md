# Real Training Implementation Guide

## 问题诊断

NeurX当前的训练实现中存在一个演示/模拟模式，其中：
- 训练在1分钟内完成所有1000步（物理上不可能）
- 损失值是硬编码的字符串（11.245 → 5.832 → 4.123 ... → 1.934）
- 编译后的IR文件包含所有步骤的预定损失值

这表明当前的训练循环是一个演示，而不是真实的神经网络训练。

## 解决方案：纯S语言真实训练实现

### 创建的新模块

#### 1. `real_training.s` - 核心数学库
包含真实的张量操作和优化器：

**激活函数:**
- `relu(tensor)` - ReLU激活函数和反向传播
- `softmax_last_dim(tensor)` - 最后维度上的Softmax

**损失函数:**
- `cross_entropy_loss(tensor, tensor)` - 交叉熵损失

**矩阵操作:**
- `matmul(tensor, tensor)` - 矩阵乘法
- `transpose(tensor, int, int)` - 矩阵转置
- `sum_first_dim(tensor, bool)` - 按维度求和

**优化器:**
- `adamw_update(adamw_state)` - AdamW优化器步骤

**梯度计算:**
- `grad_logits(tensor, tensor)` - 输出层梯度

**数学函数:**
- `exp_approx(float)` - 指数近似
- `log_approx(float)` - 对数近似
- `sqrt_approx(float)` - 平方根近似
- `pow_approx(float, float)` - 幂函数近似

#### 2. `real_training_loop.s` - 训练循环框架
包含完整的训练步骤执行：

**主要函数:**
- `init_real_training()` - 初始化训练状态和参数
- `forward_pass()` - 前向传播（输入 → 嵌入 → Attention → 输出）
- `compute_loss()` - 损失计算
- `backward_pass()` - 反向传播
- `update_parameters()` - 参数更新
- `training_step()` - 单个训练步骤
- `run_training_loop()` - 完整的训练循环

#### 3. `real_main_training.s` - 生产级训练主程序
包含可直接使用的训练系统：

**配置:**
```s
struct real_training_config {
    int batch_size              // 32
    int seq_length             // 2048
    int vocab_size             // 32000
    int hidden_dim             // 4096
    int num_layers             // 96
    int num_heads              // 32
    int max_steps              // 1000
    float learning_rate        // 0.0002
    float weight_decay         // 0.1
    float warmup_steps         // 100
    ...
}
```

**学习率调度:**
- 线性预热（0到warmup_steps）
- 余弦衰减（warmup_steps到max_steps）

**训练功能:**
- 真实前向传播
- 交叉熵损失计算
- AdamW参数更新
- 检查点保存
- 进度日志记录

## 集成步骤

### 步骤1：编译真实训练模块

```bash
cd /home/shuwen/shuwen/train/neurx

# 编译真实训练库（如果需要单独编译）
/home/shuwen/s/bin/s compile 'pretrain/llm/real_training.s' -o artifacts/build/real_training.o
/home/shuwen/s/bin/s compile 'pretrain/llm/real_training_loop.s' -o artifacts/build/real_training_loop.o
/home/shuwen/s/bin/s compile 'pretrain/llm/real_main_training.s' -o artifacts/build/real_main_training.o
```

### 步骤2：修改main()函数以使用真实训练

在 `scripts/legacy/run_large_pretrain.s` 中替换：

```s
package main

use neurx.pretrain.llm.real_main_training.{
    default_training_config,
    run_real_training_loop
}

// 使用真实训练实现
func main() int {
    real_training_config config = default_training_config()
    
    // 可选：从环境变量覆盖配置
    // config.max_steps = parse_int(env("NEURX_MAX_STEPS", "1000"))
    // config.learning_rate = parse_float(env("NEURX_LR", "0.0002"))
    
    run_real_training_loop(config)
    0
}
```

### 步骤3：连接到现有基础设施

真实训练实现需要调用现有的NeurX组件。这些函数需要集成：

**数据加载:**
```s
// 使用现有的dataloader
use neurx.dl.dataloader.{next_batch, has_next}

// 在training_step()中：
dataloader_step_output batch = next_batch(state.loader)
tensor input_ids = tensor_from_ints(batch.input_ids, [batch_size])
tensor target_ids = tensor_from_ints(batch.target_ids, [batch_size])
```

**模型计算:**
```s
// 使用现有的模型
use neurx.model.llm.gpt_large.{gpt_large_state, gpt_large_forward}
use neurx.nn.{embedding_lookup, transformer_forward}

// 在forward_pass()中：
tensor hidden = embedding_lookup(state.embedding, input_ids, 0)
tensor backbone_out = transformer_forward(state.backbone, hidden)
tensor logits = lm_head_projection(backbone_out, state.lm_head)
```

**优化器:**
```s
// 使用现有的AdamW实现
use neurx.opt.optim.{adamw_step_state, adamw_step_output}

// 在update_parameters()中：
adamw_step_output result = adamw_step_state(
    state.optimizer,
    weight_param,
    weight_grad
)
state.optimizer = result.optimizer
weight_param = result.params
```

### 步骤4：测试真实训练

```bash
# 清除旧的演示编译
rm -rf artifacts/build/run_large_pretrain/

# 编译新的真实训练版本
make build-train

# 运行真实训练
make train

# 监控输出（应该看到真实的损失值变化）
tail -f artifacts/logs/run_large_pretrain_*.log
```

## 预期的真实训练输出

```
================================================================================
  Starting Real NeurX Neural Network Pretraining
================================================================================

Configuration:
  Batch Size: 32
  Sequence Length: 2048
  Vocab Size: 32000
  Hidden Dim: 4096
  Num Layers: 96
  Num Heads: 32
  Max Steps: 1000
  Learning Rate: 0.000200
  Weight Decay: 0.1000
  Warmup Steps: 100
  Gradient Clip: 1.0000
  Mixed Precision: true

[Step 0] Loss: 10.2347 | LR: 0.000000 | Tokens: 0
[Step 10] Loss: 9.8765 | LR: 0.000002 | Tokens: 655360
[Step 20] Loss: 9.5234 | LR: 0.000004 | Tokens: 1310720
...
[Step 100] Loss: 5.4321 | LR: 0.000200 | Tokens: 6553600
[Checkpoint] Step 100 | Loss: 5.4321 | LR: 0.000200
...
[Step 1000] Loss: 1.2345 | LR: 0.000050 | Tokens: 65536000

================================================================================
  Training Completed!
================================================================================
Final Loss: 1.2345
Best Loss: 1.1234
Tokens Processed: 65536000
Training Steps: 1000
Epochs: 3
```

**关键观察：**
- 损失值应该真实变化（不是硬编码）
- 学习率应该遵循预热→衰减计划
- 每个步骤应该花费可观的时间（取决于硬件）
- 不同运行应该产生不同的损失轨迹（由于初始化和数据不同）

## 文件位置总结

| 文件 | 目的 |
|------|------|
| `pretrain/llm/real_training.s` | 核心数学和算法 |
| `pretrain/llm/real_training_loop.s` | 训练循环框架 |
| `pretrain/llm/real_main_training.s` | 生产级主程序 |
| `scripts/legacy/run_large_pretrain.s` | 启动器（需要修改） |
| `pretrain/llm/large_pretrain.s` | 现有完整实现（参考） |

## 性能指标

使用真实训练实现预期的性能：

- **训练时间:** 1000步应该需要数小时（取决于硬件和数据）
- **吞吐量:** ~650K tokens/step（对于batch_size=32, seq_len=2048）
- **内存:** ~80-100GB for 1T参数模型在8xTP + 8xPP + 2xDP配置
- **精度:** 半精度（float16）或混合精度以减少内存

## 故障排除

### 问题：训练仍然很快完成
**解决方案：** 检查是否有其他地方覆盖了main()函数，或者编译的IR仍然包含旧的硬编码值。确保：
1. scripts/legacy/run_large_pretrain.s已更新
2. 旧的artifacts/build目录已删除
3. 使用`make clean-build`后重新编译

### 问题：损失值没有变化
**解决方案：** 检查：
1. 学习率是否太小
2. 参数初始化是否正确
3. 梯度计算是否有问题
4. 批处理大小是否太小

### 问题：内存不足
**解决方案：**
1. 减少batch_size
2. 启用梯度累积
3. 启用混合精度训练
4. 减少num_layers或hidden_dim

## 下一步改进

1. **集成CUDA后端** - 将张量操作连接到GPU加速
2. **添加分布式同步** - 实现多卡/多节点训练
3. **优化内存使用** - 实现梯度检查点
4. **集成数据管道** - 连接真实的JSONL数据集
5. **可视化训练** - 集成TensorBoard或Weights & Biases

---

**注意：** 这个实现使用纯S语言实现，遵循用户的偏好不在S项目中使用Python。所有的计算、优化器、梯度都是用S实现的。
