# Neurx S Module Roadmap

This document defines the next S-language modules to strengthen NeurX as a full stack framework.
The focus is practical: serving control plane, distributed training, compiler optimization, autograd completeness, and runtime diagnostics.

## Priority Stack

1. Serving runtime
2. Distributed training
3. Compiler and lowering
4. Autograd and module ergonomics
5. Quantization, export, and diagnostics

## 1. Serving Runtime

Current canonical modules:

- `serving/serve/serve.s`
- `serving/serve/admission_control.s`
- `serving/serve/continuous_batch.s`
- `serving/cache/kv_cache.s`
- `serving/cache/paged_kv_cache.s`
- `serving/cache/prefix_cache.s`
- `serving/decode/decode.s`
- `serving/sampling/sampling.s`
- `serving/vllm/vllm.s`
- `scheduler/serving_vllm_scheduler.s`
- `serving/vllm/request_queue.s`
- `serving/vllm/metrics.s`

Next capabilities:

- request admission and rejection accounting
- continuous batching across multiple concurrent requests
- prefix cache hit/miss and eviction tracking
- queue policy selection with FCFS and shortest-remaining modes
- decode-step and finish-step accounting

Suggested S APIs:

- `new_serving_runtime_state(int max_active_requests, int max_prefill_tokens, int batch_capacity, int layer_count, int page_size, int max_pages, int max_prefix_entries, int max_prefix_tokens, string policy) serving_runtime_state`
- `serving_runtime_submit_request(serving_runtime_state state, string request_id, int prefill_tokens, int remaining_tokens) serving_runtime_state`
- `serving_runtime_schedule_next(serving_runtime_state state) serving_runtime_state`
- `serving_runtime_record_decode(serving_runtime_state state, int decode_tokens) serving_runtime_state`
- `serving_runtime_finish_request(serving_runtime_state state, int release_tokens) serving_runtime_state`
- `serving_runtime_queue_depth(serving_runtime_state state) int`
- `serving_runtime_cache_hits(serving_runtime_state state) int`
- `serving_runtime_cache_misses(serving_runtime_state state) int`
- `serving_runtime_avg_queue_depth(serving_runtime_state state) float`

Minimum tests:

- `tests/test_s_serving_admission.s`
- `tests/test_s_serving_runtime.s`

## 2. Distributed Training

Current canonical modules:

- `distributed/comm/comm.s`
- `distributed/ddp/ddp.s`
- `distributed/tp/tp.s`
- `distributed/tp_collective/tp_collective.s`
- `distributed/pp/pp.s`
- `distributed/pipelining/pipelining.s`
- `distributed/zero/zero.s`
- `distributed/launcher/launcher.s`

Next capabilities:

- process group lifecycle and collective abstraction
- DDP gradient bucket synchronization
- tensor parallel shard mapping
- ZeRO-style optimizer shard bookkeeping
- pipeline stage queues and activation flow

Suggested S APIs:

- `new_process_group(string backend, int rank, int world_size) process_group_state`
- `process_group_rank(process_group_state state) int`
- `process_group_world_size(process_group_state state) int`
- `all_reduce_sum(process_group_state state, []float values) []float`
- `all_gather(process_group_state state, []float values) []float`
- `reduce_scatter_sum(process_group_state state, []float values) []float`
- `new_ddp_state(string name, int bucket_cap, bool find_unused) ddp_state`
- `ddp_mark_grad_ready(ddp_state state, string param_name) ddp_state`
- `ddp_reduce_ready_buckets(ddp_state state, process_group_state pg) ddp_state`
- `new_tp_state(string name, int world_size, int rank) tp_state`
- `tp_shard_param(tp_state state, string param_name, int size) tp_state`
- `tp_all_gather(tp_state state, string param_name) tp_state`
- `new_zero_state(string name, int world_size, int rank) zero_state`
- `zero_shard_optimizer_state(zero_state state, string param_name, int size) zero_state`

Minimum tests:

- `tests/test_distributed_comm.s`
- `tests/test_distributed_ddp.s`
- `tests/test_distributed_launcher.s`
- `tests/test_s_distributed_comm_runtime.s`
- `tests/test_s_distributed_ddp_runtime.s`
- `tests/test_s_distributed_tp_runtime.s`
- `tests/test_s_distributed_zero_runtime.s`

