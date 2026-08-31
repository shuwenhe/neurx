package distributed
    dense
    sparse
    blocked
}

struct tensor_metadata {
    int64[] shape
    string dtype
    tensor_layout layout
    int rank
}

struct distributed_tensor {
    string tensor_id
    tensor_metadata metadata
    tensor_handle local_shard
    int[] shard_locations
    bool requires_sync
    int64 version
}

struct tensor_operation {
    string op_name
    distributed_tensor input
    distributed_tensor output
    comm_op_type comm_type
}

struct tensor_all_reduce {
    string tensor_id
    reduce_op op
    int group_id
}

struct tensor_all_gather {
    string tensor_id
    int group_id
}

func new_distributed_tensor(string tensor_id, int64[] shape, string dtype, tensor_layout layout) distributed_tensor {
    metadata := tensor_metadata {
        shape: shape,
        dtype: dtype,
        layout: layout,
        rank: len(shape),
    }
    local_handle := new_tensor_handle(0, "cuda", 0, 1, dtype)
    shard_locs := []int{}
    distributed_tensor {
        tensor_id: tensor_id,
        metadata: metadata,
        local_shard: local_handle,
        shard_locations: shard_locs,
        requires_sync: false,
        version: 0,
    }
}

func (distributed_tensor* dtensor) mark_dirty() () {
    dtensor.requires_sync = true
    dtensor.version = dtensor.version + 1
}

func (distributed_tensor* dtensor) mark_synced() () {
    dtensor.requires_sync = false
}

func (distributed_tensor* dtensor) get_version() int64 {
    dtensor.version
}

func (distributed_tensor* dtensor) is_synced() bool {
    !dtensor.requires_sync
}

func (distributed_tensor* dtensor) get_shape() []int64 {
    dtensor.metadata.shape
}

func (distributed_tensor* dtensor) get_dtype() string {
    dtensor.metadata.dtype
}

func (distributed_tensor* dtensor) get_rank() int {
    dtensor.metadata.rank
}

struct distributed_tensor_manager {
    map[string, distributed_tensor] tensors
    distributed_context ctx
}

func new_distributed_tensor_manager(distributed_context ctx) distributed_tensor_manager {
    distributed_tensor_manager {
        tensors: map[string, distributed_tensor]{},
        ctx: ctx,
    }
}

func (distributed_tensor_manager* mgr) register_tensor(string tensor_id, int64[] shape, string dtype) string {
    dtensor := new_distributed_tensor(tensor_id, shape, dtype, tensor_layout_dense)
    mgr.tensors[tensor_id] = dtensor
    tensor_id
}

func (distributed_tensor_manager* mgr) get_tensor(string tensor_id) distributed_tensor {
    if tensor_id in mgr.tensors {
        mgr.tensors[tensor_id]
    }
    new_distributed_tensor("", []int64{}, "float32", tensor_layout_dense)
}

func (distributed_tensor_manager* mgr) has_tensor(string tensor_id) bool {
    tensor_id in mgr.tensors
}

func (distributed_tensor_manager* mgr) remove_tensor(string tensor_id) bool {
    if tensor_id in mgr.tensors {
        del mgr.tensors[tensor_id]
        true
    }
    false
}

func (distributed_tensor_manager* mgr) all_reduce_tensor(string tensor_id, reduce_op op) bool {
    if !mgr.has_tensor(tensor_id) {
        false
    }
    dtensor := mgr.get_tensor(tensor_id)
    comm := mgr.ctx.get_communicator()
    result := comm.all_reduce(dtensor.local_shard, op)
    if result.success {
        dtensor.mark_synced()
        true
    }
    false
}

func (distributed_tensor_manager* mgr) all_gather_tensor(string tensor_id) bool {
    if !mgr.has_tensor(tensor_id) {
        false
    }
    dtensor := mgr.get_tensor(tensor_id)
    comm := mgr.ctx.get_communicator()
    recv_tensors := []tensor_handle{}
    i := 0
    for i < mgr.ctx.get_world_size() {
        recv_tensors = append(recv_tensors, dtensor.local_shard)
        i = i + 1
    }
    result := comm.all_gather(dtensor.local_shard, recv_tensors)
    if result.success {
        dtensor.mark_synced()
        true
    }
    false
}

func (distributed_tensor_manager* mgr) synchronize_all() bool {
    for tid in mgr.tensors.keys() {
        dtensor := mgr.get_tensor(tid)
        if dtensor.requires_sync {
            op := reduce_op_sum()
            mgr.all_reduce_tensor(tid, op)
        }
    }
    true
}
