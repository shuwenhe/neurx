# Robotics Train Pipeline

This pipeline describes the robotics trajectory-training flow:

- dataset: trajectory samples and observation schemas
- perception: encode observations into latent vectors
- policy: map latent vectors to actions
- train_loop: update metrics and stop conditions
- eval: track lightweight workflow ticks

The workflow accepts `eval_every` and `save_every` as scheduling hints.
