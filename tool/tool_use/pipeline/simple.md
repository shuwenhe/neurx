# Tool Use Pipeline

Stages:
- dataset: prompts -> tool schema -> shard
- policy: state -> action -> tool call
- memory: store -> retrieve -> update
- evaluator: success -> score -> log

IO contract:
- Input: prompt manifest, tool manifest, run config
- Output: checkpoint root under `artifacts/checkpoints/agent/tool_use`, trajectories and success metrics
