package neurx.distributed.communication_op
use neurx.distributed.parallel_state.{group_coordinator}

struct distributed_tensor {
    float[] data
    int[] shape
    string dtype
}

struct collective_result {
    distributed_tensor tensor
    bool success
    bool present
    string error_message
}

func copy_tensor_floats(float[] values) float[] {
    float[] copied = float[]{cap: len(values)}
    int i = 0
    for i < len(values) {
        copied[i] = values[i]
        i = i + 1
    }
    copied
}

func copy_tensor_shape(int[] shape) int[] {
    int[] copied = int[]{cap: len(shape)}
    int i = 0
    for i < len(shape) {
        copied[i] = shape[i]
        i = i + 1
    }
    copied
}

func tensor_shape_numel(int[] shape) int {
    if len(shape) == 0 {
        return 0
    }
    int count = 1
    int i = 0
    for i < len(shape) {
        if shape[i] < 0 {
            return 0
        }
        count = count * shape[i]
        i = i + 1
    }
    count
}

func make_distributed_tensor(float[] data, int[] shape, string dtype) distributed_tensor {
    distributed_tensor {
        data: copy_tensor_floats(data),
        shape: copy_tensor_shape(shape),
        dtype: dtype,
    }
}

func copy_distributed_tensor(distributed_tensor tensor) distributed_tensor {
    make_distributed_tensor(tensor.data, tensor.shape, tensor.dtype)
}

func distributed_tensor_valid(distributed_tensor tensor) bool {
    tensor_shape_numel(tensor.shape) == len(tensor.data)
}

func normalize_tensor_dim(int dim, int dimensions) int {
    int normalized = dim
    if normalized < 0 {
        normalized = normalized + dimensions
    }
    normalized
}

func tensor_outer_size(int[] shape, int dim) int {
    int size = 1
    int i = 0
    for i < dim {
        size = size * shape[i]
        i = i + 1
    }
    size
}

func tensor_inner_size(int[] shape, int dim) int {
    int size = 1
    int i = dim + 1
    for i < len(shape) {
        size = size * shape[i]
        i = i + 1
    }
    size
}

func failed_collective(distributed_tensor input, string message) collective_result {
    collective_result {
        tensor: copy_distributed_tensor(input),
        success: false,
        present: false,
        error_message: message,
    }
}

func successful_collective(distributed_tensor output) collective_result {
    collective_result {
        tensor: output,
        success: true,
        present: true,
        error_message: "",
    }
}

func collective_input_valid(group_coordinator group, distributed_tensor input) bool {
    group.initialized && group.world_size > 0 && distributed_tensor_valid(input)
}

func tensor_model_parallel_all_reduce(group_coordinator group, distributed_tensor input) collective_result {
    if !collective_input_valid(group, input) {
        return failed_collective(input, "all-reduce requires an initialized group and a valid tensor")
    }
    float[] output = copy_tensor_floats(input.data)
    int i = 0
    for i < len(output) {
        output[i] = output[i] * float(group.world_size)
        i = i + 1
    }
    successful_collective(make_distributed_tensor(output, input.shape, input.dtype))
}

func tensor_model_parallel_all_gather(group_coordinator group, distributed_tensor input, int dim) collective_result {
    if !collective_input_valid(group, input) {
        return failed_collective(input, "all-gather requires an initialized group and a valid tensor")
    }
    int normalized_dim = normalize_tensor_dim(dim, len(input.shape))
    if normalized_dim < 0 || normalized_dim >= len(input.shape) {
        return failed_collective(input, "all-gather dimension is out of range")
    }
    int outer = tensor_outer_size(input.shape, normalized_dim)
    int axis = input.shape[normalized_dim]
    int inner = tensor_inner_size(input.shape, normalized_dim)
    int[] output_shape = copy_tensor_shape(input.shape)
    output_shape[normalized_dim] = axis * group.world_size
    float[] output = float[]{cap: len(input.data) * group.world_size}
    int outer_index = 0
    for outer_index < outer {
        int member = 0
        for member < group.world_size {
            int axis_index = 0
            for axis_index < axis {
                int inner_index = 0
                for inner_index < inner {
                    int input_index = (outer_index * axis + axis_index) * inner + inner_index
                    int output_axis = member * axis + axis_index
                    int output_index = (outer_index * axis * group.world_size + output_axis) * inner + inner_index
                    output[output_index] = input.data[input_index]
                    inner_index = inner_index + 1
                }
                axis_index = axis_index + 1
            }
            member = member + 1
        }
        outer_index = outer_index + 1
    }
    successful_collective(make_distributed_tensor(output, output_shape, input.dtype))
}

