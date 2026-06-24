# Robotics Train Run

Launch scripts for the robotics trajectory-training workflow belong here.

Available entrypoints:

- `launch.sh`: run the default sample config
- `run_with_config.sh`: compile a workflow entrypoint from an explicit YAML config and optional `--steps` override
- `observe_with_config.sh`: compile an observation entrypoint for the same config

The run layer calls `neurx.workflows.robotics.train.pipeline_runner.run_robotics_training_with_schedule`.
In the current environment, `s source.s output.ir` validates compilation of the generated entrypoint but does not execute `main()`.
