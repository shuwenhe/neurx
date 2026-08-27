package neurx.lora.examples.basic_usage

use std.slices
use std.option.option
use std.result.result
use std.map.map

use neurx.lora.lora_config::{lora_config}
use neurx.lora.lora_adapter::{lora_adapter}
use neurx.lora.lora_manager::{lora_adapter_manager}

func example_create_basic_adapter() ((), string) {

    config := lora_config::default()
    config.lora_rank = 8
    config.lora_alpha = 16.0
    config.lora_dropout = 0.05

    target_modules := string[]()
    target_modules = append(target_modules, "q_proj")
    target_modules = append(target_modules, "v_proj")
    config.target_modules = target_modules

    config.validate().map_err(|e| e.message)

    adapter := lora_adapter::new("lora_basic", *config)

    lora_a := float[][]]()
    i := 0
    for i < 768 {
        row := float[]()
        j := 0
        for j < 8 {
            row = append(row, 0.01)
            j = j + 1
        }
        lora_a = append(lora_a, row)
        i = i + 1
    }

    lora_b := float[][]]()
    i := 0
    for i < 8 {
        row := float[]()
        j := 0
        for j < 768 {
            row = append(row, 0.0)
            j = j + 1
        }
        lora_b = append(lora_b, row)
        i = i + 1
    }

    adapter.add_module_weights("q_proj", lora_a, lora_b)

    adapter.validate()

    println("✓ Created LoRA adapter: " + adapter.name)
    println("  Size: " + adapter.get_size_mb().to_string() + " MB")
    println("  Modules: " + adapter.get_module_names().len().to_string())

    return (), ""
}

func example_apply_lora() ((), string) {

    config := lora_config::default()
    config.lora_rank = 4
    config.lora_alpha = 8.0

    targets := string[]()
    targets = append(targets, "dense")
    config.target_modules = targets

    adapter := lora_adapter::new("lora_apply", *config)

    lora_a := float[][]]()
    i := 0
    for i < 64 {
        row := float[]()
        j := 0
        for j < 4 {
            row = append(row, 0.01 * j as float)
            j = j + 1
        }
        lora_a = append(lora_a, row)
        i = i + 1
    }

    lora_b := float[][]]()
    i := 0
    for i < 4 {
        row := float[]()
        j := 0
        for j < 32 {
            row = append(row, 0.02)
            j = j + 1
        }
        lora_b = append(lora_b, row)
        i = i + 1
    }

    adapter.add_module_weights("dense", lora_a, lora_b)

    input := float[]()
    i := 0
    for i < 64 {
        input = append(input, 1.0)
        i = i + 1
    }

    output := adapter.apply_lora("dense", input, 1.0)

    println("✓ Applied LoRA")
    println("  Input size: " + len(input).to_string())
    println("  Output size: " + len(output).to_string())

    return (), ""
}

func example_adapter_manager() ((), string) {
    manager := lora_adapter_manager::new()

    config1 := lora_config::default()
    config1.lora_rank = 8
    targets1 := string[]()
    targets1 = append(targets1, "q_proj")
    config1.target_modules = targets1

    adapter1 := lora_adapter::new("adapter_1", *config1)
    manager.add_adapter("adapter_1", *adapter1)

    config2 := lora_config::default()
    config2.lora_rank = 16
    targets2 := string[]()
    targets2 = append(targets2, "v_proj")
    config2.target_modules = targets2

    adapter2 := lora_adapter::new("adapter_2", *config2)
    manager.add_adapter("adapter_2", *adapter2)

    manager.activate_adapter("adapter_1")
    manager.activate_adapter("adapter_2")

    active := manager.get_active_adapters()
    println("✓ Created adapter manager")
    println("  Total adapters: " + manager.list_adapters().len().to_string())
    println("  Active adapters: " + len(active).to_string())

    manager.set_global_scale(0.5)

    manager.deactivate_adapter("adapter_2")
    println("  Active after deactivation: " + manager.get_active_adapters().len().to_string())

    return (), ""
}

func example_batch_apply_lora() ((), string) {
    config := lora_config::default()
    config.lora_rank = 4
    targets := string[]()
    targets = append(targets, "linear")
    config.target_modules = targets

    adapter := lora_adapter::new("lora_batch", *config)

    lora_a := float[][]]()
    i := 0
    for i < 32 {
        row := float[]()
        j := 0
        for j < 4 {
            row = append(row, 0.01)
            j = j + 1
        }
        lora_a = append(lora_a, row)
        i = i + 1
    }

    lora_b := float[][]]()
    i := 0
    for i < 4 {
        row := float[]()
        j := 0
        for j < 16 {
            row = append(row, 0.02)
            j = j + 1
        }
        lora_b = append(lora_b, row)
        i = i + 1
    }

    adapter.add_module_weights("linear", lora_a, lora_b)

    inputs := *float[[]]()
    batch_size := 4
    seq_len := 32

    b := 0
    for b < batch_size {
        input := float[]()
        s := 0
        for s < seq_len {
            input = append(input, 1.0)
            s = s + 1
        }
        inputs = append(inputs, input)
        b = b + 1
    }

    outputs := adapter.apply_lora_batch("linear", inputs, 1.0)

    println("✓ Batch applied LoRA")
    println("  Batch size: " + batch_size.to_string())
    println("  Output count: " + len(outputs).to_string())

    return (), ""
}

func main() {
    println("=== LoRA foundation使useexample ===\n")

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

    println("\n=== allexamplecomplete ===")
}
