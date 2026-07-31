# verl中尚未在neurx实现的功能

本文档列出了verl中存在但neurx中还未实现的算法和功能。

---

## 1. RL算法变体（Advantage Estimators）

### 1.1 GRPO_PASSK
**文件位置（verl）**: `verl/trainer/ppo/core_algos.py`

**功能描述**:
- GRPO的pass@k变体，专门用于代码生成任务
- 基于pass@k评估指标进行优势估计
- 适用于需要多样性采样和正确性验证的场景

**使用场景**:
- 代码生成（HumanEval, MBPP等）
- 需要pass@k评估的任务

**优先级**: 🔴 高（代码任务常用）

---

### 1.2 RLOO_VECTORIZED
**文件位置（verl）**: `verl/trainer/ppo/core_algos.py`

**功能描述**:
- RLOO的向量化实现
- 性能优化版本，批量计算LOO baseline
- 减少计算开销，提高训练速度

**使用场景**:
- 大规模RLOO训练
- 需要高效REINFORCE Leave-One-Out的场景

**优先级**: 🟡 中（性能优化）

---

### 1.3 GRPO_VECTORIZED
**文件位置（verl）**: `verl/trainer/ppo/core_algos.py`

**功能描述**:
- GRPO的向量化实现
- 批量计算组相对优势
- 更高效的内存和计算利用

**使用场景**:
- 大规模GRPO训练
- 推理任务的高效训练

**优先级**: 🟡 中（性能优化）

---

### 1.4 TIR_OPTIMAL_TOKEN_BASELINE
**文件位置（verl）**: `verl/trainer/ppo/core_algos.py`

**功能描述**:
- Token-level Importance Reweighted Optimal Token Baseline
- 结合importance sampling和token-wise baseline
- 处理off-policy问题的同时减少方差

**关键特性**:
- Token级别的重要性权重
- 最优方差减少
- 适用于off-policy场景

**使用场景**:
- Off-policy训练
- 需要同时处理分布偏移和高方差的场景

**优先级**: 🔴 高（理论创新）

---

### 1.5 REINFORCE_PLUS_PLUS_BASELINE
**文件位置（verl）**: `verl/trainer/ppo/core_algos.py`

**功能描述**:
- REINFORCE++的baseline变体
- 可能使用不同的baseline策略（如learned baseline）
- 与原始REINFORCE++的区别在于baseline计算方式

**使用场景**:
- 需要更精确baseline的简单任务

**优先级**: 🟢 低（现有REINFORCE++已足够）

---

## 2. Rollout Correction（解决训练-推理不匹配）

### 2.1 概述
verl实现了完整的Rollout Correction框架，用于解决RL训练中的off-policy问题：

**问题来源**:
1. **Policy mismatch**: Rollout policy (vLLM BF16) vs Training policy (FSDP FP32)
2. **Model staleness**: 使用旧checkpoint收集的数据
3. **General off-policy**: 任何分布偏移

**文件位置（verl）**:
- `verl/trainer/config/algorithm.py` - RolloutCorrectionConfig
- `verl/trainer/ppo/rollout_corr_helper.py` - 实现

---

### 2.2 核心技术

#### 2.2.1 Importance Sampling (IS)
- **Token-level IS**: 低方差但有偏
- **Sequence-level IS**: 无偏但高方差
- **IS threshold**: 截断重要性权重（TIS）
- **Batch normalization**: 批内标准化

#### 2.2.2 Rejection Sampling (RS)
多种rejection sampling模式：
- `token_k1`: Token级别，使用 `-log r`
- `token_k2`: Token级别，使用 `0.5 * (log r)^2`
- `token_k3`: Token级别，使用 `exp(log r) - 1 - log r`
- `seq_sum_k1/k2/k3`: Sequence求和变体
- `seq_mean_k1/k2/k3`: Sequence均值变体
- `seq_max_k2/k3`: Sequence最大值变体

#### 2.2.3 Geometric Mean Rejection
- 长度归一化的IS ratio
- 使用几何均值 `E[log(r)]`
- 更稳定的rejection criterion

#### 2.2.4 IcePop
- 将IS权重设为0（而非截断）当超出 `[lower, upper]` 范围
- 更激进的off-policy样本过滤

---

### 2.3 操作模式

#### Decoupled Mode (3 policies)
- π_rollout: 用于生成数据
- π_old: 用于PPO的old policy
- π_θ: 当前训练的policy
- IS weights校正π_old和π_rollout之间的gap

#### Bypass Mode (2 policies)
- π_rollout = π_old（重用rollout log prob）
- π_θ: 当前训练的policy
- 更快，但假设rollout policy即为old policy

---

### 2.4 预设配置

verl提供了多个预设：
- `decoupled_token_is()`: Token-TIS
- `decoupled_seq_is()`: Seq-TIS
- `decoupled_seq_is_rs()`: Seq-MIS
- `decoupled_geo_rs()`: Geo-RS
- `bypass_ppo_clip()`: PPO-clip only
- `bypass_pg_is()`: REINFORCE + Seq-TIS
- 等等...

---

### 2.5 参考论文
Liu, Li, Fu, Wang, Liu, Shen (2025)
"When Speed Kills Stability: Demystifying RL Collapse from the Training-Inference Mismatch"
https://richardli.xyz/rl-collapse

**优先级**: 🔴🔴 非常高（解决实际生产问题）

---

## 3. Distillation功能

### 3.1 Forward KL Distillation with Top-K
**文件位置（verl）**:
- `verl/trainer/distillation/losses.py`
- `verl/trainer/distillation/fsdp/losses.py`
- `verl/trainer/distillation/megatron/losses.py`

