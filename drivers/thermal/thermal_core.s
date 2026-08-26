package neurx.drivers.thermal

use std.vec.vec
use std.option.option

struct thermal_sensor {
    sensor_id int
    name &str
    current_temp_c int
    max_temp_c int
    min_temp_c int
    warning_threshold_c int
    critical_threshold_c int
}

struct thermal_zone {
    zone_id int
    name &str
    type_name &str
    sensors* vec[int]
    current_temp_c int
    passive_cooling_enabled bool
    active_cooling_level int
}

struct cooling_device {
    device_id int
    name &str
    type_name &str
    max_state int
    current_state int
    power_saving_mode bool
}

struct thermal_governor {
    name &str
    aggressive_mode bool
    polling_interval_ms int
    throttle_step_percent int
}

struct thermal_core {
    zones* vec[thermal_zone]
    sensors* vec[thermal_sensor]
    cooling_devices* vec[cooling_device]
    governor* thermal_governor
    emergency_shutdown_enabled bool
    total_throttle_events int
}

func (core* thermal_core) init(name &str, aggressive bool) {
    core.governor.name = name
    core.governor.aggressive_mode = aggressive
    core.governor.polling_interval_ms = 1000
    core.governor.throttle_step_percent = if aggressive { 20 } else { 10 }
    core.emergency_shutdown_enabled = true
    core.total_throttle_events = 0
}

func (core* thermal_core) register_sensor(sensor_id int, name &str, max_temp_c int, warning_c int, critical_c int) {
    let sensor = thermal_sensor {
        sensor_id: sensor_id,
        name: name,
        current_temp_c: 25,
        max_temp_c: max_temp_c,
        min_temp_c: 0,
        warning_threshold_c: warning_c,
        critical_threshold_c: critical_c
    }
    core.sensors.push(sensor)
}

func (core* thermal_core) create_thermal_zone(zone_id int, name &str, type_name &str) {
    let zone = thermal_zone {
        zone_id: zone_id,
        name: name,
        type_name: type_name,
        sensors: nil,
        current_temp_c: 25,
        passive_cooling_enabled: false,
        active_cooling_level: 0
    }
    core.zones.push(zone)
}

func (core* thermal_core) register_cooling_device(device_id int, name &str, type_name &str, max_state int) {
    let device = cooling_device {
        device_id: device_id,
        name: name,
        type_name: type_name,
        max_state: max_state,
        current_state: 0,
        power_saving_mode: false
    }
    core.cooling_devices.push(device)
}

func (core* thermal_core) update_sensor_temperature(sensor_id int, temp_c int) {
    for i in 0..core.sensors.len() {
        if core.sensors[i].sensor_id == sensor_id {
            core.sensors[i].current_temp_c = temp_c
            break
        }
    }
}

func (core thermal_core) get_average_temperature() int {
    if core.sensors.len() == 0 {
        return 25
    }
    let mut sum = 0
    for i in 0..core.sensors.len() {
        sum = sum + core.sensors[i].current_temp_c
    }
    sum / core.sensors.len()
}

func (core thermal_core) get_max_temperature() int {
    if core.sensors.len() == 0 {
        return 25
    }
    let mut max_temp = 0
    for i in 0..core.sensors.len() {
        if core.sensors[i].current_temp_c > max_temp {
            max_temp = core.sensors[i].current_temp_c
        }
    }
    max_temp
}

func (core thermal_core) evaluate_thermal_state() &str {
    let max_temp = core.get_max_temperature()
    
    if max_temp >= 95 {
        "Critical"
    } else if max_temp >= 85 {
        "Warning"
    } else if max_temp >= 70 {
        "Elevated"
    } else {
        "Normal"
    }
}

func (core thermal_core) should_enable_passive_cooling() bool {
    let max_temp = core.get_max_temperature()
    max_temp >= 80
}

func (core thermal_core) should_throttle_frequency() bool {
    let max_temp = core.get_max_temperature()
    max_temp >= 85
}

func (core thermal_core) get_throttle_level() int {
    let max_temp = core.get_max_temperature()
    
    if max_temp >= 95 {
        100
    } else if max_temp >= 90 {
        75
    } else if max_temp >= 85 {
        50
    } else if max_temp >= 80 {
        25
    } else {
        0
    }
}

func (core* thermal_core) apply_passive_cooling(zone_id int) {
    for i in 0..core.zones.len() {
        if core.zones[i].zone_id == zone_id {
            core.zones[i].passive_cooling_enabled = true
            break
        }
    }
}

func (core* thermal_core) apply_active_cooling(zone_id int, level int) {
    for i in 0..core.zones.len() {
        if core.zones[i].zone_id == zone_id {
            let max_level = if core.zones[i].active_cooling_level > 3 { 3 } else { core.zones[i].active_cooling_level }
            core.zones[i].active_cooling_level = if level > max_level { max_level } else { level }
            break
        }
    }
}

func (core* thermal_core) set_cooling_device_state(device_id int, state int) {
    for i in 0..core.cooling_devices.len() {
        if core.cooling_devices[i].device_id == device_id {
            core.cooling_devices[i].current_state = if state > core.cooling_devices[i].max_state { core.cooling_devices[i].max_state } else { state }
            break
        }
    }
}

func (core* thermal_core) handle_thermal_event() &str {
    let state = core.evaluate_thermal_state()
    
    switch state {
        "Critical" : {
            if core.emergency_shutdown_enabled {
                "Emergency thermal shutdown triggered"
            } else {
                "Critical temperature detected - throttling to maximum"
            }
        },
        "Warning" : {
            core.total_throttle_events = core.total_throttle_events + 1
            "Warning: High temperature - applying aggressive throttling"
        },
        "Elevated" : {
            "Elevated temperature - enabling passive cooling"
        },
        "Normal" : {
            "Temperature normal"
        },
        _ : {
            "Unknown thermal state"
        }
    }
}

func (core thermal_core) get_cooling_device_state(device_id int) option[int] {
    for i in 0..core.cooling_devices.len() {
        if core.cooling_devices[i].device_id == device_id {
            return option::some(core.cooling_devices[i].current_state)
        }
    }
    option::none()
}

func (core thermal_core) get_status() &str {
    core.evaluate_thermal_state()
}

func (core thermal_core) get_total_throttle_events() int {
    core.total_throttle_events
}

func (core thermal_core) get_sensor_count() int {
    core.sensors.len()
}

func (core thermal_core) get_cooling_device_count() int {
    core.cooling_devices.len()
}
