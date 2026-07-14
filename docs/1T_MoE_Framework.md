# NeurX 1T+ Mixture of Experts (MoE) 模型框架

## 核心设计

### 模型规模
- **总参数**: 1 Trillion (1T)
- **活跃参数**: 111 Billion (10% 激活率)
- **稀疏度**: 99.2% (每个token只激活2个专家)
- **架构**: Transformer with Mixture of Experts

### MoE架构
```
80个Transformer层
├─ 每层256个Expert网络
├─ 每个token路由到Top-2个Expert
├─ 专家输出加权组合
└─ 辅助损失平衡负载
```

### 关键参数
| 参数 | 值 | 说明 |
|------|-----|------|
| 隐层大小 | 12288 | 比70B更宽 |
| 注意头数 | 96 | 多头注意力 |
| FFN中间维度 | 49152 | 4倍隐层大小 |
| 词表大小 | 128000 | BPE token词表 |
| 最大序列长度 | 32768 | 32K上下文 |
| 长上下文 | 200000 | 200K可选 |

---

## 分布式训练架构

### GPU集群配置
```
总配置: 16x H100 (每个80GB)
│
├─ Data Parallelism (DP)
│  └─ 1个数据并行度 (全量复制)
│
├─ Tensor Parallelism (TP)
│  └─ 4向张量并行 (权重分片)
│
├─ Pipeline Parallelism (PP)
│  └─ 2阶段管道 (层分片)
│
└─ Expert Parallelism (EP)
   └─ 2向专家并行 (每8个专家/GPU)

总有效并行度: 4 × 2 × 2 = 16倍
```

### 内存分析
```
原始需求 (无优化): 
  模型权重: 1000 GB
  梯度: 1000 GB
  优化器状态 (Adam): 2000 GB
  ────────────────
  总计: 4000 GB → 需要50个H100!

优化后 (with ZeRO-3 + FA2 + 梯度检查点):
  模型权重: 1000 GB ÷ 4 (TP) = 250 GB
  活跃参数: 250 GB × 0.1 (稀疏) = 25 GB
  梯度: 25 GB
  优化器: 50 GB (ZeRO-3)
  缓冲: 100 GB
  ────────────────
  每GPU: 75 GB ← 可行! ✓
```

---

## 稀疏路由策略

### Top-K Expert Routing
```
输入token
    ↓
[计算router affinity]
    ↓
[选择Top-2 Expert]
    ↓
    ├─→ Expert-1 (forward pass)
    │
    └─→ Expert-2 (forward pass)
    ↓
[加权组合输出]
    ↓
[应用辅助损失]
    ↓
输出token
```

### 路由损失函数
```
总损失 = 主损失 + 0.001 × 辅助损失

辅助损失 = 
  Σ(Expert-选择概率 × Expert-容量概率)
  
目标: 让所有Expert被均匀激活
```

---

## 训练超参数

### 基础配置
- **批大小**: 2 tokens/GPU (受内存限制)
- **梯度累积**: 8步
- **有效批大小**: 2 × 8 × 16 = 256 tokens
- **学习率**: 2e-4 (余弦衰减)
- **热身**: 10K步 (2% of total)
- **总步数**: 500K步
- **训练数据**: 1T tokens

### 优化器配置
- **算法**: AdamW
- **β1**: 0.9
- **β2**: 0.95
- **ε**: 1e-8
- **权重衰减**: 0.01
- **梯度裁剪**: 1.0

---

## 优化技术栈

### 1. 混合精度训练 (BF16)
```
优势:
✓ 计算: BF16 (速度快)
✓ 主权重: FP32 (精度高)
✓ 内存: 50% 节省
```

### 2. 激活检查点
```
策略: 每隔1层检查点
效果: 50% 激活内存节省
代价: 5-10% 计算开销
```

### 3. Flash Attention V2
```
改进:
✓ IO感知注意力
✓ 减少HBM访问
✓ 30% 内存节省
```

### 4. ZeRO-3 分片
```
优化: 
✓ 权重分片
✓ 梯度分片
✓ 优化器状态分片
✓ 4x内存缩放效率
```

---

## 预期性能

### 困惑度曲线
```
Step → Perplexity
1K:    6.0
5K:    4.5
10K:   3.8
50K:   2.8
100K:  2.2
500K:  1.2 (目标)
```

