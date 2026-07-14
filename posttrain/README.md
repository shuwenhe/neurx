# neurx posttrain

This directory hosts posttraining-specific orchestration in S modules.

- config: posttraining configuration state
- data: posttraining sample and preference batch state
- loop: posttraining step and stage state machine
- reward: reward model and preference scoring state
- rlhf: minimal PPO skeleton for RLHF-style optimization steps
- sft: supervised fine-tuning entry points, including LoRA-backed SFT
- checkpoint: posttraining checkpoint scheduling state
- eval: posttraining evaluation state

Entry module:

- posttrain.s: default pipeline bootstrap and iterative posttrain runner
- posttrain.s: input-driven step APIs and train-pipeline adapter APIs
- script/run_lora_sft_training.s: callable LoRA SFT training entry
