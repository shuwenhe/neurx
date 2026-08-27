package neurx.lora.lora_config

use std.slices
use std.option.option
use std.result.result
use std.map.map

struct lora_config {
    lora_rank: int
    lora_alpha: float
    lora_dropout: float
    target_modules: *string[]
    bias: string
    task_type: string
    modules_to_save: option[*string[]]
    init_lora_weights: bool
}

struct lora_config_error {
    code: string
    message: string
}

func lora_config::default() lora_config {
    lora_config {
        lora_rank: 8,
        lora_alpha: 16.0,
        lora_dropout: 0.05,
        target_modules: string[](),
        bias: "none",
        task_type: "CAUSAL_LM",
        modules_to_save: option::none,
        init_lora_weights: true,
    }
}

func (lora_config* config) validate() ((), lora_config_error) {

    if config.lora_rank <= 0 || config.lora_rank > 1024 {
        return (lora_config_error {
            code: "INVALID_RANK",
            message: "lora_rank must be in range (0, 1024], got: " + config.lora_rank.to_string(),
        })
    }

    if config.lora_alpha <= 0.0 {
        return (lora_config_error {
            code: "INVALID_ALPHA",
            message: "lora_alpha must be positive, got: " + config.lora_alpha.to_string(),
        })
    }

    if config.lora_dropout < 0.0 || config.lora_dropout > 1.0 {
        return (lora_config_error {
            code: "INVALID_DROPOUT",
            message: "lora_dropout must be in range [0.0, 1.0], got: " + config.lora_dropout.to_string(),
        })
    }

    valid_bias := config.bias == "none" ||
                     config.bias == "lora_only" ||
                     config.bias == "all"
    if !valid_bias {
        return (lora_config_error {
            code: "INVALID_BIAS",
            message: "bias must be 'none', 'lora_only' or 'all', got: " + config.bias,
        })
    }

    if len(config.task_type) == 0 {
        return (lora_config_error {
            code: "INVALID_TASK_TYPE",
            message: "task_type cannot be empty",
        })
    }

    return (), ""
}

func lora_config::from_dict(
    config_dict: *map[string, string]
) (lora_config, lora_config_error) {
    config := lora_config::default()

    switch config_dict.get("lora_rank") {
        option::some(val) : {
            switch val.parse::<int>() {
                option::some(rank) : {
                    config.lora_rank = rank
                },
                option::none : {
                    return (lora_config_error {
                        code: "PARSE_ERROR",
                        message: "Failed to parse lora_rank: " + val,
                    })
                },
            }
        },
        option::none : {},
    }

    switch config_dict.get("lora_alpha") {
        option::some(val) : {
            switch val.parse::<float>() {
                option::some(alpha) : {
                    config.lora_alpha = alpha
                },
                option::none : {
                    return (lora_config_error {
                        code: "PARSE_ERROR",
                        message: "Failed to parse lora_alpha: " + val,
                    })
                },
            }
        },
        option::none : {},
    }

    switch config_dict.get("lora_dropout") {
        option::some(val) : {
            switch val.parse::<float>() {
                option::some(dropout) : {
                    config.lora_dropout = dropout
                },
                option::none : {
                    return (lora_config_error {
                        code: "PARSE_ERROR",
                        message: "Failed to parse lora_dropout: " + val,
                    })
                },
            }
        },
        option::none : {},
    }

    switch config_dict.get("bias") {
        option::some(val) : {
            config.bias = val
        },
        option::none : {},
    }

    switch config_dict.get("task_type") {
        option::some(val) : {
            config.task_type = val
        },
        option::none : {},
    }

    config.validate()

return     (config, "")
}

func (lora_config* config) get_lora_scaling() float {
    config.lora_alpha / config.lora_rank as float
}

func (lora_config* config) is_target_module(string module_name) bool {
    for target in config.target_modules.iter() {
        if target == module_name {
            return true
        }
    }
    false
}

func (lora_config* config) should_save_full_weights(string module_name) bool {
    switch config.modules_to_save {
        option::some(modules) : {
            for module in modules.iter() {
                if module == module_name {
                    return true
                }
            }
            false
        },
        option::none : false,
    }
}

func (lora_config* config) summary() string {
    s := "LoRA Configuration:\n"
    s = s + "  rank: " + config.lora_rank.to_string() + "\n"
    s = s + "  alpha: " + config.lora_alpha.to_string() + "\n"
    s = s + "  dropout: " + config.lora_dropout.to_string() + "\n"
    s = s + "  bias: " + config.bias + "\n"
    s = s + "  task_type: " + config.task_type + "\n"
    s = s + "  scaling_factor: " + config.get_lora_scaling().to_string() + "\n"
    s
}
