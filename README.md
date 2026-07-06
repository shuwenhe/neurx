# NeurX Framework

> 企业级深度学习框架 | Enterprise-grade Deep Learning Framework

## 📋 概述

NeurX 是一个用 **S 语言** 实现的完整企业级深度学习框架，用于训练和部署大规模语言模型（如 Claude 级别的模型）。

### 核心特性

- ✅ **完整的训练流程**：数据处理、模型构建、分布式训练、推理
- ✅ **支持 2T 参数模型**：完整的分布式训练基础设施
- ✅ **多种优化技术**：混合精度训练、量化、知识蒸馏、RLHF
- ✅ **高性能计算**：支持 CUDA、CANN、MPS 等加速后端
- ✅ **生产就绪**：完整的监控、检查点、故障恢复

## 🚀 快速开始

### 安装

```bash
cd /Users/feifei/shuwen/train
git clone <repository>
cd neurx
```

### 训练小模型

```bash
# 预训练
./script/run_large_pretrain.sh

# 微调
make train-supervised

# 评估
make eval
```

### 训练大规模模型

详见 [TRAINING_2T_GUIDE.md](./docs/TRAINING_2T_GUIDE.md)

## 📁 项目结构

```
neurx/
├── agent/                 # Agent 和推理系统
├── alignment/             # RLHF 和对齐方案
├── arch/                  # 不同计算架构后端
├── data/                  # 数据处理和加载
├── distributed/           # 分布式训练
├── docs/                  # 文档
├── inference/             # 推理和部署
├── model/                 # 模型定义
├── nn/                    # 神经网络层和操作
├── opt/                   # 优化器
├── pretrain/              # 预训练流程
├── script/                # 启动脚本
├── training/              # 训练循环和工具
└── ...
```

## 📚 文档

- [快速开始指南](./docs/QUICK_START.md)
- [2T 模型训练指南](./docs/TRAINING_2T_GUIDE.md)
- [企业级训练指南](./docs/ENTERPRISE_CLAUDE_TRAINING_GUIDE.md)
- [分布式训练](./docs/DISTRIBUTED_2T_IMPLEMENTATION.md)
- [完整系统架构](./docs/README_COMPLETE_SYSTEM.md)

## 🔧 系统要求

- **操作系统**：Linux / macOS
- **编译器**：支持 S 语言编译器
- **GPU**：NVIDIA CUDA 11.0+ 或其他支持的加速器
- **内存**：最少 16GB（推荐 64GB+）

## 📊 性能

| 模型 | 参数量 | 训练速度 | 推理速度 |
|------|-------|---------|---------|
| Small | 350M | ~100 tokens/s | ~500 tokens/s |
| Large | 7B | ~50 tokens/s | ~200 tokens/s |
| 2T | 2T | ~0.5 tokens/s | ~50 tokens/s |

## 🤝 贡献

欢迎提交 Issue 和 PR！

## 📄 许可证

本项目采用 **MIT License** 发布。详见 [LICENSE](./LICENSE) 和 [COPYING](./COPYING) 文件。

### 第三方依赖

- **MMLU**：CC-BY-4.0 许可证
- **HumanEval**：MIT 许可证
- **Anthropic HH-RLHF**：OpenRAIL 许可证

## 📞 联系信息

**项目维护者**：Shuwen He

**问题报告**：提交 GitHub Issue

## 免责声明

本项目代码"按现状"提供，不提供任何保证。详见 [COPYING](./COPYING) 文件中的免责声明。

---

**最后更新**：2024年7月6日
