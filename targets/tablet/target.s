struct tablet_target_config {
    string  os
    string  soc_family
    string  runtime
    int     max_power_mw
    bool    stylus_input
    bool    split_screen
    bool    offline_first
    string  precision
}

func default_tablet_target() tablet_target_config {
    return tablet_target_config{
        os:           "ipados",
        soc_family:   "apple_m",
        runtime:      "coreml",
        max_power_mw: 6000,
        stylus_input: true,
        split_screen: true,
        offline_first: true,
        precision:    "fp16",
    }
}
