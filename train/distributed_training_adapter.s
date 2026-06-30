package neurx.train.distributed_training_adapter

use neurx.distributed.comm
use neurx.train.large_scale_runtime
use neurx.train.parallel

// Bridge the runtime policy into executable distributed collectives.

struct distributed_training_adapter_state {
    large_scale_training_runtime runtime
    training_bridge_state bridge
    train_parallel_state parallel
    bool ready
}

struct distributed_step_result {
    bool sync_gradients
    bool use_allreduce
    bool use_reduce_scatter
    bool use_all_gather
    bool prefetch_now
    []float gradients
    []float reduced_gradients
    []float activations
    []float parameters
    distributed_training_adapter_state adapter
    bool checkpoint_now
    bool log_now
    bool recovery_needed
}

func copy_float([]float values) []float {
    []float out = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func new_distributed_training_adapter(string mode, string backend, int world_size, int rank, int shard_dim) distributed_training_adapter_state {
    large_scale_training_runtime runtime = bridge_runtime_for_mode(mode)
    training_bridge_state bridge = bridge_runtime_state(runtime)
    train_parallel_state parallel_state = new_train_parallel_state(backend, world_size, rank, shard_dim)
    distributed_training_adapter_state {
        runtime: runtime,
        bridge: bridge,
        parallel: parallel_state,
        ready: bridge.ready_for_large_scale_training,
    }
}

func distributed_adapter_refresh(distributed_training_adapter_state adapter) distributed_training_adapter_state {
    training_bridge_state bridge = bridge_runtime_state(adapter.runtime)
    distributed_training_adapter_state {
        runtime: adapter.runtime,
        bridge: bridge,
        parallel: adapter.parallel,
        ready: bridge.ready_for_large_scale_training,
    }
}

func distributed_adapter_is_ready(distributed_training_adapter_state adapter) bool {
    adapter.ready
}

func distributed_adapter_data_parallel_enabled(distributed_training_adapter_state adapter) bool {
    runtime_data_parallel_enabled(adapter.runtime)
}

func distributed_adapter_data_parallel_size(distributed_training_adapter_state adapter) int {
    runtime_data_parallel_size(adapter.runtime)
}

func distributed_adapter_tensor_parallel_size(distributed_training_adapter_state adapter) int {
    runtime_tensor_parallel_size(adapter.runtime)
}

func distributed_adapter_pipeline_parallel_size(distributed_training_adapter_state adapter) int {
    runtime_pipeline_parallel_size(adapter.runtime)
}

func distributed_adapter_sync_gradients(distributed_training_adapter_state adapter, []float gradients) []float {
    if !bridge_should_use_allreduce(adapter.runtime) {
        return copy_float(gradients)
    }
    train_parallel_all_reduce_grad(adapter.parallel, gradients)
}

func distributed_adapter_reduce_scatter(distributed_training_adapter_state adapter, []float gradients) []float {
    if !bridge_should_use_reduce_scatter(adapter.runtime) {
        return copy_float(gradients)
    }
    train_parallel_reduce_scatter_grad(adapter.parallel, gradients)
}

func distributed_adapter_all_gather_activation(distributed_training_adapter_state adapter, []float activations) []float {
    if !bridge_should_use_all_gather(adapter.runtime) {
        return copy_float(activations)
    }
    train_parallel_all_gather_activation(adapter.parallel, activations)
}

func distributed_adapter_all_gather_parameters(distributed_training_adapter_state adapter, []float parameters) []float {
    if !bridge_should_use_all_gather(adapter.runtime) {
        return copy_float(parameters)
    }
    train_parallel_all_gather_params(adapter.parallel, parameters)
}

func distributed_adapter_record_step(
    distributed_training_adapter_state adapter,
    int step,
    float loss,
    int batch_tokens,
    bool overflow_detected
) distributed_training_adapter_state {
    distributed_step_result result = distributed_adapter_step(adapter, step, loss, batch_tokens, overflow_detected)
    result.adapter
}

func distributed_adapter_step(
    distributed_training_adapter_state adapter,
    int step,
    float loss,
    int batch_tokens,
    bool overflow_detected
) distributed_step_result {
    training_bridge_actions actions = bridge_runtime_actions(
        adapter.runtime,
        step,
        loss,
        batch_tokens,
        overflow_detected
    )

    distributed_training_adapter_state next_adapter = distributed_training_adapter_state {
        runtime: runtime_record_step(adapter.runtime, loss, batch_tokens, overflow_detected),
        bridge: adapter.bridge,
        parallel: adapter.parallel,
        ready: adapter.ready,
    }
    next_adapter.bridge = bridge_runtime_state(next_adapter.runtime)
    next_adapter.ready = next_adapter.bridge.ready_for_large_scale_training

    []float empty = []float{}
    []float synced = copy_float(empty)
    []float reduced = copy_float(empty)
    []float gathered = copy_float(empty)
    []float params = copy_float(empty)

    if actions.sync_gradients {
        synced = distributed_adapter_sync_gradients(adapter, empty)
    }
    if actions.use_reduce_scatter {
        reduced = distributed_adapter_reduce_scatter(adapter, empty)
    }
    if actions.use_all_gather {
        gathered = distributed_adapter_all_gather_activation(adapter, empty)
        params = distributed_adapter_all_gather_parameters(adapter, empty)
    }

    distributed_step_result {
        sync_gradients: actions.sync_gradients,
        use_allreduce: actions.use_allreduce,
        use_reduce_scatter: actions.use_reduce_scatter,
        use_all_gather: actions.use_all_gather,
        prefetch_now: actions.prefetch_now,
        gradients: synced,
        reduced_gradients: reduced,
        activations: gathered,
        parameters: params,
        adapter: next_adapter,
        checkpoint_now: actions.checkpoint_now,
        log_now: actions.log_now,
        recovery_needed: actions.recovery_needed,
    }
}

func distributed_adapter_register_param(distributed_training_adapter_state adapter, string param_name, int size) distributed_training_adapter_state {
    distributed_training_adapter_state {
        runtime: adapter.runtime,
        bridge: adapter.bridge,
        parallel: train_parallel_register_param(adapter.parallel, param_name, size),
        ready: adapter.ready,
    }
}

func distributed_adapter_mark_grad_ready(distributed_training_adapter_state adapter, string param_name) distributed_training_adapter_state {
    distributed_training_adapter_state {
        runtime: adapter.runtime,
        bridge: adapter.bridge,
        parallel: train_parallel_mark_grad_ready(adapter.parallel, param_name),
        ready: adapter.ready,
    }
}

func distributed_adapter_finalize_step(distributed_training_adapter_state adapter) distributed_training_adapter_state {
    distributed_training_adapter_state {
        runtime: adapter.runtime,
        bridge: adapter.bridge,
        parallel: train_parallel_finalize_step(adapter.parallel),
        ready: adapter.ready,
    }
}

func distributed_adapter_summary(distributed_training_adapter_state adapter) string {
    bridge_summary_text(adapter.runtime)
}
