package neurx.backend.platform.driving

use std.slices
use std.io.println

struct safety_critical_runtime {
    string os_name
    int watchdog_period_ms
    bool redundancy_enabled
    int safety_certification_level
    []string critical_functions
}

func new_safety_critical_runtime(string os) safety_critical_runtime {
    return safety_critical_runtime{
        os_name: os,
        watchdog_period_ms: 50,
        redundancy_enabled: true,
        safety_certification_level: 3,
        critical_functions: string[](),
    }
}

func (safety_critical_runtime* runtime) register_critical_function(string func_name) {
    runtime.critical_functions = append(runtime.critical_functions, func_name)
}

func (runtime* runtime) get_watchdog_period_ms() int {    runtime.watchdog_period_ms
}

func (runtime* runtime) is_redundancy_enabled() bool {    runtime.redundancy_enabled
}

func (runtime* runtime) get_critical_function_count() int {    len(runtime.critical_functions)
}

func (runtime* runtime) get_os_name() string {    runtime.os_name
}

func (runtime* runtime) get_safety_level() int {    runtime.safety_certification_level
}
