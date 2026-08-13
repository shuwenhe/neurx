# NeurX

NeurX is an LLM training and inference framework implemented in S. It covers training, post-training, inference, distributed communication, quantization, KV cache, scheduling, monitoring, and deployment.

## Project layout

- `inference/`: inference engines, services, scheduling, optimizations, and runtime
- `distributed/`: distributed communication and fault tolerance
- `checkpoint/`: weight loading, saving, and checkpoint management
- `model/`, `models/`, `nn/`: model definitions and core operators
- `posttrain/`, `pretrain/`, `trainer/`: training and alignment workflows
- `quantization/`: quantization-related implementations
- `tokenizer/`: tokenizer implementations
- `serving/`, `api/`: external services and interfaces
- `tests/`: compilation, regression, and system verification
- `scripts/`: legacy scripts and compatibility helpers

## Common commands

List all targets first:

```bash
make help
```

Common targets include:

```bash
make quickstart-s
make verify-setup-s
make production-inference
make production-chat
make posttrain-phase2a
make runtime-test
make test-golden
```

## Conventions

- The codebase is primarily written in S
- Identifiers use `snake_case`
- Methods are defined inside `impl` blocks
- Function parameters use `type name` order

## Notes

The repository evolves over time. For the current implementation status, refer to the `.s` files in each directory and the targets in `Makefile`.
