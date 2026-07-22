

struct robot_target_config {
    string  platform
    int     control_hz
    int     perception_hz
    bool    ros2_enabled
    bool    sim_mode
    string  robot_type
    []string actuators
    []string sensors
}

func default_robot_target() robot_target_config {
    return robot_target_config{
        platform:       "jetson_orin",
        control_hz:     1000,
        perception_hz:  100,
        ros2_enabled:   true,
        sim_mode:       false,
        robot_type:     "arm",
        actuators:      ["joint_motors", "gripper"],
        sensors:        ["camera", "depth", "imu", "force_torque"],
    }
}
