# Text-to-Image Pipeline

Stages:
- dataset: prompts -> tokenize -> shard
- latents: noise -> schedule -> encode
- model: init -> denoise -> loss
- optimizer: grads -> step -> scheduler
- checkpoint: save -> keep best

IO contract:
- Input: prompt manifest, run config
- Output: checkpoints and generated samples

