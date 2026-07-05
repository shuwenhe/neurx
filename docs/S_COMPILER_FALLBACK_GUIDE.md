# S 编译器回退机制指南

## 📋 问题描述

在本地开发环境中，S 编译器通常不可用（它仅在生产集群上的 `/opt/s/bin/s` 存在）。之前的脚本在 1T 模式下 S 编译器不可用时会硬性失败，而不是优雅地回退到演示模式。

## ✅ 解决方案

已更新 `script/run_gpt_large_pretrain.sh` 以支持灵活的回退机制：

### 默认行为（保持向后兼容）
```bash
./script/run_gpt_large_pretrain.sh --model 1t
# 结果: S 编译器不可用时失败，并提示：
# ✗ S编译器不可用（1T 模式不回退到演示）
# 💡 提示: 设置 NEURX_ALLOW_DEMO=1 来启用演示模式回退
```

### 启用 1T 模式演示回退
```bash
NEURX_ALLOW_DEMO=1 ./script/run_gpt_large_pretrain.sh --model 1t
# 结果: S 编译器不可用时会优雅地回退到演示模式
# ⚠ S编译器不可用，1T 模式将以演示模式运行
#   (这仅用于本地开发测试，完整训练需要 S 编译器)
```

`NEURX_ALLOW_FULL_1T_LOCAL=1` 也会启用同样的回退逻辑，和 `NEURX_ALLOW_DEMO=1` 等价。

### 其他模型的行为（不受影响）
```bash
./script/run_gpt_large_pretrain.sh --model gpt-large
# 结果: S 编译器不可用时总是回退到演示模式（原有行为保持不变）
```

## 📊 回退机制流程

```
训练脚本启动
  ↓
尝试编译 S 源代码
  ↓
[编译成功]  →  执行训练程序
  
[编译失败]  →  检查模型类型
  ├─ 1T 模式且 NEURX_ALLOW_DEMO ≠ 1  →  硬性失败 + 提示信息
  ├─ 1T 模式且 NEURX_ALLOW_DEMO = 1   →  回退到演示模式
  └─ 其他模型                         →  回退到演示模式
```

## 🔧 改进详情

### 1. 改进编译错误消息
```bash
# 之前:
⚠ S编译器不可用

# 之后:
⚠ S编译器不可用
   位置: /Users/feifei/shuwen/train/s/.local/bin/s
   说明: 本地开发环境不需要 S 编译器，集群部署时会自动使用
```

### 2. 改进集群编排处理
```bash
# 之前:
✗ S编译器不可用，无法执行集群编排  (返回失败)

# 之后:
⚠ S编译器不可用，将生成集群配置但跳过编译
   (允许生成配置文件用于后续部署)
```

### 3. 改进回退决策逻辑
```bash
# 之前:
if [ "$MODEL_SIZE" = "1t" ]; then
    echo "✗ (1T 模式不回退到演示)"
    return 1
fi

# 之后:
if [ "$MODEL_SIZE" = "1t" ] && [ "${NEURX_ALLOW_DEMO:-0}" != "1" ]; then
    echo "✗ (1T 模式不回退到演示)"
    echo "💡 提示: 设置 NEURX_ALLOW_DEMO=1 来启用演示模式回退"
    return 1
fi

if [ "$MODEL_SIZE" = "1t" ] && [ "${NEURX_ALLOW_DEMO:-0}" = "1" ]; then
    echo "⚠ (1T 模式将以演示模式运行)"
fi
```

## 🎯 使用场景

### 场景 1: 本地开发和测试（不需要编译）
```bash
# 启用演示模式测试 1T 模型配置
NEURX_ALLOW_DEMO=1 make train
```

### 场景 2: 本地验证框架（但要求编译）
```bash
# 使用 gpt-large 模型进行本地验证（默认回退到演示）
./script/run_gpt_large_pretrain.sh --model gpt-large
```

### 场景 3: 集群部署（完整编译和训练）
```bash
# 在集群上执行，S 编译器可用
sbatch script/submit_training_job.sh
```

### 场景 4: 集群配置生成（不编译）
```bash
# 仅生成集群配置，跳过编译
NEURX_CLUSTER_CONFIG_ONLY=1 ./script/run_gpt_large_pretrain.sh --model 1t
```

