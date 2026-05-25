// targets/mobile/target.s
// Mobile target: AI OS layer for smartphones (iOS / Android).
//
// Constraints:
//   - Power budget: < 3W sustained inference
//   - Thermal throttle awareness
//   - On-device privacy: no mandatory cloud offload
//   - Background execution limits enforced by OS
//
// Primary SoCs: Apple A-series (ANE), Qualcomm Snapdragon (HTP), MediaTek (APU)
// OS: iOS 17+, Android 14+
// Runtime: CoreML, NNAPI, QNN

struct mobile_target_config {
    string  os             // "ios" | "android"
    string  soc_family     // "apple_a" | "snapdragon" | "dimensity"
    string  runtime        // "coreml" | "nnapi" | "qnn"
    int     max_power_mw
    bool    on_device_only
    bool    background_allowed
    string  precision      // "fp16" | "int8" | "int4"
}

func default_mobile_target() -> mobile_target_config {
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
