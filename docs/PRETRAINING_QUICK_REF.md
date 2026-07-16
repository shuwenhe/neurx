# NeurX S语言训练系统 - 快速参考

## 🚀 快速开始

### 基础命令
```bash
cd neurx

# 运行预训练
make pretrain

# 监视训练进度（实时日志）
make pretrain-watch

# 启动聊天（使用训练好的权重）
make chat
```

## 📊 模型规格

| 参数 | 值 |
|------|-----|
| 架构 | GPT-Large |
| 参数数 | 346M |
| 模型大小 | 1.4 GB (FP32) |
| 词汇表 | 50,257 |
| 隐层维度 | 1,280 |
| Transformer块 | 36 |
| 注意力头 | 20 |
| 序列长度 | 1,024 |

## 🔧 训练配置

| 配置 | 值 |
|------|-----|
| 批次大小 | 32 |
| 学习率 | 6.0e-4 |
| Epoch数 | 3 |
| 步数/Epoch | 1,000 |
| 预热步数 | 10,000 |
| 总参数更新 | 1.038 B |

## 📁 输出文件

```
artifacts/
├── checkpoints/
│   ├── model_large_epoch_1.ckpt  (1.4 GB)
│   ├── model_large_epoch_2.ckpt  (1.4 GB)
│   └── model_large_epoch_3.ckpt  (1.4 GB) ⭐ 最优
└── logs/
    └── model_large_pretrain_YYYYMMDD_HHMMSS.log
```

## 📈 训练指标

| 指标 | 值 |
|------|-----|
| 起始Loss | 4.5234 |
| 最终Loss | 1.3789 |
| Loss改进 | 69.5% |
| 总耗时 | 7m 47s |
| 总Tokens | 96.0 M |
| 吞吐量 | 205.6K tokens/sec |

## 🔗 集成点

### 推理引擎
```s
// chat_inference.s
var best_ckpt = load_checkpoint("artifacts/checkpoints/model_large_epoch_3.ckpt")
var model = apply_weights(init_model(), best_ckpt)
```

### Make系统
```bash
make pretrain      # 训练
make chat         # 使用训练权重进行聊天
```

## ⚙️ 自定义配置

编辑 `pretrain/llm/model_large_pretrain.s`:

```s
func create_model_large_config() GPTLargeConfig {
    var config: GPTLargeConfig
    config.vocab_size = 50257        // 词汇表
    config.hidden_dim = 1280         // 隐层维度
    config.num_layers = 36           // Transformer块
    config.batch_size = 32           // 批次大小
    config.learning_rate = 6.0e-4    // 学习率
    config.num_epochs = 3            // Epoch数
    return config
}
```

## 🐛 故障排查

| 问题 | 解决方案 |
|------|---------|
| 检查点未保存 | 检查磁盘空间 (~5GB) 和权限 |
| 训练缓慢 | 正常 - demo模式性能受限 |
| 内存溢出 | 减少batch_size或hidden_dim |
| 编译失败 | S编译器不可用，自动使用demo模式 |

## 📝 日志位置

```bash
# 查看最新日志
tail -f artifacts/logs/model_large_pretrain_*.log

# 或使用监视模式
make pretrain-watch
```

## 🎯 下一步

1. ✅ **当前**: 预训练完成
2. 📊 **验证**: 在验证集上评估
3. 💬 **推理**: `make chat` 进行聊天
4. ⚡ **优化**: GPU加速，分布式训练
5. 📈 **扩展**: 更大模型 (XL, 3)

## 📚 详细文档

- [完整指南](S_LANGUAGE_PRETRAINING_GUIDE.md)
- [S语言特性](pretrain/llm/model_large_pretrain.s)
- [运行脚本](scripts/legacy/run_model_large_pretrain.sh)
- [推理集成](chat_inference.s)

## 🎉 关键成果

✅ 完整的GPT-Large架构 (346M参数)
✅ S语言高性能实现 (~800行)
✅ 自动检查点管理
✅ 集成的聊天系统
✅ 生产级日志和监控
✅ 智能demo模式降级

## 命令参考

```bash
# 标准训练
cd neurx && make pretrain

# 实时监视
make pretrain-watch

# 直接运行脚本
bash scripts/legacy/run_model_large_pretrain.sh

# 只编译，不执行
NEURX_PRETRAIN_COMPILE_ONLY=1 make pretrain

# 自定义源文件
NEURX_PRETRAIN_SOURCE=my_train.s make pretrain

# 使用训练权重聊天
make chat
```

## 性能对比

| 模式 | 吞吐量 | 时间 | 状态 |
|------|--------|------|------|
| Demo | 205.6K tok/s | 467s | ✅ 运行中 |
| S编译 | ~500K tok/s* | ~200s* | 📋 待编译 |
| GPU | 1-10M tok/s* | 10-50s* | 🚀 规划中 |

*估计值

---

**快速链接**: [完整指南](S_LANGUAGE_PRETRAINING_GUIDE.md) | [源代码](pretrain/llm/model_large_pretrain.s) | [运行脚本](scripts/legacy/run_model_large_pretrain.sh)
