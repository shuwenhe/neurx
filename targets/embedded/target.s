// targets/embedded/target.s
// Embedded target: ultra-constrained AI OS for MCU/DSP-class devices.
// Covers wearables, smart sensors, IoT edge nodes.
//
// Constraints:
//   - RAM: 256KB – 8MB
//   - Flash: 512KB – 32MB
//   - No OS or bare-metal RTOS (FreeRTOS / Zephyr)
//   - Quantized inference only (int8 / int4 / binary)
//   - Power: < 100mW
//
// Primary SoCs: STM32, ESP32-S3, NXP i.MX RT, Ambiq Apollo
// Frameworks: TFLite Micro, CMSIS-NN

struct embedded_target_config {
    string  mcu_family      // "stm32" | "esp32" | "nxp_imxrt" | "ambiq"
    int     ram_kb
    int     flash_kb
    string  rtos            // "freertos" | "zephyr" | "bare_metal"
    string  inference_runtime // "tflite_micro" | "cmsis_nn"
    int     max_power_mw
    string  precision       // "int8" | "int4" | "binary"
}

func default_embedded_target() -> embedded_target_config {
    return embedded_target_config{
        mcu_family:         "stm32",
        ram_kb:             512,
        flash_kb:           2048,
        rtos:               "freertos",
        inference_runtime:  "tflite_micro",
        max_power_mw:       50,
        precision:          "int8",
    }
}
