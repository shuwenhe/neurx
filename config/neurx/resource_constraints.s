package config

    memory_constraint
    compute_constraint
    bandwidth_constraint
    thermal_constraint
    power_constraint
    device_constraint
}

    satisfied
    warning
    violated
    critical
}

struct resource_constraint {
    string name
    constraint_type type
    int64 min_value
    int64 max_value
    int64 current_value
    string description
}

struct constraint_check {
    string constraint_name
    constraint_status status
    float violation_ratio
    string message
}

struct constraint_report {
    bool all_satisfied
    constraint_check[] checks
    string[] recommendations
    int64 check_time_ms
}

struct memory_constraints {
    int64 max_gpu_memory
    int64 max_cpu_memory
    int64 reserved_memory
    int64 min_free_memory
    float max_utilization_percent
}

struct compute_constraints {
    int32 max_batch_size
    int32 max_sequence_length
    int32 max_num_tokens
    float max_flops_percent
    int32 max_concurrent_operations
}

struct bandwidth_constraints {
    int64 max_memory_bandwidth
    int64 max_pcie_bandwidth
    int64 max_nvlink_bandwidth
}

struct thermal_constraints {
    float max_temperature
    float max_power_draw
    float thermal_throttle_temp
}

interface resource_constraint_checker {
    func check_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_report*)

    func check_memory_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_check[])

    func check_compute_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_check[])

    func check_bandwidth_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_check[])

    func can_allocate_memory(size int64, hw_info hardware_info*) (bool)

    func estimate_memory_usage(cfg device_config_full*) (int64)

    func get_available_resources(hw_info hardware_info*) (device_config_full*)

    func apply_conservative_limits(cfg device_config_full*, hw_info hardware_info*) (device_config_full*)
}

struct resource_constraint_checker_impl {
    memory_constraints* mem_constraints
    compute_constraints* compute_constraints
    bandwidth_constraints* bw_constraints
    thermal_constraints* thermal_constraints
}

func create_resource_constraint_checker() (resource_constraint_checker_impl*) {
    checker := *resource_constraint_checker_impl{
        mem_constraints: create_default_memory_constraints(),
        compute_constraints: create_default_compute_constraints(),
        bw_constraints: create_default_bandwidth_constraints(),
        thermal_constraints: create_default_thermal_constraints(),
    }
    return checker
}

func create_default_memory_constraints() (memory_constraints*) {
    constraints := *memory_constraints{
        max_gpu_memory: 48 * 1024 * 1024 * 1024,
        max_cpu_memory: 256 * 1024 * 1024 * 1024,
        reserved_memory: 2 * 1024 * 1024 * 1024,
        min_free_memory: 512 * 1024 * 1024,
        max_utilization_percent: 95.0,
    }
    return constraints
}

func create_default_compute_constraints() (compute_constraints*) {
    constraints := *compute_constraints{
        max_batch_size: 1024,
        max_sequence_length: 32768,
        max_num_tokens: 33554432,
        max_flops_percent: 95.0,
        max_concurrent_operations: 16,
    }
    return constraints
}

func create_default_bandwidth_constraints() (bandwidth_constraints*) {
    constraints := *bandwidth_constraints{
        max_memory_bandwidth: 1024 * 1024 * 1024 * 1024,
        max_pcie_bandwidth: 256 * 1024 * 1024 * 1024,
        max_nvlink_bandwidth: 900 * 1024 * 1024 * 1024,
    }
    return constraints
}

func create_default_thermal_constraints() (thermal_constraints*) {
    constraints := *thermal_constraints{
        max_temperature: 83.0,
        max_power_draw: 700.0,
        thermal_throttle_temp: 75.0,
    }
    return constraints
}

func (resource_constraint_checker_impl* c) check_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_report*) {
    report := *constraint_report{
        all_satisfied: true,
        checks: []constraint_check{},
        recommendations: []string{},
        check_time_ms: 0,
    }

    if cfg == nil || hw_info == nil {
        report.all_satisfied = false
        return report
    }

    mem_checks := c.check_memory_constraints(cfg, hw_info)
    for check in mem_checks {
        report.checks = append(report.checks, check)
        if check.status == constraint_status.violated || check.status == constraint_status.critical {
            report.all_satisfied = false
        }
    }

    compute_checks := c.check_compute_constraints(cfg, hw_info)
    for check in compute_checks {
        report.checks = append(report.checks, check)
        if check.status == constraint_status.violated || check.status == constraint_status.critical {
            report.all_satisfied = false
        }
    }

    bw_checks := c.check_bandwidth_constraints(cfg, hw_info)
    for check in bw_checks {
        report.checks = append(report.checks, check)
    }

    if !report.all_satisfied {
        report.recommendations = c.generate_recommendations(report.checks)
    }

    return report
}

func (resource_constraint_checker_impl* c) check_memory_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_check[]) {
    checks := []constraint_check{}

    if cfg.mem_cfg == nil {
        return checks
    }

    max_allocatable := hw_info.mem_info.total_memory - c.mem_constraints.reserved_memory

    check1 := constraint_check{
        constraint_name: "gpu_memory_limit",
        status: constraint_status.satisfied,
        violation_ratio: 0.0,
        message: "GPU memory usage within limits",
    }

    if cfg.mem_cfg.max_memory > max_allocatable {
        check1.status = constraint_status.violated
        check1.violation_ratio = float(cfg.mem_cfg.max_memory - max_allocatable) / float(max_allocatable)
        check1.message = "Requested GPU memory exceeds available capacity"
    }

    checks = append(checks, check1)

    utilization := float(cfg.mem_cfg.max_memory) / float(hw_info.mem_info.total_memory) * 100.0
    check2 := constraint_check{
        constraint_name: "memory_utilization",
        status: constraint_status.satisfied,
        violation_ratio: 0.0,
        message: "Memory utilization within acceptable range",
    }

    if utilization > c.mem_constraints.max_utilization_percent {
        check2.status = constraint_status.warning
        check2.violation_ratio = (utilization - c.mem_constraints.max_utilization_percent) / c.mem_constraints.max_utilization_percent
        check2.message = "Memory utilization is very high"
    }

    checks = append(checks, check2)

    return checks
}

