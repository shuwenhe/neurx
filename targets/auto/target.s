












struct auto_target_config {
    string  soc_family
    bool    functional_safety
    int     max_latency_ms
    bool    secure_boot
    string  os_base
    []string sensors
    bool    v2x_enabled
}

func default_auto_target() auto_target_config {
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
