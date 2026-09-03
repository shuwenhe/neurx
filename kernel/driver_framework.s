package neurx.kernel.driver_framework

use neurx.kernel.device_model.{device, device_register, device_unregister, device_get}

struct driver_result {
    bool success
    int error_code
    string error_message
}

struct driver_ops {

    func probe(device dev) driver_result
    func remove(device dev) driver_result
    
    func suspend(device dev, int state) driver_result
    func resume(device dev) driver_result
    
    func irq_handler(device dev, int irq) driver_result
    
    func reset(device dev) driver_result
}

struct registered_driver {
    string driver_name
    string driver_version
    string device_pattern
    driver_ops ops
    
    int priority
    []string supported_devices
    bool auto_probe
    
    int device_count
    
    bool is_loaded
    int initialization_status
}

struct driver_registry {
    registered_driver[] drivers
    int driver_count
}

driver_registry global_driver_registry = driver_registry {
    drivers: make([]registered_driver, 64),
    driver_count: 0,
}

func driver_register(
    string driver_name,
    string driver_version,
    string device_pattern,
    driver_ops ops,
    int priority
) int {
    if global_driver_registry.driver_count >= len(global_driver_registry.drivers) {
        return -1
    }
    
    int i = 0
    for i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == driver_name {
            return -2
        }
        i = i + 1
    }
    
    registered_driver drv = registered_driver {
        driver_name: driver_name,
        driver_version: driver_version,
        device_pattern: device_pattern,
        ops: ops,
        priority: priority,
        device_count: 0,
        is_loaded: true,
        initialization_status: 0,
    }
    
    i = global_driver_registry.driver_count
    while i > 0 && global_driver_registry.drivers[i - 1].priority > priority {
        global_driver_registry.drivers[i] = global_driver_registry.drivers[i - 1]
        i = i - 1
    }
    
    global_driver_registry.drivers[i] = drv
    global_driver_registry.driver_count = global_driver_registry.driver_count + 1
    
    return 0
}

func driver_unregister(string driver_name) int {
    int idx = -1
    int i = 0
    for i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == driver_name {
            idx = i
        }
        i = i + 1
    }
    
    if idx < 0 {
        return -1
    }
    
    if global_driver_registry.drivers[idx].device_count > 0 {
        return -2
    }
    
    for i = idx; i < global_driver_registry.driver_count - 1; i = i + 1 {
        global_driver_registry.drivers[i] = global_driver_registry.drivers[i + 1]
    }
    
    global_driver_registry.driver_count = global_driver_registry.driver_count - 1
    return 0
}

func driver_matches_device(string pattern, device dev) bool {

    int pat_len = len(pattern)
    int dev_len = len(dev.device_type)
    
    if pat_len > dev_len {
        return false
    }
    
    if pattern[pat_len - 1] == 42 {
        int i = 0
        while i < pat_len - 1 {
            if pattern[i] != dev.device_type[i] {
                return false
            }
            i = i + 1
        }
        return true
    }
    
    return pattern == dev.device_type
}

func device_probe(device dev) driver_result {
    int i = 0
    
    for i < global_driver_registry.driver_count {
        registered_driver drv = global_driver_registry.drivers[i]
        
        if driver_matches_device(drv.device_pattern, dev) {

            driver_result result = drv.ops.probe(dev)
            
            if result.success {

                global_driver_registry.drivers[i].device_count = global_driver_registry.drivers[i].device_count + 1
                
                dev.driver_name = drv.driver_name
                device_register(dev)
                
                return result
            }
        }
        
        i = i + 1
    }
    
    return driver_result {
        success: false,
        error_code: -1,
        error_message: "No compatible driver found",
    }
}

func device_remove(string device_id) driver_result {
    device dev = device_get(device_id)
    
    if !dev.is_present {
        return driver_result {
            success: false,
            error_code: -1,
            error_message: "Device not found",
        }
    }
    
    if dev.driver_name == "" {
        return driver_result {
            success: false,
            error_code: -2,
            error_message: "No driver bound to device",
        }
    }
    
    int i = 0
    while i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == dev.driver_name {

            driver_result result = global_driver_registry.drivers[i].ops.remove(dev)
            
            if result.success {
                global_driver_registry.drivers[i].device_count = global_driver_registry.drivers[i].device_count - 1
                device_unregister(device_id)
            }
            
            return result
        }
        
        i = i + 1
    }
    
    return driver_result {
        success: false,
        error_code: -3,
        error_message: "Driver not found in registry",
    }
}

func device_suspend(string device_id, int power_state) driver_result {
    device dev = device_get(device_id)
    
    if !dev.is_present {
        return driver_result {
            success: false,
            error_code: -1,
            error_message: "Device not found",
        }
    }
    
    if dev.driver_name == "" {
        return driver_result {
            success: false,
            error_code: -2,
            error_message: "No driver bound to device",
        }
    }
    
    int i = 0
    while i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == dev.driver_name {
            return global_driver_registry.drivers[i].ops.suspend(dev, power_state)
        }
        i = i + 1
    }
    
    return driver_result {
        success: false,
        error_code: -3,
        error_message: "Driver not found",
    }
}

func device_resume(string device_id) driver_result {
    device dev = device_get(device_id)
    
    if !dev.is_present {
        return driver_result {
            success: false,
            error_code: -1,
            error_message: "Device not found",
        }
    }
    
    if dev.driver_name == "" {
        return driver_result {
            success: false,
            error_code: -2,
            error_message: "No driver bound to device",
        }
    }
    
    int i = 0
    while i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == dev.driver_name {
            return global_driver_registry.drivers[i].ops.resume(dev)
        }
        i = i + 1
    }
    
    return driver_result {
        success: false,
        error_code: -3,
        error_message: "Driver not found",
    }
}

func driver_get(string driver_name) registered_driver {
    int i = 0
    for i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == driver_name {
            return global_driver_registry.drivers[i]
        }
        i = i + 1
    }
    return registered_driver {
        driver_name: "",
        is_loaded: false,
    }
}

func driver_list_all() []string {
    []string result = make([]string, 64)
    int i = 0
    for i < global_driver_registry.driver_count {
        result[i] = global_driver_registry.drivers[i].driver_name
        i = i + 1
    }
    return result
}

func driver_count() int {
    return global_driver_registry.driver_count
}

func driver_dump_registry() string {
    string output = ""
    output = output + "Driver Registry (" + string(global_driver_registry.driver_count) + " drivers)\n"
    output = output + "==========================================\n"
    
    int i = 0
    for i < global_driver_registry.driver_count {
        registered_driver drv = global_driver_registry.drivers[i]
        output = output + "[" + string(i) + "] " + drv.driver_name + " v" + drv.driver_version + "\n"
        output = output + "    Pattern: " + drv.device_pattern + "\n"
        output = output + "    Devices: " + string(drv.device_count) + "\n"
        output = output + "    Status: " + (if drv.is_loaded { "loaded" } else { "unloaded" }) + "\n"
        i = i + 1
    }
    
    return output
}

func driver_success() driver_result {
    return driver_result {
        success: true,
        error_code: 0,
        error_message: "",
    }
}

func driver_error(int code, string message) driver_result {
    return driver_result {
        success: false,
        error_code: code,
        error_message: message,
    }
}
