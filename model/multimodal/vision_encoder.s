package neurx.model.multimodal.vision_encoder
import "neurx.util.math"
enum vision_encoder_type {
    TRANSFORMER = 0
    RESNET = 1
    HYBRID = 2
}
struct vision_encoder_config {
    vision_encoder_type encoder_type
    int image_size
    int patch_size
    int num_channels
    int hidden_dim
    int num_layers
    int num_heads
    int num_scales
    float rope_scale
    float rope_theta
    bool use_adaptive_resolution
    bool use_2d_rope
    bool use_multi_scale_features
    int max_image_size
    int min_image_size
}

struct image_feature {
    []float features
    []float spatial_features
    []float scale_features
    int width
    int height
    int num_patches
    int num_scales
}

struct vision_encoder {
    vision_encoder_config config
    [][]float patch_embedding_weights
    []float patch_embedding_biases
    [][]float transformer_weights
    [][]float transformer_biases
    [][]float positional_embeddings
    [][]float scale_projection_weights
    []float scale_projection_biases
}

struct image_token {
    []float embedding
    int row_idx
    int col_idx
    int scale_idx
}
func new_vision_encoder_config() vision_encoder_config {
    vision_encoder_config {
        encoder_type: TRANSFORMER,
        image_size: 224,
        patch_size: 16,
        num_channels: 3,
        hidden_dim: 768,
        num_layers: 12,
        num_heads: 12,
        num_scales: 3,
        rope_scale: 1.0,
        rope_theta: 10000.0,
        use_adaptive_resolution: true,
        use_2d_rope: true,
        use_multi_scale_features: true,
        max_image_size: 1024,
        min_image_size: 64,
    }
}

func new_image_feature(int width, int height, int hidden_dim, int num_scales) image_feature {
    int num_patches = (width / 16) * (height / 16)
    image_feature {
        features: math.allocate_float(num_patches * hidden_dim, 0.0),
        spatial_features: math.allocate_float(num_patches * hidden_dim, 0.0),
        scale_features: math.allocate_float(num_scales * hidden_dim, 0.0),
        width: width,
        height: height,
        num_patches: num_patches,
        num_scales: num_scales,
    }
}

func new_vision_encoder(vision_encoder_config config) vision_encoder {
    int num_patches = (config.image_size / config.patch_size) * (config.image_size / config.patch_size)
    vision_encoder encoder {
        config: config,
        patch_embedding_weights: math.allocate_float(config.patch_size * config.patch_size * config.num_channels * config.hidden_dim, 0.0),
        patch_embedding_biases: math.allocate_float(config.hidden_dim, 0.0),
        transformer_weights: math.allocate_float(config.num_layers * config.hidden_dim * config.hidden_dim, 0.0),
        transformer_biases: math.allocate_float(config.num_layers * config.hidden_dim, 0.0),
        positional_embeddings: math.allocate_float(num_patches * config.hidden_dim, 0.0),
        scale_projection_weights: math.allocate_float(config.num_scales * config.hidden_dim * config.hidden_dim, 0.0),
        scale_projection_biases: math.allocate_float(config.num_scales * config.hidden_dim, 0.0),
    }
    int i = 0
    while i < num_patches {
        encoder.positional_embeddings[i * config.hidden_dim..(i+1) * config.hidden_dim] =
            compute_2d_rope_embedding(i / (config.image_size / config.patch_size), i % (config.image_size / config.patch_size), config)
        i = i + 1
    }
    encoder
}

func compute_2d_rope_embedding(int row, int col, vision_encoder_config config) []float {
    []float embedding = math.allocate_float(config.hidden_dim, 0.0)
    float theta = config.rope_theta
    float scale = config.rope_scale
    int head_dim = config.hidden_dim / config.num_heads
    int head = 0
    while head < config.num_heads {
        int dim = 0
        while dim < head_dim {
            float inv_freq = 1.0 / math.exp_approx(float(dim) * math.log_approx(theta) / float(head_dim))
            float row_embedding = float(row) * inv_freq * scale
            float col_embedding = float(col) * inv_freq * scale
            if dim % 2 == 0 {
                embedding[head * head_dim + dim] = math.cos_approx(row_embedding)
                embedding[head * head_dim + dim + 1] = math.sin_approx(col_embedding)
            } else {
                embedding[head * head_dim + dim] = -math.sin_approx(row_embedding)
                embedding[head * head_dim + dim + 1] = math.cos_approx(col_embedding)
            }
            dim = dim + 2
        }
        head = head + 1
    }
    embedding
}

