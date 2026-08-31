package config


    strict
    normal
    lenient
}


    range_check
    enum_check
    dependency_check
    compatibility_check
    performance_check
}

struct validation_rule {
    string name
    validation_rule_type rule_type
    string description
    func(device_config_full*, hardware_info*) (bool) check_fn
}

struct validation_error {
    string rule_name
    string message
    validation_rule_type rule_type
    int32 severity
}

struct validation_report {
    bool is_valid
    validation_error[] errors
    validation_error[] warnings
    string[] suggestions
    int64 validation_time_ms
}

interface config_validator {
    func validate(cfg device_config_full*, hw_info hardware_info*) (validation_report*)

    func validate_with_level(cfg device_config_full*, hw_info hardware_info*, level validation_level) (validation_report*)

    func add_custom_rule(rule validation_rule*) (bool)

    func validate_memory_constraints(cfg device_config_full*, hw_info hardware_info*) (validation_error[])

    func validate_compute_capabilities(cfg device_config_full*, hw_info hardware_info*) (validation_error[])

    func validate_feature_support(cfg device_config_full*, hw_info hardware_info*) (validation_error[])

    func validate_precision_support(dtype precision_type, hw_info hardware_info*) (bool)

    func get_applicable_rules(cfg device_config_full*) (validation_rule*[])
}

struct config_validator_impl {
    validation_rule*[] rules
    validation_rule*[] custom_rules
    validation_level current_level
}

func create_config_validator() (config_validator_impl*) {
    validator := *config_validator_impl{
        rules: validation_rule*[]{},
        custom_rules: validation_rule*[]{},
        current_level: validation_level.normal,
    }

    validator.rules = initialize_default_rules()

    return validator
}

func initialize_default_rules() (validation_rule*[]) {
    rules := validation_rule*[]{}

    rule_memory := *validation_rule{
        name: "memory_allocation",
        rule_type: validation_rule_type.range_check,
        description: "Validates memory allocation doesn't exceed available hardware",
    }
    rules = append(rules, rule_memory)

    rule_compute := *validation_rule{
        name: "compute_capability",
        rule_type: validation_rule_type.compatibility_check,
        description: "Checks if computation config matches device capabilities",
    }
    rules = append(rules, rule_compute)

    rule_precision := *validation_rule{
        name: "precision_support",
        rule_type: validation_rule_type.compatibility_check,
        description: "Validates device supports requested precision types",
    }
    rules = append(rules, rule_precision)

    rule_feature := *validation_rule{
        name: "feature_availability",
        rule_type: validation_rule_type.dependency_check,
        description: "Checks if requested features are available on device",
    }
    rules = append(rules, rule_feature)

    rule_parallelism := *validation_rule{
        name: "parallelism_config",
        rule_type: validation_rule_type.compatibility_check,
        description: "Validates parallelism settings match device configuration",
    }
    rules = append(rules, rule_parallelism)

    return rules
}

func (config_validator_impl* v) validate(cfg device_config_full*, hw_info hardware_info*) (validation_report*) {
    return v.validate_with_level(cfg, hw_info, validation_level.normal)
}

func (config_validator_impl* v) validate_with_level(cfg device_config_full*, hw_info hardware_info*, level validation_level) (validation_report*) {
    report := *validation_report{
        is_valid: true,
        errors: []validation_error{},
        warnings: []validation_error{},
        suggestions: []string{},
        validation_time_ms: 0,
    }

    if cfg == nil {
        error := validation_error{
            rule_name: "null_config",
            message: "Configuration is nil",
            rule_type: validation_rule_type.range_check,
            severity: 10,
        }
        report.errors = append(report.errors, error)
        report.is_valid = false
        return report
    }

    if hw_info == nil {
        error := validation_error{
            rule_name: "null_hardware",
            message: "Hardware info is nil",
            rule_type: validation_rule_type.range_check,
            severity: 10,
        }
        report.errors = append(report.errors, error)
        report.is_valid = false
        return report
    }

    mem_errors := v.validate_memory_constraints(cfg, hw_info)
    for err in mem_errors {
        report.errors = append(report.errors, err)
    }

    compute_errors := v.validate_compute_capabilities(cfg, hw_info)
    for err in compute_errors {
        report.errors = append(report.errors, err)
    }

    feature_errors := v.validate_feature_support(cfg, hw_info)
    for err in feature_errors {
        report.errors = append(report.errors, err)
    }

    if len(report.errors) > 0 {
        report.is_valid = false
    }

    if cfg.opt_cfg != nil {
        if cfg.opt_cfg.compute_utilization_target < 0.5 {
            suggestion := "Consider increasing compute_utilization_target for better performance"
            report.suggestions = append(report.suggestions, suggestion)
        }
        if cfg.opt_cfg.memory_utilization_target > 0.95 {
            suggestion := "Memory utilization target is very high, may cause OOM errors"
            report.suggestions = append(report.suggestions, suggestion)
        }
    }

    v.current_level = level

    return report
}