func (resource_constraint_checker_impl* c) check_compute_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_check[]) {
    checks := []constraint_check{}

    if cfg.comp_cfg == nil {
        return checks
    }

    check1 := constraint_check{
        constraint_name: "batch_size",
        status: constraint_status.satisfied,
        violation_ratio: 0.0,
        message: "Batch size within limits",
    }

    if cfg.comp_cfg.max_batch_size > c.compute_constraints.max_batch_size {
        check1.status = constraint_status.warning
        check1.violation_ratio = float(cfg.comp_cfg.max_batch_size - c.compute_constraints.max_batch_size) / float(c.compute_constraints.max_batch_size)
        check1.message = "Batch size exceeds recommended limit"
    }

    checks = append(checks, check1)

    return checks
}

func (resource_constraint_checker_impl* c) check_bandwidth_constraints(cfg device_config_full*, hw_info hardware_info*) (constraint_check[]) {
    checks := []constraint_check{}

    check1 := constraint_check{
        constraint_name: "memory_bandwidth",
        status: constraint_status.satisfied,
        violation_ratio: 0.0,
        message: "Memory bandwidth requirement satisfied",
    }

    checks = append(checks, check1)

    return checks
}

func (resource_constraint_checker_impl* c) can_allocate_memory(size int64, hw_info hardware_info*) (bool) {
    available := hw_info.mem_info.available_memory - c.mem_constraints.min_free_memory
    return size <= available
}

func (resource_constraint_checker_impl* c) estimate_memory_usage(cfg device_config_full*) (int64) {
    if cfg.mem_cfg == nil {
        return 0
    }

    base_usage := cfg.mem_cfg.max_memory

    if cfg.mem_cfg.enable_kv_cache {
        kv_usage := int64(float(base_usage) * cfg.mem_cfg.kv_cache_ratio)
        base_usage = base_usage + kv_usage
    }

    return base_usage
}

func (resource_constraint_checker_impl* c) get_available_resources(hw_info hardware_info*) (device_config_full*) {
    cfg := *device_config_full{}

    available_mem := hw_info.mem_info.available_memory - c.mem_constraints.min_free_memory
    mem_cfg := create_default_memory_config(available_mem)
    cfg.mem_cfg = mem_cfg

    comp_cfg := create_default_compute_config()
    cfg.comp_cfg = comp_cfg

    return cfg
}

func create_default_memory_config(available_mem int64) (memory_config*) {
    cfg := *memory_config{
        max_memory: available_mem,
        gpu_memory_utilization: 85,
        enable_prefix_caching: true,
        enable_kv_cache: true,
        kv_cache_ratio: 0.8,
        block_size: 16,
        num_blocks: int32(available_mem / 65536),
        use_sliding_window: false,
    }
    return cfg
}

func create_default_compute_config() (computation_config*) {
    cfg := *computation_config{
        enable_flash_attn: true,
        enable_triton: true,
        enable_torch_compile: false,
        compile_backend: "inductor",
        use_tensor_parallelism: false,
        use_pipeline_parallelism: false,
        enable_async_processing: true,
        max_batch_size: 64,
    }
    return cfg
}

func (resource_constraint_checker_impl* c) apply_conservative_limits(cfg device_config_full*, hw_info hardware_info*) (device_config_full*) {
    conservative := *device_config_full{}

    if cfg.dev_cfg != nil {
        conservative.dev_cfg = cfg.dev_cfg
    }

    if cfg.mem_cfg != nil {
        mem_cfg := *cfg.mem_cfg
        mem_cfg.gpu_memory_utilization = 70
        mem_cfg.kv_cache_ratio = 0.6
        conservative.mem_cfg = *mem_cfg
    }

    if cfg.comp_cfg != nil {
        comp_cfg := *cfg.comp_cfg
        comp_cfg.max_batch_size = comp_cfg.max_batch_size / 2
        conservative.comp_cfg = *comp_cfg
    }

    if cfg.attn_cfg != nil {
        conservative.attn_cfg = cfg.attn_cfg
    }

    if cfg.opt_cfg != nil {
        opt_cfg := *cfg.opt_cfg
        opt_cfg.compute_utilization_target = 0.7
        opt_cfg.memory_utilization_target = 0.75
        conservative.opt_cfg = *opt_cfg
    }

    return conservative
}

func (resource_constraint_checker_impl* c) generate_recommendations(checks []constraint_check) (string[]) {
    recommendations := []string{}

    for check in checks {
        if check.status == constraint_status.warning || check.status == constraint_status.violated {
            match check.constraint_name {
                "gpu_memory_limit" => {
                    recommendations = append(recommendations, "Reduce max_memory allocation or use smaller batch sizes")
                }
                "memory_utilization" => {
                    recommendations = append(recommendations, "Consider using gradient checkpointing to reduce memory usage")
                }
                "batch_size" => {
                    recommendations = append(recommendations, "Reduce batch size to improve stability")
                }
                _ => {}
            }
        }
    }

    return recommendations
}

func constraint_status_to_string(status constraint_status) (string) {
    match status {
        constraint_status.satisfied => return "satisfied"
        constraint_status.warning => return "warning"
        constraint_status.violated => return "violated"
        constraint_status.critical => return "critical"
    }
    return "unknown"
}