func adaptive_resolution_scaling([]float image, int original_width, int original_height,
                                  vision_encoder_config config) ([]float, int, int) {
    int target_size = config.image_size
    if config.use_adaptive_resolution {
        float ratio = float(original_width) / float(original_height)
        if ratio > 1.0 {
            target_size = math.min_int(config.max_image_size, int(float(config.image_size) * ratio))
        } else {
            target_size = math.min_int(config.max_image_size, int(float(config.image_size) / ratio))
        }
        target_size = math.max_int(config.min_image_size, target_size)
    }
    int new_width = target_size
    int new_height = target_size
    if float(original_width) / float(original_height) > 1.0 {
        new_height = int(float(target_size) / (float(original_width) / float(original_height)))
    } else {
        new_width = int(float(target_size) * (float(original_width) / float(original_height)))
    }
    int num_pixels = new_width * new_height * config.num_channels
    []float scaled_image = math.allocate_float(num_pixels, 0.0)
    int y = 0
    while y < new_height {
        int x = 0
        while x < new_width {
            int orig_y = int(float(y) * float(original_height) / float(new_height))
            int orig_x = int(float(x) * float(original_width) / float(new_width))
            int c = 0
            while c < config.num_channels {
                int orig_idx = (orig_y * original_width + orig_x) * config.num_channels + c
                int new_idx = (y * new_width + x) * config.num_channels + c
                if orig_idx < len(image) && new_idx < len(scaled_image) {
                    scaled_image[new_idx] = image[orig_idx]
                }
                c = c + 1
            }
            x = x + 1
        }
        y = y + 1
    }
    (scaled_image, new_width, new_height)
}

func patchify_image([]float image, int width, int height, vision_encoder_config config) []float {
    int patch_size = config.patch_size
    int num_channels = config.num_channels
    int hidden_dim = config.hidden_dim
    int num_patches_x = width / patch_size
    int num_patches_y = height / patch_size
    int num_patches = num_patches_x * num_patches_y
    []float patches = math.allocate_float(num_patches * hidden_dim, 0.0)
    int py = 0
    while py < num_patches_y {
        int px = 0
        while px < num_patches_x {
            int patch_idx = py * num_patches_x + px
            []float patch = math.allocate_float(patch_size * patch_size * num_channels, 0.0)
            int y = 0
            while y < patch_size {
                int x = 0
                while x < patch_size {
                    int c = 0
                    while c < num_channels {
                        int img_idx = ((py * patch_size + y) * width + (px * patch_size + x)) * num_channels + c
                        int patch_idx_ = (y * patch_size + x) * num_channels + c
                        if img_idx < len(image) && patch_idx_ < len(patch) {
                            patch[patch_idx_] = image[img_idx]
                        }
                        c = c + 1
                    }
                    x = x + 1
                }
                y = y + 1
            }
            []float patch_embedding = math.allocate_float(hidden_dim, 0.0)
            int i = 0
            while i < hidden_dim {
                patch_embedding[i] = config.patch_embedding_biases[i]
                int j = 0
                while j < patch_size * patch_size * num_channels {
                    patch_embedding[i] = patch_embedding[i] + patch[j] * config.patch_embedding_weights[j * hidden_dim + i]
                    j = j + 1
                }
                patch_embedding[i] = math.gelu_approx(patch_embedding[i])
                i = i + 1
            }
            patches[patch_idx * hidden_dim..(patch_idx+1) * hidden_dim] = patch_embedding
            px = px + 1
        }
        py = py + 1
    }
    patches
}

