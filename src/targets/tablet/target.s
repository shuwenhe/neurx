// targets/tablet/target.s
// Tablet target: AI OS layer for iPads and Android tablets.
//
// Constraints:
//   - Power budget: < 6W sustained (larger battery than phone)
//   - Large-screen context: richer UI, split-screen agents
//   - Stylus / touch input as perception modality
//   - Offline-first: intermittent connectivity
//
// Primary SoCs: Apple M-series (iPad Pro), Snapdragon 8cx, MediaTek Dimensity
// OS: iPadOS 17+, Android 14+
// Runtime: CoreML, NNAPI, QNN

struct tablet_target_config {
    string  os              // "ipados" | "android"
    string  soc_family      // "apple_m" | "snapdragon_8cx" | "dimensity"
    string  runtime         // "coreml" | "nnapi" | "qnn"
    int     max_power_mw
    bool    stylus_input
    bool    split_screen
    bool    offline_first
    string  precision       // "fp16" | "int8"
}

func default_tablet_target() -> tablet_target_config {
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
