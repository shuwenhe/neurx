# NeurX Launcher (S Language 版本)

## 文件说明

### 1. 原Shell脚本（已修复）
**文件**: `scripts/legacy/launch_multinode_pretrain.sh`

**修复内容**: 修复了单节点训练时的checkpoint路径问题
```bash
# 修复前: 总是添加rank后缀，导致checkpoint找不到
NEURX_PRETRAIN_RESUME_FROM=$OUT/rank_${rank}/transformer_v2.ckpt

# 修复后: 单节点时不添加rank后缀
if (( ${#HOSTS[@]} == 1 )); then
  ckpt_path="$OUT/transformer_v2.ckpt"
else
  ckpt_path="$OUT/rank_${rank}/transformer_v2.ckpt"
fi
```

---

### 2. S语言启动器框架
**文件**: `scripts/legacy/launch_multinode_pretrain.s`

**功能**:
- 读取和解析hostfile
- 配置管理和验证
- 环境变量构建
- 进程启动协调

**特点**:
- 类型安全的配置结构
- 模块化设计
- 易于扩展和维护

**编译和运行**:
```bash
# 编译
cd /home/shuwen/shuwen/train/neurx
s compile scripts/legacy/launch_multinode_pretrain.s -o artifacts/build/launcher

# 运行
./artifacts/build/launcher
```

---

### 3. S语言脚本生成器（推荐）
**文件**: `scripts/legacy/generate_launcher.s`

**功能**:
- 从环境变量读取配置
- 验证配置参数
- 生成优化的shell脚本
- 自动计算world_size

**特点**:
- 配置即代码
- 自动验证参数
- 生成高效的shell脚本

**使用流程**:
```bash
# 1. 编译生成器
cd /home/shuwen/shuwen/train/neurx
s compile scripts/legacy/generate_launcher.s -o artifacts/build/generate_launcher

# 2. 生成脚本
NEURX_ROOT=$(pwd) ./artifacts/build/generate_launcher

# 3. 执行生成的脚本
bash scripts/legacy/launch_multinode_pretrain_generated.sh
```

---

## 快速启动（修复后）

### 单节点训练（推荐方式）
```bash
cd /home/shuwen/shuwen/train/neurx

# 方式1: 使用原修复后的shell脚本
make pretrain-gpu

# 方式2: 直接执行
bash scripts/legacy/launch_multinode_pretrain.sh
```

**输出应该显示断点续训**:
```
[trainer-v2] rank=0 world_size=1 local_rank=0 shards=5131 checkpoint=/home/shuwen/shuwen/train/neurx/checkpoint/NeurX-1.3
[checkpoint] restored v2 step=360 shard=0 line=2 micro=0  ← 断点续训成功！
[trainer-v2] tokenizer=bpe vocab=374 layers=24 seq=256 dim=1024 heads=16 ffn=4096 micro_batch=1 grad_accum=8 effective_sequences=8
[trainer-v2] step=360/1000000000 optimizer_step=45 loss=12.482535 tokens=92160 shard=0 line=2 accum=0/8  ← 从360步继续
```

### 多节点训练
```bash
# 创建hostfile
cat > configs/pretrain.hosts << 'EOF'
node1 8
node2 8
node3 8
EOF

# 启动训练
NEURX_HOSTFILE=$(pwd)/configs/pretrain.hosts bash scripts/legacy/launch_multinode_pretrain.sh
```

---

## 环境变量配置

### 必需参数
```bash
NEURX_ROOT                      # NeurX项目根目录
NEURX_HOSTFILE                  # Hostfile路径
NEURX_PRETRAIN_OUTPUT_DIR       # Checkpoint保存目录
```

### 可选参数（带默认值）
```bash
# 训练配置
NEURX_PRETRAIN_STEPS=1000000000
NEURX_PRETRAIN_MICRO_BATCH=1
NEURX_PRETRAIN_SEQ_LEN=256
NEURX_PRETRAIN_LR=0.0002
NEURX_PRETRAIN_LOG_INTERVAL=10
NEURX_PRETRAIN_SAVE_INTERVAL=100

# 模型配置
NEURX_TRANSFORMER_DIM=1024
NEURX_TRANSFORMER_HEADS=16
NEURX_TRANSFORMER_FFN=4096
NEURX_TRANSFORMER_NUM_LAYERS=24
NEURX_GRADIENT_ACCUMULATION_STEPS=8

# Tokenizer
NEURX_TOKENIZER_VOCAB=${NEURX_ROOT}/data/corpus/vocab.json
NEURX_TOKENIZER_MERGES=${NEURX_ROOT}/data/corpus/merges.txt

# 分布式
MASTER_ADDR=localhost
MASTER_PORT=29500
```

