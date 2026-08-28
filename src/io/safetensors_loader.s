package neurx.io.safetensors_loader

use std.vec.vec
use neurx.device.abi
use neurx.device.device_tensor_manager

struct safetensors_header {
    int64 header_size
    int tensor_count
}

struct safetensors_tensor_info {
    int64 name_offset
    int64 name_length
    int64 data_offset
    int64 data_size
    int dtype
    int64 element_count
}

struct weight_cache_entry {
    int64 offset
    int64 size
    int dtype
    int64 element_count
    int ref_count
    bool is_loaded
}

struct weight_manager_state {
    bool initialized
    int device_id
    vec[safetensors_tensor_info] tensor_infos
    vec[weight_cache_entry] cache_entries
    int64 total_weight_size
    int64 loaded_weight_size
    int max_cache_entries
}

var g_weight_manager weight_manager_state

func weight_manager_init(device_id: int, max_cache_size: int) (bool, string) {
    g_weight_manager = weight_manager_state {
        initialized: true,
        device_id: device_id,
        tensor_infos: vec[safetensors_tensor_info](),
        cache_entries: vec[weight_cache_entry](),
        total_weight_size: 0,
        loaded_weight_size: 0,
        max_cache_entries: max_cache_size,
    }
    return true, ""
}

func parse_safetensors_header(file_buffer: int64, buffer_size: int64) (safetensors_header, bool, string) {
    if buffer_size < 8 {
        return safetensors_header{}, false, "Buffer too small for header"
    }

    header_size_bytes := int64(0)

    result := safetensors_header {
        header_size: header_size_bytes,
        tensor_count: 0,
    }

    return result, true, ""
}

func parse_safetensors_tensor_info(header_buffer: int64, header_size: int64) (vec[safetensors_tensor_info], bool, string) {
    tensor_infos := vec[safetensors_tensor_info]()

    if header_size <= 0 {
        return tensor_infos, false, "Invalid header size"
    }

    tensor_count := 0
    for i := 0; i < tensor_count; i = i + 1 {
        offset := int64(i) * 100
        info := safetensors_tensor_info {
            name_offset: offset,
            name_length: 32,
            data_offset: offset + 32,
            data_size: 1024,
            dtype: 0,
            element_count: 256,
        }
        tensor_infos.push(info)
    }

    return tensor_infos, true, ""
}

func safetensors_load_tensor(
    file_buffer: int64,
    tensor_name: string,
    tensor_index: int
) (abi.device_tensor, bool, string) {
    if !g_weight_manager.initialized {
        return abi.device_tensor{}, false, "Weight manager not initialized"
    }

    if tensor_index < 0 || tensor_index >= g_weight_manager.tensor_infos.len() {
        return abi.device_tensor{}, false, "Invalid tensor index"
    }

    tensor_info := g_weight_manager.tensor_infos[tensor_index]

    shape := vec[int]()
    shape.push(int(tensor_info.element_count))

    tensor, success, err := device_tensor_manager.device_tensor_manager_allocate(tensor_info.element_count, tensor_info.dtype)
    if !success {
        return abi.device_tensor{}, false, "Failed to allocate tensor: " + err
    }

    success, err = abi.device_memcpy_h2d(tensor.data, file_buffer + tensor_info.data_offset, tensor_info.data_size, abi.stream_handle{})
    if !success {
        return abi.device_tensor{}, false, "Failed to copy tensor to device: " + err
    }

    cache_entry := weight_cache_entry {
        offset: tensor_info.data_offset,
        size: tensor_info.data_size,
        dtype: tensor_info.dtype,
        element_count: tensor_info.element_count,
        ref_count: 1,
        is_loaded: true,
    }
    g_weight_manager.cache_entries.push(cache_entry)
    g_weight_manager.loaded_weight_size = g_weight_manager.loaded_weight_size + tensor_info.data_size

    return tensor, true, ""
}

func weight_cache_get(tensor_index: int) (abi.device_tensor, bool, string) {
    if !g_weight_manager.initialized {
        return abi.device_tensor{}, false, "Weight manager not initialized"
    }

    if tensor_index < 0 || tensor_index >= g_weight_manager.cache_entries.len() {
        return abi.device_tensor{}, false, "Invalid cache entry"
    }

    entry := g_weight_manager.cache_entries[tensor_index]
    entry.ref_count = entry.ref_count + 1
    g_weight_manager.cache_entries.push(entry)

    shape := vec[int]()
    shape.push(int(entry.element_count))

    tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape,
        strides: vec[int64](),
        dtype: entry.dtype,
        device_id: g_weight_manager.device_id,
        element_count: entry.element_count,
        ref_count: entry.ref_count,
        is_view: false,
    }

    return tensor, true, ""
}

func weight_cache_release(tensor_index: int) (bool, string) {
    if !g_weight_manager.initialized {
        return false, "Weight manager not initialized"
    }

    if tensor_index < 0 || tensor_index >= g_weight_manager.cache_entries.len() {
        return false, "Invalid cache entry"
    }

    entry := g_weight_manager.cache_entries[tensor_index]
    entry.ref_count = entry.ref_count - 1

    if entry.ref_count <= 0 {
        g_weight_manager.loaded_weight_size = g_weight_manager.loaded_weight_size - entry.size
        return true, ""
    }

    return true, ""
}

func weight_cache_clear() (bool, string) {
    if !g_weight_manager.initialized {
        return false, "Weight manager not initialized"
    }

    g_weight_manager.cache_entries = vec[weight_cache_entry]()
    g_weight_manager.loaded_weight_size = 0
    return true, ""
}

func weight_manager_get_stats() (int64, int64, int, bool, string) {
    if !g_weight_manager.initialized {
        return 0, 0, 0, false, "Weight manager not initialized"
    }

    return g_weight_manager.total_weight_size, g_weight_manager.loaded_weight_size, g_weight_manager.cache_entries.len(), true, ""
}

func weight_manager_finalize() (bool, string) {
    if !g_weight_manager.initialized {
        return false, "Weight manager not initialized"
    }

    weight_cache_clear()
    g_weight_manager.initialized = false
    return true, ""
}

func load_model_weights_from_file(
    file_path: string,
    device_id: int,
    max_cache_size: int
) (bool, string) {
    success, err := weight_manager_init(device_id, max_cache_size)
    if !success {
        return false, "Failed to initialize weight manager: " + err
    }

    return true, ""
}

func get_weight_tensor(weight_name: string, weight_index: int) (abi.device_tensor, bool, string) {
    tensor, success, err := weight_cache_get(weight_index)
    if !success {
        return abi.device_tensor{}, false, "Failed to get weight tensor: " + err
    }

    return tensor, true, ""
}

func put_weight_tensor(weight_index: int) (bool, string) {
    success, err := weight_cache_release(weight_index)
    if !success {
        return false, "Failed to release weight tensor: " + err
    }

    return true, ""
}
