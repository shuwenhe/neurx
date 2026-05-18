# Video Diffusion Pipeline

Stages:
- dataset: clips -> decode -> shard
- latents: frames -> encode -> noise
- model: init -> denoise -> loss
- optimizer: grads -> step -> scheduler
- checkpoint: save -> keep best

IO contract:
- Input: clip manifest, run config
- Output: checkpoints and generated videos

