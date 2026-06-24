// targets/robot/target.s
// Robotics target: embodied AI OS for manipulation, navigation, and perception.
//
// Constraints:
//   - Real-time control loop: 1kHz servo / 100Hz perception
//   - ROS 2 / DDS interoperability
//   - Power-aware: battery budget tracking
//   - Hardware-in-the-loop simulation support
//
// Primary SoCs: NVIDIA Jetson Orin, Rockchip RK3588
// Middleware: ROS 2 Humble/Iron, micro-ROS
// Actuators: joint motors, grippers, mobile base

struct robot_target_config {
    string  platform           // "jetson_orin" | "rk3588"
    int     control_hz         // servo loop frequency
    int     perception_hz      // perception loop frequency
    bool    ros2_enabled
    bool    sim_mode           // hardware-in-the-loop or pure sim
    string  robot_type         // "arm" | "mobile" | "humanoid" | "drone"
    []string actuators
    []string sensors
}

func default_robot_target() -> robot_target_config {
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
