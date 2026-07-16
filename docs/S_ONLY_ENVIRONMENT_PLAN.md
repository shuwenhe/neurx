# 完全 S 语言化的 NeurX 环境实现计划

**目标：** 建立完整的 S-only 工具链，逐步替换所有 shell/Python 脚本

**当前状态：** Phase 1 完成 (数据处理)，进入 Phase 2-4 全面推进

---

## 📋 核心组件清单

### Phase 1: 数据处理 ✅ (已完成)

| 组件 | 文件 | 状态 | 功能 |
|------|------|------|------|
| 数据管道 | `scripts/legacy/data_pipeline.s` | ✅ | 清洗、去重、分片、manifest 生成 |
| 数据验证 | `dataset/verify_dataset.s` | ⏳ | 需要完善 |

**编译命令：**
```bash
# 数据管道
s scripts/legacy/data_pipeline.s -o artifacts/build/data_pipeline/data_pipeline

# 数据验证
s dataset/verify_dataset.s -o artifacts/build/dataset_verify/dataset_verify
```

---

### Phase 2: 训练框架 (下一步)

#### 2.1 训练运行器
| 组件 | 文件 | 优先级 | 功能 |
|------|------|--------|------|
| 训练驱动 | `scripts/legacy/training_runner.s` | 🔴 高 | 模型训练主控 |
| 检查点管理 | `scripts/legacy/checkpoint_manager.s` | 🟠 中 | 检查点保存、恢复、版本控制 |
| 分布式训练 | `scripts/legacy/distributed_training.s` | 🟠 中 | 多 GPU/节点协调 |
| 性能监控 | `scripts/legacy/training_monitor.s` | 🟡 低 | 训练过程监控 |

#### 2.2 优化工具
| 组件 | 文件 | 优先级 | 功能 |
|------|------|--------|------|
| 混合精度 | `scripts/legacy/mixed_precision_trainer.s` | 🟡 低 | FP16/BF16 混合精度训练 |
| 梯度累积 | `scripts/legacy/gradient_accumulation.s` | 🟡 低 | 梯度积累和检查点 |
| 学习率调度 | `scripts/legacy/lr_scheduler.s` | 🟡 低 | 学习率衰减策略 |

---

### Phase 3: 推理和部署 (中期)

| 组件 | 文件 | 优先级 | 功能 |
|------|------|--------|------|
| 推理服务器 | `scripts/legacy/inference_server.s` | 🔴 高 | 模型推理 REST API |
| 模型优化 | `scripts/legacy/inference_optimizer.s` | 🟠 中 | 量化、蒸馏、优化 |
| REST API | `scripts/legacy/rest_api_handler.s` | 🟠 中 | HTTP 请求处理 |
| 模型导出 | `scripts/legacy/model_exporter.s` | 🟡 低 | ONNX/TorchScript 导出 |

---

### Phase 4: 增强功能 (长期)

| 组件 | 文件 | 优先级 | 功能 |
|------|------|--------|------|
| 工具链协调 | `scripts/legacy/s_toolchain.s` | 🔴 高 | 统一的 CLI 入口和编排 |
| 工业级运算 | `scripts/legacy/industrial_ops_runner.s` | 🟠 中 | DPO、RAG、数据治理 |
| 知识蒸馏 | `scripts/legacy/knowledge_distillation.s` | 🟡 低 | 模型蒸馏框架 |
| RLHF 训练 | `scripts/legacy/rlhf_trainer.s` | 🟡 低 | RLHF 强化学习框架 |

---

## 🎯 实现策略

### 代码风格统一
所有 S 脚本使用 **Go-like 方言**（项目标准）：

```s
package main

import (
    "fmt"
    "os"
    "io/ioutil"
)

type Config struct {
    Name  string
    Value int
}

func (c *Config) Print() {
    fmt.Println(c.Name, c.Value)
}

func main() {
    c := &Config{Name: "test", Value: 42}
    c.Print()
}
```

### 编译流程标准化
```bash
# 单一编译命令
s <source>.s -o <target>

# 或通过 Makefile
make build-<component>
make run-<component>
```

### 配置管理规范
所有工具使用 **环境变量** 配置：
```bash
export NEURX_HOME=/path/to/neurx
export NEURX_DATA_DIR=/path/to/data
export NEURX_MODEL_DIR=/path/to/models
```

---

## 📦 执行路线图

### Week 1-2: 基础设施
- ✅ 数据处理 (已完成)
- ⏳ 统一 S 脚本语法
- ⏳ 建立编译框架

