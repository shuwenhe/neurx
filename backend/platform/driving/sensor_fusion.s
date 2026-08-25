package neurx.backend.platform.driving

use std.vec.vec
use std.io.println

enum sensor_type {
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
        active_sensors: vec[sensor_type](),
        fusion_rate_hz: hz,
        max_sensor_latency_us: 50000,
        outlier_rejection_enabled: true,
    }
}

func (engine: &mut sensor_fusion_engine) register_sensor(sensor_type stype) {
    engine.active_sensors.push(stype)
}

func (engine: &sensor_fusion_engine) fuse_readings([]sensor_reading readings) sensor_fusion_result {
    fused_state := vec[float]()
    uncertainty := vec[float]()
    
    for i in 0..readings.len() {
        if readings[i].valid {
            for j in 0..readings[i].data.len() {
                fused_state.push(readings[i].data[j])
            }
        }
    }
    
    return sensor_fusion_result{
        fused_state: fused_state,
        uncertainty: uncertainty,
        fusion_latency_us: 0,
    }
}

func (engine: &sensor_fusion_engine) get_active_sensor_count() int {
    engine.active_sensors.len()
}

func (engine: &sensor_fusion_engine) get_fusion_rate_hz() int {
    engine.fusion_rate_hz
}

func (engine: &sensor_fusion_engine) get_max_sensor_latency_us() int {
    engine.max_sensor_latency_us
}
