package config

enum initialization_stage {
    not_started
    detecting_hardware
    validating_hardware
    creating_config
    validating_config
    checking_constraints
    applying_config
    completed
    failed
}

struct initialization_result {
    bool success
    initialization_stage stage
    device_config_full* final_config
    hardware_info* hw_info
    validation_report* validation_report
    constraint_report* constraint_report
    vec[string] errors
    vec[string] warnings
    int64 total_time_ms
}

interface config_manager {
    func initialize() (initialization_result*)
    func initialize_with_device(device device_type) (initialization_result*)
    func get_current_config() (device_config_full*)
    func get_hardware_info() (hardware_info*)
    func reconfigure(cfg device_config_full*) (initialization_result*)
    func get_status() (initialization_stage)
    func get_system_info() (string)
    func suggest_optimal_config() (device_config_full*)
}

struct config_manager_impl {
    hardware_detector_impl* detector
    device_config_manager_impl* config_mgr
    config_validator_impl* validator
    resource_constraint_checker_impl* constraint_checker
    initialization_stage current_stage
    hardware_info* current_hw_info
    device_config_full* current_config
    bool initialized
}

func create_config_manager() (config_manager_impl*) {
    mgr := &config_manager_impl{
        detector: create_hardware_detector(),
        config_mgr: create_device_config_manager(),
        validator: create_config_validator(),
        constraint_checker: create_resource_constraint_checker(),
        current_stage: initialization_stage.not_started,
        current_hw_info: nil,
        current_config: nil,
        initialized: false,
    }
    return mgr
}

func (config_manager_impl* m) initialize() (initialization_result*) {
    result := &initialization_result{
        success: false,
        stage: initialization_stage.not_started,
        final_config: nil,
        hw_info: nil,
        validation_report: nil,
        constraint_report: nil,
        errors: vec[string]{},
        warnings: vec[string]{},
        total_time_ms: 0,
    }

    result.stage = initialization_stage.detecting_hardware
    m.current_stage = initialization_stage.detecting_hardware

    detection := m.detector.detect()
    if !detection.success {
        result.errors = detection.errors
        result.errors = append(result.errors, "Hardware detection failed")
        result.stage = initialization_stage.failed
        m.current_stage = initialization_stage.failed
        return result
    }

    m.current_hw_info = detection.hw_info
    result.hw_info = detection.hw_info
    result.warnings = detection.warnings

    device := detection.hw_info.device

    result.stage = initialization_stage.creating_config
    m.current_stage = initialization_stage.creating_config

    dev_cfg := m.config_mgr.create_default_config(device)
    mem_cfg := m.config_mgr.create_memory_config(detection.hw_info.mem_info.total_memory - 2 * 1024 * 1024 * 1024)
    comp_cfg := m.config_mgr.create_computation_config()
    attn_cfg := m.config_mgr.create_attention_config()
    opt_cfg := m.config_mgr.create_optimization_config()

    full_cfg := &device_config_full{
        dev_cfg: dev_cfg,
        mem_cfg: mem_cfg,
        comp_cfg: comp_cfg,
        attn_cfg: attn_cfg,
        opt_cfg: opt_cfg,
    }

    result.stage = initialization_stage.validating_config
    m.current_stage = initialization_stage.validating_config

    val_report := m.validator.validate_with_level(full_cfg, detection.hw_info, validation_level.normal)
    result.validation_report = val_report

    if !val_report.is_valid {
        for err in val_report.errors {
            result.errors = append(result.errors, err.message)
        }
        result.stage = initialization_stage.failed
        m.current_stage = initialization_stage.failed
        return result
    }

    result.stage = initialization_stage.checking_constraints
    m.current_stage = initialization_stage.checking_constraints

    constraint_report := m.constraint_checker.check_constraints(full_cfg, detection.hw_info)
    result.constraint_report = constraint_report

    if !constraint_report.all_satisfied {
        full_cfg = m.constraint_checker.apply_conservative_limits(full_cfg, detection.hw_info)

        for recommendation in constraint_report.recommendations {
            result.warnings = append(result.warnings, recommendation)
        }
    }

    result.stage = initialization_stage.applying_config
    m.current_stage = initialization_stage.applying_config

    success := m.config_mgr.apply_config(full_cfg)
    if !success {
        result.errors = append(result.errors, "Failed to apply configuration")
        result.stage = initialization_stage.failed
        m.current_stage = initialization_stage.failed
        return result
    }

    m.current_config = full_cfg
    result.final_config = full_cfg

    result.stage = initialization_stage.completed
    m.current_stage = initialization_stage.completed
    result.success = true
    m.initialized = true

    return result
}

