# neurx posttrain

This directory hosts posttraining-specific orchestration in S modules.

- config: posttraining configuration state
- data: posttraining sample and preference batch state
- loop: posttraining step and stage state machine
- reward: reward model and preference scoring state
- rlhf: minimal PPO skeleton for RLHF-style optimization steps
- checkpoint: posttraining checkpoint scheduling state
- eval: posttraining evaluation state

Entry module:

- posttrain.s: default pipeline bootstrap and iterative posttrain runner
- posttrain.s: input-driven step APIs and train-pipeline adapter APIs
