Robotics training workflow (MVP)

Layout:
- config/: workflow config (sample.yaml)
- pipeline/: stage descriptions
- run/: launch scripts
- dataset/: dataset placeholders
- pipeline_runner.s: executable workflow runner bridging to `model/robotics/train_robotics.s`

Quick run:
- `workflows/robotics/train/run/launch.sh`
- or `workflows/robotics/train/run/run_with_config.sh --steps 32`
