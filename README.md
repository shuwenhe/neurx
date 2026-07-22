# NeurX

NeurX 是一个面向大语言模型训练、推理与部署的工程化框架。项目以 S 语言模块为主体，并提供 C/C++、CUDA 和 Ascend CANN 后端，覆盖预训练、后训练、分布式训练、量化、服务化及评测等流程。

## 主要能力

- CPU、CUDA 与 Ascend NPU 训练和推理
- 数据并行、张量并行、流水线并行及 ZeRO
- Transformer、MoE、Flash Attention 和分页 KV Cache
- 预训练、监督微调、LoRA、DPO、GRPO 与 RLHF
- 检查点、量化、评测、监控和 OpenAI 兼容服务

## 项目结构

```text
attention/      注意力机制与 CUDA 实现
cann/           Ascend CANN 后端
cuda/           CUDA 运行时、算子与训练桥接
data/           数据加载、清洗和分片
distributed/    分布式训练组件
inference/      推理引擎与采样策略
model/          模型定义与加载
posttrain/      微调与对齐训练
pretrain/       预训练入口和配置
serving/        在线服务与请求治理
tests/          测试与验证程序
tools/          构建及模型处理工具
```

## 环境要求

- Linux 或 macOS
- GNU Make、Bash 和可用的 C/C++ 编译器
- S 编译器；默认从相邻的 `s` 仓库或系统 `PATH` 中查找
- GPU 工作流需要 NVIDIA CUDA Toolkit
- NPU 工作流需要 Ascend Toolkit、CANN Runtime 和可用的 Ascend 设备

可以通过变量指定 S 编译器位置：

```bash
make S_COMPILER=/path/to/s help
```

## 快速开始

查看主要命令：

```bash
make help
```

运行 CPU 推理：

```bash
make infer
```

启动 GPU 或 Ascend NPU 预训练：

```bash
make pretrain-gpu
make pretrain-npu
```

运行后训练和交互式对话：

```bash
make posttrain
make chat
```

运行测试时，可按需选择 Makefile 中的测试目标，例如：

```bash
make transformer-reference-test
make inference-runtime-test
make test-checkpoint-resume
```

## 配置

训练、数据集、检查点和设备参数可以通过 Make 变量或环境变量覆盖。例如：

```bash
make pretrain-gpu PRETRAIN_MODEL_NAME=NeurX-1.3 PRETRAIN_STEPS=1000
```

如需连接外部 API，可复制示例配置并填入自己的密钥：

```bash
cp secrets.env.example secrets.env
```

不要将真实密钥提交到版本库。

## 许可证

本项目采用 [MIT License](LICENSE)。