func (config_validator_impl* v) add_custom_rule(rule validation_rule*) (bool) {
    if rule == nil {
        return false
    }
    v.custom_rules = append(v.custom_rules, rule)
    return true
}

func (config_validator_impl* v) validate_memory_constraints(cfg device_config_full*, hw_info hardware_info*) (validation_error[]) {
    errors := []validation_error{}

    if cfg.mem_cfg == nil {
        return errors
    }

    if cfg.mem_cfg.max_memory > hw_info.mem_info.total_memory {
        error := validation_error{
            rule_name: "memory_allocation",
            message: "Requested memory exceeds available hardware memory",
            rule_type: validation_rule_type.range_check,
            severity: 10,
        }
        errors = append(errors, error)
    }

    available_mem := hw_info.mem_info.total_memory - hw_info.mem_info.used_memory
    if cfg.mem_cfg.max_memory > available_mem {
        error := validation_error{
            rule_name: "memory_availability",
            message: "Requested memory exceeds available free memory",
            rule_type: validation_rule_type.range_check,
            severity: 8,
        }
        errors = append(errors, error)
    }

    if cfg.mem_cfg.num_blocks <= 0 {
        error := validation_error{
            rule_name: "block_count",
            message: "Number of memory blocks must be positive",
            rule_type: validation_rule_type.range_check,
            severity: 9,
        }
        errors = append(errors, error)
    }

    return errors
}

func (config_validator_impl* v) validate_compute_capabilities(cfg device_config_full*, hw_info hardware_info*) (validation_error[]) {
    errors := []validation_error{}

    if hw_info.device == device_type.cpu && cfg.comp_cfg != nil {
        if cfg.comp_cfg.enable_flash_attn {
            error := validation_error{
                rule_name: "compute_capability",
                message: "Flash attention is not supported on CPU devices",
                rule_type: validation_rule_type.compatibility_check,
                severity: 7,
            }
            errors = append(errors, error)
        }
    }

    if cfg.comp_cfg != nil && cfg.comp_cfg.max_batch_size > 1024 {
        error := validation_error{
            rule_name: "batch_size_limits",
            message: "Very large batch sizes may cause memory issues",
            rule_type: validation_rule_type.range_check,
            severity: 5,
        }
        errors = append(errors, error)
    }

    if cfg.dev_cfg != nil && hw_info.device == device_type.cpu {
        if cfg.dev_cfg.use_cuda_graphs {
            error := validation_error{
                rule_name: "feature_support",
                message: "CUDA graphs are not supported on CPU devices",
                rule_type: validation_rule_type.compatibility_check,
                severity: 7,
            }
            errors = append(errors, error)
        }
    }

    return errors
}

func (config_validator_impl* v) validate_feature_support(cfg device_config_full*, hw_info hardware_info*) (validation_error[]) {
    errors := []validation_error{}

    if hw_info.gpu_props != nil {
        if cfg.dev_cfg != nil && cfg.dev_cfg.use_managed_memory && !hw_info.gpu_props.supports_managed_memory {
            error := validation_error{
                rule_name: "managed_memory",
                message: "Device does not support managed memory",
                rule_type: validation_rule_type.dependency_check,
                severity: 6,
            }
            errors = append(errors, error)
        }
    }

    if cfg.attn_cfg != nil && cfg.attn_cfg.backend == "triton" {
        if hw_info.device == device_type.cpu {
            error := validation_error{
                rule_name: "triton_support",
                message: "Triton backend is not available on CPU",
                rule_type: validation_rule_type.dependency_check,
                severity: 7,
            }
            errors = append(errors, error)
        }
    }

    return errors
}

func (config_validator_impl* v) validate_precision_support(dtype precision_type, hw_info hardware_info*) (bool) {
    match dtype {
        precision_type.float32 => return true
        precision_type.float16 => {
            if hw_info.device == device_type.cuda || hw_info.device == device_type.rocm {
                return true
            }
            return false
        }
        precision_type.bfloat16 => {
            if hw_info.device == device_type.cuda {
                if hw_info.gpu_props != nil && hw_info.gpu_props.compute_capability >= 80 {
                    return true
                }
            }
            return false
        }
        precision_type.int8 => {
            if hw_info.device == device_type.cuda || hw_info.device == device_type.rocm {
                return true
            }
            return false
        }
        precision_type.int4 => {
            if hw_info.device == device_type.cuda {
                return true
            }
            return false
        }
        precision_type.auto => return true
    }
    return false
}

func (config_validator_impl* v) get_applicable_rules(cfg device_config_full*) (validation_rule*[]) {
    applicable := validation_rule*[]{}

    for rule in v.rules {
        if rule == nil {
            continue
        }

        applicable = append(applicable, rule)
    }

    for rule in v.custom_rules {
        if rule == nil {
            continue
        }

        applicable = append(applicable, rule)
    }

    return applicable
}

func validation_level_to_string(level validation_level) (string) {
    match level {
        validation_level.strict => return "strict"
        validation_level.normal => return "normal"
        validation_level.lenient => return "lenient"
    }
    return "unknown"
}
