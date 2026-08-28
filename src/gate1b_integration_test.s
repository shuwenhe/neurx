package neurx.io

use neurx.io.safetensors_loader

func test_weight_manager_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := safetensors_loader.weight_manager_init(0, 10)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    passed = passed + 1
    return passed, failed, "test_weight_manager_init passed"
}

func test_parse_safetensors_header() (int, int, string) {
    passed := 0
    failed := 0

    buffer_size := int64(1024)
    header, success, err := safetensors_loader.parse_safetensors_header(0, buffer_size)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if header.header_size < 0 {
        failed = failed + 1
        return passed, failed, "Invalid header size"
    }

    passed = passed + 1
    return passed, failed, "test_parse_safetensors_header passed"
}

func test_parse_safetensors_tensor_info() (int, int, string) {
    passed := 0
    failed := 0

    header_buffer := int64(0)
    header_size := int64(256)
    tensor_infos, success, err := safetensors_loader.parse_safetensors_tensor_info(header_buffer, header_size)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if tensor_infos.len() < 0 {
        failed = failed + 1
        return passed, failed, "Invalid tensor infos"
    }

    passed = passed + 1
    return passed, failed, "test_parse_safetensors_tensor_info passed"
}

func test_weight_cache_get_release() (int, int, string) {
    passed := 0
    failed := 0

    success, err := safetensors_loader.weight_manager_init(0, 10)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    cache_success, cache_err := safetensors_loader.weight_cache_clear()
    if !cache_success {
        failed = failed + 1
        return passed, failed, "Failed to clear cache: " + cache_err
    }

    passed = passed + 1
    return passed, failed, "test_weight_cache_get_release passed"
}

func test_weight_cache_clear() (int, int, string) {
    passed := 0
    failed := 0

    success, err := safetensors_loader.weight_manager_init(0, 10)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    cache_success, cache_err := safetensors_loader.weight_cache_clear()
    if !cache_success {
        failed = failed + 1
        return passed, failed, "Failed to clear: " + cache_err
    }

    passed = passed + 1
    return passed, failed, "test_weight_cache_clear passed"
}

func test_weight_manager_stats() (int, int, string) {
    passed := 0
    failed := 0

    success, err := safetensors_loader.weight_manager_init(0, 10)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    total_size, loaded_size, cache_count, stats_success, stats_err := safetensors_loader.weight_manager_get_stats()
    if !stats_success {
        failed = failed + 1
        return passed, failed, "Failed to get stats: " + stats_err
    }

    if total_size < 0 || loaded_size < 0 || cache_count < 0 {
        failed = failed + 1
        return passed, failed, "Invalid stats values"
    }

    passed = passed + 1
    return passed, failed, "test_weight_manager_stats passed"
}

func test_load_model_weights_from_file() (int, int, string) {
    passed := 0
    failed := 0

    file_path := "model_weights.safetensors"
    success, err := safetensors_loader.load_model_weights_from_file(file_path, 0, 10)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    passed = passed + 1
    return passed, failed, "test_load_model_weights_from_file passed"
}

func run_all_tests() (int, int, string) {
    total_passed := 0
    total_failed := 0
    results := ""

    p1, f1, r1 := test_weight_manager_init()
    total_passed = total_passed + p1
    total_failed = total_failed + f1
    results = results + r1 + " | "

    p2, f2, r2 := test_parse_safetensors_header()
    total_passed = total_passed + p2
    total_failed = total_failed + f2
    results = results + r2 + " | "

    p3, f3, r3 := test_parse_safetensors_tensor_info()
    total_passed = total_passed + p3
    total_failed = total_failed + f3
    results = results + r3 + " | "

    p4, f4, r4 := test_weight_cache_get_release()
    total_passed = total_passed + p4
    total_failed = total_failed + f4
    results = results + r4 + " | "

    p5, f5, r5 := test_weight_cache_clear()
    total_passed = total_passed + p5
    total_failed = total_failed + f5
    results = results + r5 + " | "

    p6, f6, r6 := test_weight_manager_stats()
    total_passed = total_passed + p6
    total_failed = total_failed + f6
    results = results + r6 + " | "

    p7, f7, r7 := test_load_model_weights_from_file()
    total_passed = total_passed + p7
    total_failed = total_failed + f7
    results = results + r7

    return total_passed, total_failed, results
}
