# Tool Use Pipeline

Stages:
- dataset: prompts -> tool schema -> shard
- policy: state -> action -> tool call
- memory: store -> retrieve -> update
- evaluator: success -> score -> log

IO contract:
- Input: prompt manifest, tool manifest, run config
- Output: trajectories and success metrics

