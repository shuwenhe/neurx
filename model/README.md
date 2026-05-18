# model

Model-family modules live here.

## Layout

- `core/`: reusable model building blocks shared across families
- `vision/`: image classification, detection, segmentation, and backbone modules
- `llm/`: language model blocks, transformer stacks, and generation helpers
- `diffusion/`: diffusion backbones, schedulers, and sampler variants
- `multimodal/`: joint vision-language or multi-encoder model compositions
- `audio/`: speech, audio classification, and sequence models
- `video/`: temporal backbones, video understanding, and spatiotemporal models
- `reward/`: reward models, preference heads, and scoring wrappers

## Rule

- Keep model-family composition here.
- Keep tensor, autograd, runtime, and serving logic in the canonical core directories.