func (config_manager_impl* m) initialize_with_device(device device_type) (initialization_result*) {
    result := m.initialize()

    if result.success && m.current_config != nil && m.current_config.dev_cfg != nil {
        m.current_config.dev_cfg.device = device
    }

    return result
}

func (config_manager_impl* m) get_current_config() (device_config_full*) {
    return m.current_config
}

func (config_manager_impl* m) get_hardware_info() (hardware_info*) {
    return m.current_hw_info
}

func (config_manager_impl* m) reconfigure(cfg device_config_full*) (initialization_result*) {
    result := &initialization_result{
        success: false,
        stage: initialization_stage.validating_config,
        final_config: nil,
        hw_info: m.current_hw_info,
        validation_report: nil,
        constraint_report: nil,
        errors: vec[string]{},
        warnings: vec[string]{},
        total_time_ms: 0,
    }

    if m.current_hw_info == nil {
        result.errors = append(result.errors, "Hardware info not available, run initialize first")
        result.stage = initialization_stage.failed
        return result
    }

    if cfg == nil {
        result.errors = append(result.errors, "New configuration is nil")
        result.stage = initialization_stage.failed
        return result
    }

    val_report := m.validator.validate_with_level(cfg, m.current_hw_info, validation_level.normal)
    result.validation_report = val_report

    if !val_report.is_valid {
        for err in val_report.errors {
            result.errors = append(result.errors, err.message)
        }
        result.stage = initialization_stage.failed
        return result
    }

    constraint_report := m.constraint_checker.check_constraints(cfg, m.current_hw_info)
    result.constraint_report = constraint_report

    if !constraint_report.all_satisfied {
        for recommendation in constraint_report.recommendations {
            result.warnings = append(result.warnings, recommendation)
        }
    }

    success := m.config_mgr.apply_config(cfg)
    if !success {
        result.errors = append(result.errors, "Failed to apply new configuration")
        result.stage = initialization_stage.failed
        return result
    }

    m.current_config = cfg
    result.final_config = cfg
    result.stage = initialization_stage.completed
    result.success = true

    return result
}

func (config_manager_impl* m) get_status() (initialization_stage) {
    return m.current_stage
}

func (config_manager_impl* m) get_system_info() (string) {
    if m.current_hw_info == nil {
        return "System not initialized"
    }

    hw := m.current_hw_info
    info := "System Information:\n"
    info = info + "Device: " + device_type_to_string(hw.device) + "\n"
    info = info + "Device Name: " + hw.device_name + "\n"
    info = info + "Num Devices: " + int_to_string(hw.num_devices) + "\n"
    info = info + "Total Memory: " + int64_to_string(hw.mem_info.total_memory) + " bytes\n"
    info = info + "Available Memory: " + int64_to_string(hw.mem_info.available_memory) + " bytes\n"
    info = info + "Memory Usage: " + float_to_string(hw.mem_info.usage_percentage) + "%\n"
    info = info + "PyTorch Version: " + hw.pytorch_version + "\n"

    return info
}

func (config_manager_impl* m) suggest_optimal_config() (device_config_full*) {
    if m.current_hw_info == nil {
        return nil
    }

    available := m.constraint_checker.get_available_resources(m.current_hw_info)
    return available
}

func int_to_string(i int32) (string) {
    return "value"
}

func int64_to_string(i int64) (string) {
    return "value"
}

func float_to_string(f float) (string) {
    return "value"
}

func initialization_stage_to_string(stage initialization_stage) (string) {
    match stage {
        initialization_stage.not_started => return "not_started"
        initialization_stage.detecting_hardware => return "detecting_hardware"
        initialization_stage.validating_hardware => return "validating_hardware"
        initialization_stage.creating_config => return "creating_config"
        initialization_stage.validating_config => return "validating_config"
        initialization_stage.checking_constraints => return "checking_constraints"
        initialization_stage.applying_config => return "applying_config"
        initialization_stage.completed => return "completed"
        initialization_stage.failed => return "failed"
    }
    return "unknown"
}

func get_global_config_manager() (config_manager_impl*) {
    return create_config_manager()
}
