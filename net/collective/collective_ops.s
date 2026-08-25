package neurx.net.collective


    allreduce,
    allgather,
    broadcast,
    reduce_scatter
}

struct collective_request {
    collective_operation operation
    int participant_count
    int data_size_bytes
    int timeout_ms
}

struct collective_result {
    bool success
    int* result_data
    int result_size
    int latency_us
}

struct collective_group {
    int group_id
    int* participant_ids
    int participant_count
}

func create_collective_group(int* participant_ids, int count) result[collective_group, string] {
    (collective_group {
        group_id: 0,
        participant_ids: participant_ids,
        participant_count: count
    })
}

func execute_allreduce(collective_group* group, int data_ptr, int data_size) result[collective_result, string] {
    (collective_result {
        success: true,
        result_data: 0 as int*,
        result_size: data_size,
        latency_us: 1000
    })
}

func execute_allgather(collective_group* group, int* local_data, int local_size) result[collective_result, string] {
    (collective_result {
        success: true,
        result_data: 0 as int*,
        result_size: local_size * group*.participant_count,
        latency_us: 2000
    })
}

func execute_broadcast(collective_group* group, int root_id, int data_ptr, int data_size) result[collective_result, string] {
    (collective_result {
        success: true,
        result_data: 0 as int*,
        result_size: data_size,
        latency_us: 500
    })
}