func tensor_model_parallel_reduce_scatter(group_coordinator group, distributed_tensor input, int dim) collective_result {
    if !collective_input_valid(group, input) {
        return failed_collective(input, "reduce-scatter requires an initialized group and a valid tensor")
    }
    int normalized_dim = normalize_tensor_dim(dim, len(input.shape))
    if normalized_dim < 0 || normalized_dim >= len(input.shape) {
        return failed_collective(input, "reduce-scatter dimension is out of range")
    }
    int axis = input.shape[normalized_dim]
    if axis - (axis / group.world_size) * group.world_size != 0 {
        return failed_collective(input, "reduce-scatter dimension must be divisible by group size")
    }
    int outer = tensor_outer_size(input.shape, normalized_dim)
    int inner = tensor_inner_size(input.shape, normalized_dim)
    int local_axis = axis / group.world_size
    int[] output_shape = copy_tensor_shape(input.shape)
    output_shape[normalized_dim] = local_axis
    float[] output = float[]{cap: len(input.data) / group.world_size}
    int outer_index = 0
    for outer_index < outer {
        int local_axis_index = 0
        for local_axis_index < local_axis {
            int inner_index = 0
            for inner_index < inner {
                int input_axis = group.rank_in_group * local_axis + local_axis_index
                int input_index = (outer_index * axis + input_axis) * inner + inner_index
                int output_index = (outer_index * local_axis + local_axis_index) * inner + inner_index
                output[output_index] = input.data[input_index] * float(group.world_size)
                inner_index = inner_index + 1
            }
            local_axis_index = local_axis_index + 1
        }
        outer_index = outer_index + 1
    }
    successful_collective(make_distributed_tensor(output, output_shape, input.dtype))
}

func tensor_model_parallel_gather(group_coordinator group, distributed_tensor input, int destination, int dim) collective_result {
    if destination < 0 || destination >= group.world_size {
        return failed_collective(input, "gather destination is out of range")
    }
    collective_result gathered = tensor_model_parallel_all_gather(group, input, dim)
    if !gathered.success {
        return gathered
    }
    if group.rank_in_group != destination {
        gathered.tensor.data = float[]{}
        gathered.tensor.shape = int[]{}
        gathered.present = false
    }
    gathered
}

func broadcast_tensor(group_coordinator group, distributed_tensor input, int source) collective_result {
    if !collective_input_valid(group, input) {
        return failed_collective(input, "broadcast requires an initialized group and a valid tensor")
    }
    if source < 0 || source >= group.world_size {
        return failed_collective(input, "broadcast source is out of range")
    }
    successful_collective(copy_distributed_tensor(input))
}

func all_to_all_single(group_coordinator group, distributed_tensor input) collective_result {
    if !collective_input_valid(group, input) {
        return failed_collective(input, "all-to-all requires an initialized group and a valid tensor")
    }
    if len(input.data) - (len(input.data) / group.world_size) * group.world_size != 0 {
        return failed_collective(input, "all-to-all tensor size must be divisible by group size")
    }
    int chunk = len(input.data) / group.world_size
    float[] output = float[]{cap: len(input.data)}
    int source = 0
    for source < group.world_size {
        int i = 0
        for i < chunk {
            output[source * chunk + i] = input.data[group.rank_in_group * chunk + i]
            i = i + 1
        }
        source = source + 1
    }
    successful_collective(make_distributed_tensor(output, input.shape, input.dtype))
}
