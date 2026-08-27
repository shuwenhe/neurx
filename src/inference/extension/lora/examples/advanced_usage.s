package neurx.lora.examples.advanced_usage

use std.slices
use std.option.option
use std.result.result
use std.map.map

use neurx.lora.lora_config::{lora_config}
use neurx.lora.lora_adapter::{lora_adapter}
use neurx.lora.weight_fusion::{weight_fusion_engine, compute_lora_delta}
use neurx.lora.lora_state::{lora_state_manager}

func example_weight_fusion() ((), string) {
    println("example 1: 权重融合")

    config := lora_config::default()
    config.lora_rank = 8
    config.lora_alpha = 16.0

    targets := vec[string]()
    targets.push("attention")
    config.target_modules = targets

    adapter := lora_adapter::new("fusion_adapter", *config)

    lora_a := vec[vec[float]]()
    i := 0
    for i < 128 {
        row := vec[float]()
        j := 0
        for j < 8 {
            row.push(0.01)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    lora_b := vec[vec[float]]()
    i := 0
    for i < 8 {
        row := vec[float]()
        j := 0
        for j < 128 {
            row.push(0.01)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    adapter.add_module_weights("attention", lora_a, lora_b)

    original_weights := map[string, *vec[vec[float]]]()
    orig_weight := vec[vec[float]]()
    i := 0
    for i < 128 {
        row := vec[float]()
        j := 0
        for j < 128 {
            row.push(1.0)
            j = j + 1
        }
        orig_weight.push(row)
        i = i + 1
    }
    original_weights.insert("attention", orig_weight)

    adapter.fuse_weights(*original_weights)

    println("  ✓ 权重already融合")
    println("    融合status: " + adapter.is_fused().to_string())
    println("    适配器bigsmall: " + adapter.get_size_mb().to_string() + " MB")

    adapter.unfuse_weights(*original_weights)

    println("  ✓ 权重already反融合")
    println("    融合status: " + adapter.is_fused().to_string())

    ((, ""))
}

func example_lora_state_management() ((), string) {
    println("\nexample 2: 请求statusmanagement")

    state_manager := lora_state_manager::new(4)

    req_ids := vec[string]()
    req_ids.push("req_001")
    req_ids.push("req_002")
    req_ids.push("req_003")

    for req_id in req_ids.iter() {
        adapter_names := vec[string]()
        adapter_names.push("lora_a")

        scales := vec[float]()
        scales.push(1.0)

        state_manager.create_request_state(req_id, adapter_names, scales)
    }

    println("  ✓ 创建ed " + state_manager.get_request_count().to_string() + " item请求")

    for req_id in req_ids.iter() {
        state_manager.activate_request(req_id)
    }

    active_count := state_manager.get_active_request_count()
    println("  ✓ 激活ed " + active_count.to_string() + " item请求")

    state_manager.deactivate_request("req_002")
    println("  ✓ 停useback活跃请求: " + state_manager.get_active_request_count().to_string())

    active := state_manager.get_active_requests()
    println("    活跃请求: " + active.len().to_string())

    ((, ""))
}

func example_multi_adapter_caching() ((), string) {
    println("\nexample 3: more适配器缓存management")

    state_manager := lora_state_manager::new(8)

    adapter_names := vec[string]()
    adapter_names.push("adapter_1")
    adapter_names.push("adapter_2")

    scales := vec[float]()
    scales.push(1.0)
    scales.push(0.5)

    state_manager.create_request_state("multi_req", adapter_names, scales)

    cached_weight := vec[vec[float]]()
    i := 0
    for i < 64 {
        row := vec[float]()
        j := 0
        for j < 64 {
            row.push(1.5)
            j = j + 1
        }
        cached_weight.push(row)
        i = i + 1
    }

    state_manager.cache_fused_weights("multi_req_adapter_1", cached_weight)

    println("  ✓ already缓存融合权重")

    (cache_entries, cache_size) := state_manager.get_cache_stats()
    println("    缓存条目: " + cache_entries.to_string())
    println("    缓存bigsmall: " + cache_size.to_string() + " MB")

    state_manager.clear_request_cache("multi_req")
    println("  ✓ alreadyclear除请求缓存")

    (cache_entries, _) := state_manager.get_cache_stats()
    println("    clear除back缓存条目: " + cache_entries.to_string())

    ((, ""))
}

func example_dynamic_adapter_switch() ((), string) {
    println("\nexample 4: 动态适配器切换")

    state_manager := lora_state_manager::new(4)

    init_adapters := vec[string]()
    init_adapters.push("task_a")

    init_scales := vec[float]()
    init_scales.push(1.0)

    state_manager.create_request_state("dynamic_req", init_adapters, init_scales)

    switch state_manager.get_request_state("dynamic_req") {
        option::some(state) : {
            println("  ✓ 初始适配器: " + state.adapter_names[0])
            println("    初始缩放: " + state.adapter_scales[0].to_string())
        },
        option::none : {},
    }

    new_adapters := vec[string]()
    new_adapters.push("task_b")
    new_adapters.push("task_c")

    new_scales := vec[float]()
    new_scales.push(0.8)
    new_scales.push(0.2)

    state_manager.switch_adapters("dynamic_req", new_adapters, new_scales)

    switch state_manager.get_request_state("dynamic_req") {
        option::some(state) : {
            println("  ✓ already切换适配器")
            println("    new适配器数: " + state.adapter_names.len().to_string())
            println("    thoneitem适配器: " + state.adapter_names[0])
        },
        option::none : {},
    }

    updated_scales := vec[float]()
    updated_scales.push(0.5)
    updated_scales.push(0.5)

    state_manager.update_adapter_scales("dynamic_req", updated_scales)
    println("  ✓ already更new缩放because子")

    ((, ""))
}

func example_weight_computation_perf() ((), string) {
    println("\nexample 5: 权重计算ity能")

    engine := weight_fusion_engine::new(8, 16.0)

    println("  ✓ 创建融合engine")
    println("    rank: 8")
    println("    alpha: 16.0")
    println("    缩放because子: " + engine.scaling_factor.to_string())

    lora_a := vec[vec[float]]()
    i := 0
    for i < 256 {
        row := vec[float]()
        j := 0
        for j < 8 {
            row.push(0.01)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    lora_b := vec[vec[float]]()
    i := 0
    for i < 8 {
        row := vec[float]()
        j := 0
        for j < 256 {
            row.push(0.01)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    delta := compute_lora_delta(lora_a, lora_b, engine.scaling_factor)

    println("  ✓ 计算complete")
    println("    输入形状: (" + lora_a.len().to_string() + ", " + lora_a[0].len().to_string() + ")")
    println("    权重形状: (" + lora_b.len().to_string() + ", " + lora_b[0].len().to_string() + ")")
    println("    输出形状: (" + delta.len().to_string() + ", " + delta[0].len().to_string() + ")")

    ((, ""))
}

func main() {
    println("=== LoRA high级使useexample ===\n")

    switch example_weight_fusion() {
        (_, "") : {},
        (0, e) : println("Error: " + e),
    }

    switch example_lora_state_management() {
        (_, "") : {},
        (0, e) : println("Error: " + e),
    }

    switch example_multi_adapter_caching() {
        (_, "") : {},
        (0, e) : println("Error: " + e),
    }

    switch example_dynamic_adapter_switch() {
        (_, "") : {},
        (0, e) : println("Error: " + e),
    }

    switch example_weight_computation_perf() {
        (_, "") : {},
        (0, e) : println("Error: " + e),
    }

    println("\n=== allexamplecomplete ===")
}
