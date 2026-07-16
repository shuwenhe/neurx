# 训练性能优化指南

## 📊 当前性能诊断

### 硬件配置
- **GPU**: NVIDIA RTX 4060 Ti (16GB显存)
- **模型**: 1T参数 (配置文件指定)
- **实际速度**: ~2.5 tokens/step ⚠️ 极低

### 性能对标
```
RTX 4060 Ti理论性能:
├─ FP32峰值: 10 TFLOPS
├─ BF16峰值: 20 TFLOPS  
├─ INT8峰值: 40 TFLOPS
└─ 预期单卡吞吐:
    ├─ 1.5B模型: 500-1000 tokens/sec ✓
    ├─ 7B模型: 50-100 tokens/sec ⚠️ 勉强可行
    └─ 1T模型: 0.1-1 tokens/sec ❌ 不可行
```

### 核心问题
```
配置 vs 硬件 严重不匹配:

1. 模型大小
   ├─ 配置: 1T参数 (1,000 billion)
   ├─ 需要: ~4TB显存 (FP32) / ~1TB (BF16)
   └─ 可用: 16GB ❌ 相差62,500倍

2. 分布式设置
   ├─ 配置: world_size=1024, tensor_parallel=64
   ├─ 用途: 分布式训练1024个GPU
   └─ 实际: 1个GPU ❌ 过度配置

3. 批处理
   ├─ global_batch: 4096
   ├─ micro_batch: 2
   ├─ accumulation: 512步
   └─ 实际可用: 16-32 ❌ 过大

4. 内存优化
   ├─ CPU卸载: 启用 (极低效)
   ├─ 梯度检查点: 启用 (重复计算)
   └─ ZeRO-3: 启用 (不适合单卡)
```

---

## 🚀 优化方案

### 方案1: 使用适配硬件的模型配置 (推荐)

**预期性能提升: 10-100倍**

```bash
# 使用优化的配置
cp config_optimized_4060ti.json train_config.yaml

# 启动训练
make pretrain-gpu
```

**配置变更**:
```json
{
  "模型参数": "1.5B (vs 1T)",
  "隐层维度": "1024 (vs 12800)",
  "网络层数": "24 (vs 96)",
  "Batch大小": "32 (vs 4096)",
  "MicroBatch": "4 (vs 2)",
  "梯度累积": "8 (vs 512)",
  "world_size": "1 (vs 1024)",
  "混合精度": "BF16 (自动)",
  "梯度检查点": "禁用 (显存足够)",
  "CPU卸载": "禁用"
}
```

**预期性能**:
- **tokens/step**: 256-512 (vs 2.5)
- **显存占用**: 12-14GB (vs OOM或极其缓慢)
- **训练速度**: 250-500 tokens/sec
- **步进时间**: 0.5-1 sec/step (vs 数秒)

---

### 方案2: 快速参数调优 (如必须用1T配置)

如果必须使用1T模型配置，按优先级做以下调整:

#### 第1级 - 立即改进 (减少梯度累积)
```bash
export NEURX_PRETRAIN_MICRO_BATCH=4
export NEURX_PRETRAIN_GRADIENT_ACCUMULATION=4
# 预期: 3-5倍提升, tokens/step: 10-12
```

#### 第2级 - 启用量化 (减少显存)
```bash
export NEURX_MIXED_PRECISION=int8
export NEURX_ACTIVATION_CHECKPOINTING=1
# 预期: 另外3-5倍提升, tokens/step: 30-60
```

#### 第3级 - 启用CPU卸载 (最后手段)
```bash
export NEURX_CPU_OFFLOAD=1
export NEURX_CPU_OFFLOAD_DIR=/tmp/neurx_offload
mkdir -p /tmp/neurx_offload
# 预期: 再提升2-3倍, tokens/step: 60-180
# 副作用: 大量CPU↔GPU数据传输, 可能更慢
```

---

### 方案3: 多卡分布式训练 (理想方案)

如果有多个GPU:

```bash
# 4个GPU训练1T模型
export NEURX_HOSTFILE=configs/4gpu.hosts
cat > configs/4gpu.hosts << 'EOF'
localhost 4
EOF

bash scripts/legacy/launch_multinode_pretrain.sh

# 预期性能:
# ├─ tokens/step: 100-200 (4卡并行)
# ├─ 梯度同步开销: ~10-15%
# └─ 总体吞吐: 400-800 tokens/sec
```

