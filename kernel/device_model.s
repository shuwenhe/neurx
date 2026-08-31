package neurx.kernel.device_model

// Device identification and registration

// Device bus types
enum device_bus_type {
    BUS_PLATFORM,
    BUS_PCI,
    BUS_ACPI,
    BUS_I2C,
    BUS_CUSTOM,
}

// Device resource types
enum resource_type {
    RESOURCE_IO,
    RESOURCE_MEM,
    RESOURCE_IRQ,
    RESOURCE_DMA,
}

// Device resource descriptor
struct device_resource {
    resource_type res_type
    int start
    int end
    int flags
}

// Device descriptor (core device model)
struct device {
    string device_id            // "0000:01:00.0" for PCI
    string device_name
    string driver_name
    device_bus_type bus_type
    
    // Classification
    string device_class         // "gpu", "npu", "memory", etc.
    string device_type          // "nvidia_gpu", "huawei_npu", etc.
    
    // Hardware identification
    int vendor_id
    int device_id_hw
    int class_id
    int revision
    
    // Resources
    device_resource[] resources
    int irq_count
    int[] irq_numbers
    
    // Driver management
    int driver_private          // opaque driver context pointer
    
    // Power and state
    int power_state             // 0=on, 1=sleep, 2=deep_sleep, 3=off
    bool is_present
    bool is_active
    bool is_suspended
    
    // Tree structure
    string parent_device_id
    string[] child_devices
    
    // Statistics
    int attach_count            // how many processes use this device
    int error_count
    int interrupt_count
}

// Device tree - hierarchical representation of hardware
struct device_tree {
    device[] devices
    int device_count
    string root_device_id
}

// Global device registry
device_tree global_device_tree = device_tree {
    devices: make([]device, 128),
    device_count: 0,
    root_device_id: "root",
}

// ============================================================================
// Device Registration API
// ============================================================================

// Register a device with the system
func device_register(device dev) int {
    if global_device_tree.device_count >= len(global_device_tree.devices) {
        return -1  // device tree full
    }
    
    // Check for duplicate
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_id == dev.device_id {
            return -2  // already registered
        }
        i = i + 1
    }
    
    // Add to tree
    global_device_tree.devices[global_device_tree.device_count] = dev
    global_device_tree.device_count = global_device_tree.device_count + 1
    
    return 0
}

// Unregister a device
func device_unregister(string device_id) int {
    int idx = -1
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_id == device_id {
            idx = i
        }
        i = i + 1
    }
    
    if idx < 0 {
        return -1  // not found
    }
    
    // Remove by shifting
    for i = idx; i < global_device_tree.device_count - 1; i = i + 1 {
        global_device_tree.devices[i] = global_device_tree.devices[i + 1]
    }
    
    global_device_tree.device_count = global_device_tree.device_count - 1
    return 0
}

// Lookup device by ID
func device_get(string device_id) device {
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_id == device_id {
            return global_device_tree.devices[i]
        }
        i = i + 1
    }
    return device {
        device_id: "",
        device_name: "",
        is_present: false,
    }
}

// List devices of a given class
func device_list_by_class(string device_class) []string {
    string[] result = make([]string, 64)
    int count = 0
    
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_class == device_class {
            result[count] = global_device_tree.devices[i].device_id
            count = count + 1
        }
        i = i + 1
    }
    
    return result
}

// List all devices of a given type
func device_list_by_type(string device_type) []string {
    string[] result = make([]string, 64)
    int count = 0
    
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_type == device_type {
            result[count] = global_device_tree.devices[i].device_id
            count = count + 1
        }
        i = i + 1
    }
    
    return result
}

// Get all GPUs in system
func device_get_all_gpus() []string {
    return device_list_by_class("gpu")
}

// Get all NPUs in system
func device_get_all_npus() []string {
    return device_list_by_class("npu")
}

// ============================================================================
// Device State Management
// ============================================================================

// Update device state
func device_set_state(string device_id, bool is_active, int power_state) int {
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_id == device_id {
            global_device_tree.devices[i].is_active = is_active
            global_device_tree.devices[i].power_state = power_state
            return 0
        }
        i = i + 1
    }
    return -1  // device not found
}

// Increment device error count
func device_record_error(string device_id) int {
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_id == device_id {
            global_device_tree.devices[i].error_count = global_device_tree.devices[i].error_count + 1
            return 0
        }
        i = i + 1
    }
    return -1
}

// Increment interrupt count
func device_record_interrupt(string device_id) int {
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_id == device_id {
            global_device_tree.devices[i].interrupt_count = global_device_tree.devices[i].interrupt_count + 1
            return 0
        }
        i = i + 1
    }
    return -1
}

// ============================================================================
// Device Discovery & Enumeration
// ============================================================================

// Scan for available devices (placeholder - will be implemented per architecture)
func device_scan_pci_bus() int {
    // This would call platform-specific PCI enumeration
    // For now, return 0 (implemented in architecture-specific code)
    return 0
}

func device_scan_platform_devices() int {
    // Platform device enumeration
    return 0
}

// ============================================================================
// Helper Functions
// ============================================================================

// Get device count
func device_count() int {
    return global_device_tree.device_count
}

// Get device count by class
func device_count_by_class(string device_class) int {
    int count = 0
    int i = 0
    for i < global_device_tree.device_count {
        if global_device_tree.devices[i].device_class == device_class {
            count = count + 1
        }
        i = i + 1
    }
    return count
}

// Convert power state to string
func power_state_to_string(int state) string {
    if state == 0 { return "on" }
    if state == 1 { return "sleep" }
    if state == 2 { return "deep_sleep" }
    if state == 3 { return "off" }
    return "unknown"
}

// Convert bus type to string
func bus_type_to_string(device_bus_type bus) string {
    if bus == BUS_PLATFORM { return "platform" }
    if bus == BUS_PCI { return "pci" }
    if bus == BUS_ACPI { return "acpi" }
    if bus == BUS_I2C { return "i2c" }
    return "custom"
}

// Dump device info (for debugging)
func device_dump_info(string device_id) string {
    device d = device_get(device_id)
    if !d.is_present {
        return "Device not found: " + device_id
    }
    
    string info = ""
    info = info + "Device: " + d.device_name + "\n"
    info = info + "  ID: " + d.device_id + "\n"
    info = info + "  Class: " + d.device_class + "\n"
    info = info + "  Type: " + d.device_type + "\n"
    info = info + "  Bus: " + bus_type_to_string(d.bus_type) + "\n"
    info = info + "  Driver: " + d.driver_name + "\n"
    info = info + "  Active: " + (if d.is_active { "yes" } else { "no" }) + "\n"
    info = info + "  Power State: " + power_state_to_string(d.power_state) + "\n"
    info = info + "  Errors: " + string(d.error_count) + "\n"
    info = info + "  Interrupts: " + string(d.interrupt_count) + "\n"
    
    return info
}

// List all devices
func device_dump_all() string {
    string output = ""
    output = output + "Device Tree (" + string(global_device_tree.device_count) + " devices)\n"
    output = output + "==========================================\n"
    
    int i = 0
    for i < global_device_tree.device_count {
        device d = global_device_tree.devices[i]
        output = output + "[" + string(i) + "] " + d.device_id + " (" + d.device_class + ")\n"
        output = output + "    " + d.device_name + " - " + d.driver_name + "\n"
        i = i + 1
    }
    
    return output
}
