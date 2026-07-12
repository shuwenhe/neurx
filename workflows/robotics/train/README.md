Robotics trajectory training workflow (MVP)

Layout:
- config/: workflow config and presets
- pipeline/: stage descriptions and IO contract
- run/: launch scripts
- dataset/: dataset placeholders
- pipeline_runner.s: executable workflow runner bridging to `model/robotics/trajectory_train.s`

Quick run:
- `workflows/robotics/train/run/launch.s`
- or `workflows/robotics/train/run/run_with_config.s`
- observe tick state with `workflows/robotics/train/run/observe_with_config.s`

Current CLI note:
- In this environment, `s source.s output.ir` validates compilation of the generated workflow entrypoint. It does not execute `main()` directly.

Primary config keys in `config/sample.yaml`:
- `obs_dim`
- `latent_dim`
- `act_dim`
- `sample_count`
- `max_steps`
- `eval_every`
- `save_every`
- `learning_rate`
- `task_name`

Primary S entrypoints:
- `neurx.model.robotics.train.robotics_robot_train_config`
- `neurx.model.robotics.train.robotics_robot_train_state`
- `neurx.model.robotics.train.robotics_robot_train_run`
- `neurx.workflows.robotics.train.pipeline_runner.run_robotics_training_with_schedule`
- `neurx.workflows.robotics.train.pipeline_runner.run_robotics_training_schedule_state`

Observable tick-state getters:
- `neurx.workflows.robotics.train.pipeline_runner.robotics_workflow_training_state`
- `neurx.workflows.robotics.train.pipeline_runner.robotics_workflow_eval_count`
- `neurx.workflows.robotics.train.pipeline_runner.robotics_workflow_save_count`
- `neurx.workflows.robotics.train.pipeline_runner.robotics_workflow_last_eval_step`
- `neurx.workflows.robotics.train.pipeline_runner.robotics_workflow_last_save_step`
- `neurx.workflows.robotics.train.pipeline_runner.robotics_workflow_eval_interval`
- `neurx.workflows.robotics.train.pipeline_runner.robotics_workflow_save_interval`

Completion semantics:
- Workflow run is considered successful when `state.finished == true` and `state.metrics.step == max_steps`.

Current MVP scope:
- Uses synthetic trajectory generation from model-side training state.
- Provides fast smoke validation for orchestration and step/metric transitions.
- Does not yet include real simulator/hardware rollouts in this workflow layer.
- `eval_every` and `save_every` now drive workflow tick simulation and are observable through the exported tick-state runner.