---

## 📈 性能对比 (相同配置下)

| 模型 | 显存 | Batch | tokens/sec | steps/day |
|------|------|-------|-----------|----------|
| 1.5B (推荐) | 12GB | 32 | **300-500** | **25.9M** |
| 7B | 14GB | 16 | 80-120 | 6.9M |
| 13B | OOM | - | - | - |
| 1T单卡 | OOM | - | **0.1-1** | **8.6k** |
| 1T 4卡 | 4x16GB | 128 | 300-500 | 25.9M |

---

## 🔧 快速优化命令

### 诊断当前性能
```bash
cd /home/shuwen/shuwen/train/neurx

# 查看当前训练速度
tail -100 checkpoint/NeurX-1.3/rank_0.log | grep trainer-v2 | tail -5

# 计算 tokens/sec
# tokens = (step - prev_step) * seq_len
# 如: step从9010到9030 = 20步, 256 tokens/step
#     时间差 = 30秒 => 20*256/30 = 170 tokens/sec
```

### 立即使用优化配置
```bash
# 1. 停止当前训练 (Ctrl+C)
# 2. 切换配置
cat config_optimized_4060ti.json > train_config.yaml

# 3. 清除旧checkpoint以重新开始
rm -f checkpoint/NeurX-1.3/transformer_v2.ckpt

# 4. 重启
make pretrain-gpu
```

### 监控性能改进
```bash
# 终端1: 启动训练
make pretrain-gpu

# 终端2: 实时监控
watch -n 10 'tail -20 checkpoint/NeurX-1.3/rank_0.log | grep trainer-v2'

# 终端3: GPU监控
watch -n 1 'nvidia-smi'
```

---

## 💡 为什么这么慢?

### 分析原理

**1T参数模型需要的显存** (估算):
```
模型权重 (BF16):      1T params * 2 bytes = 2TB
梯度:                2TB (同样大小)
优化器状态(AdamW):    2TB * 2 (m, v) = 4TB
激活值:               ~200GB (batch=4096, seq=256)
总计:                ~8.2TB ❌❌❌
```

**RTX 4060 Ti可用: 16GB**

所以系统必须:
- ✗ 激活值写到磁盘 (随机I/O很慢)
- ✗ 梯度在CPU和GPU间传输 (PCIe 3.0瓶颈)
- ✗ 模型权重部分在CPU内存 (显存交换)
- ✗ 频繁重计算激活值 (CPU时间被占用)

**结果**: 每个step的实际操作时间远大于计算时间

### 最优配置对比

**1.5B模型显存需求**:
```
模型权重:        1.5B * 2B = 3GB
梯度:            3GB
优化器状态:      6GB
激活值:          2GB
总计:            14GB ✓ 可行
```

**显存利用效率**:
- 1T模型: 16GB中99%用于I/O等待
- 1.5B模型: 16GB中99%用于实际计算

---

## 📋 检查清单

- [ ] 确认当前速度 (tokens/sec)
- [ ] 选择优化方案 (方案1推荐)
- [ ] 备份checkpoint
- [ ] 修改配置
- [ ] 重启训练
- [ ] 监控新速度
- [ ] 计算预期完成时间

---

## 常见问题

**Q: 能继续用1T配置吗?**
A: 可以但强烈不推荐。需要至少32个GPU或进行大量量化。

**Q: 从1.5B改为7B行吗?**
A: 可以,但显存用量14-15GB,性能会降到100-200 tokens/sec。

**Q: 能用混合精度加速?**
A: BF16已内置,不会有额外加速。FP8需要特殊硬件支持。

**Q: 为什么不用LoRA?**
A: 这是预训练,不是微调。LoRA不适用。

---

## 下一步

1. **立即**: 使用方案1 (优化配置) - 10-100倍提升
2. **可选**: 添加多卡支持以扩展到1T
3. **长期**: 升级GPU或使用云计算

性能应该立即从 2.5 tokens/step 提升到 256-512 tokens/step! 🚀
