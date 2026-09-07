package neurx.driver

struct device_type {
    int value
}

func device_type_cpu() device_type { device_type { value: 0 } }

func device_type_memory() device_type { device_type { value: 1 } }

func device_type_storage() device_type { device_type { value: 2 } }

func device_type_network() device_type { device_type { value: 3 } }

func device_type_gpu() device_type { device_type { value: 4 } }

func device_type_tpu() device_type { device_type { value: 5 } }

func device_type_sensor() device_type { device_type { value: 6 } }

func device_type_actuator() device_type { device_type { value: 7 } }

func device_type_pci() device_type { device_type { value: 8 } }

func device_type_usb() device_type { device_type { value: 9 } }

struct device_state {
    int value
}

func device_state_unknown() device_state { device_state { value: 0 } }

func device_state_detected() device_state { device_state { value: 1 } }

func device_state_initialized() device_state { device_state { value: 2 } }

func device_state_bound() device_state { device_state { value: 3 } }

func device_state_suspended() device_state { device_state { value: 4 } }

func device_state_removed() device_state { device_state { value: 5 } }

struct device_attribute {
    string attr_name
    string attr_value
    int attr_type
}

struct device {
    string device_id
    string device_name
    device_type dev_type
    device_state dev_state
    string driver_name
    int vendor_id
    int device_id_hw
    device_attribute[] attributes
    int irq_number
    int dma_channel
    int instance_count
}

struct device_driver {
    string driver_name
    string driver_version
    device_type supported_type
    int probe_count
    int remove_count
    int suspend_count
    int resume_count
    int error_count
}

struct device_class {
    string class_name
    device_type class_type
    device[] devices
    int max_devices
    int total_devices
    int total_active
}

struct device_bus {
    string bus_name
    device[] devices
    device_driver[] drivers
    int total_devices
    int total_drivers
    int hotplug_enabled
}

struct device_manager {
    device_bus[] buses
    device_class[] classes
    int total_devices
    int total_drivers
    int hotplug_events
    int device_discovery_time_us
}

func device_create(string device_id, string device_name, device_type dev_type) device {
    dev := device {
        device_id: device_id,
        device_name: device_name,
        dev_type: dev_type,
        dev_state: device_state_device_unknown,
        driver_name: "",
        vendor_id: 0,
        device_id_hw: 0,
        attributes: device_attribute[](),
        irq_number: -1,
        dma_channel: -1,
        instance_count: 0
    }
    return dev
}

func (device* dev) set_attribute(string attr_name, string attr_value) (bool, string) {
    attr := device_attribute {
        attr_name: attr_name,
        attr_value: attr_value,
        attr_type: 0
    }
    dev.attributes = append(dev.attributes, attr)
    return true, ""
}

func (device* dev) set_state(device_state state) {
    dev.dev_state = state
}

func (device* dev) bind_driver(string driver_name, int irq, int dma) (bool, string) {
    if driver_name == "" {
        return ((), "Invalid driver name")
    }
    dev.driver_name = driver_name
    dev.irq_number = irq
    dev.dma_channel = dma
    dev.dev_state = device_state_device_bound
    return true, ""
}

func device_driver_create(string driver_name, string version, device_type dev_type) device_driver {
    driver := device_driver {
        driver_name: driver_name,
        driver_version: version,
        supported_type: dev_type,
        probe_count: 0,
        remove_count: 0,
        suspend_count: 0,
        resume_count: 0,
        error_count: 0
    }
    return driver
}

func (device_driver* driver) probe() (bool, string) {
    driver.probe_count = driver.probe_count + 1
    return true, ""
}

func (device_driver* driver) remove() (bool, string) {
    driver.remove_count = driver.remove_count + 1
    return true, ""
}

func (device_driver* driver) suspend() (bool, string) {
    driver.suspend_count = driver.suspend_count + 1
    return true, ""
}

func (device_driver* driver) resume() (bool, string) {
    driver.resume_count = driver.resume_count + 1
    return true, ""
}