**功能描述**:
- 使用top-k log probabilities进行KL蒸馏
- 内存高效（不需要完整vocab的softmax）
- 支持chunked computation for large vocab

**关键特性**:
- `_chunked_topk_log_probs()`: 分块计算避免OOM
- Sequence parallel support
- FP32 logsumexp for numerical stability

**neurx现状**:
- 已有 `multi_teacher_distillation.s`
- 但缺少top-k优化和各种loss变体

**优先级**: 🟡 中（性能优化）

---

### 3.2 Distillation Loss Registry
verl实现了可扩展的distillation loss注册系统：
- `register_distillation_loss()` decorator
- 支持自定义loss functions
- 配置驱动的loss选择

**建议**:
在neurx中实现类似的registry pattern

**优先级**: 🟢 低（架构优化）

---

## 4. Reward Manager扩展

虽然neurx已实现部分reward managers，但verl还有：

### 4.1 Remote Reward Manager
**文件位置（verl）**: `verl/workers/reward_manager/remote.py`

**功能描述**:
- 远程奖励模型服务
- 支持HTTP/gRPC调用
- 适用于大型奖励模型

**优先级**: 🟡 中（分布式训练）

---

### 4.2 GDPO Reward Manager
**文件位置（verl）**: `verl/workers/reward_manager/`

**功能描述**:
- 配套GDPO算法的reward manager
- 多维度奖励管理

**neurx现状**: 已实现GDPO算法，但可能需要配套的reward manager

**优先级**: 🟢 低（已有GDPO实现）

---

## 5. 高级训练模式

### 5.1 Fully Async Policy Training
**文件位置（verl）**:
- `verl/experimental/fully_async_policy/fully_async_trainer.py`
- `verl/experimental/fully_async_policy/fully_async_rollouter.py`

**功能描述**:
- 完全异步的policy训练
- Rollout和training完全解耦
- 最大化GPU利用率

**优先级**: 🔴 高（性能提升）

---

### 5.2 One-Step Off-Policy Training
**文件位置（verl）**: `verl/experimental/one_step_off_policy/ray_trainer.py`

**功能描述**:
- 单步off-policy更新
- 适用于快速迭代场景

**优先级**: 🟡 中

---

### 5.3 Dynamic Scheduling
**文件位置（verl）**: `verl/experimental/fully_async_policy/dynamic_schedule/`

**功能描述**:
- 动态调度rollout和training资源
- 自适应batch size
- 资源利用率优化

**优先级**: 🟡 中

---

## 6. 优化工具

### 6.1 Prefix Grouping
**文件位置（verl）**: `verl/trainer/ppo/prefix_grouper_utils.py`

**功能描述**:
- 共享prefix优化
- 减少重复计算
- 适用于多个相同prefix的prompts

**优先级**: 🟡 中（性能优化）

---

### 6.2 Sequence Length Balancing
**文件位置（verl）**: `verl/utils/seqlen_balancing.py`

**功能描述**:
- Largest Differencing Method (LDM) 算法
- 平衡batch中的序列长度
- 减少padding开销

**优先级**: 🟡 中（性能优化）

---

### 6.3 Transfer Queue Utilities
**文件位置（verl）**: `verl/utils/transferqueue_utils.py`

**功能描述**:
- 高效的worker间数据传输
- Lazy compute优化
- 适用于分布式训练

**优先级**: 🟢 低（基础设施）

---

## 7. 特殊优化器

### 7.1 Muon Optimizer
**文件位置（verl）**: `verl/utils/megatron/optimizer.py`

**功能描述**:
- Megatron-Core集成的新兴优化器
- Muon算法支持

**neurx现状**: 有optimizer模块，但可能缺少Muon

**优先级**: 🟢 低（实验性）

---

## 实现优先级总结

### 🔴🔴 非常高优先级
1. **Rollout Correction框架** - 解决训练稳定性问题

### 🔴 高优先级
2. **GRPO_PASSK** - 代码任务必需
3. **TIR_OPTIMAL_TOKEN_BASELINE** - 理论先进
4. **Fully Async Policy Training** - 显著性能提升

### 🟡 中优先级
5. **RLOO_VECTORIZED / GRPO_VECTORIZED** - 性能优化
6. **Forward KL Distillation with Top-K** - 内存优化
7. **Remote Reward Manager** - 分布式支持
8. **Prefix Grouping / Sequence Balancing** - 计算优化

### 🟢 低优先级
9. **REINFORCE_PLUS_PLUS_BASELINE** - 现有已足够
10. **Distillation Loss Registry** - 架构优化
11. **各种工具类** - 锦上添花

---

## 建议实现顺序

1. **第一批**: Rollout Correction（最重要）
2. **第二批**: GRPO_PASSK, TIR_OPTIMAL_TOKEN_BASELINE
3. **第三批**: Vectorized variants, Top-K distillation
4. **第四批**: Async training, Dynamic scheduling
5. **第五批**: 各种优化工具

---

## 当前neurx已实现的算法总结

✅ **已实现（共32个）**:
- PPO (GAE)
- GRPO
- DPO, ORPO, SimPO
- DAPO, ReMax, RLOO, REINFORCE++
- PRIME, DrGRPO, VAPO
- SPPO, GSPO, GDPO, PF-PPO
- GMPO, SAPO, DPPO, CISPO
- GPG, OPO, OTB
- Mooncake checkpoint
- TensorRT-LLM, HF Transformers backends
- Multi-teacher distillation
- 4种reward managers

❌ **未实现（至少15个核心功能）**:
- 5个算法变体
- Rollout Correction完整框架
- Top-K distillation优化
- Async training模式
- 各种性能优化工具

---

**总计**: verl中还有约15-20个重要功能在neurx中未实现，其中Rollout Correction框架是最关键的缺失部分。
