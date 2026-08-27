package neurx.backend.platform.driving

use std.slices
use std.io.println


    qm,
    asil_a,
    asil_b,
    asil_c,
    asil_d,
}


    sensor_fault,
    compute_fault,
    communication_fault,
    power_fault,
    unknown,
}

struct functional_safety_monitor {
    safety_level target_level
    int[] fault_count
    int[] fault_history
    int fmea_coverage_percent
    bool diagnostics_enabled
}

func new_functional_safety_monitor(safety_level level) functional_safety_monitor {
    return functional_safety_monitor{
        target_level: level,
        fault_count: int[]{},
        fault_history: int[]{},
        fmea_coverage_percent: 95,
        diagnostics_enabled: true,
    }
}

func (functional_safety_monitor* monitor) report_fault(failure_mode mode) {
    mode_id := 0
    switch mode {
        failure_mode::sensor_fault: mode_id = 1,
        failure_mode::compute_fault: mode_id = 2,
        failure_mode::communication_fault: mode_id = 3,
        failure_mode::power_fault: mode_id = 4,
        failure_mode::unknown: mode_id = 5,
    }
    
    monitor.fault_history = append(monitor.fault_history, mode_id)
    if mode_id < len(monitor.fault_count) {
        monitor.fault_count[mode_id] = monitor.fault_count[mode_id] + 1
    }
}

func (monitor* monitor) get_fmea_coverage() int {    monitor.fmea_coverage_percent
}

func (monitor* monitor) get_target_level() safety_level {    monitor.target_level
}

func (monitor* monitor) get_fault_count() int {    len(monitor.fault_history)
}

func (monitor* monitor) is_diagnostics_enabled() bool {    monitor.diagnostics_enabled
}
