Robotics trajectory training workflow (MVP)

Layout:
- config/: workflow config (sample.yaml)
- pipeline/: stage descriptions
- run/: launch scripts
- dataset/: dataset placeholders
- pipeline_runner.s: executable workflow runner bridging to `model/robotics/trajectory_train.s`

Quick run:
- `workflows/robotics/train/run/launch.sh`
- or `workflows/robotics/train/run/run_with_config.sh --steps 32`

Primary config keys in `config/sample.yaml`:
- `obs_dim`
- `latent_dim`
- `act_dim`
- `sample_count`
- `max_steps`
- `learning_rate`
- `task_name`
