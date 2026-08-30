package neurx.kernel.driver_framework

use neurx.kernel.device_model.{device, device_register, device_unregister, device_get}

// ============================================================================
// Driver Operations & Lifecycle
// ============================================================================

// Result type for driver operations
struct driver_result {
    bool success
    int error_code
    string error_message
}

// Driver operation callbacks
struct driver_ops {
    // Device discovery and binding (mandatory)
    func probe(device dev) driver_result
    func remove(device dev) driver_result
    
    // Power management (optional)
    func suspend(device dev, int state) driver_result
    func resume(device dev) driver_result
    
    // Interrupt handling (optional)
    func irq_handler(device dev, int irq) driver_result
    
    // Reset and recovery (optional)
    func reset(device dev) driver_result
}

// Registered driver metadata
struct registered_driver {
    string driver_name
    string driver_version
    string device_pattern        // e.g., "nvidia_*" or "0000:01:00.*"
    driver_ops ops
    
    // Driver properties
    int priority                  // 0=highest, 10=lowest (for probe order)
    string[] supported_devices    // list of compatible device types
    bool auto_probe               // automatically probe for devices?
    
    // Reference counting
    int device_count              // devices bound to this driver
    
    // Driver state
    bool is_loaded
    int initialization_status     // 0=ok, !0=error
}

// Global driver registry
struct driver_registry {
    registered_driver[] drivers
    int driver_count
}

driver_registry global_driver_registry = driver_registry {
    drivers: registered_driver[]{cap: 64},
    driver_count: 0,
}

// ============================================================================
// Driver Registration API
// ============================================================================

// Register a driver with the system
func driver_register(
    string driver_name,
    string driver_version,
    string device_pattern,
    driver_ops ops,
    int priority
) int {
    if global_driver_registry.driver_count >= len(global_driver_registry.drivers) {
        return -1  // registry full
    }
    
    // Check for duplicate
    int i = 0
    for i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == driver_name {
            return -2  // already registered
        }
        i = i + 1
    }
    
    // Create new driver entry
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
    
    // Insert in priority order
    i = global_driver_registry.driver_count
    while i > 0 && global_driver_registry.drivers[i - 1].priority > priority {
        global_driver_registry.drivers[i] = global_driver_registry.drivers[i - 1]
        i = i - 1
    }
    
    global_driver_registry.drivers[i] = drv
    global_driver_registry.driver_count = global_driver_registry.driver_count + 1
    
    return 0
}

// Unregister a driver
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
        return -1  // not found
    }
    
    // Can't unregister if devices still bound
    if global_driver_registry.drivers[idx].device_count > 0 {
        return -2  // devices still attached
    }
    
    // Remove by shifting
    for i = idx; i < global_driver_registry.driver_count - 1; i = i + 1 {
        global_driver_registry.drivers[i] = global_driver_registry.drivers[i + 1]
    }
    
    global_driver_registry.driver_count = global_driver_registry.driver_count - 1
    return 0
}

// ============================================================================
// Device-Driver Binding
// ============================================================================

// Match device with driver (simple pattern matching)
func driver_matches_device(string pattern, device dev) bool {
    // Simple wildcard matching: "nvidia_*" matches "nvidia_gpu_0"
    int pat_len = len(pattern)
    int dev_len = len(dev.device_type)
    
    if pat_len > dev_len {
        return false
    }
    
    // Check if pattern ends with '*'
    if pattern[pat_len - 1] == 42 {  // '*' = 42 in ASCII
        int i = 0
        while i < pat_len - 1 {
            if pattern[i] != dev.device_type[i] {
                return false
            }
            i = i + 1
        }
        return true
    }
    
    // Exact match
    return pattern == dev.device_type
}

// Probe a device - try to bind a driver to it
func device_probe(device dev) driver_result {
    int i = 0
    
    // Try drivers in priority order (already sorted)
    for i < global_driver_registry.driver_count {
        registered_driver drv = global_driver_registry.drivers[i]
        
        if driver_matches_device(drv.device_pattern, dev) {
            // Try to probe
            driver_result result = drv.ops.probe(dev)
            
            if result.success {
                // Update driver's device count
                global_driver_registry.drivers[i].device_count = global_driver_registry.drivers[i].device_count + 1
                
                // Update device's driver binding
                dev.driver_name = drv.driver_name
                device_register(dev)
                
                return result
            }
        }
        
        i = i + 1
    }
    
    // No driver found
    return driver_result {
        success: false,
        error_code: -1,
        error_message: "No compatible driver found",
    }
}

// Remove a device - unbind driver from it
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
    
    // Find the driver
    int i = 0
    while i < global_driver_registry.driver_count {
        if global_driver_registry.drivers[i].driver_name == dev.driver_name {
            // Call driver's remove function
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

// ============================================================================
// Power Management
// ============================================================================

// Suspend a device
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
    
    // Find and call driver
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

// Resume a device
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
    
    // Find and call driver
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

// ============================================================================
// Query API
// ============================================================================

// Get driver by name
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

// List all registered drivers
func driver_list_all() string[] {
    string[] result = string[]{cap: 64}
    int i = 0
    for i < global_driver_registry.driver_count {
        result[i] = global_driver_registry.drivers[i].driver_name
        i = i + 1
    }
    return result
}

// Get driver count
func driver_count() int {
    return global_driver_registry.driver_count
}

// ============================================================================
// Debug & Monitoring
// ============================================================================

// Dump driver registry
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

// Helper to create a dummy driver result
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