func multihead_attention_2d([]float queries, []float keys, []float values,
                            int num_heads, int head_dim, int seq_len) []float {
    int hidden_dim = num_heads * head_dim
    []float output = math.allocate_float(seq_len * hidden_dim, 0.0)
    int head = 0
    while head < num_heads {
        []float q_head = math.allocate_float(seq_len * head_dim, 0.0)
        []float k_head = math.allocate_float(seq_len * head_dim, 0.0)
        []float v_head = math.allocate_float(seq_len * head_dim, 0.0)
        int i = 0
        while i < seq_len {
            int j = 0
            while j < head_dim {
                q_head[i * head_dim + j] = queries[i * hidden_dim + head * head_dim + j]
                k_head[i * head_dim + j] = keys[i * hidden_dim + head * head_dim + j]
                v_head[i * head_dim + j] = values[i * hidden_dim + head * head_dim + j]
                j = j + 1
            }
            i = i + 1
        }
        []float attention_scores = math.allocate_float(seq_len * seq_len, 0.0)
        i = 0
        while i < seq_len {
            int j = 0
            while j < seq_len {
                float score = 0.0
                int k = 0
                while k < head_dim {
                    score = score + q_head[i * head_dim + k] * k_head[j * head_dim + k]
                    k = k + 1
                }
                attention_scores[i * seq_len + j] = score / math.sqrt_approx(float(head_dim))
                j = j + 1
            }
            i = i + 1
        }
        []float attn_slice = attention_scores
        for idx in 0..seq_len-1 {
            []float row = attn_slice[idx * seq_len..(idx+1) * seq_len]
            []float softmax_row = math.softmax_1d(row)
            attn_slice[idx * seq_len..(idx+1) * seq_len] = softmax_row
        }
        []float head_output = math.allocate_float(seq_len * head_dim, 0.0)
        i = 0
        while i < seq_len {
            int j = 0
            while j < seq_len {
                int k = 0
                while k < head_dim {
                    head_output[i * head_dim + k] = head_output[i * head_dim + k] +
                                                   attention_scores[i * seq_len + j] * v_head[j * head_dim + k]
                    k = k + 1
                }
                j = j + 1
            }
            i = i + 1
        }
        i = 0
        while i < seq_len {
            int j = 0
            while j < head_dim {
                output[i * hidden_dim + head * head_dim + j] = head_output[i * head_dim + j]
                j = j + 1
            }
            i = i + 1
        }
        head = head + 1
    }
    output
}

func transformer_layer_forward([]float input, []float weights_qkv, []float weights_out,
                               []float biases_qkv, []float biases_out,
                               int num_heads, int head_dim, int seq_len) []float {
    int hidden_dim = num_heads * head_dim
    []float qkv = math.matmul_bias(input, weights_qkv, biases_qkv, seq_len, hidden_dim, hidden_dim * 3)
    []float queries = math.allocate_float(seq_len * hidden_dim, 0.0)
    []float keys = math.allocate_float(seq_len * hidden_dim, 0.0)
    []float values = math.allocate_float(seq_len * hidden_dim, 0.0)
    int i = 0
    while i < seq_len {
        int j = 0
        while j < hidden_dim {
            queries[i * hidden_dim + j] = qkv[i * hidden_dim * 3 + j]
            keys[i * hidden_dim + j] = qkv[i * hidden_dim * 3 + hidden_dim + j]
            values[i * hidden_dim + j] = qkv[i * hidden_dim * 3 + hidden_dim * 2 + j]
            j = j + 1
        }
        i = i + 1
    }
    []float attention_output = multihead_attention_2d(queries, keys, values, num_heads, head_dim, seq_len)
    []float output = math.matmul_bias(attention_output, weights_out, biases_out, seq_len, hidden_dim, hidden_dim)
    i = 0
    while i < seq_len * hidden_dim {
        output[i] = output[i] + input[i]
        output[i] = math.gelu_approx(output[i])
        i = i + 1
    }
    output
}

