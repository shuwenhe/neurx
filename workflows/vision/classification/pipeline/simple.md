# Vision Classification Pipeline

Stages:
- dataset: manifest -> decode -> augment
- dataloader: batch -> collate -> normalize
- model: init -> forward -> loss
- optimizer: grads -> step -> scheduler
- checkpoint: save -> keep best

IO contract:
- Input: dataset manifest, run config
- Output: checkpoint root under `artifacts/checkpoints/vision/classification` and metrics
