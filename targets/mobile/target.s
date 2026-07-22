

struct mobile_target_config {
    string  os
    string  soc_family
    string  runtime
    int     max_power_mw
    bool    on_device_only
    bool    background_allowed
    string  precision
}

func default_mobile_target() mobile_target_config {
    return mobile_target_config{
        os:                 "android",
        soc_family:         "snapdragon",
        runtime:            "qnn",
        max_power_mw:       2500,
        on_device_only:     true,
        background_allowed: false,
        precision:          "int8",
    }
}
