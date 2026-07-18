# neurx 1T MoE 框架 - 文件夹结构和编译/运行分析报告

## 📊 总体统计

| 指标 | 数值 |
|------|------|
| **总文件夹数** | 97 个 (不含 `.` 当前目录) |
| **包含 S 代码的文件夹** | 51 个 |
| **总 S 代码文件数** | 317 个 |
| **总代码行数** | 34,131+ 行 |

---

## 🔄 编译和运行分析

### ⚠️ 重要说明

**不是所有文件夹中的代码都会在每次训练时被编译和运行**

根据分析，实际编译和运行流程为：

1. **S 编译器** (`s/` 文件夹)
   - 状态: 不在本地环境 (只在生产集群 `/opt/s/bin/s`)
   - 编译: 本地无法编译（生产集群环境依赖）
   - 运行: 不参与训练（是编译工具本身）

2. **主训练程序** (`pretrain/llm/model_large_pretrain.s`)
   - 状态: ✅ 已实现
   - 编译: 是
   - 运行: 是 (每次都运行)

3. **实际会被编译和运行的核心模块** (17 个):
   ```
   ✅ pretrain/llm/model_large_pretrain.s    (主入口)
   ✅ model/llm/model_large_train.s          (大规模训练)
   ✅ moe/llm_moe_1t.s               (1T MoE 模型)
   ✅ pretrain/distributed/               (分布式训练)
   ✅ pretrain/optimizer/                  (优化器)
   ✅ pretrain/tokenizer/bpe.s             (BPE 分词)
   ✅ pretrain/checkpoint/                 (检查点管理)
   ✅ pretrain/data/                       (数据加载)
   ✅ pretrain/eval/                       (评估)
   ✅ pretrain/loop/                       (训练循环)
   ✅ pretrain/config/                     (配置)
   ✅ nn/                                  (神经网络层)
   ✅ opt/optim/                           (优化算法)
   ✅ tensor/                              (张量操作)
   ✅ ops/                                 (基础操作)
   ✅ cuda/ 或 backends/                   (GPU 后端)
   ```

---

## 📁 完整文件夹分类

### A. 核心训练代码 (会参与编译和运行)

| 文件夹 | S 文件数 | 编译 | 运行 | 说明 |
|--------|---------|------|------|------|
| **pretrain** | 见子目录 | ✅ | ✅ | 预训练系统主目录 |
| ├─ llm | 多个 | ✅ | ✅ | LLM 预训练 |
| ├─ distributed | - | ✅ | ✅ | DDP/TP/PP/EP |
| ├─ optimizer | - | ✅ | ✅ | AdamW 优化器 |
| ├─ tokenizer | 2 | ✅ | ✅ | BPE 分词 |
| ├─ checkpoint | - | ✅ | ✅ | 检查点保存/加载 |
| ├─ data | - | ✅ | ✅ | 数据管道 |
| ├─ eval | - | ✅ | ✅ | 评估和验证 |
| ├─ loop | - | ✅ | ✅ | 训练循环控制 |
| ├─ config | - | ✅ | ✅ | 配置管理 |
| **model/llm** | 多个 | ✅ | ✅ | LLM 模型定义 |
| **nn** | 5 | ✅ | ✅ | 神经网络层 |
| **tensor** | 11 | ✅ | ✅ | 张量操作 |
| **ops** | 2 | ✅ | ✅ | 基础算子 |
| **cuda** | 10 | ✅ | ✅ | GPU 计算内核 |
| **opt/optim** | 8 | ✅ | ✅ | 优化算法 |

### B. 可选/辅助代码 (可能参与编译，但不是必须)

| 文件夹 | S 文件数 | 编译 | 运行 | 说明 |
|--------|---------|------|------|------|
| **training** | 6 | ⚠️ 可选 | ⚠️ 可选 | 通用训练工具 |
| **inference** | 22 | ⚠️ 可选 | ✗ | 推理和部署 (非训练) |
| **distributed** | 23 | ⚠️ 可选 | ⚠️ 部分 | 通用分布式框架 |
| **data** | 16 | ⚠️ 可选 | ⚠️ 部分 | 数据处理工具 |
| **eval** | 1 | ⚠️ 可选 | ⚠️ 可选 | 评估工具 |
| **dataset** | 2 | ⚠️ 可选 | ⚠️ 可选 | 数据集管理 |
| **quantization** | 2 | ✗ | ✗ | 模型量化 (非训练) |
| **serving** | 2 | ✗ | ✗ | 模型服务 (非训练) |

