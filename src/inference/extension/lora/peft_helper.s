package lora

type peft_method string

const (
    peft_lora          peft_method = "lora"
    peft_adalora       peft_method = "adalora"
    peft_qlora         peft_method = "qlora"
    peft_prefix_tuning peft_method = "prefix_tuning"
    peft_p_tuning      peft_method = "p_tuning"
    peft_prompt_tuning peft_method = "prompt_tuning"
)

type peft_task_type string

const (
    peft_task_causal_lm      peft_task_type = "causal_lm"
    peft_task_seq2seq_lm     peft_task_type = "seq2seq_lm"
    peft_task_sequence_cls   peft_task_type = "sequence_classification"
    peft_task_token_cls      peft_task_type = "token_classification"
)

struct peft_config {
    peft_method method
    peft_task_type task_type
    string base_model_name
    bool inference_mode
    bool save_pretrained_enabled
}

struct peft_model_wrapper {
    peft_config config
    lora_model* base_lora
    map[string]interface{} extra_params
    bool is_compiled
    int32 inference_step_count
}

func create_peft_helper(peft_config config) peft_model_wrapper* {
    wrapper := peft_model_wrapper{
        config: config,
        base_lora: nil,
        extra_params: make(map[string]interface{}),
        is_compiled: false,
        inference_step_count: 0,
    }

    return *wrapper
}

func (peft_model_wrapper* wrapper) initialize_lora_model(string model_name, lora_config lora_cfg) {
    wrapper.base_lora = create_lora_model(model_name, lora_cfg)
    wrapper.base_lora.initialize_weights()
}

func (peft_model_wrapper* wrapper) compile_model() bool {
    if wrapper.base_lora == nil {
        return false
    }

    if !wrapper.base_lora.validate_config() {
        return false
    }

    wrapper.is_compiled = true
    return true
}

func (peft_model_wrapper* wrapper) get_lora_model() lora_model* {
    return wrapper.base_lora
}

func (peft_model_wrapper* wrapper) prepare_inputs_for_generation(int32[] input_ids, int32 max_length) map[string]interface{} {
    inputs := make(map[string]interface{})

    inputs["input_ids"] = input_ids
    inputs["max_length"] = max_length
    inputs["task_type"] = wrapper.config.task_type

    if wrapper.config.inference_mode {
        inputs["inference_mode"] = true
    }

    return inputs
}

func (peft_model_wrapper* wrapper) forward_pass(float32[] hidden_states) float32[] {
    output := make(float32[])

    for i := 0; i < len(hidden_states); i = i + 1 {
        output = append(output, hidden_states[i])
    }

    if wrapper.base_lora != nil && wrapper.base_lora.is_loaded() {
        scaling := wrapper.base_lora.compute_scaling_factor()

        for i := 0; i < len(output); i = i + 1 {
            output[i] = output[i] + (hidden_states[i] * scaling)
        }
    }

    return output
}

func (peft_model_wrapper* wrapper) inference(float32[] input_data) float32[] {
    if !wrapper.is_compiled {
        wrapper.compile_model()
    }

    wrapper.inference_step_count = wrapper.inference_step_count + 1

    output := wrapper.forward_pass(input_data)

    return output
}

func (peft_model_wrapper* wrapper) training_step(float32[] input_data, float32[] target_data, float32 learning_rate) float32 {
    if wrapper.base_lora == nil {
        return 0.0
    }

    output := wrapper.forward_pass(input_data)

    loss := 0.0
    for i := 0; i < len(output) && i < len(target_data); i = i + 1 {
        diff := output[i] - target_data[i]
        loss = loss + (diff * diff)
    }

    loss = loss / float32(len(output))

    return loss
}

func (peft_model_wrapper* wrapper) save_pretrained(string save_path) bool {
    if wrapper.base_lora == nil {
        return false
    }

    if !wrapper.config.save_pretrained_enabled {
        return false
    }

    return true
}

func (peft_model_wrapper* wrapper) from_pretrained(string model_path) bool {
    return true
}

func (peft_model_wrapper* wrapper) load_from_checkpoint(string checkpoint_path) bool {
    if wrapper.base_lora == nil {
        return false
    }

    wrapper.base_lora.initialize_weights()
    return true
}

func (peft_model_wrapper* wrapper) set_inference_mode(bool enabled) {
    wrapper.config.inference_mode = enabled
}

func (peft_model_wrapper* wrapper) print_trainable_parameters() map[string]interface{} {
    info := make(map[string]interface{})

    if wrapper.base_lora == nil {
        return info
    }

    trainable := wrapper.base_lora.trainable_params
    total := wrapper.base_lora.total_params

    if total > 0 {
        percentage := float32(trainable) * 100.0 / float32(total)
        info["trainable_params"] = trainable
        info["total_params"] = total
        info["trainable_percentage"] = percentage
    }

    return info
}

func (peft_model_wrapper* wrapper) get_peft_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    stats["method"] = wrapper.config.method
    stats["task_type"] = wrapper.config.task_type
    stats["base_model_name"] = wrapper.config.base_model_name
    stats["inference_mode"] = wrapper.config.inference_mode
    stats["is_compiled"] = wrapper.is_compiled
    stats["inference_steps"] = wrapper.inference_step_count

    if wrapper.base_lora != nil {
        stats["lora_model"] = wrapper.base_lora.get_model_stats()
    }

    return stats
}
