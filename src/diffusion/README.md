# neurx diffusion

This directory hosts diffusion-specific orchestration in S modules.

- config: diffusion configuration state
- noise: beta/alpha schedule states
- model: minimal denoiser model state
- sampler: DDPM/DDIM sampler states
- train: diffusion training step state
- eval: diffusion generation/eval state
- diffusion.s: unified diffusion entry points