## 3. Compiler and Lowering

Current canonical modules:

- `compile/compiler.s`
- `compile/pipeline.s`
- `compile/ir/ir.s`
- `compile/passes/pass_manager.s`
- `compile/lowering/lowering.s`
- `compile/executor/executor.s`
- `compile/cache/cache.s`
- `compile/runtime/runtime.s`

Next capabilities:

- stable graph capture and lowering transitions
- pass ordering and pass registration
- constant folding and fusion passes
- memory planning metadata
- cache-key tracking for compile reuse

Suggested S APIs:

- `new_pass_manager(string name) pass_manager_state`
- `pass_manager_add(pass_manager_state state, string pass_name) pass_manager_state`
- `pass_manager_run(pass_manager_state state, compile_state graph) compile_state`
- `fuse_pointwise_chain(compile_state graph) compile_state`
- `compile_plan_memory(compile_state graph) compile_state`
- `make_cache_key(string module_name, string backend, string mode, bool dynamic, bool fullgraph, bool debug) string`
- `run_compile_pipeline(string module_name, string backend, string mode, bool dynamic, bool fullgraph, bool debug) compile_pipeline_state`

Minimum tests:

- `tests/test_compile_compiler.s`
- `tests/test_compile_runtime.s`
- `tests/test_s_compile_passes_runtime.s`

## 4. Autograd and Module Ergonomics

Current canonical modules:

- `ad/ad.s`
- `ad/autograd_minimal.s`
- `ad/context.s`
- `ad/eqn.s`
- `ad/function.s`
- `ad/ir.s`
- `ad/tracer.s`
- `autograd/backward.s`
- `autograd/state.s`
- `nn/nn.s`
- `nn/conv.s`
- `nn/pooling.s`
- `nn/activations.s`
- `nn/rnn.s`

Next capabilities:

- gradcheck utilities
- anomaly detection and error metadata
- module containers
- attention building blocks
- module-state serialization helpers

Suggested S APIs:

- `gradcheck_run(string op_name, []float input, float eps, float atol, float rtol) bool`
- `anomaly_set_enabled(bool enabled) anomaly_state`
- `anomaly_detect_step(anomaly_state state, []float grads) anomaly_state`
- `new_module_list() module_list_state`
- `module_list_add(module_list_state state, string module_name) module_list_state`
- `new_module_dict() module_dict_state`
- `module_dict_set(module_dict_state state, string key, string module_name) module_dict_state`
- `scaled_dot_product_attention([]float q, []float k, []float v, int head_dim) []float`

Minimum tests:

- `tests/test_autograd.s`
- `tests/test_tensor.s`
- `tests/test_transformer.s`
- `tests/test_s_autograd_gradcheck_runtime.s`
- `tests/test_s_autograd_anomaly_runtime.s`
- `tests/test_s_nn_container_runtime.s`
- `tests/test_s_attention_runtime.s`

## 5. Quantization, Export, and Diagnostics

Target files:

- `runtime/quant.s`
- `runtime/export.s`
- `runtime/profiler.s`

Next capabilities:

- observer state and calibration statistics
- fake-quant flows for training-aware quantization
- export metadata for downstream tooling
- timeline events and step-level diagnostics

Suggested S APIs:

- `new_observer_state(string name) observer_state`
- `observer_update(observer_state state, []float values) observer_state`
- `quantize_dynamic([]float values, float scale, int zero_point) []int`
- `qat_fake_quant([]float values, float scale, int zero_point) []float`
- `export_graph_manifest(compile_state graph, string out_path) string`
- `profiler_start(string run_name) profiler_state`
- `profiler_record(profiler_state state, string event_name, int duration_us, string category) profiler_state`
- `profiler_stop(profiler_state state) profiler_state`
- `profiler_summary(profiler_state state) []string`

Minimum tests:

- `tests/test_s_quant_runtime.s`
- `tests/test_s_export_runtime.s`
- `tests/test_s_profiler_runtime.s`

## Migration Rule

Keep new code in the canonical S directories.
Use `infer/` only as compatibility surface while old callers are being migrated.
Use `s-compile-runtime` as the verification path for every new module batch.

