package neurx.lora.examples.basic_usage

use std.vec.vec
use std.option.option
use std.result.result
use std.map.map

use neurx.lora.lora_config::{lora_config}
use neurx.lora.lora_adapter::{lora_adapter}
use neurx.lora.lora_manager::{lora_adapter_manager}

func example_create_basic_adapter() result[(), string] {

    config := lora_config::default()
    config.lora_rank = 8
    config.lora_alpha = 16.0
    config.lora_dropout = 0.05

    target_modules := vec[string]()
    target_modules.push("q_proj")
    target_modules.push("v_proj")
    config.target_modules = target_modules

    config.validate().map_err(|e| e.message)

    adapter := lora_adapter::new("lora_basic", &config)

    lora_a := vec[vec[float]]()
    i := 0
    while i < 768 {
        row := vec[float]()
        j := 0
        while j < 8 {
            row.push(0.01)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    lora_b := vec[vec[float]]()
    i := 0
    while i < 8 {
        row := vec[float]()
        j := 0
        while j < 768 {
            row.push(0.0)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    adapter.add_module_weights("q_proj", lora_a, lora_b)

    adapter.validate()

    println("✓ Created LoRA adapter: " + adapter.name)
    println("  Size: " + adapter.get_size_mb().to_string() + " MB")
    println("  Modules: " + adapter.get_module_names().len().to_string())

    ((, ""))
}

func example_apply_lora() result[(), string] {

    config := lora_config::default()
    config.lora_rank = 4
    config.lora_alpha = 8.0

    targets := vec[string]()
    targets.push("dense")
    config.target_modules = targets

    adapter := lora_adapter::new("lora_apply", &config)

    lora_a := vec[vec[float]]()
    i := 0
    while i < 64 {
        row := vec[float]()
        j := 0
        while j < 4 {
            row.push(0.01 * j as float)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    lora_b := vec[vec[float]]()
    i := 0
    while i < 4 {
        row := vec[float]()
        j := 0
        while j < 32 {
            row.push(0.02)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    adapter.add_module_weights("dense", lora_a, lora_b)

    input := vec[float]()
    i := 0
    while i < 64 {
        input.push(1.0)
        i = i + 1
    }

    output := adapter.apply_lora("dense", input, 1.0)

    println("✓ Applied LoRA")
    println("  Input size: " + input.len().to_string())
    println("  Output size: " + output.len().to_string())

    ((, ""))
}

func example_adapter_manager() result[(), string] {
    manager := lora_adapter_manager::new()

    config1 := lora_config::default()
    config1.lora_rank = 8
    targets1 := vec[string]()
    targets1.push("q_proj")
    config1.target_modules = targets1

    adapter1 := lora_adapter::new("adapter_1", &config1)
    manager.add_adapter("adapter_1", &adapter1)

    config2 := lora_config::default()
    config2.lora_rank = 16
    targets2 := vec[string]()
    targets2.push("v_proj")
    config2.target_modules = targets2

    adapter2 := lora_adapter::new("adapter_2", &config2)
    manager.add_adapter("adapter_2", &adapter2)

    manager.activate_adapter("adapter_1")
    manager.activate_adapter("adapter_2")

    active := manager.get_active_adapters()
    println("✓ Created adapter manager")
    println("  Total adapters: " + manager.list_adapters().len().to_string())
    println("  Active adapters: " + active.len().to_string())

    manager.set_global_scale(0.5)

    manager.deactivate_adapter("adapter_2")
    println("  Active after deactivation: " + manager.get_active_adapters().len().to_string())

    ((, ""))
}

func example_batch_apply_lora() result[(), string] {
    config := lora_config::default()
    config.lora_rank = 4
    targets := vec[string]()
    targets.push("linear")
    config.target_modules = targets

    adapter := lora_adapter::new("lora_batch", &config)

    lora_a := vec[vec[float]]()
    i := 0
    while i < 32 {
        row := vec[float]()
        j := 0
        while j < 4 {
            row.push(0.01)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    lora_b := vec[vec[float]]()
    i := 0
    while i < 4 {
        row := vec[float]()
        j := 0
        while j < 16 {
            row.push(0.02)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    adapter.add_module_weights("linear", lora_a, lora_b)

    inputs := vec[&vec[float]]()
    batch_size := 4
    seq_len := 32

    b := 0
    while b < batch_size {
        input := vec[float]()
        s := 0
        while s < seq_len {
            input.push(1.0)
            s = s + 1
        }
        inputs.push(input)
        b = b + 1
    }

    outputs := adapter.apply_lora_batch("linear", inputs, 1.0)

    println("✓ Batch applied LoRA")
    println("  Batch size: " + batch_size.to_string())
    println("  Output count: " + outputs.len().to_string())

    ((, ""))
}

func main() {
    println("=== LoRA 基础使用示例 ===\n")

    switch example_create_basic_adapter() {
        (_, "") : {},
        (0, e) : println("Error in example_create_basic_adapter: " + e),
    }

    println()

    switch example_apply_lora() {
        (_, "") : {},
        (0, e) : println("Error in example_apply_lora: " + e),
    }

    println()

    switch example_adapter_manager() {
        (_, "") : {},
        (0, e) : println("Error in example_adapter_manager: " + e),
    }

    println()

    switch example_batch_apply_lora() {
        (_, "") : {},
        (0, e) : println("Error in example_batch_apply_lora: " + e),
    }

    println("\n=== 所有示例完成 ===")
}