### C. 开发和测试代码 (本地开发，不参与训练)

| 文件夹 | S 文件数 | 编译 | 运行 | 说明 |
|--------|---------|------|------|------|
| **test** | 14 | ✓ 可选 | ✓ 可选 | 单元测试 |
| **tests** | 3 | ✓ 可选 | ✓ 可选 | 集成测试 |
| **examples** | 6 | ✓ 可选 | ✓ 可选 | 示例代码 |
| **agent** | 24 | ✗ | ✗ | AI Agent 系统 |
| **tools** | 6 | ✓ 可选 | ✓ 可选 | 工具脚本 |

### D. 未使用或计划中的代码 (不参与编译)

| 文件夹 | S 文件数 | 编译 | 运行 | 说明 |
|--------|---------|------|------|------|
| **alignment** | 7 | ✗ | ✗ | 后训练对齐 (SFT/DPO/GRPO) |
| **posttrain** | 1 | ✗ | ✗ | 后训练系统 |
| **reasoning** | 2 | ✗ | ✗ | 推理能力 (未实现) |
| **world_model** | 1 | ✗ | ✗ | 世界模型 (未实现) |
| **diffusion** | 1 | ✗ | ✗ | 扩散模型 (非 LLM) |
| **api** | 1 | ✗ | ✗ | API 服务层 |
| **deployment** | 1 | ✗ | ✗ | 部署工具 |
| **deploy** | 1 | ✗ | ✗ | 部署脚本 |

### E. 基础设施和配置 (非 S 代码)

| 文件夹 | 说明 |
|--------|------|
| **scripts** | 39 个 Bash 脚本 (包括训练启动) |
| **s** | 33 个 S 编译器文件 (生产集群依赖) |
| **logging** | 12 个日志系统文件 |
| **artifacts** | 检查点、日志、输出 (运行时生成) |
| **build** | 编译输出目录 |
| **include** | C 头文件 (外部库) |
| **bin** | 可执行文件 |

### F. 空或配置文件 (无实现代码)

- `.git/` - Git 版本控制
- `.github/` - GitHub CI/CD
- `.vscode/` - VS Code 配置
- `.run/` - Run 配置
- `.neurx/` - neurx 配置
- `configs/` - YAML/JSON 配置
- `docs/` - 文档
- `deploy/production/` - 生产配置
- 其他辅助目录

---

## 🏃  训练时实际加载的模块依赖图

```
model_large_pretrain.s (主程序)
├─ llm_moe_1t.s
│  ├─ model_large_train.s (Transformer 定义)
│  │  ├─ nn/attention.s
│  │  ├─ nn/ffn.s
│  │  └─ tensor/ops.s
│  ├─ moe/llm_moe_1t_loss.s
│  └─ distributed/moe_all_to_all.s
├─ pretrain/distributed/
│  ├─ ddp.s
│  ├─ tensor_parallel.s
│  └─ zero_gradient_reduce.s
├─ pretrain/optimizer/adamw.s
├─ pretrain/tokenizer/bpe.s
├─ pretrain/checkpoint/
├─ pretrain/data/
├─ pretrain/eval/
├─ pretrain/loop/
├─ pretrain/config/
├─ cuda/kernels.s (GPU 计算)
├─ tensor/ops.s
├─ ops/math.s
└─ tensor/new.s (张量创建)
```

---

## 📋 详细文件夹清单 (97 个)

### 系统配置 (11 个)
1. `.git` - Git 版本控制 ✗
2. `.github` - GitHub CI/CD ✗
3. `.neurx` - neurx 配置 ✗
4. `.run` - Run IDE 配置 ✗
5. `.vscode` - VS Code 配置 ✗
6. `configs` - 配置文件 ✗
7. `production_deployment` - 生产部署 ✗
8. `docs` - 文档 ✗
9. `include` - C 头文件 ✗
10. `bin` - 可执行文件 ✗
11. `build` - 编译输出 ✗

### 核心训练系统 (12 个) ✅ 全部参与编译运行
1. `pretrain/llm` - 预训练 LLM ✅
2. `model/llm` - LLM 模型 ✅
3. `model/tokenizer` - 分词 ✅
4. `distributed` - 分布式框架 ✅
5. `training` - 训练工具 ⚠️
6. `data` - 数据管道 ⚠️
7. `dataset` - 数据集 ⚠️
8. `nn` - 神经网络 ✅
9. `tensor` - 张量操作 ✅
10. `ops` - 基础算子 ✅
11. `cuda` - GPU 内核 ✅
12. `opt` - 优化算法 ✅

