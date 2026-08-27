package neurx.kernel.platform

func PROFILE_DATACENTER() int { 1 }
func PROFILE_ROBOTICS() int { 2 }
func PROFILE_AUTOMOTIVE() int { 3 }

struct platform_capabilities {
    bool smp
    bool numa
    bool iommu
    bool preempt_rt
    bool memory_protection
    bool secure_boot
    bool measured_boot
    bool watchdog
    bool pci
    bool virtio
    bool rdma
    bool can_bus
    bool tsn
    bool sensor_io
    bool actuator_io
    bool gpu_compute
    bool npu_compute
    bool fault_containment
}

struct readiness_report {
    bool common_ready
    bool profile_ready
    int missing_common
    int missing_profile
    int safety_level
}

func empty_platform_capabilities() platform_capabilities {
    platform_capabilities {
        smp: false, numa: false, iommu: false, preempt_rt: false,
        memory_protection: false, secure_boot: false, measured_boot: false,
        watchdog: false, pci: false, virtio: false, rdma: false,
        can_bus: false, tsn: false, sensor_io: false, actuator_io: false,
        gpu_compute: false, npu_compute: false, fault_containment: false
    }
}

func common_missing(platform_capabilities caps) int {
    int missing = 0
    if !caps.smp { missing = missing + 1 }
    if !caps.memory_protection { missing = missing + 1 }
    if !caps.secure_boot { missing = missing + 1 }
    if !caps.watchdog { missing = missing + 1 }
    if !caps.fault_containment { missing = missing + 1 }
    return missing
}

func datacenter_missing(platform_capabilities caps) int {
    int missing = 0
    if !caps.numa { missing = missing + 1 }
    if !caps.iommu { missing = missing + 1 }
    if !caps.pci { missing = missing + 1 }
    if !caps.virtio { missing = missing + 1 }
    if !caps.rdma { missing = missing + 1 }
    if !caps.gpu_compute && !caps.npu_compute { missing = missing + 1 }
    return missing
}

func robotics_missing(platform_capabilities caps) int {
    int missing = 0
    if !caps.preempt_rt { missing = missing + 1 }
    if !caps.sensor_io { missing = missing + 1 }
    if !caps.actuator_io { missing = missing + 1 }
    if !caps.can_bus { missing = missing + 1 }
    return missing
}

func automotive_missing(platform_capabilities caps) int {
    int missing = robotics_missing(caps)
    if !caps.tsn { missing = missing + 1 }
    if !caps.measured_boot { missing = missing + 1 }
    if !caps.iommu { missing = missing + 1 }
    return missing
}

func evaluate_platform(int profile, platform_capabilities caps) readiness_report {
    int common = common_missing(caps)
    int profile_missing = 0
    int safety_level = 0
    if profile == PROFILE_DATACENTER() {
        profile_missing = datacenter_missing(caps)
        safety_level = 1
    } else if profile == PROFILE_ROBOTICS() {
        profile_missing = robotics_missing(caps)
        safety_level = 2
    } else if profile == PROFILE_AUTOMOTIVE() {
        profile_missing = automotive_missing(caps)
        safety_level = 3
    } else {
        profile_missing = 1
    }
    readiness_report {
        common_ready: common == 0,
        profile_ready: common == 0 && profile_missing == 0,
        missing_common: common,
        missing_profile: profile_missing,
        safety_level safety_level
    }
}
