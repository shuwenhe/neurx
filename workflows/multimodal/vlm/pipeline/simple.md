# VLM Pipeline

Stages:
- dataset: image-text pairs -> encode -> shard
- fusion: image encoder -> text encoder -> combine
- model: init -> forward -> loss
- optimizer: grads -> step -> scheduler
- checkpoint: save -> keep best

IO contract:
- Input: paired image-text manifest, run config
- Output: checkpoint root under `artifacts/checkpoints/multimodal/vlm` and evaluation metrics
