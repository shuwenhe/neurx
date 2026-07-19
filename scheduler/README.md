# NeurX Scheduler

`scheduler/` contains scheduler implementations used across NeurX.

Use this directory for:
- learning-rate scheduling
- task queues
- background jobs
- multi-agent scheduling
- priority and fairness policy
- serving and inference request scheduling

Key files:
- `training_scheduler.s` — training LR scheduler compatibility wrapper.
- `schedulers.s` — cosine, linear, and step LR schedule primitives.
- `lr_scheduler.s` — generic warmup/decay LR scheduler.
- `lr_scheduler_moe_1t.s` — 1T MoE training LR scheduler.
- `agent_scheduler.s` — agent/task priority scheduling.
- `kernel_sched.s` — Linux-kernel-style run queue scheduler model.
- `serving_vllm_scheduler.s` — serving vLLM request scheduling.
- `inference_vllm_scheduler.s` — inference vLLM request scheduling.