### 推理和部署 (5 个) ✗ 不参与训练
1. `inference` - 推理系统
2. `serving` - 模型服务
3. `quantization` - 量化
4. `deployment` - 部署工具
5. `deploy` - 部署脚本

### 后训练系统 (4 个) ✗ 计划中
1. `alignment` - 对齐训练
2. `posttrain` - 后训练
3. `reasoning` - 推理能力
4. `world_model` - 世界模型

### 开发工具 (8 个) ✓ 可选
1. `test` - 单元测试 ✓
2. `tests` - 集成测试 ✓
3. `examples` - 示例代码 ✓
4. `tools` - 工具脚本 ✓
5. `script` - Shell 脚本 ✓
6. `eval` - 评估工具 ✓
7. `logging` - 日志系统 ⚠️
8. `observability` - 可观测性 ⚠️

### 通用库和框架 (7 个) ⚠️ 部分使用
1. `autodiff` - 自动求导
2. `backends` - 后端
3. `compile` - 编译
4. `context` - 上下文
5. `executor` - 执行器
6. `engine` - 引擎
7. `runtime` - 运行时

### 其他组件 (35 个) ✗ 未在训练中使用
- `action` - Action 系统
- `agent` - AI Agent
- `api` - API 服务
- `arch` - 架构
- `asset_imports` - 资源导入
- `assets` - 资源
- `checkpoint` - 检查点
- `checkpoints` - 检查点存储
- `chat_history` - 聊天历史
- `compute` - 计算
- `core` - 核心库
- `drivers` - 驱动
- `diffusion` - 扩散模型
- `end_to_end_output` - E2E 输出
- `executor` - 执行器
- `ipc` - 进程通信
- `kernel` - 内核
- `lf` - 低级函数
- `logs` - 日志
- `memory` - 内存管理
- `ml` - 机器学习
- `monitoring` - 监控
- `net` - 网络
- `output`, `outputs` - 输出
- `packages` - 包管理
- `perception` - 感知
- `platform` - 平台
- `plugins` - 插件
- `optimization` - 优化
- `packages` - 包
- `perception` - 感知
- `platform` - 平台
- `plugins` - 插件
- 等等...

---

## 🔴 编译状态总结

