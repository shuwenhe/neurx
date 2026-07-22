package neurx.distributed

func get_dtype_size(string dtype) int {
    switch dtype {
        case "fp32":
            4
        case "fp16":
            2
        case "bf16":
            2
        case "int32":
            4
        case "int8":
            1
        default:
            4
    }
}

func log_collective_op(
    string op_name,
    string reduce_type,
    int bytes,
    int world_size
) {

    println("NCCL " + op_name + "(" + reduce_type + "): " +
            int_to_string(bytes) + " bytes across " +
            int_to_string(world_size) + " GPUs")
}
