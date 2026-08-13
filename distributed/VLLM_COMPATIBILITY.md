# vLLM distributed compatibility

NeurX implements the inference-facing vLLM distributed contracts in S.

## Modules

- `parallel_state.s` implements world, tensor, pipeline, data, expert,
  prefill-context, and decode-context parallel groups. Rank layout follows
  `DP x PP x PCP x TP`, matching vLLM's current `parallel_state.py` layout.
- `communication_op.s` implements tensor-parallel all-reduce, dimension-aware
  all-gather, reduce-scatter, destination gather, broadcast, and all-to-all
  semantics over flattened S tensors.
- `device_communicators/device_communicator.s` provides NCCL-backed native
  collectives, point-to-point operations, async handles, communicator teardown,
  and checkpoint prepare/restore lifecycle hooks.
- `kv_transfer/kv_transfer_state.s` implements disaggregated KV transfer
  initialization, routing, request lifecycle, accounting, and shutdown.
- `weight_transfer/weight_transfer_state.s` implements transactional model
  weight updates with backend validation, parameter accounting, draft-model
  capability checks, commit/failure states, and shutdown.
- `elastic_ep/elastic_state.s` implements bounded, staged expert-parallel
  resize with generation tracking, commit, and rollback.
- `eplb/eplb_state.s` records expert routing load and produces executable
  expert migration plans when imbalance crosses the configured threshold.
- `kv_transfer/connectors/connector_registry.s` describes and validates the
  vLLM connector families and implements their operation lifecycle.
- `ec_transfer/ec_transfer_state.s` implements encoder-cache transfer request
  lifecycle and accounting for disaggregated multimodal inference.

`communication_op.s` is a deterministic single-process semantic backend used
for CPU tests. It models identical input on every rank. Production buffers use
the native pointer APIs in `device_communicator.s`; they do not use the semantic
backend to pretend that inter-process communication occurred.

## Verification

Run:

```bash
make vllm-distributed-test
```

The test compiles a bundled S program and executes topology, collective, KV
transfer, weight update, and teardown contracts through the S IR runtime.

## Native ABI

The device communicator expects these runtime symbols:

- `neurx_nccl_init_rank`, `neurx_nccl_destroy`
- `neurx_nccl_all_reduce_f32`, `neurx_nccl_all_gather_f32`
- `neurx_nccl_reduce_scatter_f32`, `neurx_nccl_broadcast_f32`
- `neurx_nccl_send_f32`, `neurx_nccl_recv_f32`, `neurx_nccl_barrier`

CPU-only contract tests do not initialize the NCCL communicator.

Connector-specific data planes such as NIXL, Mooncake, and LMCache still
require their vendor runtime. The S implementation supplies selection,
validation, lifecycle, and accounting and does not report a transfer as a
hardware success without a data-plane adapter.
