# Robotics Train Run

Launch scripts for the robotics trajectory-training workflow belong here.

Available entrypoints:

- `launch.s`: run the default sample config
- `run_with_config.s`: compile a workflow entrypoint from environment-configured values
- `observe_with_config.s`: compile an observation entrypoint for the same config

The run layer calls `neurx.workflows.robotics.train.pipeline_runner.run_robotics_training_with_schedule`.
In the current environment, `s source.s output.ir` validates compilation of the generated entrypoint but does not execute `main()`.
