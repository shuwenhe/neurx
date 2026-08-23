# Inference Executor

Owns model execution plans for prefill and decode. Scheduling policy remains in
`scheduler`, request-to-token orchestration remains in `engine`, and hardware
operations remain in `backends`.
