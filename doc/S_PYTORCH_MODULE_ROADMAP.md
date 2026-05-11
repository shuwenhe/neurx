# Neurx S Language PyTorch-Parity Roadmap

This document defines an implementation-first module split for S language development.
The focus is: distributed training core, parallel strategies, autograd completeness,
compiler path, and deployment basics.

## 1) Directory-Oriented Module Split

### 1.1 Distributed Communication Core (P0)

Target files:

- distributed/comm.s
- distributed/process_group.s
- distributed/reducer.s

Core capabilities:

- process group lifecycle (init, destroy)
- collective ops abstraction (all_reduce, all_gather, reduce_scatter, broadcast, barrier)
- p2p abstraction (send, recv, batch_send_recv)
- gradient bucket state and flush policy

Suggested S APIs:

- new_process_group(string backend, int rank, int world_size) process_group_state
- process_group_state_dict(process_group_state state) process_group_state
- process_group_load_state_dict(process_group_state state, process_group_state other) process_group_state
- process_group_rank(process_group_state state) int
- process_group_world_size(process_group_state state) int
- all_reduce_sum(process_group_state state, []float values) []float
- all_reduce_mean(process_group_state state, []float values) []float
- all_gather(process_group_state state, []float values) []float
- reduce_scatter_sum(process_group_state state, []float values) []float
- p2p_send(process_group_state state, int peer_rank, []float payload) process_group_state
- p2p_recv(process_group_state state, int peer_rank, int expected_size) []float

Minimum tests:

- test/test_distributed_comm.s
- test/test_s_distributed_comm_runtime.py


### 1.2 DDP Core (P0)

Target files:

- distributed/ddp.s

Core capabilities:

- parameter broadcast on startup
- gradient bucketing
- overlap-friendly reducer state machine
- mean gradient synchronization

Suggested S APIs:

- new_ddp_state(string name, int bucket_cap, bool find_unused) ddp_state
- ddp_state_dict(ddp_state state) ddp_state
- ddp_load_state_dict(ddp_state state, ddp_state other) ddp_state
- ddp_add_param(ddp_state state, string param_name, int size) ddp_state
- ddp_mark_grad_ready(ddp_state state, string param_name) ddp_state
- ddp_reduce_ready_buckets(ddp_state state, process_group_state pg) ddp_state
- ddp_finalize_step(ddp_state state) ddp_state

Minimum tests:

- test/test_distributed_ddp.s
- test/test_s_distributed_ddp_runtime.py


### 1.3 FSDP Core (P1)

Target files:

- distributed/fsdp.s
- distributed/shard.s

Core capabilities:

- parameter flatten and sharding metadata
- pre-forward all_gather state
- post-backward reduce_scatter state
- optimizer state sharding hooks

Suggested S APIs:

- new_fsdp_state(string name, int world_size, int rank, bool cpu_offload) fsdp_state
- fsdp_state_dict(fsdp_state state) fsdp_state
- fsdp_load_state_dict(fsdp_state state, fsdp_state other) fsdp_state
- fsdp_register_param(fsdp_state state, string name, int size) fsdp_state
- fsdp_pre_forward_all_gather(fsdp_state state, process_group_state pg) fsdp_state
- fsdp_post_backward_reduce_scatter(fsdp_state state, process_group_state pg) fsdp_state
- fsdp_free_full_params(fsdp_state state) fsdp_state

Minimum tests:

- test/test_distributed_fsdp.s
- test/test_s_distributed_fsdp_runtime.py


### 1.4 Pipeline Parallel Runtime (P1)

Current base exists:

- distributed/pipelining.s
- runtime/pp.s

Next capabilities:

- explicit activation channel model
- explicit gradient channel model
- stage-local execution queue
- interop with DDP/FSDP reducers

Suggested incremental S APIs:

- pipeline_send_activation(pipeline_schedule_state state, int to_stage, []float payload) pipeline_schedule_state
- pipeline_recv_activation(pipeline_schedule_state state, int from_stage, int expected_size) []float
- pipeline_send_gradient(pipeline_schedule_state state, int to_stage, []float payload) pipeline_schedule_state
- pipeline_recv_gradient(pipeline_schedule_state state, int from_stage, int expected_size) []float
- pipeline_step_forward(pipeline_schedule_state state) pipeline_schedule_state
- pipeline_step_backward(pipeline_schedule_state state) pipeline_schedule_state

