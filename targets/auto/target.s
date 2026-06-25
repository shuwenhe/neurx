// targets/auto/target.s
// Automotive target: in-vehicle AI OS for ADAS, cockpit, and autonomous driving.
//
// Constraints:
//   - Functional safety: ISO 26262 ASIL-B/D
//   - Hard real-time: latency budget <= 10ms per inference step
//   - No dynamic memory allocation in safety-critical paths
//   - Secure boot + hardware attestation required
//
// Primary SoCs: NVIDIA DRIVE Orin, Qualcomm SA8xxx, Renesas R-Car
// OS base: QNX, AGL (Automotive Grade Linux), RTOS
// Connectivity: CAN, Ethernet AVB, V2X

struct auto_target_config {
    string  soc_family         // "orin" | "sa8xxx" | "rcar"
    bool    functional_safety
    int     max_latency_ms
    bool    secure_boot
    string  os_base            // "qnx" | "agl" | "rtos"
    []string sensors           // ["camera", "lidar", "radar", "ultrasonic"]
    bool    v2x_enabled
}

func default_auto_target() -> auto_target_config {
    return auto_target_config{
        soc_family:       "orin",
        functional_safety: true,
        max_latency_ms:   10,
        secure_boot:      true,
        os_base:          "qnx",
        sensors:          ["camera", "lidar", "radar"],
        v2x_enabled:      false,
    }
}
