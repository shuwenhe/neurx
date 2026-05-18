# Workflows

`workflows/` is the compatibility orchestration layer of NeurX.

It remains in the tree for older task flows and lifecycle code:

- `deploy/`: deployment and release-state transitions
- `sim/`: simulation setup and environment toggles
- `real/`: real-world connection and safety transitions

## What Belongs Here

- Multi-stage task flows that already exist
- Deployment / simulation / real orchestration for legacy pipelines
- Simulation-to-real lifecycle control for compatibility code
- State machines that combine multiple model or runtime components

## What Does Not Belong Here

- Model architecture definitions
- Layer / block / optimizer implementations
- Tensor, autograd, runtime, or backend primitives
- New model training entrypoints
- Single-purpose utility code that does not coordinate a workflow

## Rule of Thumb

If the code answers "what step happens next in the task lifecycle for legacy code?", it belongs here.
If the code answers "how does the model compute, train, evaluate, or adapt?", it belongs in `model/`, `train/`, `pretrain/`, `posttrain/`, `nn/`, `tensor/`, or `runtime/`.

## Robotics

The robotics subtree remains here only as compatibility orchestration:

- `workflows/robotics/workflow.s`: end-to-end robotics orchestration
- `workflows/robotics/deploy/deploy.s`: deployment-state control
- `workflows/robotics/sim/sim.s`: simulation-state control
- `workflows/robotics/real/real.s`: real-world connection and safety control

The model-side robotics entrypoints now live under `model/robotics/`.

## Scope Guard

Keep `workflows/` frozen unless you are maintaining compatibility. New robotics training code should go under `model/robotics/` instead.

## Recommended Modern Layout

Move new, active multi-stage pipelines into a small, well-structured subtree. Each workflow should expose a tiny, stable API that calls into the runtime/scheduler layer rather than directly invoking kernels or CUDA.

Suggested top-level layout:

```
/workflows
	/llm
		/pretrain
		/sft
		/dpo
		/inference

	/vision
		/classification
		/detection

	/diffusion
		/text2image
		/image2image
		/video

	/multimodal
		/vlm

	/agent
		/tool_use
		/memory

	/benchmark
	/dataset
```

Inside each leaf workflow prefer the same minimal layout:

```
config/      # YAML or small S structs describing runs
pipeline/    # Pipeline description (stages, IO contract)
run/         # Launch scripts / entrypoints (call runtime API)
dataset/     # Dataset manifest, tokenizer, prepping tools
```

Design notes:
- Workflows should call the runtime API → IR → scheduler, not CUDA/kernels directly.
- Implement `Pipeline`-like interfaces so model types (LLM/Diffusion/Vision) reuse checkpointing, logging, and distributed plumbing.
- Keep `workflows/` focused on orchestration and compatibility; model implementations remain in `model/`, training helpers in `train/`, and optimizer/runtime primitives in `runtime/`.

This repository now includes a scaffolded `workflows/llm`, `workflows/vision`, `workflows/diffusion`, `workflows/multimodal`, and `workflows/agent` to follow this convention. Add concrete pipelines under the `pipeline/` directories.
