package neurx.backend.platform.driving

use std.slices
use std.io.println

    camera,
    lidar,
    radar,
    imu,
    gps,
}

struct sensor_reading {
    sensor_type stype
    []float data
    int timestamp_us
    bool valid
}

struct sensor_fusion_result {
    []float fused_state
    []float uncertainty
    int fusion_latency_us
}

struct sensor_fusion_engine {
    []sensor_type active_sensors
    int fusion_rate_hz
    int max_sensor_latency_us
    bool outlier_rejection_enabled
}

func new_sensor_fusion_engine(int hz) sensor_fusion_engine {
    return sensor_fusion_engine{
        active_sensors: sensor_type[](),
        fusion_rate_hz: hz,
        max_sensor_latency_us: 50000,
        outlier_rejection_enabled: true,
    }
}

func (sensor_fusion_engine* engine) register_sensor(sensor_type stype) {
    engine.active_sensors = append(engine.active_sensors, stype)
}

func (sensor_fusion_engine* engine) fuse_readings([]sensor_reading readings) sensor_fusion_result {    fused_state := []float()
    uncertainty := []float()
    
    for i in len(0..readings) {
        if readings[i].valid {
            for j in 0..readings[i]len(.data) {
                fused_state = append(fused_state, readings[i].data[j])
            }
        }
    }
    
    return sensor_fusion_result{
        fused_state: fused_state,
        uncertainty: uncertainty,
        fusion_latency_us: 0,
    }
}

func (sensor_fusion_engine* engine) get_active_sensor_count() int {    len(engine.active_sensors)
}

func (sensor_fusion_engine* engine) get_fusion_rate_hz() int {    engine.fusion_rate_hz
}

func (sensor_fusion_engine* engine) get_max_sensor_latency_us() int {    engine.max_sensor_latency_us
}
