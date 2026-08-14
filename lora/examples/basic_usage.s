package neurx.lora.examples.basic_usage

use std.vec.vec
use std.option.option
use std.result.result
use std.map.map

use neurx.lora.lora_config::{lora_config}
use neurx.lora.lora_adapter::{lora_adapter}
use neurx.lora.lora_manager::{lora_adapter_manager}

func example_create_basic_adapter() result[(), string] {

    let mut config = lora_config::default()
    config.lora_rank = 8
    config.lora_alpha = 16.0
    config.lora_dropout = 0.05

    let mut target_modules = vec[string]()
    target_modules.push("q_proj")
    target_modules.push("v_proj")
    config.target_modules = target_modules

    config.validate().map_err(|e| e.message)?

    let mut adapter = lora_adapter::new("lora_basic", &config)

    let mut lora_a = vec[vec[float]]()
    let i = 0
    while i < 768 {
        let mut row = vec[float]()
        let j = 0
        while j < 8 {
            row.push(0.01)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    let mut lora_b = vec[vec[float]]()
    let i = 0
    while i < 8 {
        let mut row = vec[float]()
        let j = 0
        while j < 768 {
            row.push(0.0)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    adapter.add_module_weights("q_proj", lora_a, lora_b)?

    adapter.validate()?

    println("✓ Created LoRA adapter: " + adapter.name)
    println("  Size: " + adapter.get_size_mb().to_string() + " MB")
    println("  Modules: " + adapter.get_module_names().len().to_string())

    result::ok(())
}

func example_apply_lora() result[(), string] {

    let mut config = lora_config::default()
    config.lora_rank = 4
    config.lora_alpha = 8.0

    let mut targets = vec[string]()
    targets.push("dense")
    config.target_modules = targets

    let mut adapter = lora_adapter::new("lora_apply", &config)

    let mut lora_a = vec[vec[float]]()
    let i = 0
    while i < 64 {
        let mut row = vec[float]()
        let j = 0
        while j < 4 {
            row.push(0.01 * j as float)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    let mut lora_b = vec[vec[float]]()
    let i = 0
    while i < 4 {
        let mut row = vec[float]()
        let j = 0
        while j < 32 {
            row.push(0.02)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    adapter.add_module_weights("dense", lora_a, lora_b)?

    let mut input = vec[float]()
    let i = 0
    while i < 64 {
        input.push(1.0)
        i = i + 1
    }

    let output = adapter.apply_lora("dense", input, 1.0)?

    println("✓ Applied LoRA")
    println("  Input size: " + input.len().to_string())
    println("  Output size: " + output.len().to_string())

    result::ok(())
}

func example_adapter_manager() result[(), string] {
    let mut manager = lora_adapter_manager::new()

    let mut config1 = lora_config::default()
    config1.lora_rank = 8
    let mut targets1 = vec[string]()
    targets1.push("q_proj")
    config1.target_modules = targets1

    let adapter1 = lora_adapter::new("adapter_1", &config1)
    manager.add_adapter("adapter_1", &adapter1)?

    let mut config2 = lora_config::default()
    config2.lora_rank = 16
    let mut targets2 = vec[string]()
    targets2.push("v_proj")
    config2.target_modules = targets2

    let adapter2 = lora_adapter::new("adapter_2", &config2)
    manager.add_adapter("adapter_2", &adapter2)?

    manager.activate_adapter("adapter_1")?
    manager.activate_adapter("adapter_2")?

    let active = manager.get_active_adapters()
    println("✓ Created adapter manager")
    println("  Total adapters: " + manager.list_adapters().len().to_string())
    println("  Active adapters: " + active.len().to_string())

    manager.set_global_scale(0.5)?

    manager.deactivate_adapter("adapter_2")?
    println("  Active after deactivation: " + manager.get_active_adapters().len().to_string())

    result::ok(())
}

func example_batch_apply_lora() result[(), string] {
    let mut config = lora_config::default()
    config.lora_rank = 4
    let mut targets = vec[string]()
    targets.push("linear")
    config.target_modules = targets

    let mut adapter = lora_adapter::new("lora_batch", &config)

    let mut lora_a = vec[vec[float]]()
    let i = 0
    while i < 32 {
        let mut row = vec[float]()
        let j = 0
        while j < 4 {
            row.push(0.01)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    let mut lora_b = vec[vec[float]]()
    let i = 0
    while i < 4 {
        let mut row = vec[float]()
        let j = 0
        while j < 16 {
            row.push(0.02)
            j = j + 1
        }
        lora_b.push(row)
        i = i + 1
    }

    adapter.add_module_weights("linear", lora_a, lora_b)?

    let mut inputs = vec[&vec[float]]()
    let batch_size = 4
    let seq_len = 32

    let b = 0
    while b < batch_size {
        let mut input = vec[float]()
        let s = 0
        while s < seq_len {
            input.push(1.0)
            s = s + 1
        }
        inputs.push(input)
        b = b + 1
    }

    let outputs = adapter.apply_lora_batch("linear", inputs, 1.0)?

    println("✓ Batch applied LoRA")
    println("  Batch size: " + batch_size.to_string())
    println("  Output count: " + outputs.len().to_string())

    result::ok(())
}

func main() {
    println("=== LoRA 基础使用示例 ===\n")

    switch example_create_basic_adapter() {
        result::ok(_) : {},
        result::err(e) : println("Error in example_create_basic_adapter: " + e),
    }

    println()

    switch example_apply_lora() {
        result::ok(_) : {},
        result::err(e) : println("Error in example_apply_lora: " + e),
    }

    println()

    switch example_adapter_manager() {
        result::ok(_) : {},
        result::err(e) : println("Error in example_adapter_manager: " + e),
    }

    println()

    switch example_batch_apply_lora() {
        result::ok(_) : {},
        result::err(e) : println("Error in example_batch_apply_lora: " + e),
    }

    println("\n=== 所有示例完成 ===")
}