---

## 关键修复验证

### 检查Checkpoint文件
```bash
# 单节点checkpoint位置
ls -lh checkpoint/NeurX-1.3/transformer_v2.ckpt

# 多节点checkpoint位置
ls -lh checkpoint/NeurX-1.3/rank_0/transformer_v2.ckpt
ls -lh checkpoint/NeurX-1.3/rank_1/transformer_v2.ckpt
```

### 检查环境变量
```bash
# 获取实际的NEURX_PRETRAIN_RESUME_FROM值
echo $NEURX_PRETRAIN_RESUME_FROM

# 或从启动脚本中提取
grep "NEURX_PRETRAIN_RESUME_FROM" scripts/legacy/launch_multinode_pretrain.sh
```

### 监控训练日志
```bash
# 单节点
tail -f checkpoint/NeurX-1.3/rank_0.log | grep -E "(checkpoint|trainer-v2|step=)"

# 多节点
tail -f checkpoint/NeurX-1.3/rank_*/rank_*.log
```

---

## 架构对比

| 特性 | Shell脚本 | S语言直接 | S生成器 |
|------|---------|---------|--------|
| 易读性 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 类型安全 | ❌ | ✅ | ✅ |
| 参数验证 | 手动 | 自动 | 自动 |
| 执行效率 | 最快 | 有开销 | 最快 |
| 调试难度 | 中 | 低 | 低 |
| 扩展性 | 低 | 高 | 高 |

---

## 故障排除

### 问题1: 断点续训不工作（step=1）

**症状**:
```
[trainer-v2] step=1/1000000000 ...  ← 从step=1开始，不是断点续训
```

**原因**: Checkpoint路径不匹配

**解决**:
```bash
# 检查checkpoint文件是否存在
ls -lh checkpoint/NeurX-1.3/transformer_v2.ckpt

# 检查launcher脚本中的NEURX_PRETRAIN_RESUME_FROM
grep "ckpt_path" scripts/legacy/launch_multinode_pretrain.sh

# 确保不添加rank后缀
# ✅ 正确: $OUT/transformer_v2.ckpt
# ❌ 错误: $OUT/rank_0/transformer_v2.ckpt
```

### 问题2: NCCL初始化超时

**症状**:
```
[multinode] shared NCCL id: /path/to/unique_id
# 等待超过60秒...
```

**解决**:
```bash
# 检查NCCL ID文件权限
ls -l artifacts/nccl/unique_id

# 手动清理
rm -f artifacts/nccl/unique_id*

# 重启训练
make pretrain-gpu
```

### 问题3: GPU显存不足

**症状**:
```
CUDA error: out of memory
```

**解决**:
```bash
# 减少micro_batch或seq_len
NEURX_PRETRAIN_MICRO_BATCH=1 \
NEURX_PRETRAIN_SEQ_LEN=128 \
make pretrain-gpu
```

---

## 性能优化建议

1. **单节点多GPU**: 使用 `scripts/legacy/launch_multinode_pretrain.sh`，world_size自动设置
2. **多节点**: 使用低延迟网络（InfiniBand）和设置 `NCCL_SOCKET_IFNAME`
3. **大模型**: 启用混合精度：`NEURX_MIXED_PRECISION=bf16`
4. **数据加载**: 使用SSD存储shards，开启异步数据加载

---

## S语言脚本优势总结

| 方面 | Shell | S语言 |
|------|-------|-------|
| **类型检查** | ❌ | ✅ 编译时检查 |
| **参数验证** | 手动脚本 | 自动化 |
| **配置管理** | 散乱 | 结构化 |
| **错误处理** | try-catch难 | 原生异常 |
| **性能** | 高 | 与C相当 |
| **可维护性** | 低 | 高 |

推荐使用 **S生成器方案**：在S中管理复杂逻辑，生成优化的shell脚本执行。
