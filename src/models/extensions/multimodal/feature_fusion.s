package neurx.multimodal.feature_fusion

import (
    "neurx.tensor.types"
    "neurx.multimodal.types"
)

enum FusionStrategy {
    concatenation,
    addition,
    attention,
    transformer,
    gating
}

struct FeatureFusion {
    fusion_strategy: FusionStrategy,
    hidden_dim: i32,
    num_heads: i32,
    dropout_rate: f32,
    use_residual: bool,
    normalization: string
}

func NewFeatureFusion(
    hidden_dim: i32,
    fusion_strategy: FusionStrategy
) &FeatureFusion {
    return &FeatureFusion{
        fusion_strategy: fusion_strategy,
        hidden_dim: hidden_dim,
        num_heads: 8,
        dropout_rate: 0.1,
        use_residual: true,
        normalization: "layer_norm"
    }
}

func (f: &FeatureFusion) FuseConcatenation(
    embeddings: map[types.Modality, &types.Tensor]
) &types.Tensor {
    var total_dim i32 = 0
    var seq_len i32 = 0

    for modality, embedding := range embeddings {
        if modality == types.Modality.text {
            if seq_len == 0 {
                seq_len = embedding.shape[0]
            }
            total_dim += embedding.shape[1]
        } else {
            if seq_len == 0 {
                seq_len = embedding.shape[0]
            }
            total_dim += embedding.shape[1]
        }
    }

    fused := make([]f32, seq_len * total_dim)
    col_idx := 0

    for modality, embedding := range embeddings {
        emb_dim := embedding.shape[1]

        for seq := 0; seq < seq_len; seq += 1 {
            for dim := 0; dim < emb_dim; dim += 1 {
                fused[seq * total_dim + col_idx + dim] = embedding.data[seq * emb_dim + dim]
            }
        }

        col_idx += emb_dim
    }

    return &types.Tensor{
        data: fused,
        shape: [2]i32{seq_len, total_dim},
        dtype: "float32"
    }
}

func (f: &FeatureFusion) FuseAddition(
    embeddings: map[types.Modality, &types.Tensor]
) &types.Tensor {
    var fused &types.Tensor
    count := i32(0)

    for modality, embedding := range embeddings {
        if fused == nil {
            fused_data := make([]f32, len(embedding.data))
            for i := 0; i < len(embedding.data); i += 1 {
                fused_data[i] = embedding.data[i]
            }
            fused = &types.Tensor{
                data: fused_data,
                shape: embedding.shape,
                dtype: embedding.dtype
            }
        } else {

            for i := 0; i < len(embedding.data); i += 1 {
                fused.data[i] += embedding.data[i]
            }
        }
        count += 1
    }

    if count > 0 {
        for i := 0; i < len(fused.data); i += 1 {
            fused.data[i] /= f32(count)
        }
    }

    return fused
}

func (f: &FeatureFusion) FuseAttention(
    embeddings: map[types.Modality, &types.Tensor],
    query_modality: types.Modality
) &types.Tensor {

    var query_tensor &types.Tensor
    if query_emb, exists := embeddings[query_modality]; exists {
        query_tensor = query_emb
    }

    if query_tensor == nil {
        return nil
    }

    seq_len := query_tensor.shape[0]
    output_dim := f.hidden_dim

    output := make([]f32, seq_len * output_dim)

    for seq := 0; seq < seq_len; seq += 1 {

        var total_context = make([]f32, output_dim)
        var total_weight f32 = 0.0

        for modality, embedding := range embeddings {
            if modality == query_modality {
                continue
            }

            emb_dim := embedding.shape[1]

            score := f32(1.0) / f32(len(embeddings))

            for dim := 0; dim < emb_dim && dim < output_dim; dim += 1 {
                avg_val := f32(0.0)
                for s := 0; s < embedding.shape[0]; s += 1 {
                    avg_val += embedding.data[s * emb_dim + dim]
                }
                total_context[dim] += (avg_val / f32(embedding.shape[0])) * score
            }

            total_weight += score
        }

        for dim := 0; dim < output_dim; dim += 1 {
            if total_weight > 0.0 {
                output[seq * output_dim + dim] = total_context[dim] / total_weight
            }
        }
    }

    return &types.Tensor{
        data: output,
        shape: [2]i32{seq_len, output_dim},
        dtype: "float32"
    }
}

