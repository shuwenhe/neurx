import "tensor/tensor.s"
import "src/inference/extension/tokenizer/tokenizer.s"
import "src/inference/sampling_strategies.s"

struct hf_transformers_config {
    model_name_or_path: string
    device: string
    dtype: string
    max_new_tokens: i32
    temperature: f32
    top_k: i32
    top_p: f32
    repetition_penalty: f32
    do_sample: bool
    num_beams: i32
    use_cache: bool
    low_cpu_mem_usage: bool
    torch_dtype: string
    batch_size: i32
    padding_side: string
    trust_remote_code: bool
    revision: string
}

struct hf_transformers_rollout {
    config: hf_transformers_config
    model: *hf_model
    tokenizer: *hf_tokenizer
    device: device
    total_prompts: i64
    total_tokens_generated: i64
    total_time_ms: i64
}

struct hf_model {
    model_type: string
    config: model_config
    layers: []transformer_layer
    lm_head: *linear
    token_embeddings: *embedding
    position_embeddings: *embedding
    past_key_values: [][]tensor
}

struct hf_tokenizer {
    vocab_size: i32
    pad_token_id: i32
    eos_token_id: i32
    bos_token_id: i32
    vocab: map[string]i32
    inverse_vocab: map[i32]string
    special_tokens: map[string]i32
}

func new_hf_transformers_rollout(hf_transformers_config config) . hf_transformers_rollout {
    model := load_hf_model(
        config.model_name_or_path,
        config.device,
        config.dtype,
        config.trust_remote_code,
        config.low_cpu_mem_usage
    )
    tokenizer := load_hf_tokenizer(
        config.model_name_or_path,
        config.padding_side,
        config.trust_remote_code
    )
    device := parse_device(config.device)
    return hf_transformers_rollout{
        config: config,
        model: model,
        tokenizer: tokenizer,
        device: device,
        total_prompts: 0,
        total_tokens_generated: 0,
        total_time_ms: 0,
    }
}

func (hf_transformers_rollout* rollout) generate_batch(
    []string prompts
) . ([]string, [][]f32) {
    start_time := get_time_ms()
    rollout.total_prompts += i64(len(prompts))
    input_ids, attention_mask  := rollout.tokenize_batch(prompts)
    output_ids, log_probs  := rollout.generate(
        input_ids,
        attention_mask,
        rollout.config.max_new_tokens
    )
    responses := []
    for i in 0..output_ids.shape[0] {
        output_seq := output_ids[i]
        response := rollout.tokenizer.decode(output_seq)
        responses = append(responses, response)
        rollout.total_tokens_generated += i64(output_seq.shape[0] - input_ids.shape[1])
    }
    elapsed := get_time_ms() - start_time
    rollout.total_time_ms += elapsed
    return responses, log_probs
}

func (hf_transformers_rollout* rollout) generate(
    tensor input_ids,
    tensor attention_mask,
    i32 max_new_tokens
) . (tensor, [][]f32) {
    batch_size := input_ids.shape[0]
    input_length := input_ids.shape[1]
    max_length := input_length + max_new_tokens
    output_ids := tensor_zeros([batch_size, max_length], i64 dtype)
    output_ids[.., ..input_length] = input_ids
    finished := tensor_zeros([batch_size], bool dtype)
    all_log_probs := []
    for i in 0..batch_size {
        all_log_probs = append(all_log_probs, [])
    }
    rollout.model.past_key_values = []
    for step in 0..max_new_tokens {
        if finished.all() {
            break
        }
        current_input: tensor
        current_attention_mask: tensor
        if step == 0 {
            current_input = input_ids
            current_attention_mask = attention_mask
        } else {
            current_input = output_ids[.., input_length + step - 1].unsqueeze(1)
            new_mask := tensor_ones([batch_size, 1])
            current_attention_mask = concat(attention_mask, new_mask, dim: 1)
            attention_mask = current_attention_mask
        }
        logits, past_kv  := rollout.model.forward(
            current_input,
            attention_mask: current_attention_mask,
            past_key_values: rollout.model.past_key_values,
            use_cache: rollout.config.use_cache
        )
        if rollout.config.use_cache {
            rollout.model.past_key_values = past_kv
        }
        next_token_logits := logits[.., -1, ..]
        next_tokens, token_log_probs  := rollout.sample_next_tokens(
            next_token_logits,
            finished
        )
        output_ids[.., input_length + step] = next_tokens
        for i in 0..batch_size {
            if !finished[i].item() {
                all_log_probs[i].push(token_log_probs[i])
            }
        }
        for i in 0..batch_size {
            if next_tokens[i].item() == rollout.tokenizer.eos_token_id {
                finished[i] = true
            }
        }
    }
    return output_ids, all_log_probs
}

