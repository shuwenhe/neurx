# NeurX

NeurX is an AI model development framework implemented primarily in the S programming language. It contains components for model definition, automatic differentiation, distributed training, pre-training, post-training, inference, serving, CUDA acceleration, and Ascend CANN integration.

## Repository layout

- `model/`, `nn/`, `tensor/`, `attention/`: model and tensor primitives.
- `autograd/`, `optimizer/`, `loss/`: training and differentiation components.
- `pretrain/`, `posttrain/`, `trainer/`: model training workflows.
- `inference/`, `generation/`, `serving/`: inference and deployment components.
- `distributed/`, `scheduler/`, `shard/`: distributed execution support.
- `cuda/`: NVIDIA CUDA kernels and native bridges.
- `cann/`: Huawei Ascend CANN integration.
- `runtime/`, `compile/`, `executor/`: S execution and compilation support.
- `configs/`: model, training, evaluation, and extended Makefile configurations.
- `scripts/`: build, data, training, and operational utilities.
- `tests/`: integration and regression tests.

## Requirements

- Linux or macOS
- GNU Make and Bash
- The S compiler repository
- A C11-compatible compiler
- Optional: NVIDIA CUDA toolkit for GPU workflows
- Optional: Huawei Ascend CANN toolkit for NPU workflows

By default, the Makefile searches for the S repository in several common locations. Set it explicitly when needed:

```sh
make S_REPO_ROOT=/path/to/s <target>
```

## Quick start

List the primary commands:

```sh
make help
```

Build the generic S IR runner:

```sh
make build-s-ir-runner
```

Run the main workflows:

```sh
make shard
make pretrain-gpu
make pretrain-npu
make posttrain
make infer
make chat
```

## Inference

Build and run the production S inference path:

```sh
make build-production-s-inference
make chat
```

This path has no Python or curl dependency. The S control plane owns ChatML conversation state,
backend lifecycle, and request dispatch through S socket intrinsics. The native CPU backend memory-maps SafeTensors,
uses OpenMP/AVX-optimized transformer kernels, keeps the model resident, and reuses KV-cache
prefixes between chat turns.

Useful runtime settings:

```sh
make chat NEURX_CPU_THREADS=6 CHAT_MAX_NEW_TOKENS=128
```

Use `/reset` to clear both conversation history and the resident KV-cache.

Build and run the S post-training chat frontend:

```sh
make build-hf-posttrain-chat-s
make hf-posttrain-chat
```

The chat frontend supports these environment variables:

- `NEURX_CHAT_MODEL_PATH`
- `NEURX_CHAT_SYSTEM_PROMPT`
- `NEURX_CHAT_MAX_NEW_TOKENS`
- `NEURX_CHAT_INFERENCE_RUNNER`

## Large-model workflows

Extended large-model targets are stored in `configs/Makefile.large_models` and can be combined with the main Makefile:

```sh
make -f Makefile -f configs/Makefile.large_models train-help
make -f Makefile -f configs/Makefile.large_models train-large
make -f Makefile -f configs/Makefile.large_models train-xlarge
```

Additional standalone build definitions are available in:

- `configs/Makefile.complete`
- `configs/Makefile.eval`
- `cuda/Makefile.cuda`

## Configuration and outputs

- Training and model configurations are stored in `configs/`.
- Generated binaries, IR, logs, and exported files are written under `artifacts/`.
- Checkpoints are written under `checkpoint/` or configured output directories.
- Secrets should be supplied through environment variables or an ignored local `secrets.env` file.

## License

See the repository license files for licensing terms.