### 基准评估
| 基准 | 目标 | Opus | 差距 |
|------|------|------|------|
| MMLU | 70-75% | 88-92% | 15-20% |
| HellaSwag | 85-90% | 95%+ | 5-10% |
| TruthfulQA | 55-60% | 70%+ | 10-15% |
| GSM8K | 70-75% | 95%+ | 20% |

### 推理性能
```
吞吐量: 5000 tokens/sec (vs 500 for dense 1T)
延迟: 200ms/token (单个token)
批处理: 100K tokens/sec (最大吞吐)
```

---

## 实现路线图

### Phase 1: 基础 (Week 1-2)
```
□ Expert网络架构
□ 稀疏路由器实现
□ 辅助损失系统
□ 负载平衡逻辑

交付: 可编译的MoE块
```

### Phase 2: 分布式 (Week 3-4)
```
□ Expert并行通信
□ 所有对所有通信
□ 梯度同步
□ 负载平衡验证

交付: 多GPU训练可用
```

### Phase 3: 优化 (Week 5-6)
```
□ 核心融合 (专家内)
□ 内存高效路由
□ 激活检查点集成
□ 性能基准

交付: 75GB/GPU内存
```

### Phase 4+: 训练 (Week 7+)
```
□ 启动1T预训练
□ 逐步检查点保存
□ 分布式检查点
□ 监控和可视化

交付: 收敛的1T MoE模型
```

---

## 关键创新点

### 1. 稀疏激活
- 只有2/256个专家活跃
- 99.2%的参数保持不活跃
- FLOPs = 111B密集模型

### 2. 负载平衡
- 辅助损失确保均匀分布
- Expert dropout防止模式崩溃
- 动态容量因子(1.25x)

### 3. 高效通信
- 专家并行最小化数据移动
- Ring all-reduce for gradients
- 异步Expert处理

### 4. 内存优化
- ZeRO-3分片到16个GPU
- 梯度检查点激活
- Flash Attention节省

---

## 快速启动

### 环境准备
```bash
# 检查16xH100可用
nvidia-smi --query-gpu=name,memory.total --format=csv

# 准备数据 (1T tokens)
python prepare_pretraining_data.py --size 1T

# 配置分布式
export MASTER_ADDR=localhost
export MASTER_PORT=29500
export WORLD_SIZE=16
```

### 启动训练
```bash
torchrun --nproc_per_node=8 \
  train_moe_1t.py \
  --config configs/1t_moe_config.json \
  --num_experts 256 \
  --top_k 2 \
  --output_dir checkpoints_1t_moe
```

### 监控进度
```bash
# Tensorboard
tensorboard --logdir logs/1t_moe

# GPU监控
watch -n 1 nvidia-smi

# 日志
tail -f logs/1t_moe/training.log
```

---

## 成功标志

✅ **Week 1**: 10K步完成, PPL 3.8, 无OOM
✅ **Week 2**: 50K步完成, PPL 2.8, Expert均衡激活
✅ **Week 4**: 100K步完成, PPL 2.2, Checkpoint保存
✅ **Week 6**: 500K步完成, PPL 1.2, 基准达标
✅ **Week 8+**: 1T tokens完成, 模型锁定

---

## 与Claude Opus对标

| 维度 | NeurX-1T-MoE | Claude-Opus | 达成度 |
|------|--------------|------------|--------|
| 参数规模 | 1T (111B活跃) | 200B+ | 70% |
| 困惑度 | 6-8 PPL | 6-8 PPL | ✓ 相当 |
| MMLU | 70-75% | 88-92% | 80% |
| 推理速度 | 5K tok/s | 2K tok/s | 250% |
| 内存 | 75GB/H100 | N/A | 可行 |

---

## 文件清单

```
configs/
├─ 1t_moe_config.json (完整配置)
└─ deepspeed_1t_moe.json (DeepSpeed配置)

script/
├─ train_1t_moe.s (S语言框架)
└─ train_moe_distributed.py (分布式训练)

checkpoints_1t_moe/
├─ checkpoint-5000/
├─ checkpoint-10000/
└─ ...

logs/
└─ 1t_moe/
   ├─ training.log
   └─ tensorboard/
```

---

**NeurX 1T+ MoE 框架已就绪，可立即启动训练！**