## 🚀 演示模式能力

即使在演示模式运行 1T 模型，您也可以：
- ✓ 查看完整的模型配置
- ✓ 验证 4D 并行参数
- ✓ 测试数据加载逻辑
- ✓ 生成检查点文件
- ✓ 生成集群配置
- ✓ 验证框架结构完整性

但不能：
- ✗ 执行实际的 S 代码编译
- ✗ 运行真实的训练循环（仅模拟）
- ✗ 验证 GPU 计算正确性

## ⚙️ 环境变量参考

| 变量 | 值 | 说明 |
|------|-----|------|
| `NEURX_ALLOW_DEMO` | `1` | 允许所有模型在 S 编译器不可用时回退到演示模式 |
| `NEURX_ALLOW_FULL_1T_LOCAL` | `1` | 允许 1T 本地运行时在 S 编译器不可用时回退到演示模式 |
| `S_COMPILER` | 路径 | S 编译器位置（默认: `$NEURX_ROOT/../s/.local/bin/s`) |
| `NEURX_CLUSTER_DISABLE` | `1` | 禁用集群编排功能 |
| `MODEL_SIZE` | `1t`, `gpt-large` | 模型大小 |
| `NEURX_CLUSTER_CONFIG_ONLY` | `1` | 仅生成集群配置，不执行训练 |

## 📝 日志示例

### 启用回退的日志输出
```
════════════════════════════════════════════════════════════════
🚀 NeurX neurx-1t-moe 预训练系统 (S语言实现)
════════════════════════════════════════════════════════════════

▶ 尝试编译 S 源文件...
⚠ S编译器不可用
   位置: /Users/feifei/shuwen/train/s/.local/bin/s
   说明: 本地开发环境不需要 S 编译器，集群部署时会自动使用

⚠ S编译器不可用，1T 模式将以演示模式运行
   (这仅用于本地开发测试，完整训练需要 S 编译器)

════════════════════════════════════════════════════════════════
运行neurx-1t-moe预训练演示 (S Language实现)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
模型配置 (neurx-1t-moe)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  架构:              decoder-only-transformer-moe
  词汇表大小:        128000
  隐层维度:          12288
  Transformer块:     80
  注意力头:          96
  FFN中间层:         49152
  最大序列长度:      32768
  MoE专家数:         256 / layer
  Top-K路由:         2

✅ neurx-1t-moe预训练流程完成
```

## 🔗 相关文件

- `script/run_gpt_large_pretrain.sh` - 主训练脚本（已改进）
- `script/verify_framework.sh` - 框架验证脚本
- `Makefile` - 构建系统

## 💡 故障排除

### Q: 我想在本地运行 1T 模型演示
A: 设置 `NEURX_ALLOW_DEMO=1` 环境变量：
```bash
NEURX_ALLOW_DEMO=1 make train
```
也可以使用 `NEURX_ALLOW_FULL_1T_LOCAL=1 make train`，效果相同。

### Q: 我想要 1T 模式在 S 编译器不可用时失败
A: 不设置 `NEURX_ALLOW_DEMO` 或设置为 `0`（默认行为）：
```bash
make train  # 默认行为：失败并提示
```

### Q: 我如何知道是否运行的是演示模式
A: 查看日志输出中的以下指标：
```
⚠ S编译器不可用，1T 模式将以演示模式运行
```

### Q: 演示模式和实际训练有什么区别
A: 
- **演示模式**: 模拟训练流程，显示配置和模拟结果，不执行真实计算
- **实际训练**: 编译 S 代码，在 GPU 上执行真实训练

## 🎓 最佳实践

1. **本地开发**：使用 `NEURX_ALLOW_DEMO=1` 快速验证
2. **集群部署**：确保 S 编译器可用，让脚本自动编译
3. **CI/CD 验证**：使用 `NEURX_ALLOW_DEMO=1` 进行快速健全性检查
4. **生产训练**：在真实集群上运行，使用完整编译

---

**更新日期**: 2026-07-02
**脚本版本**: v2.1
**支持的模型**: gpt-large, 1t-moe
