package neurx.distributed.partition
struct partition_info {
    int total_params
    int num_partitions
    int partition_id
    int partition_size
    int start_idx
    int end_idx
}

func create_partition_info(int total_params, int num_partitions, int partition_id) partition_info {
    partition_info info
    info.total_params = total_params
    info.num_partitions = num_partitions
    info.partition_id = partition_id
    info.partition_size = total_params / num_partitions
    int remainder = total_params - (info.partition_size * num_partitions)
    if partition_id < remainder {
        info.partition_size = info.partition_size + 1
        info.start_idx = partition_id * info.partition_size
    } else {
        int offset = remainder * (info.partition_size + 1)
        info.start_idx = offset + (partition_id - remainder) * info.partition_size
    }
    info.end_idx = info.start_idx + info.partition_size
    return info
}

func get_local_partition([]float global_data, partition_info info) []float {
    []float local_data = []
    int i = info.start_idx
    while i < info.end_idx {
        if i < len(global_data) {
            local_data = append(local_data, global_data[i])
        }
        i = i + 1
    }
    return local_data
}

func scatter_partition([]float local_data, partition_info info, int total_size) []float {
    []float global_data = []
    int i = 0
    while i < total_size {
        global_data = append(global_data, 0.0)
        i = i + 1
    }
    i = 0
    int idx = info.start_idx
    while i < len(local_data) && idx < info.end_idx {
        if idx < total_size {
            global_data[idx] = local_data[i]
        }
        i = i + 1
        idx = idx + 1
    }
    return global_data
}

func print_partition_info(partition_info info) {
    println("Partition Info:")
    println("  total_params: " + int_to_string(info.total_params))
    println("  num_partitions: " + int_to_string(info.num_partitions))
    println("  partition_id: " + int_to_string(info.partition_id))
    println("  partition_size: " + int_to_string(info.partition_size))
    println("  start_idx: " + int_to_string(info.start_idx))
    println("  end_idx: " + int_to_string(info.end_idx))
}

func int_to_string(int n) string {
    if n == 0 { return "0" }
    if n == 1 { return "1" }
    if n == 2 { return "2" }
    if n == 3 { return "3" }
    if n == 4 { return "4" }
    if n == 5 { return "5" }
    if n == 6 { return "6" }
    if n == 7 { return "7" }
    if n == 8 { return "8" }
    if n < 0 {
        return "-" + int_to_string(0 - n)
    }
    string result = ""
    int remaining = n
    while remaining >= 10 {
        int digit = remaining - ((remaining / 10) * 10)
        remaining = remaining / 10
        if digit == 0 { result = "0" + result }
        if digit == 1 { result = "1" + result }
        if digit == 2 { result = "2" + result }
        if digit == 3 { result = "3" + result }
        if digit == 4 { result = "4" + result }
        if digit == 5 { result = "5" + result }
        if digit == 6 { result = "6" + result }
        if digit == 7 { result = "7" + result }
        if digit == 8 { result = "8" + result }
        if digit == 9 { result = "9" + result }
    }
    if remaining == 0 { result = "0" + result }
    if remaining == 1 { result = "1" + result }
    if remaining == 2 { result = "2" + result }
    if remaining == 3 { result = "3" + result }
    if remaining == 4 { result = "4" + result }
    if remaining == 5 { result = "5" + result }
    if remaining == 6 { result = "6" + result }
    if remaining == 7 { result = "7" + result }
    if remaining == 8 { result = "8" + result }
    if remaining == 9 { result = "9" + result }
    return result
}

