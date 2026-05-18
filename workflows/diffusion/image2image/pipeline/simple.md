# Image-to-Image Pipeline

Stages:
- dataset: source images -> augment -> shard
- latents: encode -> noise -> schedule
- model: init -> denoise -> loss
- optimizer: grads -> step -> scheduler
- checkpoint: save -> keep best

IO contract:
- Input: source image manifest, run config
- Output: checkpoints and transformed samples

