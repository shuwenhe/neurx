package neurx.model.weight_loader
use neurx.runtime.io.{runtime_read_binary_file, runtime_file_exists}
use std.io.eprintln

// Safetensors file structure:
// [8 bytes header length (little-endian u64)]
// [N bytes JSON metadata]
// [tensor data...]

struct model_weights {
    // Embedding
    []float embed_tokens          // [151936, 896]
    
    // 24 layers
    []layer_weights layers
    
    // Final norm
    []float norm_weight            // [896]
    
    // LM head (reuse embed_tokens for tied weights)
    bool weights_loaded
}

struct layer_weights {
    // Attention projections
    []float q_proj                 // [896, 896]
    []float k_proj                 // [896, 896]
    []float v_proj                 // [896, 896]
    []float o_proj                 // [896, 896]
    
    // MLP projections
    []float gate_proj              // [896, 4864]
    []float up_proj                // [896, 4864]
    []float down_proj              // [4864, 896]
    
    // Layer norms
    []float input_layernorm        // [896]
    []float post_attention_layernorm  // [896]
}

// Parse little-endian u64
func parse_u64_le([]int bytes, int offset) int {
    int b0 = bytes[offset]
    int b1 = bytes[offset + 1]
    int b2 = bytes[offset + 2]
    int b3 = bytes[offset + 3]
    int b4 = bytes[offset + 4]
    int b5 = bytes[offset + 5]
    int b6 = bytes[offset + 6]
    int b7 = bytes[offset + 7]
    
    // For small header sizes, lower 4 bytes should be enough
    int result = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
    result
}

// Parse little-endian f32
func parse_f32_le([]int bytes, int offset) float {
    int b0 = bytes[offset]
    int b1 = bytes[offset + 1]
    int b2 = bytes[offset + 2]
    int b3 = bytes[offset + 3]
    
    // Simple approximation: interpret as float
    // TODO: proper IEEE 754 parsing
    int bits = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
    
    // Sign bit
    int sign = 1
    if b3 >= 128 {
        sign = -1
    }
    
    // Simplified conversion (works for small values)
    float val = (bits as float) / 1000000.0
    val * (sign as float)
}

// Load a single tensor from safetensors data
func load_tensor_simple([]int file_bytes, int tensor_offset, int num_elements) []float {
    []float data = []float{cap: num_elements}
    
    int i = 0
    while i < num_elements {
        float val = parse_f32_le(file_bytes, tensor_offset + i * 4)
        data[i] = val
        i = i + 1
    }
    
    data
}

// Simplified weight loader (mock for Phase 1)
func load_model_weights_mock(string model_dir, int hidden_size, int num_layers) model_weights {
    eprintln("[Weight Loader] Loading mock weights for testing")
    eprintln("[Weight Loader] Model dir: " + model_dir)
    eprintln("[Weight Loader] Hidden size: " + int_to_str(hidden_size))
    eprintln("[Weight Loader] Num layers: " + int_to_str(num_layers))
    
    int vocab_size = 151936
    int intermediate_size = 4864
    
    // Create mock layers
    []layer_weights layers = []layer_weights{cap: num_layers}
    int i = 0
    while i < num_layers {
        layers[i] = layer_weights{
            q_proj: init_gaussian(hidden_size * hidden_size, 0.02),
            k_proj: init_gaussian(hidden_size * hidden_size, 0.02),
            v_proj: init_gaussian(hidden_size * hidden_size, 0.02),
            o_proj: init_gaussian(hidden_size * hidden_size, 0.02),
            gate_proj: init_gaussian(hidden_size * intermediate_size, 0.02),
            up_proj: init_gaussian(hidden_size * intermediate_size, 0.02),
            down_proj: init_gaussian(intermediate_size * hidden_size, 0.02),
            input_layernorm: ones_array(hidden_size),
            post_attention_layernorm: ones_array(hidden_size)
        }
        i = i + 1
    }
    
    model_weights{
        embed_tokens: init_gaussian(vocab_size * hidden_size, 0.02),
        layers: layers,
        norm_weight: ones_array(hidden_size),
        weights_loaded: true
    }
}

func init_gaussian(int size, float std) []float {
    []float arr = []float{cap: size}
    int i = 0
    while i < size {
        // Simple pseudo-random initialization
        float val = ((i * 12345 + 67890) - ((i * 12345 + 67890) / 100000) * 100000) as float
        val = (val / 100000.0 - 0.5) * std * 2.0
        arr[i] = val
        i = i + 1
    }
    arr
}

func ones_array(int size) []float {
    []float arr = []float{cap: size}
    int i = 0
    while i < size {
        arr[i] = 1.0
        i = i + 1
    }
    arr
}

func int_to_str(int x) string {
    if x == 0 { return "0" }
    if x < 0 { return "-" + int_to_str(0 - x) }
    
    string result = ""
    int num = x
    while num > 0 {
        int digit = num - ((num / 10) * 10)
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
        num = num / 10
    }
    result
}