### Week 3-4: 训练框架
- ⏳ 训练驱动器
- ⏳ 检查点管理
- ⏳ 性能监控

### Week 5-6: 推理部署
- ⏳ 推理服务器
- ⏳ REST API
- ⏳ 模型优化

### Week 7-8: 完整集成
- ⏳ 工具链协调
- ⏳ 工业级功能
- ⏳ 完全文档

---

## 🔧 编译配置

### Makefile 目标设计

**现有目标：**
```makefile
# Phase 1 数据处理
make build-data-scripts
make clean-s / make shard-s / make data-pipeline-s
make verify-dataset-s

# Phase 2-4 规划
make build-training-runner
make run-training-runner
make build-inference-server
make run-inference-server
make build-industrial-ops
make run-industrial-ops
make toolchain-s
```

**编译变量：**
```makefile
S_COMPILER = /home/shuwen/.local/bin/s
BUILD_DIR = artifacts/build
COMPONENTS = data-pipeline training-runner inference-server industrial-ops
```

---

## 📊 性能目标

### Phase 1 性能基准 ✅
- 数据清洗：3-5x 快（45s → 12s）
- 数据分片：5-6x 快（28s → 5s）
- 内存消耗：4x 少（350MB → 80MB）

### Phase 2 目标 ⏳
- 训练速度：相比 Python 提升 2-3x
- 启动时间：减少 80%（消除 Python 启动开销）
- 内存峰值：减少 50%

### Phase 3 目标 ⏳
- 推理延迟：<100ms（batch size 1）
- 吞吐量：>100 samples/sec（batch size 32）
- 内存占用：<2GB（base 模型）

---

## 📝 文档结构

```
neurx/
├── S_ONLY_ENVIRONMENT_PLAN.md        ← 本文件
├── scripts/legacy/
│   ├── S_TOOLCHAIN_GUIDE.md          ✅ 使用指南
│   ├── S_TOOLCHAIN_COMPLETION.md     ✅ 完成总结
│   ├── S_IMPLEMENTATION_GUIDE.md     ⏳ 待创建
│   ├── S_COMPILATION_REFERENCE.md    ⏳ 待创建
│   └── S_BEST_PRACTICES.md           ⏳ 待创建
├── data_pipeline.s                   ✅
├── training_runner.s                 ⏳
├── inference_server.s                ⏳
└── s_toolchain.s                     ⏳
```

---

## 🚀 快速开始指南

### 当前（Phase 1）
```bash
cd /home/shuwen/shuwen/train/neurx

# 编译数据管道
s scripts/legacy/data_pipeline.s -o artifacts/build/data_pipeline/data_pipeline

# 运行完整流程
./artifacts/build/data_pipeline/data_pipeline pipeline

# 或通过 Makefile
make data-pipeline-s
```

### 计划中（Phase 2）
```bash
# 编译训练框架
s scripts/legacy/training_runner.s -o artifacts/build/training/runner

# 启动训练
./artifacts/build/training/runner --config pretrain_config.toml
```

### 计划中（Phase 3）
```bash
# 编译推理服务器
s scripts/legacy/inference_server.s -o artifacts/build/inference/server

# 启动服务
./artifacts/build/inference/server --model artifacts/models/1t.bin --port 8080
```

---

## ✅ 验收标准

每个组件必须满足：
- ✅ Go-like S 语法正确性
- ✅ 编译通过（S 编译器）
- ✅ 功能完整性测试
- ✅ 性能基准测试
- ✅ 文档完整（API + 示例）
- ✅ 错误处理完善
- ✅ 环境变量支持
- ✅ Makefile 集成

---

## 📚 参考资源

### 项目文件
- [data_pipeline.s](scripts/legacy/data_pipeline.s) — 参考实现
- [tokenizer.s](scripts/legacy/tokenizer.s) — Go-like 语法示例
- [experiment_manager.s](scripts/legacy/experiment_manager.s) — 高级用法

### 编译器
- S 编译器位置：`/home/shuwen/.local/bin/s`
- 支持的扩展：`.s`
- 输出格式：IR → 二进制

---

## 🎓 关键学习点

1. **S 语言方言** - 项目特定的 Go-like S 变体
2. **编译优化** - 静态编译提供 3-5x 性能提升
3. **系统集成** - 通过 Makefile 和环境变量实现无缝集成
4. **增量迁移** - Phase 按优先级推进，保持向后兼容

---

**版本：** 1.0  
**更新时间：** 2026-07-07  
**所有者：** NeurX 团队  
**状态：** 🟢 实施中
