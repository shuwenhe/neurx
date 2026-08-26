package neurx.net.collective

use std.vec.vec

struct tensor_descriptor {
    int tensor_id
    int total_size
    int element_type
    int rank
}

struct collective_operation {
    int op_id
    string op_type
    vec[int] participant_ranks
    tensor_descriptor tensor_desc
    int status
}

struct collective_context {
    int rank
    int world_size
    vec[collective_operation] operations
    int op_counter
}

func create_collective_context(int rank, int world_size) collective_context {
    ctx := collective_context {
        rank: rank,
        world_size: world_size,
        operations: vec[collective_operation](),
        op_counter: 0
    }
    ctx
}

func allreduce_op(collective_context ctx, tensor_descriptor desc) collective_context {
    op := collective_operation {
        op_id: ctx.op_counter,
        op_type: "allreduce",
        participant_ranks: vec[int](),
        tensor_desc: desc,
        status: 0
    }
    ctx.operations.push(op)
    ctx.op_counter = ctx.op_counter + 1
    ctx
}

func allgather_op(collective_context ctx, tensor_descriptor desc) collective_context {
    op := collective_operation {
        op_id: ctx.op_counter,
        op_type: "allgather",
        participant_ranks: vec[int](),
        tensor_desc: desc,
        status: 0
    }
    ctx.operations.push(op)
    ctx.op_counter = ctx.op_counter + 1
    ctx
}

func broadcast_op(collective_context ctx, int root_rank, tensor_descriptor desc) collective_context {
    op := collective_operation {
        op_id: ctx.op_counter,
        op_type: "broadcast",
        participant_ranks: vec[int](),
        tensor_desc: desc,
        status: 0
    }
    ctx.operations.push(op)
    ctx.op_counter = ctx.op_counter + 1
    ctx
}

func reduce_scatter_op(collective_context ctx, tensor_descriptor desc) collective_context {
    op := collective_operation {
        op_id: ctx.op_counter,
        op_type: "reduce_scatter",
        participant_ranks: vec[int](),
        tensor_desc: desc,
        status: 0
    }
    ctx.operations.push(op)
    ctx.op_counter = ctx.op_counter + 1
    ctx
}
