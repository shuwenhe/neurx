# NeurX

NeurX is an engineering framework for training, inference, and deployment of large language models. The project is primarily implemented with S language modules and provides C/C++, CUDA, and Ascend CANN backends. It covers pretraining, post-training, distributed training, quantization, serving, and evaluation workflows.

## Features

- Training and inference on CPU, CUDA, and Ascend NPU
- Data, tensor, and pipeline parallelism, including ZeRO
- Transformer, MoE, Flash Attention, and paged KV cache
- Pretraining, supervised fine-tuning, LoRA, DPO, GRPO, and RLHF
- Checkpointing, quantization, evaluation, monitoring, and OpenAI-compatible serving

## Project Structure

```text
attention/      Attention mechanisms and CUDA implementations
cann/           Ascend CANN backend
cuda/           CUDA runtime, kernels, and training bridges
data/           Data loading, cleaning, and sharding
distributed/    Distributed training components
inference/      Inference engine and sampling strategies
model/          Model definitions and loading
posttrain/      Fine-tuning and alignment
pretrain/       Pretraining entry points and configuration
serving/        Online serving and request governance
tests/          Tests and verification programs
tools/          Build and model-processing utilities
```

## Requirements

- Linux or macOS
- GNU Make, Bash, and a C/C++ compiler
- The S compiler, discovered from a neighboring `s` repository or the system `PATH`
- NVIDIA CUDA Toolkit for GPU workflows
- Ascend Toolkit, CANN Runtime, and an available Ascend device for NPU workflows

You can specify the S compiler explicitly:

```bash
make S_COMPILER=/path/to/s help
```

## Quick Start

List the primary commands:

```bash
make help
```

Run CPU inference:

```bash
make infer
```

Start pretraining on a GPU or Ascend NPU:

```bash
make pretrain-gpu
make pretrain-npu
```

Run post-training or start an interactive chat session:

```bash
make posttrain
make chat
```

Select a test target from the Makefile as needed. For example:

```bash
make transformer-reference-test
make inference-runtime-test
make test-checkpoint-resume
```

## Configuration

Training, dataset, checkpoint, and device settings can be overridden with Make variables or environment variables. For example:

```bash
make pretrain-gpu PRETRAIN_MODEL_NAME=NeurX-1.3 PRETRAIN_STEPS=1000
```

To connect to an external API, copy the example configuration and add your credentials:

```bash
cp secrets.env.example secrets.env
```

Never commit real credentials to the repository.

## License

This project is licensed under the [MIT License](LICENSE).
