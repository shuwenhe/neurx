# Agent Skills Pipeline

Stages:
- collect: traces -> failures -> candidate signals
- synthesize: failures -> draft skill spec
- evaluate: draft skill -> benchmark scores
- promote: scores -> registry update
- monitor: runtime logs -> drift detection -> rollback or retire

IO contract:
- Input: trace logs, benchmark manifest, evolution config
- Output: skill registry snapshot, candidate report, checkpoint artifacts
