Robotics trajectory training pipeline (MVP)

Stages:
- dataset: load trajectory samples
- perception: encode observations into latent vectors
- policy: initialize/update robotics policy state
- train_loop: run steps, update metrics and convergence flags
- eval: compute quick rollout metrics

Stage IO sketch:
- dataset -> perception: `observation[obs_dim]`
- perception -> policy: `latent[latent_dim]`
- policy -> train_loop: `action[act_dim]`, `loss`, `action_error`
- train_loop -> eval: `metrics.step`, `metrics.loss`, `finished`

Contract:
- Input: config/sample.yaml
- Output: training state (`finished`, `metrics.step`, `metrics.loss`)

Evaluation signals (MVP):
- `metrics.loss`: trajectory regression quality
- `metrics.action_error`: action-space error proxy
- `finished`: reaches `max_steps`

Design rule:
workflow -> model/robotics -> runtime/model API -> IR -> scheduler
(no direct kernel invocation in workflow layer)
