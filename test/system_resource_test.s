package neurx.test.system_resource_test

use neurx.mm.oom_killer.oom_killer
use neurx.drivers.thermal.thermal_core.thermal_core
use neurx.drivers.cpufreq.cpufreq_core.cpufreq_core
use neurx.sys.resource_manager.system_resources

func test_oom_killer_basic() {
  let mut killer = oom_killer {
    state: &mut memory_pressure_state { 
      total_memory: 0,
      available_memory: 0,
      threshold_percent: 0,
      oom_kill_enabled: false,
      last_kill_time_ms: 0
    },
    processes: &mut vec[process_info](),
    kill_history: &mut vec[int]()
  }
  
  killer.init(8192)
  
  killer.register_process(100, "inference_engine", 2147483648, 50, false)
  killer.register_process(101, "training_service", 1610612736, 60, false)
  killer.register_process(1, "init", 1073741824, 100, true)
  
  let pressure = killer.get_memory_pressure()
  assert pressure > 0 && pressure <= 100
}

func test_oom_killer_victim_selection() {
  let mut killer = oom_killer {
    state: &mut memory_pressure_state {
      total_memory: 0,
      available_memory: 0,
      threshold_percent: 0,
      oom_kill_enabled: false,
      last_kill_time_ms: 0
    },
    processes: &mut vec[process_info](),
    kill_history: &mut vec[int]()
  }
  
  killer.init(4096)
  
  killer.register_process(200, "low_priority", 536870912, 10, false)
  killer.register_process(201, "high_priority", 1073741824, 90, false)
  killer.register_process(202, "background", 268435456, 20, false)
  
  let victim_opt = killer.select_victim()
  switch victim_opt {
    option::some(pid) : {
      assert pid == 200
    },
    option::none : {
      assert false
    }
  }
}

func test_thermal_core_basic() {
  let mut thermal = thermal_core {
    zones: &mut vec[thermal_zone](),
    sensors: &mut vec[thermal_sensor](),
    cooling_devices: &mut vec[cooling_device](),
    governor: &mut thermal_governor {
      name: "fairbanks",
      aggressive_mode: false,
      polling_interval_ms: 0,
      throttle_step_percent: 0
    },
    emergency_shutdown_enabled: false,
    total_throttle_events: 0
  }
  
  thermal.init("thermal_governor", false)
  thermal.register_sensor(0, "cpu_sensor", 100, 85, 95)
  thermal.register_sensor(1, "gpu_sensor", 90, 80, 88)
  
  thermal.update_sensor_temperature(0, 45)
  thermal.update_sensor_temperature(1, 50)
  
  let state = thermal.evaluate_thermal_state()
  assert state == "Normal"
}

func test_thermal_throttling() {
  let mut thermal = thermal_core {
    zones: &mut vec[thermal_zone](),
    sensors: &mut vec[thermal_sensor](),
    cooling_devices: &mut vec[cooling_device](),
    governor: &mut thermal_governor {
      name: "fairbanks",
      aggressive_mode: false,
      polling_interval_ms: 0,
      throttle_step_percent: 0
    },
    emergency_shutdown_enabled: false,
    total_throttle_events: 0
  }
  
  thermal.init("thermal_governor", false)
  thermal.register_sensor(0, "cpu_sensor", 100, 85, 95)
  
  thermal.update_sensor_temperature(0, 88)
  
  let should_throttle = thermal.should_throttle_frequency()
  assert should_throttle
  
  let throttle_level = thermal.get_throttle_level()
  assert throttle_level >= 50
}

func test_cpufreq_basic() {
  let mut cpufreq = cpufreq_core {
    policies: &mut vec[cpufreq_policy](),
    frequency_tables: &mut vec[cpu_frequency_table](),
    governors: &mut vec[frequency_governor](),
    current_governor_name: "",
    power_limit_watts: 0,
    total_power_saved_mwh: 0,
    frequency_change_count: 0
  }
  
  cpufreq.init(8, 3600)
  
  cpufreq.build_frequency_table(0, 3600, 95)
  cpufreq.register_governor("performance", 80, 25, 10)
  cpufreq.register_governor("powersave", 40, 10, 20)
  
  let freq_opt = cpufreq.get_current_frequency(0)
  switch freq_opt {
    option::some(freq) : {
      assert freq > 0 && freq <= 3600
    },
    option::none : {
      assert false
    }
  }
}

func test_cpufreq_dynamic_scaling() {
  let mut cpufreq = cpufreq_core {
    policies: &mut vec[cpufreq_policy](),
    frequency_tables: &mut vec[cpu_frequency_table](),
    governors: &mut vec[frequency_governor](),
    current_governor_name: "",
    power_limit_watts: 0,
    total_power_saved_mwh: 0,
    frequency_change_count: 0
  }
  
  cpufreq.init(4, 3600)
  cpufreq.register_governor("ondemand", 60, 15, 15)
  
  let result = cpufreq.scale_frequency_dynamic(0, 85)
  switch result {
    result::ok(freq) : {
      assert freq > 0
    },
    result::err(msg) : {
      assert false
    }
  }
}

func test_resource_manager_integration() {
  let mut resources = system_resources {
    memory_manager: &mut oom_killer {
      state: &mut memory_pressure_state {
        total_memory: 0,
        available_memory: 0,
        threshold_percent: 0,
        oom_kill_enabled: false,
        last_kill_time_ms: 0
      },
      processes: &mut vec[process_info](),
      kill_history: &mut vec[int]()
    },
    thermal_manager: &mut thermal_core {
      zones: &mut vec[thermal_zone](),
      sensors: &mut vec[thermal_sensor](),
      cooling_devices: &mut vec[cooling_device](),
      governor: &mut thermal_governor {
        name: "fairbanks",
        aggressive_mode: false,
        polling_interval_ms: 0,
        throttle_step_percent: 0
      },
      emergency_shutdown_enabled: false,
      total_throttle_events: 0
    },
    frequency_manager: &mut cpufreq_core {
      policies: &mut vec[cpufreq_policy](),
      frequency_tables: &mut vec[cpu_frequency_table](),
      governors: &mut vec[frequency_governor](),
      current_governor_name: "",
      power_limit_watts: 0,
      total_power_saved_mwh: 0,
      frequency_change_count: 0
    }
  }
  
  resources.init(16384, 8, 3600, 120)
  
  resources.update_system_state(8192, 75, 70)
  
  let stats = resources.get_resource_stats()
  assert stats.memory_pressure_percent >= 0
  assert stats.memory_pressure_percent <= 100
}

func assert(condition: bool) {
  if !condition {
    abort()
  }
}