func (f: &FeatureFusion) FuseGating(
    embeddings: map[types.Modality, &types.Tensor]
) &types.Tensor {

    concat := f.FuseConcatenation(embeddings)

    if concat == nil {
        return nil
    }

    seq_len := concat.shape[0]
    total_dim := concat.shape[1]

    output := make([]f32, seq_len * f.hidden_dim)

    modality_count := i32(len(embeddings))

    for seq := 0; seq < seq_len; seq += 1 {
        for dim := 0; dim < f.hidden_dim; dim += 1 {

            val := f32(0.0)

            for mod_idx := 0; mod_idx < modality_count; mod_idx += 1 {

                gate := f32(1.0) / f32(modality_count)

                src_dim := dim + mod_idx * (total_dim / modality_count)
                if src_dim < total_dim {
                    val += concat.data[seq * total_dim + src_dim] * gate
                }
            }

            output[seq * f.hidden_dim + dim] = val
        }
    }

    return &types.Tensor{
        data: output,
        shape: [2]i32{seq_len, f.hidden_dim},
        dtype: "float32"
    }
}

func (f: &FeatureFusion) ApplyLayerNorm(
    tensor: &types.Tensor,
    eps: f32
) &types.Tensor {
    seq_len := tensor.shape[0]
    feature_dim := tensor.shape[1]

    normalized := make([]f32, len(tensor.data))

    for seq := 0; seq < seq_len; seq += 1 {

        mean := f32(0.0)
        variance := f32(0.0)

        for dim := 0; dim < feature_dim; dim += 1 {
            mean += tensor.data[seq * feature_dim + dim]
        }
        mean /= f32(feature_dim)

        for dim := 0; dim < feature_dim; dim += 1 {
            diff := tensor.data[seq * feature_dim + dim] - mean
            variance += diff * diff
        }
        variance /= f32(feature_dim)

        std_dev := f32(Sqrt(f64(variance + eps)))

        for dim := 0; dim < feature_dim; dim += 1 {
            normalized[seq * feature_dim + dim] = (tensor.data[seq * feature_dim + dim] - mean) / std_dev
        }
    }

    return &types.Tensor{
        data: normalized,
        shape: tensor.shape,
        dtype: tensor.dtype
    }
}

func (f: &FeatureFusion) Fuse(
    embeddings: map[types.Modality, &types.Tensor]
) &types.FusedFeatures {
    var fused_embedding &types.Tensor

    if f.fusion_strategy == FusionStrategy.concatenation {
        fused_embedding = f.FuseConcatenation(embeddings)
    } else if f.fusion_strategy == FusionStrategy.addition {
        fused_embedding = f.FuseAddition(embeddings)
    } else if f.fusion_strategy == FusionStrategy.attention {
        fused_embedding = f.FuseAttention(embeddings, types.Modality.text)
    } else if f.fusion_strategy == FusionStrategy.gating {
        fused_embedding = f.FuseGating(embeddings)
    } else {
        fused_embedding = f.FuseConcatenation(embeddings)
    }

    if f.normalization == "layer_norm" {
        fused_embedding = f.ApplyLayerNorm(fused_embedding, 1e-6)
    }

    return &types.FusedFeatures{
        id: "fused_" + string(rune(i32(len(embeddings)))),
        fused_embedding: fused_embedding,
        modality_embeddings: embeddings,
        attention_weights: make(map[types.Modality, &types.Tensor]),
        fusion_type: string(byte(i32(f.fusion_strategy)))
    }
}

func Sqrt(x: f64) f64 {
    if x == 0.0 {
        return 0.0
    }

    result := x
    for i := 0; i < 10; i += 1 {
        result = (result + x / result) / 2.0
    }
    return result
}

func (f: &FeatureFusion) GetFusionDimension(
    input_embeddings: map[types.Modality, &types.Tensor]
) i32 {
    if f.fusion_strategy == FusionStrategy.concatenation {
        total := i32(0)
        for _, emb := range input_embeddings {
            total += emb.shape[1]
        }
        return total
    }

    return f.hidden_dim
}

func main() {
    println("Feature Fusion Module")
    println("✅ Multimodal fusion ready")
}
