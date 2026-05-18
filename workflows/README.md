# Workflows

`workflows/` holds active multi-stage pipeline orchestration for NeurX.

## Top-Level Layout

- `llm/`: pretrain, sft, dpo, and inference workflows
- `vision/`: classification and detection workflows
- `diffusion/`: text-to-image, image-to-image, and video workflows
- `multimodal/`: visual-language model workflows
- `agent/`: tool use and memory workflows
- `benchmark/`: benchmark and evaluation workflows
- `dataset/`: shared dataset manifests and preprocessing workflows

## Design Rule

- Workflow code describes runs, stages, and IO contracts.
- Model structure stays in `model/`.
- Training mechanics stay in `train/`, `pretrain/`, and `posttrain/`.
- Runtime execution stays in `runtime/` and `serving/`.

## Directory Convention

Each concrete workflow should prefer:

- `config/`: run parameters and presets
- `pipeline/`: stage graph and IO contract
- `run/`: launch entrypoints
- `dataset/`: manifests and preprocessing helpers

## Robotics

The robotics tree remains a compatibility-focused subtree and does not define the modern workflow layout.

- `workflows/robotics/README.md`: robotics compatibility overview
- `workflows/robotics/train/`: trajectory-training workflow
- `workflows/robotics/data/`: dataset bookkeeping
- `workflows/robotics/eval/`: evaluation bookkeeping
- `workflows/robotics/sim/`: simulation state
- `workflows/robotics/real/`: real-world state
- `workflows/robotics/deploy/`: deployment state
