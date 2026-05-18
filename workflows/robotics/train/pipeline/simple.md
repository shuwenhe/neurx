Robotics training pipeline (MVP)

Stages:
- dataset: load task samples / trajectories
- dataloader: build tokenized mini-batches
- policy: initialize/update robotics policy state
- train_loop: run steps, update metrics and convergence flags
- eval: compute quick rollout metrics

Contract:
- Input: config/sample.yaml
- Output: training state (`finished`, `metrics.step`, `metrics.loss`)

Design rule:
workflow -> runtime/model API -> IR -> scheduler
(no direct kernel invocation in workflow layer)