Minimum tests:

- extend test/test_distributed_pipelining.py
- add test/test_s_pipeline_p2p_runtime.py


### 1.5 Autograd Completeness (P1)

Target files:

- ad/gradcheck.s
- ad/anomaly.s

Core capabilities:

- finite-difference gradcheck
- anomaly context and metadata
- nan/inf gradient detector

Suggested S APIs:

- gradcheck_run(string op_name, []float input, float eps, float atol, float rtol) bool
- anomaly_set_enabled(bool enabled) anomaly_state
- anomaly_state_dict(anomaly_state state) anomaly_state
- anomaly_detect_step(anomaly_state state, []float grads) anomaly_state
- anomaly_has_error(anomaly_state state) bool

Minimum tests:

- test/test_s_autograd_gradcheck_runtime.py
- test/test_s_autograd_anomaly_runtime.py


### 1.6 Compile and Graph Optimization (P1)

Target files:

- runtime/compile_passes.s
- ad/fusion.s

Core capabilities:

- pass manager state
- simple fusion opportunities (pointwise chains)
- memory planning metadata

Suggested S APIs:

- new_pass_manager(string name) pass_manager_state
- pass_manager_add(pass_manager_state state, string pass_name) pass_manager_state
- pass_manager_run(pass_manager_state state, compile_state graph) compile_state
- fuse_pointwise_chain(compile_state graph) compile_state
- compile_plan_memory(compile_state graph) compile_state

Minimum tests:

- test/test_s_compile_passes_runtime.py


### 1.7 Module Containers and High-Level NN (P1-P2)

Target files:

- nn/container.s
- nn/attention.s

Core capabilities:

- ModuleList/ModuleDict/ParameterList semantics
- scaled dot-product attention core path

Suggested S APIs:

- new_module_list() module_list_state
- module_list_add(module_list_state state, string module_name) module_list_state
- new_module_dict() module_dict_state
- module_dict_set(module_dict_state state, string key, string module_name) module_dict_state
- scaled_dot_product_attention([]float q, []float k, []float v, int head_dim) []float

Minimum tests:

- test/test_s_nn_container_runtime.py
- test/test_s_attention_runtime.py


### 1.8 Quantization and Export (P2)

Target files:

- runtime/quant.s
- runtime/export.s

Core capabilities:

- calibration stats and observer state
- fake quant path for qat
- export metadata for onnx-style bridge

Suggested S APIs:

- new_observer_state(string name) observer_state
- observer_update(observer_state state, []float values) observer_state
- quantize_dynamic([]float values, float scale, int zero_point) []int
- qat_fake_quant([]float values, float scale, int zero_point) []float
- export_graph_manifest(compile_state graph, string out_path) string

Minimum tests:

- test/test_s_quant_runtime.py
- test/test_s_export_runtime.py


### 1.9 Profiler and Runtime Diagnostics (P2)

Target files:

- runtime/profiler.s

Core capabilities:

- timeline event recording
- step-level summary stats
- communication vs compute counters

Suggested S APIs:

- profiler_start(string run_name) profiler_state
- profiler_record(profiler_state state, string event_name, int duration_us, string category) profiler_state
- profiler_stop(profiler_state state) profiler_state
- profiler_summary(profiler_state state) []string

Minimum tests:

- test/test_s_profiler_runtime.py


## 2) Suggested Delivery Waves

Wave A (must-have):

- distributed/comm.s
- distributed/ddp.s
- distributed/pipelining.s communication extension

Wave B (scale-up):

- distributed/fsdp.s
- ad/gradcheck.s
- runtime/compile_passes.s

Wave C (ecosystem):

- nn/container.s
- nn/attention.s
- runtime/quant.s
- runtime/export.s
- runtime/profiler.s


## 3) Build Integration Checklist

Required Makefile behavior:

- compile distributed/*.s into build/ir/distributed/*.ir
- include new S modules in manifest generation

Required runtime bridge behavior:

- add _invoke_special_module_function dispatch branches for each new module
- add corresponding dict/like helpers for stable S struct interop


## 4) Acceptance Criteria (Per Module)

- S source compiles via s compiler into expected build/ir path
- runtime.supports_runtime_function(module, function) covers exported APIs
- state_dict/load_state_dict round-trip passes
- at least one deterministic runtime test and one Python wrapper test pass
