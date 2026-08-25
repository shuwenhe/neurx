package neurx.drivers.sensor

enum sensor_type {
    lidar_3d,
    camera_rgb,
    camera_thermal,
    radar,
    imu_6dof,
    encoder,
    gps
}

struct sensor_data {
    sensor_type sensor_type
    int timestamp_us
    int* data
    int data_size
}

struct sensor_driver {
    sensor_type sensor_type
    int driver_id
    int sampling_rate_hz
    bool is_streaming
}

func init_sensor(sensor_type: sensor_type, sampling_rate_hz: int) result[sensor_driver, string] {
    result::ok(sensor_driver {
        sensor_type: sensor_type,
        driver_id: 0,
        sampling_rate_hz: sampling_rate_hz,
        is_streaming: false
    })
}

func read_sensor(sensor_driver* driver) result[sensor_data, string] {
    result::ok(sensor_data {
        sensor_type: driver->sensor_type,
        timestamp_us: 0,
        data: 0 as int*,
        data_size: 0
    })
}

func start_streaming(sensor_driver* driver) result[int, string] {
    driver->is_streaming = true
    result::ok(0)
}

func stop_streaming(sensor_driver* driver) result[int, string] {
    driver->is_streaming = false
    result::ok(0)
}
