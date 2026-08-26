package neurx.test.platform

use neurx.kernel.platform.empty_platform_capabilities
use neurx.kernel.platform.evaluate_platform
use neurx.kernel.platform.PROFILE_DATACENTER
use neurx.kernel.platform.PROFILE_ROBOTICS
use neurx.kernel.platform.PROFILE_AUTOMOTIVE

func expect(bool condition, string name) int {
    if condition {
        print("PASS ")
        print(name)
        return 0
    }
    print("FAIL ")
    print(name)
    return 1
}

func main() int {
    int failures = 0
    empty := empty_platform_capabilities()
    empty_report := evaluate_platform(PROFILE_DATACENTER(), empty)
    failures = failures + expect(!empty_report.profile_ready, "empty platform rejected")

    platform_capabilities dc = empty_platform_capabilities()
    dc.smp = true
    dc.memory_protection = true
    dc.secure_boot = true
    dc.watchdog = true
    dc.fault_containment = true
    dc.numa = true
    dc.iommu = true
    dc.pci = true
    dc.virtio = true
    dc.rdma = true
    dc.gpu_compute = true
    dc_report := evaluate_platform(PROFILE_DATACENTER(), dc)
    failures = failures + expect(dc_report.profile_ready, "datacenter capability gate")

    platform_capabilities robot = dc
    robot.preempt_rt = true
    robot.sensor_io = true
    robot.actuator_io = true
    robot.can_bus = true
    robot_report := evaluate_platform(PROFILE_ROBOTICS(), robot)
    failures = failures + expect(robot_report.profile_ready, "robotics capability gate")

    auto_report := evaluate_platform(PROFILE_AUTOMOTIVE(), robot)
    failures = failures + expect(!auto_report.profile_ready && auto_report.missing_profile == 2,
        "automotive requires TSN and measured boot")
    return failures
}

func _start() int { return main() }
