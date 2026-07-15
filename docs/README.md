# NeurX Framework

> Enterprise-grade Deep Learning Framework for Large Language Models

## 📋 Overview

NeurX is a complete enterprise-grade deep learning framework implemented in the **S language** for training and deploying large-scale language models (such as reference-level models).

### Core Features

- ✅ **Complete Training Pipeline**: Data processing, model building, distributed training, inference
- ✅ **Support for 2T Parameter Models**: Full distributed training infrastructure
- ✅ **Multiple Optimization Techniques**: Mixed precision training, quantization, knowledge distillation, RLHF
- ✅ **High-Performance Computing**: Support for CUDA, CANN, MPS and other acceleration backends
- ✅ **Production-Ready**: Complete monitoring, checkpointing, fault recovery

## 🚀 Quick Start

### Installation

```bash
cd /Users/feifei/shuwen/train
git clone <repository>
cd neurx
```

### Training Small Models

```bash
# Pretraining
./script/run_large_pretrain.sh

# Fine-tuning
make train-supervised

# Evaluation
make eval
```

### Training Large-Scale Models

See [TRAINING_2T_GUIDE.md](./docs/TRAINING_2T_GUIDE.md) for details

## 📁 Project Structure

```
neurx/
├── agent/                 # Agent and inference systems
├── alignment/             # RLHF and alignment solutions
├── arch/                  # Different compute architecture backends
├── data/                  # Data processing and loading
├── distributed/           # Distributed training
├── docs/                  # Documentation
├── inference/             # Inference and deployment
├── model/                 # Model definitions
├── nn/                    # Neural network layers and operations
├── opt/                   # Optimizers
├── pretrain/              # Pretraining pipeline
├── script/                # Launch scripts
├── training/              # Training loops and utilities
└── ...
```

## 📚 Documentation

- [Quick Start Guide](./QUICK_START.md)
- [2T Model Training Guide](./TRAINING_2T_GUIDE.md)
- [Enterprise Training Guide](./ENTERPRISE_NEURX_TRAINING_GUIDE.md)
- [Distributed Training](./DISTRIBUTED_2T_IMPLEMENTATION.md)
- [Complete System Architecture](./README_COMPLETE_SYSTEM.md)

## 🔧 System Requirements

- **Operating System**: Linux / macOS
- **Compiler**: S language compiler support
- **GPU**: NVIDIA CUDA 11.0+ or other supported accelerators
- **Memory**: Minimum 16GB (recommended 64GB+)

## 📊 Performance

| Model | Parameters | Training Speed | Inference Speed |
|-------|-----------|-----------------|-----------------|
| Small | 350M | ~100 tokens/s | ~500 tokens/s |
| Large | 7B | ~50 tokens/s | ~200 tokens/s |
| 2T | 2T | ~0.5 tokens/s | ~50 tokens/s |

## 🤝 Contributing

Issues and PRs are welcome!

For local save-to-commit-and-push automation, run `tools/install-auto-save-hooks.sh` once, then start `tools/watch-auto-commit-push.sh` from the repository root. The watcher uses `inotifywait` when available and falls back to polling.

## 📄 License

This project is released under the **MIT License**. See [LICENSE](./LICENSE) and [COPYING](./COPYING) files for details.

### Third-Party Dependencies

- **MMLU**: CC-BY-4.0 License
- **HumanEval**: MIT License
- **Public Preference Datasets**: Licensed according to their respective sources

## 📞 Contact Information

**Maintainer**: Shuwen He

**Bug reports**: open a GitHub Issue

## Disclaimer

This project code is provided "as is" without any warranty. See the disclaimer in [COPYING](./COPYING).

---

**Last updated**: 2024-07-06
