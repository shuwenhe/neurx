package neurx.posttrain.multimodal.vlm_rl
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}
struct vlm_config {
    int vision_encoder_dim
    int text_encoder_dim
    int hidden_dim
    int num_vision_tokens
    bool freeze_vision_encoder
    string vision_encoder_type
    int image_size
    int patch_size
}

struct multimodal_input {
    tensor image
    []int text_tokens
    []int attention_mask
    []int image_positions
}

struct vlm_output {
    tensor logits
    tensor vision_features
    tensor text_features
    tensor fused_features
}

func new_vlm_config() vlm_config {
    vlm_config {
        vision_encoder_dim: 1024,
        text_encoder_dim: 2048,
        hidden_dim: 2048,
        num_vision_tokens: 256,
        freeze_vision_encoder: true,
        vision_encoder_type: "clip",
        image_size: 448,
        patch_size: 14,
    }
}

func encode_image(
    tensor image,
    module vision_encoder,
    vlm_config config
) tensor {
    tensor normalized = tensor_ops.div_scalar(image, 255.0)
    int num_patches = (config.image_size / config.patch_size) *
                     (config.image_size / config.patch_size)
    tensor vision_features = vision_encoder.forward(normalized)
    if vision_features.shape[-1] != config.hidden_dim {
        vision_features = tensor_ops.linear_projection(
            vision_features,
            config.vision_encoder_dim,
            config.hidden_dim
        )
    }
    vision_features
}

func fuse_vision_text_features(
    tensor vision_features,
    tensor text_embeddings,
    []int image_positions,
    int seq_len
) tensor {
    int batch_size = text_embeddings.shape[0]
    int hidden_dim = text_embeddings.shape[2]
    tensor fused = tensor_ops.zeros([batch_size, seq_len, hidden_dim])
    fused = tensor_ops.copy(text_embeddings)
    int b = 0
    while b < batch_size {
        int i = 0
        while i < image_positions.len {
            int pos = image_positions[i]
            if pos >= 0 && pos < seq_len {
                tensor vision_token = tensor_ops.index_select(
                    vision_features,
                    1,
                    i
                )
                fused = tensor_ops.index_copy(
                    fused,
                    1,
                    pos,
                    vision_token
                )
            }
            i = i + 1
        }
        b = b + 1
    }
    fused
}

func vlm_forward(
    module model,
    multimodal_input input,
    vlm_config config
) vlm_output {
    tensor vision_features = model.vision_encoder.forward(input.image)
    tensor text_embeddings = model.text_embeddings(input.text_tokens)
    int seq_len = input.text_tokens.len
    tensor fused = fuse_vision_text_features(
        vision_features,
        text_embeddings,
        input.image_positions,
        seq_len
    )
    tensor hidden = model.transformer.forward(
        fused,
        input.attention_mask
    )
    tensor logits = model.lm_head.forward(hidden)
    vlm_output {
        logits: logits,
        vision_features: vision_features,
        text_features: text_embeddings,
        fused_features: fused,
    }
}

func vlm_grpo_step(
    module policy,
    module reference_policy,
    []multimodal_input inputs,
    [][]int actions,
    []tensor rewards,
    int group_size,
    float kl_coef
) tensor {
    int batch_size = inputs.len
    []vlm_output outputs = []vlm_output{cap: batch_size}
    []vlm_output ref_outputs = []vlm_output{cap: batch_size}
    int i = 0
    while i < batch_size {
        outputs[i] = policy.forward_vlm(inputs[i])
        if reference_policy.exists {
            ref_outputs[i] = reference_policy.forward_vlm(inputs[i])
        }
        i = i + 1
    }
    []tensor baselines = []tensor{cap: batch_size}
    i = 0
    while i < batch_size {
        int group_idx = i / group_size
        int group_start = group_idx * group_size
        int group_end = group_start + group_size
        tensor sum = tensor_ops.zeros_like(rewards[i])
        int count = 0
        int j = group_start
        while j < group_end {
            sum = tensor_ops.add(sum, rewards[j])
            count = count + 1
            j = j + 1
        }
        baselines[i] = tensor_ops.div_scalar(sum, count * 1.0)
        i = i + 1
    }
    []tensor advantages = []tensor{cap: batch_size}
    i = 0
    while i < batch_size {
        advantages[i] = tensor_ops.sub(rewards[i], baselines[i])
        i = i + 1
    }
    tensor adv_cat = tensor_ops.concat(advantages, 0)
    float mean_adv = tensor_ops.mean_scalar(adv_cat)
    float std_adv = tensor_ops.std_scalar(adv_cat)
    i = 0
    while i < batch_size {
        advantages[i] = tensor_ops.div_scalar(
            tensor_ops.sub_scalar(advantages[i], mean_adv),
            std_adv + 1e-8
        )
        i = i + 1
    }
    tensor total_loss = tensor_ops.zeros([1])
    i = 0
    while i < batch_size {
        tensor logits = outputs[i].logits
        tensor log_probs = tensor_ops.log_softmax(logits, -1)
        int j = 0
        tensor action_log_probs = tensor_ops.zeros([1])
        while j < actions[i].len {
            tensor lp = tensor_ops.gather(
                log_probs,
                tensor{data: [actions[i][j]], shape: [1]},
                -1
            )
            action_log_probs = tensor_ops.add(action_log_probs, lp)
            j = j + 1
        }
        tensor loss_i = tensor_ops.mul(
            action_log_probs,
            advantages[i]
        )
        total_loss = tensor_ops.add(total_loss, loss_i)
        i = i + 1
    }
    total_loss = tensor_ops.neg(
        tensor_ops.div_scalar(total_loss, batch_size * 1.0)
    )
    total_loss
}
