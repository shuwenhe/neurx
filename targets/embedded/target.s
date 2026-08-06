struct embedded_target_config {
    string  mcu_family
    int     ram_kb
    int     flash_kb
    string  rtos
    string  inference_runtime
    int     max_power_mw
    string  precision
}

func default_embedded_target() embedded_target_config {
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