func extract_multi_scale_features([]float features, int width, int height,
                                  vision_encoder_config config) []float {
    int hidden_dim = config.hidden_dim
    int num_scales = config.num_scales
    []float scale_features = math.allocate_float(num_scales * hidden_dim, 0.0)
    int num_patches_x = width / config.patch_size
    int num_patches_y = height / config.patch_size
    int scale = 0
    while scale < num_scales {
        float scale_factor = math.exp_approx(-float(scale) * 0.5)
        int center_x = num_patches_x / 2
        int center_y = num_patches_y / 2
        int radius = int(float(math.min_int(num_patches_x, num_patches_y)) * scale_factor)
        []float scale_feature = math.allocate_float(hidden_dim, 0.0)
        int count = 0
        int y = math.max_int(0, center_y - radius)
        while y < math.min_int(num_patches_y, center_y + radius) {
            int x = math.max_int(0, center_x - radius)
            while x < math.min_int(num_patches_x, center_x + radius) {
                int patch_idx = y * num_patches_x + x
                int d = 0
                while d < hidden_dim {
                    scale_feature[d] = scale_feature[d] + features[patch_idx * hidden_dim + d]
                    d = d + 1
                }
                count = count + 1
                x = x + 1
            }
            y = y + 1
        }
        if count > 0 {
            int d = 0
            while d < hidden_dim {
                scale_feature[d] = scale_feature[d] / float(count)
                d = d + 1
            }
        }
        scale_features[scale * hidden_dim..(scale+1) * hidden_dim] = scale_feature
        scale = scale + 1
    }
    scale_features
}

func encode_image(vision_encoder encoder, []float image, int original_width, int original_height) image_feature {
    vision_encoder_config config = encoder.config
    ([]float scaled_image, int new_width, int new_height) = adaptive_resolution_scaling(
        image, original_width, original_height, config
    )
    []float patches = patchify_image(scaled_image, new_width, new_height, config)
    int num_patches = (new_width / config.patch_size) * (new_height / config.patch_size)
    []float features = math.copy_float(patches)
    features = math.apply_bias(features, encoder.positional_embeddings, num_patches, config.hidden_dim)
    int layer = 0
    while layer < config.num_layers {
        []float weights_qkv = encoder.transformer_weights[layer * config.hidden_dim * config.hidden_dim..(layer+1) * config.hidden_dim * config.hidden_dim]
        []float weights_out = encoder.transformer_weights[(layer + config.num_layers) * config.hidden_dim * config.hidden_dim..(layer + config.num_layers + 1) * config.hidden_dim * config.hidden_dim]
        []float biases_qkv = encoder.transformer_biases[layer * config.hidden_dim..(layer+1) * config.hidden_dim]
        []float biases_out = encoder.transformer_biases[(layer + config.num_layers) * config.hidden_dim..(layer + config.num_layers + 1) * config.hidden_dim]
        features = transformer_layer_forward(features, weights_qkv, weights_out, biases_qkv, biases_out,
                                            config.num_heads, config.hidden_dim / config.num_heads, num_patches)
        layer = layer + 1
    }
    []float spatial_features = math.copy_float(features)
    []float scale_features = math.allocate_float(0, 0.0)
    if config.use_multi_scale_features {
        scale_features = extract_multi_scale_features(features, new_width, new_height, config)
    }
    image_feature {
        features: features,
        spatial_features: spatial_features,
        scale_features: scale_features,
        width: new_width,
        height: new_height,
        num_patches: num_patches,
        num_scales: config.num_scales,
    }
}

func project_to_text_space(image_feature feature, []float projection_weights, []float projection_biases,
                           int text_dim) []float {
    int num_tokens = feature.num_patches
    []float projected = math.allocate_float(num_tokens * text_dim, 0.0)
    projected = math.matmul_flat(feature.features, projection_weights, num_tokens, len(feature.features) / num_tokens, text_dim)
    projected = math.apply_bias(projected, projection_biases, num_tokens, text_dim)
    projected
}

func vision_encoder_get_num_tokens(int width, int height, int patch_size) int {
    (width / patch_size) * (height / patch_size)
}

func vision_encoder_compute_spatial_positions(int width, int height, int patch_size) []int {
    int num_patches_x = width / patch_size
    int num_patches_y = height / patch_size
    int num_patches = num_patches_x * num_patches_y
    []int positions = math.allocate_int(num_patches * 2, 0)
    int y = 0
    while y < num_patches_y {
        int x = 0
        while x < num_patches_x {
            int idx = y * num_patches_x + x
            positions[idx * 2] = x
            positions[idx * 2 + 1] = y
            x = x + 1
        }
        y = y + 1
    }
    positions
}
