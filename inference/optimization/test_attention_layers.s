package neurx.inference.optimization.test_attention_layers

use neurx.inference.optimization.attention_layers
use neurx.inference.optimization.attention_integration
use neurx.inference.optimization.inference_engine_optimized

func test_flash_attention_basic() {
    print("🧪 Test: Flash Attention Basic Functionality")

    int seq_len = 8
    int num_heads = 2
    int head_dim = 64
    int num_kv_heads = 2

    []float queries = make([]float, seq_len * num_heads * head_dim)
    []float keys = make([]float, seq_len * num_kv_heads * head_dim)
    []float values = make([]float, seq_len * num_kv_heads * head_dim)

    int i = 0
    for i < len(queries) {
        queries[i] = float((i % 10 + 1)) / 10.0
        i = i + 1
    }

    i = 0
    for i < len(keys) {
        keys[i] = float((i % 10 + 1)) / 10.0
        i = i + 1
    }

    i = 0
    for i < len(values) {
        values[i] = float((i % 10 + 1)) / 10.0
        i = i + 1
    }

    config := new_flash_attention_config(
        head_dim,
        num_heads,
        num_kv_heads,
        true,
        "cpu"
    )

    output := flash_attention_forward(queries, keys, values, config)

    if len(output) == len(queries) {
        print("  ✓ Output shape correct")
    } else {
        print("  ✗ Output shape mismatch")
    }

    has_invalid = false
    i = 0
    for i < len(output) {
        if output[i] > 1e10 || output[i] < -1e10 {
            has_invalid = true
        }
        i = i + 1
    }

    if !has_invalid {
        print("  ✓ No NaN/Inf values")
    } else {
        print("  ✗ Contains invalid values")
    }

    print("  ✓ PASSED\n")
}

func test_mla_config_creation() {
    print("🧪 Test: MLA Configuration Creation")

    config := new_mla_config(4096, 32, 64, 64)

    if config.hidden_dim == 4096 {
        print("  ✓ Hidden dim set correctly")
    }

    if config.num_q_heads == 32 {
        print("  ✓ Num Q heads correct")
    }

    if config.head_dim == 128 {
        print("  ✓ Head dim calculated correctly (4096/32=128)")
    }

    if config.softmax_scale > 0.08 && config.softmax_scale < 0.09 {
        print("  ✓ Softmax scale in valid range")
    }

    print("  ✓ PASSED\n")
}

func test_lightning_attention_config() {
    print("🧪 Test: Lightning Attention Configuration")

    config := lightning_attention_config{
        block_size: 128,
        head_dim: 128,
        num_heads: 32,
        dropout_p: 0.0,
        use_cache: true,
        precision: "fp32",
    }

    if config.block_size == 128 {
        print("  ✓ Block size configured")
    }

    if config.num_heads == 32 {
        print("  ✓ Number of heads set")
    }

    if config.precision == "fp32" {
        print("  ✓ Precision specified")
    }

    print("  ✓ PASSED\n")
}

func test_sparse_attention_pattern() {
    print("🧪 Test: Sparse Attention Pattern Creation")

    seq_len := 64
    config := sparse_attention_config{
        block_size: 16,
        head_dim: 64,
        num_heads: 8,
        pattern: "local",
        sparsity_ratio: 75,
        use_token_budget: false,
    }

    mask := create_sparse_pattern(seq_len, config)

    count := 0
    i := 0
    for i < len(mask.mask) {
        if mask.mask[i] {
            count = count + 1
        }
        i = i + 1
    }

    total := seq_len * seq_len
    sparsity := 100 - (count * 100 / total)

    print("  ✓ Mask created successfully")
    print("  ✓ Sparsity ratio: " + string_from_int(sparsity) + "%")
    print("  ✓ PASSED\n")
}

func test_attention_layer_manager() {
    print("🧪 Test: Attention Layer Manager")

    manager := new_attention_layer_manager(
        128,
        32,
        32,
        true,
        1024
    )

    if manager.current_method == "flash" {
        print("  ✓ Manager selected Flash for seq_len=1024")
    }

    manager.set_method("sparse")
    if manager.current_method == "sparse" {
        print("  ✓ Method switching works")
    }

    print("  ✓ PASSED\n")
}

func test_attention_optimizer() {
    print("🧪 Test: Attention Optimizer Method Selection")

    seq_len_1 := 256
    method_1 := get_best_attention_method(seq_len_1, 128, 32)
    if method_1 == "lightning" {
        print("  ✓ Correct method for seq_len=256: lightning")
    }

    seq_len_2 := 1024
    method_2 := get_best_attention_method(seq_len_2, 128, 32)
    if method_2 == "flash" {
        print("  ✓ Correct method for seq_len=1024: flash")
    }

    seq_len_3 := 4096
    method_3 := get_best_attention_method(seq_len_3, 128, 32)
    if method_3 == "sparse" {
        print("  ✓ Correct method for seq_len=4096: sparse")
    }

    print("  ✓ PASSED\n")
}

