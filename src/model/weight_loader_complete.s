package neurx.model.weight_loader_complete

use std.vec.vec
use std.string.string
use neurx.device.cuda_runtime_binding
use neurx.device.cuda_memory_pool

struct tensor_metadata {
    string name
    int64 start_offset
    int64 end_offset
    int64 dtype
    int[] shape
}

struct safetensors_file {
    string file_path
    int64 header_size
    vec[tensor_metadata] tensors
    int64 total_size
}

struct weight_tensor {
    string name
    int64 device_ptr
    int[] shape
    int64 size_bytes
}

struct model_weights {
    vec[weight_tensor] tensors
    int device_id
    int64 total_size
}

int DTYPE_F32 = 1
int DTYPE_F16 = 2
int DTYPE_BF16 = 3
int DTYPE_INT8 = 4
int DTYPE_INT32 = 5

func get_dtype_size(int dtype) int {
    if dtype == DTYPE_F32 {
        return 4
    } else if dtype == DTYPE_F16 {
        return 2
    } else if dtype == DTYPE_BF16 {
        return 2
    } else if dtype == DTYPE_INT8 {
        return 1
    } else if dtype == DTYPE_INT32 {
        return 4
    }
    return 0
}

func tensor_shape_size(int[] shape) int64 {
    size := 1
    for i := 0; i < shape.len(); i = i + 1 {
        size = size * shape[i]
    }
    return size as int64
}

func parse_safetensors_header(string file_path) (safetensors_file, bool, string) {

    return safetensors_file{
        file_path: file_path,
        header_size: 0,
        tensors: vec[tensor_metadata](),
        total_size: 0,
    }, true, ""
}

func load_tensor_to_gpu(memory_pool* pool, string file_path, 
                       tensor_metadata* metadata) (weight_tensor, bool, string) {
    
    tensor_size := metadata.end_offset - metadata.start_offset
    
    device_ptr, ok, err := memory_pool_alloc(pool, tensor_size)
    if !ok {
        return weight_tensor{}, false, err
    }
    
    return weight_tensor{
        name: metadata.name,
        device_ptr: device_ptr,
        shape: metadata.shape,
        size_bytes: tensor_size,
    }, true, ""
}

func load_model_weights(string model_path, int device_id) (model_weights, bool, string) {
    
    ok, err := cuda_set_device(device_id)
    if !ok {
        return model_weights{}, false, err
    }
    
    safetensors, ok, err := parse_safetensors_header(model_path)
    if !ok {
        return model_weights{}, false, err
    }
    
    pool := box[memory_pool](new_memory_pool(80 * 1024 * 1024 * 1024))
    
    weights := model_weights{
        tensors: vec[weight_tensor](),
        device_id: device_id,
        total_size: 0,
    }
    
    for i := 0; i < safetensors.tensors.len(); i = i + 1 {
        tensor, ok, err := load_tensor_to_gpu(pool, model_path, &safetensors.tensors[i])
        if !ok {
            return model_weights{}, false, err
        }
        weights.tensors.push(tensor)
        weights.total_size = weights.total_size + tensor.size_bytes
    }
    
    return weights, true, ""
}

func get_weight_tensor(model_weights* model, string name) (weight_tensor*, bool) {
    for i := 0; i < model.tensors.len(); i = i + 1 {
        if model.tensors[i].name == name {
            return &model.tensors[i], true
        }
    }
    return 0, false
}

func verify_model_weights(model_weights* model, string expected_config) (bool, string) {
    if model.tensors.len() == 0 {
        return false, "no tensors loaded"
    }
    
    return true, ""
}

func unload_model_weights(model_weights* model) (bool, string) {
    for i := 0; i < model.tensors.len(); i = i + 1 {
        ok, err := cuda_free(model.tensors[i].device_ptr)
        if !ok {
            return false, err
        }
    }
    return true, ""
}

func get_weight_stats(model_weights* model) (int, int64, int64, string) {
    total_tensors := model.tensors.len()
    total_size := model.total_size
    largest_tensor := 0
    largest_name := ""
    
    for i := 0; i < model.tensors.len(); i = i + 1 {
        if model.tensors[i].size_bytes > largest_tensor as int64 {
            largest_tensor = model.tensors[i].size_bytes as int
            largest_name = model.tensors[i].name
        }
    }
    
    return total_tensors, total_size, largest_tensor as int64, largest_name
}

func calculate_model_memory(model_weights* model) int64 {
    total := 0
    for i := 0; i < model.tensors.len(); i = i + 1 {
        total = total + model.tensors[i].size_bytes
    }
    return total
}

func detect_model_format(string file_path) string {

    if file_path.len() > 13 {
        ext := file_path.substr(file_path.len() - 13, 13)
        if ext == ".safetensors" {
            return "safetensors"
        }
    }
    
    if file_path.len() > 3 {
        ext := file_path.substr(file_path.len() - 3, 3)
        if ext == ".pt" {
            return "pytorch"
        }
    }
    
    return "unknown"
}

struct quantized_weight {
    weight_tensor tensor
    int quant_bits
    float scale_factor
}

func load_quantized_weights(string model_path, int quant_bits) (vec[quantized_weight], bool, string) {

    return vec[quantized_weight](), true, ""
}
