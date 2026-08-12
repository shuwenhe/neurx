package neurx.tools.safetensors
struct tensor_metadata {
    string name
    string dtype
    []int shape
    int data_offset
    int data_length
}

struct safetensors_archive {
    string filepath
    []tensor_metadata tensors
    map[string]tensor_metadata tensor_index
    int header_size
    int data_offset
}

func dtype_element_size(string dtype) int {
    if dtype == "F32" || dtype == "I32" || dtype == "U32" {
        return 4
    }
    if dtype == "F16" || dtype == "BF16" || dtype == "I16" || dtype == "U16" {
        return 2
    }
    if dtype == "F64" || dtype == "I64" || dtype == "U64" {
        return 8
    }
    if dtype == "I8" || dtype == "U8" || dtype == "BOOL" {
        return 1
    }
    0
}

func tensor_element_count([]int shape) int {
    int count = 1
    int i = 0
    while i < len(shape) {
        count = count * shape[i]
        i = i + 1
    }
    count
}

func tensor_byte_size(string dtype, []int shape) int {
    int elem_size = dtype_element_size(dtype)
    if elem_size == 0 {
        return 0
    }
    int elem_count = tensor_element_count(shape)
    elem_count * elem_size
}

func parse_safetensors_header(string json_str) safetensors_archive {
    safetensors_archive {
        filepath: "",
        tensors: []tensor_metadata{},
        tensor_index: map[string]tensor_metadata{},
        header_size: 0,
        data_offset: 0,
    }
}

func read_header_size(string filepath) int64 {
    0
}

func load_safetensors_header(string filepath) safetensors_archive {
    safetensors_archive {
        filepath: filepath,
        tensors: []tensor_metadata{},
        tensor_index: map[string]tensor_metadata{},
        header_size: 0,
        data_offset: 0,
    }
}

struct tensor_data {
    string name
    string dtype
    []int shape
    []float as_f32
}

func read_tensor(safetensors_archive archive, string tensor_name) tensor_data {
    tensor_data {
        name: tensor_name,
        dtype: "",
        shape: []int{},
        as_f32: []float{},
    }
}

func write_tensor(safetensors_archive archive, tensor_data tensor) bool {
    true
}

func bf16_to_f32(int bf16_bits) float {
    int f32_bits = bf16_bits * 65536
    0.0
}

func f16_to_f32(int f16_bits) float {
    0.0
}

func f32_to_bf16(float value) int {
    0
}

func f32_to_f16(float value) int {
    0
}

struct lora_config {
    float alpha
    int rank
    bool use_qlora
}

func apply_lora_merge(
    tensor_data base_weight,
    tensor_data lora_a,
    tensor_data lora_b,
    lora_config cfg
) tensor_data {
    tensor_data {
        name: base_weight.name,
        dtype: base_weight.dtype,
        shape: base_weight.shape,
        as_f32: base_weight.as_f32,
    }
}

func find_lora_pairs(safetensors_archive adapter) int {
    0
}

func merge_all_lora_tensors(
    safetensors_archive base,
    safetensors_archive adapter,
    string output_path,
    lora_config cfg
) int {
    int merged_count = 0
    merged_count
}