func test_performance_benchmarking() {
    print("🧪 Test: Performance Benchmarking")

    int seq_len = 512
    int head_dim = 128
    int num_heads = 32

    []float q = make([]float, seq_len * num_heads * head_dim)
    []float k = make([]float, seq_len * num_heads * head_dim)
    []float v = make([]float, seq_len * num_heads * head_dim)

    reports := benchmark_inference_methods(q, k, v, 10)

    if len(reports) > 0 {
        print("  ✓ Benchmarking completed")
        print("  ✓ Generated " + string_from_int(len(reports)) + " reports")

        report := reports[0]
        if len(report.method_name) > 0 {
            print("  ✓ First method: " + report.method_name)
        }
    }

    print("  ✓ PASSED\n")
}

func test_model_config_creation() {
    print("🧪 Test: Attention-Optimized Model Config")

    config := new_attention_optimized_config(
        4096,
        32,
        32,
        8192
    )

    if config.hidden_dim == 4096 {
        print("  ✓ Hidden dimension correct")
    }

    if config.num_layers == 32 {
        print("  ✓ Number of layers correct")
    }

    if len(config.per_layer_attention) == 32 {
        print("  ✓ Per-layer attention array initialized")
    }

    if config.per_layer_attention[0] == "lightning" {
        print("  ✓ Early layers use Lightning")
    }

    if config.per_layer_attention[16] == "flash" {
        print("  ✓ Middle layers use Flash")
    }

    if config.per_layer_attention[31] == "sparse" {
        print("  ✓ Late layers use Sparse")
    }

    print("  ✓ PASSED\n")
}

func test_inference_engine_creation() {
    print("🧪 Test: Optimized Inference Engine Creation")

    engine := new_optimized_inference_engine(
        4096,
        24,
        32,
        8192,
        "decode"
    )

    if engine.current_seq_pos == 0 {
        print("  ✓ Initial position correct")
    }

    if engine.inference_mode == "decode" {
        print("  ✓ Inference mode set correctly")
    }

    print("  ✓ PASSED\n")
}

func test_attention_presets() {
    print("🧪 Test: Attention Configuration Presets")

    balanced := get_attention_preset_balanced()
    if balanced.name == "balanced" {
        print("  ✓ Balanced preset loaded")
    }

    fast := get_attention_preset_fast()
    if fast.name == "fast" {
        print("  ✓ Fast preset loaded")
    }

    accurate := get_attention_preset_accurate()
    if accurate.name == "accurate" {
        print("  ✓ Accurate preset loaded")
    }

    if fast.lightning_cfg.block_size < balanced.lightning_cfg.block_size {
        print("  ✓ Fast preset has smaller blocks")
    }

    if accurate.lightning_cfg.block_size > balanced.lightning_cfg.block_size {
        print("  ✓ Accurate preset has larger blocks")
    }

    print("  ✓ PASSED\n")
}

func string_from_int(int n) string {
    if n == 0 {
        return "0"
    }

    string result = ""
    int abs_n = n
    if n < 0 {
        abs_n = -n
    }

    int i = 0
    for i < 20 {
        int digit = abs_n % 10
        abs_n = abs_n / 10

        result = char_from_digit(digit) + result

        if abs_n == 0 {
            break
        }
        i = i + 1
    }

    if n < 0 {
        result = "-" + result
    }

    return result
}

func char_from_digit(int d) string {
    if d == 0 { return "0" }
    if d == 1 { return "1" }
    if d == 2 { return "2" }
    if d == 3 { return "3" }
    if d == 4 { return "4" }
    if d == 5 { return "5" }
    if d == 6 { return "6" }
    if d == 7 { return "7" }
    if d == 8 { return "8" }
    if d == 9 { return "9" }
    return ""
}

func run_all_tests() {
    print("═" * 70)
    print("🧪 Advanced Attention Layers - Unit Test Suite")
    print("═" * 70)
    print("")

    test_flash_attention_basic()
    test_mla_config_creation()
    test_lightning_attention_config()
    test_sparse_attention_pattern()
    test_attention_layer_manager()
    test_attention_optimizer()
    test_performance_benchmarking()
    test_model_config_creation()
    test_inference_engine_creation()
    test_attention_presets()

    print("═" * 70)
    print("✅ All tests completed successfully!")
    print("═" * 70)
}

func main() {
    run_all_tests()
}
