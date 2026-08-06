package neurx.trainer.distributed

struct distributed_trainer_config {
    string backend
    int world_size
    int rank
    int tensor_parallel
    int pipeline_parallel
    int data_parallel
}

struct distributed_trainer_state {
    distributed_trainer_config config
    int global_step
    bool initialized
}

func new_distributed_trainer_config(int world_size, int rank) distributed_trainer_config {
    distributed_trainer_config {
        backend: "nccl",
        world_size: world_size,
        rank: rank,
        tensor_parallel: 1,
        pipeline_parallel: 1,
        data_parallel: world_size,
    }
}

func new_distributed_trainer_state(distributed_trainer_config config) distributed_trainer_state {
    distributed_trainer_state {
        config: config,
        global_step: 0,
        initialized: true,
    }
}

func distributed_trainer_step(distributed_trainer_state state) distributed_trainer_state {
    distributed_trainer_state {
        config: state.config,
        global_step: state.global_step + 1,
        initialized: state.initialized,
    }
}

func distributed_trainer_state_dict(distributed_trainer_state state) distributed_trainer_state {
    state
}

func distributed_trainer_load_state_dict(distributed_trainer_state state, distributed_trainer_state other) distributed_trainer_state {
    other
}

