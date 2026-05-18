# Vision Detection Pipeline

Stages:
- dataset: manifest -> decode -> resize
- dataloader: batch -> collate -> targets
- model: init -> forward -> loss
- optimizer: grads -> step -> scheduler
- checkpoint: save -> keep best

IO contract:
- Input: dataset manifest, run config
- Output: checkpoint root under `artifacts/checkpoints/vision/detection` and metrics
