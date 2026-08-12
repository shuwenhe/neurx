package neurx.distributed.two_t_training
use neurx.distributed.comm.{process_group_state, new_process_group, process_group_rank, process_group_world_size, process_group_state_dict, process_group_load_state_dict}
use neurx.distributed.ddp.{ddp_state, new_ddp_state, ddp_attach_process_group, ddp_is_distributed, ddp_state_dict, ddp_load_state_dict, ddp_finalize_step, ddp_sync_scale}

struct two_t_training_plan {
    int world_size
    int rank
    int tensor_parallel_degree
    int pipeline_parallel_degree
    int data_parallel_degree
    int sequence_parallel_degree
    int zero_stage
    int batch_size
    int micro_batch_size
    int seq_len
    int max_steps
    bool activation_checkpointing
    bool cpu_offload
    string backend
    process_group_state process_group
    ddp_state ddp
    int step
    int epoch
}


func two_t_mod_nonneg(int value, int divisor) int {
    if divisor <= 0 {
        return 0
    }
    int current = value
    while current >= divisor {
        current = current - divisor
    }
    while current < 0 {
        current = current + divisor
    }
    current
}


func recommended_two_t_plan(int world_size, int rank) two_t_training_plan {
    int tp = 16
    int pp = 8
    int sp = 4
    int dp = 2
    if world_size >= 512 {
        tp = 32
        pp = 16
        sp = 4
        dp = 1
    }
    two_t_training_plan {
        world_size: world_size,
        rank: rank,
        tensor_parallel_degree: tp,
        pipeline_parallel_degree: pp,
        data_parallel_degree: dp,
        sequence_parallel_degree: sp,
        zero_stage: 3,
        batch_size: 2048,
        micro_batch_size: 4,
        seq_len: 8192,
        max_steps: 1000000,
        activation_checkpointing: true,
        cpu_offload: false,
        backend: "nccl",
        process_group: new_process_group("nccl", rank, world_size),
        ddp: ddp_attach_process_group(new_ddp_state("two_t", 256, false), new_process_group("nccl", rank, world_size)),
        step: 0,
        epoch: 0,
    }
}


func new_two_t_training_plan(int world_size, int rank) two_t_training_plan {
    recommended_two_t_plan(world_size, rank)
}


func two_t_training_plan_state_dict(two_t_training_plan plan) two_t_training_plan {
    two_t_training_plan {
        world_size: plan.world_size,
        rank: plan.rank,
        tensor_parallel_degree: plan.tensor_parallel_degree,
        pipeline_parallel_degree: plan.pipeline_parallel_degree,
        data_parallel_degree: plan.data_parallel_degree,
        sequence_parallel_degree: plan.sequence_parallel_degree,
        zero_stage: plan.zero_stage,
        batch_size: plan.batch_size,
        micro_batch_size: plan.micro_batch_size,
        seq_len: plan.seq_len,
        max_steps: plan.max_steps,
        activation_checkpointing: plan.activation_checkpointing,
        cpu_offload: plan.cpu_offload,
        backend: plan.backend,
        process_group: process_group_state_dict(plan.process_group),
        ddp: ddp_state_dict(plan.ddp),
        step: plan.step,
        epoch: plan.epoch,
    }
}


func two_t_training_plan_load_state_dict(two_t_training_plan plan, two_t_training_plan other) two_t_training_plan {
    two_t_training_plan {
        world_size: other.world_size,
        rank: other.rank,
        tensor_parallel_degree: other.tensor_parallel_degree,
        pipeline_parallel_degree: other.pipeline_parallel_degree,
        data_parallel_degree: other.data_parallel_degree,
        sequence_parallel_degree: other.sequence_parallel_degree,
        zero_stage: other.zero_stage,
        batch_size: other.batch_size,
        micro_batch_size: other.micro_batch_size,
        seq_len: other.seq_len,
        max_steps: other.max_steps,
        activation_checkpointing: other.activation_checkpointing,
        cpu_offload: other.cpu_offload,
        backend: other.backend,
        process_group: process_group_load_state_dict(plan.process_group, other.process_group),
        ddp: ddp_load_state_dict(plan.ddp, other.ddp),
        step: other.step,
        epoch: other.epoch,
    }
}


func two_t_training_plan_step(two_t_training_plan plan) two_t_training_plan {
    two_t_training_plan {
        world_size: plan.world_size,
        rank: plan.rank,
        tensor_parallel_degree: plan.tensor_parallel_degree,
        pipeline_parallel_degree: plan.pipeline_parallel_degree,
        data_parallel_degree: plan.data_parallel_degree,
        sequence_parallel_degree: plan.sequence_parallel_degree,
        zero_stage: plan.zero_stage,
        batch_size: plan.batch_size,
        micro_batch_size: plan.micro_batch_size,
        seq_len: plan.seq_len,
        max_steps: plan.max_steps,
        activation_checkpointing: plan.activation_checkpointing,
        cpu_offload: plan.cpu_offload,
        backend: plan.backend,
        process_group: plan.process_group,
        ddp: ddp_finalize_step(plan.ddp),
        step: plan.step + 1,
        epoch: plan.epoch,
    }
}


func two_t_training_plan_ddp_scale(two_t_training_plan plan) float {
    ddp_sync_scale(plan.ddp)
}


func two_t_training_plan_summary(two_t_training_plan plan) string {
    string out = "two_t_training_plan("
    out = out + "world_size=" + string(plan.world_size)
    out = out + ", rank=" + string(plan.rank)
    out = out + ", tp=" + string(plan.tensor_parallel_degree)
    out = out + ", pp=" + string(plan.pipeline_parallel_degree)
    out = out + ", dp=" + string(plan.data_parallel_degree)
    out = out + ", sp=" + string(plan.sequence_parallel_degree)
    out = out + ", zero_stage=" + string(plan.zero_stage)
    out = out + ", batch_size=" + string(plan.batch_size)
    out = out + ", micro_batch_size=" + string(plan.micro_batch_size)
    out = out + ", seq_len=" + string(plan.seq_len)
    out = out + ", max_steps=" + string(plan.max_steps)
    out = out + ", ddp_distributed=" + string(ddp_is_distributed(plan.ddp))
    out = out + ", ddp_scale=" + string(two_t_training_plan_ddp_scale(plan))
    out = out + ")"
    out
}

