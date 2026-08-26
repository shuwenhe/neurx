package neurx.sys.resource_manager

use neurx.mm.oom_killer.oom_killer
use neurx.drivers.thermal.thermal_core.thermal_core
use neurx.drivers.cpufreq.cpufreq_core.cpufreq_core

struct system_resources {
  memory_manager: &mut oom_killer,
  thermal_manager: &mut thermal_core,
  frequency_manager: &mut cpufreq_core
}

struct resource_stats {
  memory_pressure_percent: int,
  thermal_status: &str,
  power_consumption_watts: int,
  throttle_active: bool
}

func (resources: &mut system_resources) init(total_memory_mb: int, num_cpus: int, max_cpu_freq_mhz: int, base_power_watts: int) {
  resources.memory_manager.init(total_memory_mb)
  resources.thermal_manager.init("neurx-thermal-governor", false)
  resources.frequency_manager.init(num_cpus, max_cpu_freq_mhz)
  
  for i in 0..num_cpus {
    resources.frequency_manager.build_frequency_table(i, max_cpu_freq_mhz, base_power_watts)
  }
  
  resources.frequency_manager.register_governor("performance", 80, 25, 10)
  resources.frequency_manager.register_governor("powersave", 40, 10, 20)
  resources.frequency_manager.register_governor("ondemand", 60, 15, 15)
}

func (resources: &mut system_resources) update_system_state(memory_usage_mb: int, cpu_utilization_percent: int, temperature_c: int) {
  let memory_bytes = memory_usage_mb * 1024 * 1024
  resources.memory_manager.state.available_memory = resources.memory_manager.state.total_memory - memory_bytes
  
  resources.thermal_manager.update_sensor_temperature(0, temperature_c)
  
  for i in 0..10 {
    let _ = resources.frequency_manager.scale_frequency_dynamic(i, cpu_utilization_percent)
  }
}

func (resources: &mut system_resources) get_resource_stats() resource_stats {
  let memory_pressure = resources.memory_manager.get_memory_pressure()
  let thermal_status = resources.thermal_manager.get_status()
  let power_consumption = resources.frequency_manager.estimate_total_power_consumption()
  let throttle_active = resources.frequency_manager.is_power_budget_exceeded()
  
  resource_stats {
    memory_pressure_percent: memory_pressure,
    thermal_status: thermal_status,
    power_consumption_watts: power_consumption,
    throttle_active: throttle_active
  }
}

func (resources: &mut system_resources) handle_resource_pressure() result[&str, &str] {
  if resources.memory_manager.should_trigger_oom() {
    let kill_result = resources.memory_manager.handle_oom_pressure()
    switch kill_result {
      result::ok(pid) : {
        return result::ok("OOM killer terminated process")
      },
      result::err(msg) : {
        return result::err(msg)
      }
    }
  }
  
  if resources.frequency_manager.is_power_budget_exceeded() {
    resources.frequency_manager.apply_power_budget_scaling()
    return result::ok("Power throttling applied")
  }
  
  let thermal_event = resources.thermal_manager.handle_thermal_event()
  thermal_event
}

func (resources: &resources) get_memory_available_mb() int {
  resources.memory_manager.get_available_memory_mb()
}

func (resources: &resources) get_temperature_celsius() int {
  resources.thermal_manager.get_max_temperature()
}

func (resources: &resources) get_total_power_watts() int {
  resources.frequency_manager.estimate_total_power_consumption()
}