func device_class_create(string class_name, device_type class_type, int max_devices) device_class {
    class := device_class {
        class_name: class_name,
        class_type: class_type,
        devices: device[](),
        max_devices: max_devices,
        total_devices: 0,
        total_active: 0
    }
    return class
}

func (device_class* dev_class) register_device(device dev) (bool, string) {
    if dev_class.total_devices >= dev_class.max_devices {
        return ((), "Device class full")
    }
    
    dev_class.devices = append(dev_class.devices, dev)
    dev_class.total_devices = dev_class.total_devices + 1
    dev_class.total_active = dev_class.total_active + 1
    
    return true, ""
}

func (device_class* dev_class) unregister_device(string device_id) (bool, string) {
    i := 0
    while i < len(dev_class.devices) {
        if dev_class.devices[i].device_id == device_id {
            dev_class.devices.pop()
            if dev_class.total_devices > 0 {
                dev_class.total_devices = dev_class.total_devices - 1
            }
            if dev_class.total_active > 0 {
                dev_class.total_active = dev_class.total_active - 1
            }
            return true, ""
        }
        i = i + 1
    }
    return ((), "Device not found")
}

func device_bus_create(string bus_name) device_bus {
    bus := device_bus {
        bus_name: bus_name,
        devices: []device{},
        drivers: []device_driver{},
        total_devices: 0,
        total_drivers: 0,
        hotplug_enabled: 1
    }
    return bus
}

func (device_bus* bus) register_device(device dev) (bool, string) {
    bus.devices = append(bus.devices, dev)
    bus.total_devices = bus.total_devices + 1
    return true, ""
}

func (device_bus* bus) register_driver(device_driver driver) (bool, string) {
    bus.drivers = append(bus.drivers, driver)
    bus.total_drivers = bus.total_drivers + 1
    return true, ""
}

func (device_bus* bus) match_and_bind() (int, string) {
    matched := 0
    
    i := 0
    while i < len(bus.devices) {
        dev_type := bus.devices[i].dev_type
        
        j := 0
        while j < len(bus.drivers) {
            if bus.drivers[j].supported_type == dev_type {
                bus.drivers[j].probe()?
                matched = matched + 1
                break
            }
            j = j + 1
        }
        
        i = i + 1
    }
    
    return matched, ""
}

func device_manager_create() device_manager {
    mgr := device_manager {
        buses: []device_bus{},
        classes: []device_class{},
        total_devices: 0,
        total_drivers: 0,
        hotplug_events: 0,
        device_discovery_time_us: 0
    }
    return mgr
}

func (device_manager* mgr) register_bus(string bus_name) (device_bus, string) {
    bus := device_bus_create(bus_name)
    mgr.buses = append(mgr.buses, bus)
    return bus, ""
}

func (device_manager* mgr) add_device(string bus_name, device dev) (bool, string) {
    i := 0
    while i < len(mgr.buses) {
        if mgr.buses[i].bus_name == bus_name {
            mgr.buses[i].register_device(dev)?
            mgr.total_devices = mgr.total_devices + 1
            return true, ""
        }
        i = i + 1
    }
    return ((), "Bus not found")
}

func (device_manager* mgr) add_driver(string bus_name, device_driver driver) (bool, string) {
    i := 0
    while i < len(mgr.buses) {
        if mgr.buses[i].bus_name == bus_name {
            mgr.buses[i].register_driver(driver)?
            mgr.total_drivers = mgr.total_drivers + 1
            return true, ""
        }
        i = i + 1
    }
    return ((), "Bus not found")
}

func (device_manager* mgr) hotplug_device(string bus_name, device dev) (bool, string) {
    mgr.hotplug_events = mgr.hotplug_events + 1
    return mgr.add_device(bus_name, dev)
}

func (device_manager* mgr) device_discovery_stats() string {
    total_dev := mgr.total_devices
    total_drv := mgr.total_drivers
    hotplug := mgr.hotplug_events
    return "Devices: " + total_dev as string + ", Drivers: " + total_drv as string + ", Hotplug: " + hotplug as string
}
