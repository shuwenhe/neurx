
package neurx.multimodal.types

import "neurx.tensor.types"

enum Modality {
    image,
    text,
    audio,
    video,
    depth,
    unknown
}

enum ImageFormat {
    rgb,
    rgba,
    bgr,
    gray,
    yuv
}

enum AudioFormat {
    pcm16,
    pcm32,
    float32,
    mu_law
}

enum ResolutionStrategy {
    pad,
    resize,
    dynamic,
    multi_crop
}

struct ImageData {
    id: string,
    raw_data: []i8,
    width: i32,
    height: i32,
    channels: i32,
    format: ImageFormat,
    metadata: map[string, string]
}

struct AudioData {
    id: string,
    samples: []f32,
    sample_rate: i32,
    num_channels: i32,
    duration_ms: i32,
    format: AudioFormat
}

struct VideoData {
    id: string,
    frames: []ImageData,
    fps: f32,
    duration_ms: i32,
    total_frames: i32
}

struct DepthData {
    id: string,
    depth_map: &types.Tensor,
    intrinsics: [9]f32,
    min_depth: f32,
    max_depth: f32
}

struct MultimodalInput {
    id: string,
    text: string,
    images: []ImageData,
    audios: []AudioData,
    videos: []VideoData,
    depth: ?DepthData,
    timestamp: i64,
    sequence_order: []i32
}

struct ImageFeatures {
    id: string,
    embeddings: &types.Tensor,
    patch_info: PatchInfo,
    spatial_resolution: (i32, i32),
    temporal_index: i32
}

struct PatchInfo {
    num_patches: i32,
    patch_size: i32,
    patch_height: i32,
    patch_width: i32,
    cls_token_idx: i32,
    spatial_shape: (i32, i32)
}

struct AudioFeatures {
    id: string,
    embeddings: &types.Tensor,
    frame_rate: i32,
    num_frames: i32,
    segment_length: i32
}

struct VideoFeatures {
    id: string,
    frame_features: []ImageFeatures,
    temporal_embeddings: &types.Tensor,
    video_embedding: &types.Tensor
}

struct FusedFeatures {
    id: string,
    fused_embedding: &types.Tensor,
    modality_embeddings: map[Modality, &types.Tensor],
    attention_weights: map[Modality, &types.Tensor],
    fusion_type: string
}

struct MultimodalConfig {
    vision_model: string,
    audio_model: string,
    image_resolution: (i32, i32),
    patch_size: i32,
    vision_dim: i32,
    audio_dim: i32,
    fusion_dim: i32,
    max_num_images: i32,
    max_num_audios: i32,
    max_num_videos: i32,
    num_vision_tokens: i32,
    num_audio_tokens: i32,
    resolution_strategy: ResolutionStrategy,
    use_dynamic_resolution: bool,
    cache_encoded_features: bool,
    device: string
}

struct ProcessingState {
    input_id: string,
    stage: string,
    start_time: i64,
    processing_times: map[string, f32],
    error_messages: []string,
    is_cached: bool
}
