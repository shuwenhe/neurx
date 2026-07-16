# NeurX 真实训练实现指南

## 项目现状分析

### ✅ 已实现的组件
1. **张量操作** (`tensor/`)
   - `matmul2d` - 矩阵乘法
   - 激活函数（ReLU、GELU等）
   - 张量基本操作

2. **损失函数** (`lf/losses.s`)
   - `cross_entropy_loss` - 完整的交叉熵损失实现
   - 数值稳定的log_softmax
   - Perplexity 计算

3. **模型结构** (`model/llm/`)
   - `gpt_large_training_state` - 训练状态管理
   - `gpt_large_training_update` - 完整的前向/反向传播
   - `gpt_large_training_loss` - 损失计算

4. **数据管理** (`data/dataloader.s`)
   - 批量数据加载
   - Token 流管理
   - 数据质量过滤

5. **优化器** (`opt/optim.s`)
   - AdamW 优化器实现
   - 学习率调度

### ❌ 需要完成的部分

1. **梯度计算**
   - `transformer_backward` - Transformer 层反向传播
   - `embedding_apply_grad` - Embedding 梯度更新
   - 注意力层反向传播
   - FFN 层反向传播

2. **分布式训练**
   - 实现 DDP AllReduce
   - 梯度同步
   - 模型并行支持

3. **GPU 加速** (可选)
   - CUDA kernel 调用
   - GPU 内存管理
   - 混精度训练

## 关键实现步骤

### Step 1: 验证前向传播
确保以下函数正常工作：
```
- transformer_forward()
- embedding_lookup()
- cross_entropy_loss()
```

### Step 2: 实现反向传播
必须实现的反向传播函数：
```s
func transformer_backward(
    transformer backbone, 
    tensor hidden, 
    tensor grad_hidden, 
    []transformer_layer_optimizer_state optimizers
) gpt_large_backward_result

struct gpt_large_backward_result {
    transformer updated_backbone
    tensor grad_input
    []transformer_layer_optimizer_state backbone_optimizers
}
```

### Step 3: 集成梯度更新
确保 `adamw_step_state()` 正确更新参数：
```s
func adamw_step_state(
    adamw_optimizer opt,
    tensor params,
    tensor grad
) adamw_step_output
```

### Step 4: 运行真实训练
使用新的启动脚本：
```bash
cd /home/shuwen/shuwen/train/neurx
make train-real
```

## 文件清单

### 核心训练文件
- `scripts/legacy/run_real_training.s` - ✨ 新的真实训练启动脚本（已创建）
- `pretrain/llm/large_pretrain.s` - 主训练循环（需要验证）
- `model/llm/model_large_train.s` - 训练更新函数（需要验证反向传播）

### 关键梯度函数 (需要实现/验证)
- `tensor/core.s` - `matmul_backward`, `embedding_backward`
- `model/llm/model_backward.s` - Transformer 层反向传播
- `nn/attention.s` - 注意力反向传播
- `nn/ffn.s` - FFN 反向传播

## 验证清单

### 前向传播验证
- [ ] 数据加载器返回有效批次
- [ ] Embedding 层正确查询
- [ ] 注意力计算无 NaN/Inf
- [ ] FFN 激活函数工作正常
- [ ] 输出 logits 形状正确

### 反向传播验证  
- [ ] 损失梯度计算正确
- [ ] 梯度形状与参数形状匹配
- [ ] 没有梯度爆炸/消失
- [ ] 参数更新方向正确

### 训练稳定性检查
- [ ] 损失值持续下降（前100步）
- [ ] 梯度范数在合理范围内 [0.1, 10.0]
- [ ] 没有 NaN/Inf 损失值
- [ ] 学习率调度工作正常

## 调试建议

### 如果训练不收敛
1. 检查学习率（太高会导致发散）
2. 验证批大小（太小导致噪声太大）
3. 检查梯度是否正确计算
4. 添加梯度裁剪 (gradient clipping)

### 如果出现 NaN/Inf
1. 检查数值稳定性（log_softmax, softmax）
2. 验证 embedding 索引不越界
3. 检查除以零的情况
4. 使用梯度检查工具

### 性能优化
1. 启用梯度累积减少内存使用
2. 使用混精度训练 (BF16)
3. 启用梯度检查点 (gradient checkpointing)
4. 实现分布式并行

## 进度跟踪

- [x] 创建真实训练启动脚本
- [ ] 实现 Transformer 反向传播
- [ ] 验证梯度计算正确性
- [ ] 集成 GPU 支持 (可选)
- [ ] 实现分布式训练
- [ ] 性能优化

## 资源

- 张量操作: `neurx/tensor/*.s`
- 损失函数: `neurx/lf/losses.s`
- 模型代码: `neurx/model/llm/*.s`
- 数据管道: `neurx/data/dataloader.s`
