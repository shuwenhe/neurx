Robotics trajectory training workflow (MVP)

Layout:
- config/: workflow config and presets
- pipeline/: stage descriptions and IO contract
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

Primary S entrypoints:
- `neurx.model.robotics.train.robotics_robot_train_config`
- `neurx.model.robotics.train.robotics_robot_train_state`
- `neurx.model.robotics.train.robotics_robot_train_run`

Completion semantics:
- Workflow run is considered successful when `state.finished == true` and `state.metrics.step == max_steps`.

Current MVP scope:
- Uses synthetic trajectory generation from model-side training state.
- Provides fast smoke validation for orchestration and step/metric transitions.
- Does not yet include real simulator/hardware rollouts in this workflow layer.
