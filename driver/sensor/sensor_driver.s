package neurx.drivers.sensor


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

func init_sensor(sensor_type sensor_type, int sampling_rate_hz) (sensor_driver, string) {
    (sensor_driver {
        sensor_type: sensor_type,
        driver_id: 0,
        sampling_rate_hz: sampling_rate_hz,
        is_streaming: false
    })
}

func read_sensor(sensor_driver* driver) (sensor_data, string) {
    (sensor_data {
        sensor_type: driver.sensor_type,
        timestamp_us: 0,
        data: 0 as int*,
        data_size: 0
    })
}

func start_streaming(sensor_driver* driver) (int, string) {
    driver.is_streaming = true
    0, ""
}

func stop_streaming(sensor_driver* driver) (int, string) {
    driver.is_streaming = false
    0, ""
}