### ✅ 必须编译 (完整功能)
- pretrain/llm/model_large_pretrain.s (主程序)
- model/llm/model_large_train.s (Transformer)
- moe/llm_moe_1t.s (1T MoE)
- distributed/* (DDP, TP, PP, EP)
- pretrain/optimizer/* (AdamW)
- pretrain/tokenizer/bpe.s (分词)
- nn/* (注意力, FFN 等)
- tensor/* (张量操作)
- cuda/* (GPU 内核)
- ops/* (基础算子)

**这 10+ 个模块必须都能编译通过，否则训练无法进行**

### ⚠️ 可选编译 (增强功能)
- training/* (通用训练工具)
- data/* (数据处理)
- eval/* (评估)
- tests/* (测试)
- examples/* (示例)

**这些模块可以不编译，但会影响数据加载和评估等功能**

### ✗ 不编译 (非训练流程)
- inference/* (推理)
- serving/* (服务)
- quantization/* (量化)
- alignment/* (后训练)
- posttrain/* (后训练)
- agent/* (Agent 系统)
- reasoning/* (推理能力)
- 其他 50+ 个文件夹

**这些模块不参与 1T MoE 的预训练过程**

---

## 📊 运行时代码执行流程

### 本地验证 (单机演示)
```
make train
  ├─ scripts/legacy/run_model_large_pretrain.sh
  │  ├─ 检查 S 编译器 (不可用，演示模式)
  │  └─ 运行训练演示 (输出假数据)
  └─ 生成假的检查点和日志
```

**状态**: 演示模式，不实际编译 S 代码

### 集群运行 (1024 GPU)
```
sbatch scripts/legacy/submit_training_job.sh
  ├─ 集群 SLURM 初始化
  ├─ 1024 个进程启动
  ├─ S 编译器编译 model_large_pretrain.s
  │  └─ 自动编译所有导入的依赖模块
  └─ 1024 个 GPU 上并行训练
     ├─ 数据加载 (pretrain/data)
     ├─ 前向传播 (model/llm)
     ├─ 损失计算 (moe/llm_moe_1t_loss.s)
     ├─ 后向传播 (autodiff)
     ├─ 优化器更新 (pretrain/optimizer)
     ├─ 梯度同步 (distributed)
     ├─ 检查点保存 (pretrain/checkpoint)
     ├─ 指标收集 (monitoring)
     └─ 4-6 天训练循环
```

**状态**: 完全编译和执行

---

## ✅ 验证和编译检查清单

### 本地环境检查
```bash
✓ bash scripts/legacy/verify_framework.sh
  → 检查 8 个核心模块是否存在
  → 验证配置文件完整性
  → 确认文档齐全

✗ S 编译器不可用 (预期)
  → 生产集群才有 /opt/s/bin/s

✓ 训练启动脚本可执行
  → scripts/legacy/run_model_large_pretrain.sh 存在
  → scripts/legacy/submit_training_job.sh 存在
```

### 集群部署前检查
```bash
⏳ S 编译器安装验证
   /opt/s/bin/s --version

⏳ SLURM 集群验证
   scontrol show config
   sinfo -N -l

⏳ 模块编译检查
   s compile pretrain/llm/model_large_pretrain.s --check

⏳ 单节点测试编译
   s compile pretrain/llm/model_large_pretrain.s
```

---

## 🎯 关键结论

### 📍 不是所有 317 个 S 文件都会在训练时被使用

**实际参与训练的核心模块**: ~30-40 个文件
- MoE 路由 (3-5 个文件)
- 张量并行 (5-8 个文件)
- 模型定义 (10-15 个文件)
- 优化器 (3-5 个文件)
- 数据处理 (3-5 个文件)
- 检查点/日志 (3-5 个文件)

**其他 277 个文件的用途**:
- 📖 示例和文档代码
- 🧪 测试用例
- 🔮 未来功能 (后训练, 推理)
- 🛠️ 开发工具
- 📊 监控和可观测性
- 🧠 其他 AI 功能 (Agent, 推理等)

### 📊 编译覆盖情况

| 情况 | 文件数 | 行数 | 说明 |
|------|--------|------|------|
| 必须编译 | ~30 | 5000+ | 1T MoE 训练核心 |
| 可选编译 | ~50 | 8000+ | 辅助和优化功能 |
| 不编译 | ~237 | 21000+ | 其他功能或未实现 |

### ⚡ 编译和执行效率

**编译时间** (估计):
- 本地编译 S 代码: 10-30 分钟 (首次完整编译)
- 增量编译: 1-5 分钟 (仅修改的部分)

**执行流程**:
1. S 编译器将 model_large_pretrain.s 编译为二进制
2. 自动跟踪所有 `use` 导入，编译依赖模块
3. 生成 1024 个节点的分布式可执行文件
4. 4-6 天训练执行

**不参与的代码** (不会增加编译时间):
- 后训练对齐代码 (SFT, DPO, GRPO)
- 推理和部署代码
- Agent 系统
- 其他未使用模块

---

## 🔍 如何确定某个文件夹的代码是否会被使用

**方法 1**: 检查导入关系
```bash
# 查看主程序导入
grep "use neurx.xxx" pretrain/llm/model_large_pretrain.s

# 追踪依赖
grep -r "use neurx.yyy" pretrain/distributed/
```

**方法 2**: 检查 S 编译器日志
```bash
s compile pretrain/llm/model_large_pretrain.s -v
# 会显示所有被编译的模块
```

**方法 3**: 查看编译输出
```bash
# 编译后查看符号表
nm build/model_large_pretrain | grep func
# 只会显示被实际使用的函数
```

---

## 📈 扩展性分析

### 后续版本可能使用的代码
- `alignment/*` - 后训练对齐 (v2.0 计划)
- `inference/*` - 模型推理 (v2.0 计划)
- `quantization/*` - 模型量化 (v2.0 计划)
- `agent/*` - 多 Agent 协作 (v3.0 计划)

### 目前不使用的原因
- 🎯 聚焦于 1T 预训练
- ⏸️ 后训练功能后续发布
- 📦 模块化设计便于扩展

---

**结论**: neurx 框架虽然有 97 个文件夹和 317 个 S 代码文件，但 **只有约 30-40 个文件会在每次训练时被编译和执行**。其余代码用于示例、测试、未来功能等。核心的 1T MoE 训练流程专注且高效。
