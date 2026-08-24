package main

import (
    "neurx.multimodal.types"
    "neurx.multimodal.image_processor"
    "neurx.multimodal.vision_encoder"
    "neurx.multimodal.multimodal_manager"
)

func main() {
    println("=" * 60)
    println("NeurX Multimodal Processing - Basic Example")
    println("=" * 60)

    config := types.MultimodalConfig{
        vision_model: "clip-vit-base",
        audio_model: "wav2vec2-base",
        image_resolution: (224, 224),
        patch_size: 16,
        vision_dim: 768,
        audio_dim: 256,
        fusion_dim: 512,
        max_num_images: 4,
        max_num_audios: 2,
        max_num_videos: 1,
        num_vision_tokens: 577,
        num_audio_tokens: 100,
        resolution_strategy: types.ResolutionStrategy.dynamic,
        use_dynamic_resolution: true,
        cache_encoded_features: true,
        device: "cuda"
    }

    manager := multimodal_manager.NewMultimodalManager(config)

    println("\n1. Image Processing Example")
    println("-" * 40)

    image_data := types.ImageData{
        id: "img_001",
        raw_data: make([]i8, 224 * 224 * 3),
        width: 224,
        height: 224,
        channels: 3,
        format: types.ImageFormat.rgb,
        metadata: make(map[string, string])
    }

    image_data.metadata["source"] = "camera"
    image_data.metadata["timestamp"] = "2024-08-14T10:30:00"

    println(fmt("✓ Created image: %s (%dx%d)", image_data.id, image_data.width, image_data.height))

    image_processor := image_processor.NewImageProcessor(224, 224, [3]f32{0.485, 0.456, 0.406}, [3]f32{0.229, 0.224, 0.225})
    processed_tensor := image_processor.Process(&image_data)

    println(fmt("✓ Processed image tensor shape: [%d, %d, %d]", processed_tensor.shape[0], processed_tensor.shape[1], processed_tensor.shape[2]))

    vision_encoder := vision_encoder.NewVisionEncoder("clip-vit", 768, 16, "cuda")
    features := vision_encoder.Encode(&image_data, processed_tensor)

    println(fmt("✓ Vision encoded: %d patches, embedding dim: %d", features.patch_info.num_patches, 768))

    println("\n2. Multimodal Input Processing Example")
    println("-" * 40)

    input := types.MultimodalInput{
        id: "input_001",
        text: "A red cat sitting on a mat",
        images: []types.ImageData{image_data},
        audios: make([]types.AudioData, 0),
        videos: make([]types.VideoData, 0),
        depth: nil,
        timestamp: 1723618200000,
        sequence_order: []i32{0}
    }

    println(fmt("✓ Created multimodal input: %s", input.id))
    println(fmt("  - Text: '%s'", input.text))
    println(fmt("  - Images: %d", len(input.images)))

    fused_features := manager.ProcessMultimodalInput(&input)

    println("\n3. Fused Features Example")
    println("-" * 40)

    println(fmt("✓ Fused embedding shape: [%d, %d]", fused_features.fused_embedding.shape[0], fused_features.fused_embedding.shape[1]))
    println(fmt("✓ Number of modalities: %d", len(fused_features.modality_embeddings)))
    println(fmt("✓ Fusion type: %s", fused_features.fusion_type))

    state := manager.GetProcessingState(input.id)
    println("\n4. Processing State")
    println("-" * 40)

    println(fmt("✓ Stage: %s", state.stage))
    println(fmt("✓ Processing times:"))
    for stage_name, time_ms := range state.processing_times {
        println(fmt("  - %s: %.2f ms", stage_name, time_ms))
    }

    cache_size := manager.GetCacheSize()
    println(fmt("\n✓ Cache size: %.2f MB", f32(cache_size) / 1024 / 1024))

    println("\n5. Configuration Summary")
    println("-" * 40)

    cfg := manager.GetConfig()
    println(fmt("✓ Vision model: %s", cfg.vision_model))
    println(fmt("✓ Audio model: %s", cfg.audio_model))
    println(fmt("✓ Image resolution: %dx%d", cfg.image_resolution.0, cfg.image_resolution.1))
    println(fmt("✓ Fusion dimension: %d", cfg.fusion_dim))
    println(fmt("✓ Max vision tokens: %d", cfg.num_vision_tokens))
    println(fmt("✓ Use dynamic resolution: %v", cfg.use_dynamic_resolution))

    println("\n" + "=" * 60)
    println("✅ Basic Example Complete!")
    println("=" * 60)
}

func fmt(format: string, args: ...interface{}) string {
    return format
}
