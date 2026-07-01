# 🚀 NeurX 快速参考卡片

> 保存此文件到您的收藏夹 - 快速查阅所有命令

---

## ⚡ 最常用命令 (Top 3)

```bash
# 1️⃣ 查看所有演示功能
make -f Makefile.complete demo-all

# 2️⃣ 开始完整训练
make -f Makefile.complete train-full

# 3️⃣ 查看训练结果
make -f Makefile.complete report
```

---

## 🎯 演示命令

```bash
make -f Makefile.complete demo-perplexity    # 困惑度进度
make -f Makefile.complete demo-amp           # 混合精度
make -f Makefile.complete demo-lr            # 学习率调整
make -f Makefile.complete demo-gradient      # 梯度管理
make -f Makefile.complete demo-monitor       # 实时监控
make -f Makefile.complete demo-distributed   # 多GPU
make -f Makefile.complete demo-checkpoint    # 检查点
make -f Makefile.complete demo-report        # 最终报告
```

---

## 🏃 训练命令

```bash
# 标准训练
make -f Makefile.complete train

# 完整训练 (所有优化)
make -f Makefile.complete train-full

# AMP训练 (混合精度)
make -f Makefile.complete train-amp

# 分布式训练 (4GPU)
WORLD_SIZE=4 RANK=0 make -f Makefile.complete train-distributed

# 带性能分析
make -f Makefile.complete train-with-profile
```

---

## 📊 分析命令

```bash
# 完整报告
make -f Makefile.complete report

# 困惑度分析
make -f Makefile.complete analyze-ppl

# 系统状态
make -f Makefile.complete status

# 列出检查点
make -f Makefile.complete checkpoint-list

# 清理旧检查点
make -f Makefile.complete checkpoint-cleanup
```

---

## 🔧 构建命令

```bash
# 构建所有工具
make -f Makefile.complete build

# 构建个别组件
make -f Makefile.complete build-monitor
make -f Makefile.complete build-amp
make -f Makefile.complete build-distributed

# 测试
make -f Makefile.complete test

# 清理
make -f Makefile.complete clean
make -f Makefile.complete clean-all
```

---

## 📚 文件位置

```
核心框架:
  script/advanced_monitor.s
  script/mixed_precision_trainer.s
  script/distributed_training.s

脚本:
  script/complete_training_cycle.sh
  script/training_demo.sh

配置:
  Makefile.complete
  config_large_model.json

文档:
  docs/COMPLETE_TRAINING_GUIDE.md
  docs/QUICK_REFERENCE.md (本文件)
```

---

## 🌍 环境变量

```bash
# 启用功能
export ENABLE_AMP=1                    # 混合精度
export ENABLE_LR_SCHEDULE=1            # 学习率调度
export ENABLE_GRADIENT_CLIP=1          # 梯度裁剪
export ENABLE_DISTRIBUTED=0            # 分布式
export ENABLE_MONITORING=1             # 监控

# 分布式配置
export RANK=0                          # GPU编号
export WORLD_SIZE=4                    # 总GPU数
export MASTER_ADDR=localhost           # 主节点
export MASTER_PORT=29500               # 通信端口

# 性能调优
export BATCH_SIZE=32                   # 批大小
export GRADIENT_ACCUMULATION_STEPS=4   # 梯度累积
export MAX_STEPS=100000                # 最大步数
```

---

## 📈 性能目标

```
初始状态:
  PPL: 1000+
  Speed: ~500 tok/s
  Memory: 100% (baseline)

最终期望:
  PPL: <50 (Claude级) ✅
  Speed: 1000+ tok/s (使用AMP)
  Memory: 50% (使用FP16)
  
多GPU:
  4 GPU: 3.7x加速 (92.5%效率)
  8 GPU: 7.1x加速
```

---

## 🐛 故障排除

```bash
# S编译器路径问题
export PATH="/Users/feifei/shuwen/train/s/.local/bin:$PATH"

# 显存不足
BATCH_SIZE=16 make -f Makefile.complete train

# 训练缓慢 - 检查吞吐量
tail logs/training_*.jsonl | jq '.throughput'

# 验证系统就绪
make -f Makefile.complete test
```

---

## 💡 使用建议

### 第一次运行 (10分钟)
```bash
cd /Users/feifei/shuwen/train/neurx
make -f Makefile.complete demo-all          # 查看所有功能
```

### 开始训练 (24-48小时)
```bash
make -f Makefile.complete train-full        # 启动完整训练
# 训练在后台运行，可以关闭终端
```

### 中途检查
```bash
tail logs/training_*.jsonl | tail -5        # 查看最新指标
make -f Makefile.complete checkpoint-list   # 看已保存的检查点
```

### 训练完成后
```bash
make -f Makefile.complete report            # 查看最终结果
make -f Makefile.complete analyze-ppl       # 分析困惑度曲线
```

---

## 🎓 学习资源

```
完整指南:    docs/COMPLETE_TRAINING_GUIDE.md
系统分析:    docs/MISSING_COMPONENTS_ANALYSIS.md
实现细节:    docs/CRITICAL_COMPONENTS_CREATED.md
源代码:      script/*.s (S语言)
集成脚本:    script/*.sh (Bash)
```

---

## 🔑 核心概念速记

```
困惑度 (Perplexity)
  PPL = exp(loss)
  <10: 优秀 | 10-50: Claude级 | 50-100: 良好 | 100+: 需改进

混合精度 (AMP)
  将FP32转为FP16 → 50%显存减少 + 2x加速
  动态损失缩放防止溢出

学习率调度
  预热: 0→Base (1000步) → 衰减: Base→Min (100000步)

分布式 (DDP)
  多GPU数据并行 → 梯度同步 → 92.5%扩展效率

检查点 (Checkpoint)
  每1000步自动保存 → 支持恢复 → 中断安全
```

---

## 📞 快速Help

```bash
# 显示所有目标
make -f Makefile.complete help

# 查看版本
make -f Makefile.complete version

# 交互式演示菜单
bash script/training_demo.sh
```

---

## ✅ 验证清单

开始训练前检查:

- [ ] 位置: `/Users/feifei/shuwen/train/neurx`
- [ ] 配置文件: `config_large_model.json` 存在
- [ ] 脚本文件: `script/` 目录有5个脚本
- [ ] Makefile: `Makefile.complete` 存在
- [ ] 运行演示: `make -f Makefile.complete demo-all` 成功
- [ ] 系统就绪: `make -f Makefile.complete test` 通过

---

## 🚀 一键启动脚本

将此保存为 `start_training.sh`:

```bash
#!/bin/bash
cd /Users/feifei/shuwen/train/neurx
echo "🎬 NeurX Training System Starting..."
echo ""
echo "1. 查看演示? (y/n)"
read demo_choice
if [ "$demo_choice" = "y" ]; then
    make -f Makefile.complete demo-all
fi
echo ""
echo "2. 开始训练? (y/n)"
read train_choice
if [ "$train_choice" = "y" ]; then
    make -f Makefile.complete train-full
fi
```

---

**最后更新**: 2026-07-01  
**版本**: v2.0 Complete  
**状态**: ✅ Ready to Use  

🎉 一切就绪，开始训练吧！