func (hf_transformers_rollout* rollout) sample_next_tokens(
    tensor logits,
    tensor finished
) . (tensor, []f32) {
    batch_size := logits.shape[0]
    if !rollout.config.do_sample {
        next_tokens := logits.argmax(dim: -1)
        log_probs := log_softmax(logits, dim: -1)
        token_log_probs := []
        for i in 0..batch_size {
            token_id := next_tokens[i].item()
            log_prob := log_probs[i, token_id].item()
            token_log_probs = append(token_log_probs, log_prob)
        }
        return next_tokens, token_log_probs
    }
    scaled_logits := logits / rollout.config.temperature
    if rollout.config.top_k > 0 {
        scaled_logits = top_k_filtering(scaled_logits, rollout.config.top_k)
    }
    if rollout.config.top_p < 1.0 {
        scaled_logits = top_p_filtering(scaled_logits, rollout.config.top_p)
    }
    if rollout.config.repetition_penalty != 1.0 {
    }
    probs := softmax(scaled_logits, dim: -1)
    next_tokens := multinomial(probs, num_samples: 1).squeeze(1)
    log_probs := log_softmax(scaled_logits, dim: -1)
    token_log_probs := []
    for i in 0..batch_size {
        if !finished[i].item() {
            token_id := next_tokens[i].item()
            log_prob := log_probs[i, token_id].item()
            token_log_probs = append(token_log_probs, log_prob)
        } else {
            token_log_probs = append(token_log_probs, 0.0)
        }
    }
    return next_tokens, token_log_probs
}

func (hf_transformers_rollout* rollout) tokenize_batch(
    []string prompts
) . (tensor, tensor) {
    all_input_ids := []
    max_length := 0
    for prompt in prompts {
        input_ids := rollout.tokenizer.encode(prompt)
        all_input_ids = append(all_input_ids, input_ids)
        if len(input_ids) > max_length {
            max_length = len(input_ids)
        }
    }
    batch_size := len(prompts)
    input_ids_tensor := tensor_full(
        [batch_size, max_length],
        rollout.tokenizer.pad_token_id,
        dtype: i64
    )
    attention_mask := tensor_zeros([batch_size, max_length])
    for i, ids in all_input_ids {
        length := len(ids)
        if rollout.config.padding_side == "left" {
            offset := max_length - length
            for j, id in ids {
                input_ids_tensor[i, offset + j] = tensor_scalar(id)
                attention_mask[i, offset + j] = tensor_scalar(1)
            }
        } else {
            for j, id in ids {
                input_ids_tensor[i, j] = tensor_scalar(id)
                attention_mask[i, j] = tensor_scalar(1)
            }
        }
    }
    return input_ids_tensor, attention_mask
}

func (hf_transformers_rollout* rollout) get_statistics() . (i64, i64, f32, f32) {
    avg_tokens_per_prompt := 0.0
    if rollout.total_prompts > 0 {
        avg_tokens_per_prompt = f32(rollout.total_tokens_generated) / f32(rollout.total_prompts)
    }
    tokens_per_second := 0.0
    if rollout.total_time_ms > 0 {
        tokens_per_second = f32(rollout.total_tokens_generated) / (f32(rollout.total_time_ms) / 1000.0)
    }
    return (
        rollout.total_prompts,
        rollout.total_tokens_generated,
        avg_tokens_per_prompt,
        tokens_per_second
    )
}

func (hf_transformers_rollout* rollout) print_statistics() {
    prompts, tokens, avg_tokens, throughput  := rollout.get_statistics()
    println("HuggingFace Transformers Rollout Statistics:")
    println(f"  Total prompts: {prompts}")
    println(f"  Total tokens generated: {tokens}")
    println(f"  Average tokens per prompt: {avg_tokens:.2f}")
    println(f"  Throughput: {throughput:.2f} tokens/s")
    println(f"  Total time: {rollout.total_time_ms / 1000} s")
}

func load_hf_model(
    string model_name,
    string device,
    string dtype,
    bool trust_remote_code,
    bool low_cpu_mem_usage
) . *hf_model {
    println(f"Loading HF model: {model_name}")
    println(f"  Device: {device}")
    println(f"  Dtype: {dtype}")
    return null
}

func load_hf_tokenizer(
    string model_name,
    string padding_side,
    bool trust_remote_code
) . *hf_tokenizer {
    println(f"Loading HF tokenizer: {model_name}")
    println(f"  Padding side: {padding_side}")
    return null
}

func parse_device(string device_str) . device {
    return device{}
}

struct device {
    device_type: string
    device_id: i32
}

struct model_config {
    hidden_size: i32
    num_layers: i32
    num_heads: i32
    vocab_size: i32
}

struct transformer_layer {
    self_attention: *attention
    mlp: *mlp
    layer_norm1: *layer_norm
    layer_norm2: *layer_norm
}

struct embedding {}

struct linear {}

struct attention {}

struct mlp {}

struct layer_norm {}

func get_time_ms() . i64 {
    return 0
}
