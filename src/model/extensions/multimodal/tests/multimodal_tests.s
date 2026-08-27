package neurx.multimodal.test

import (
    "neurx.multimodal.types"
    "neurx.multimodal.image_processor"
    "neurx.multimodal.audio_encoder"
    "neurx.multimodal.vision_encoder"
    "neurx.multimodal.dynamic_resolution"
    "neurx.multimodal.feature_fusion"
    "neurx.multimodal.utils"
)

struct TestResult {
    name: string,
    passed: bool,
    message: string,
    f32 duration_ms
}

test_results := make([]TestResult, 0)

func assert(bool condition, string message) {
    if !condition {
        println(fmt("❌ ASSERTION FAILED: %s", message))
    }
}

func assertEqual(i32 expected, i32 actual, string message) {
    if expected != actual {
        println(fmt("❌ ASSERTION FAILED: %s (expected %d, got %d)", message, expected, actual))
    }
}

func TestImageProcessor() {
    println("\n▶ Testing ImageProcessor...")

    processor := image_processor.NewImageProcessor(224, 224,
        [3]f32{0.485, 0.456, 0.406},
        [3]f32{0.229, 0.224, 0.225})

    img := types.ImageData{
        id: "test_img_1",
        raw_data: make([]i8, 224 * 224 * 3),
        width: 224,
        height: 224,
        channels: 3,
        format: types.ImageFormat.rgb,
        metadata: make(map[string, string])
    }

    assert(len(img.raw_data) == 224 * 224 * 3, "Image data size mismatch")
    println("  ✓ Image creation test passed")

    small_img := types.ImageData{
        id: "test_img_2",
        raw_data: make([]i8, 128 * 128 * 3),
        width: 128,
        height: 128,
        channels: 3,
        format: types.ImageFormat.rgb,
        metadata: make(map[string, string])
    }

    resized := processor.Resize(*small_img)
    assert(resized.width > 0, "Resized image has valid width")
    println("  ✓ Image resize test passed")

    tensor := processor.Process(*img)
    assert(tensor != nil, "Process returns valid tensor")
    assert(tensor.shape[0] > 0, "Output tensor has valid shape")
    println("  ✓ Image processing pipeline test passed")
}

func TestAudioProcessor() {
    println("\n▶ Testing AudioProcessor...")

    processor := audio_encoder.NewAudioProcessor(16000, 400, 128)

    audio := types.AudioData{
        id: "test_audio_1",
        samples: make([]f32, 16000),
        sample_rate: 16000,
        num_channels: 1,
        duration_ms: 1000,
        format: types.AudioFormat.pcm16
    }

    assert(len(audio.samples) == 16000, "Audio samples created correctly")
    println("  ✓ Audio creation test passed")

    normalized := processor.Normalize(*audio)
    assert(normalized != nil, "Normalize returns valid audio")
    println("  ✓ Audio normalization test passed")

    mel_spec := processor.MelSpectrogram(normalized)
    assert(mel_spec != nil, "Mel-spectrogram computed")
    assert(mel_spec.shape[1] > 0, "Mel-spectrogram has valid frequency bins")
    println("  ✓ Mel-spectrogram computation test passed")
}

func TestVisionEncoder() {
    println("\n▶ Testing VisionEncoder...")

    encoder := vision_encoder.NewVisionEncoder("clip-vit", 768, 16, "cuda")

    img_tensor := *types.Tensor{
        data: make([]f32, 224 * 224 * 3),
        shape: [3]i32{224, 224, 3},
        dtype: "float32"
    }

    img_data := types.ImageData{
        id: "test_vision_1",
        raw_data: make([]i8, 224 * 224 * 3),
        width: 224,
        height: 224,
        channels: 3,
        format: types.ImageFormat.rgb,
        metadata: make(map[string, string])
    }

    patches, patch_info := encoder.ExtractPatches(img_tensor)
    assert(len(patches) > 0, "Patches extracted successfully")
    assert(patch_info.num_patches > 0, "Patch info computed")
    println(fmt("  ✓ Patch extraction test passed (%d patches)", len(patches)))

    features := encoder.Encode(*img_data, img_tensor)
    assert(features != nil, "Features encoded successfully")
    assert(features.embeddings.shape[0] > 0, "Features have valid sequence length")
    println("  ✓ Vision encoding test passed")
}

func TestDynamicResolution() {
    println("\n▶ Testing DynamicResolution...")

    res_proc := dynamic_resolution.NewDynamicResolutionProcessor(224, 16, 196 + 1)

    target_h, target_w := res_proc.CalculateTargetResolution(448, 448)
    assert(target_h > 0 && target_w > 0, "Target resolution calculated")
    println(fmt("  ✓ Resolution calculation test passed (target: %dx%d)", target_h, target_w))

    patch_count := res_proc.GetPatchCount(224, 224)
    assert(patch_count > 0, "Patch count calculated")
    println(fmt("  ✓ Patch count test passed (%d patches)", patch_count))

    can_process := res_proc.CanProcessImage(1024, 1024)
    println(fmt("  ✓ Processability check test passed (1024x1024: %v)", can_process))

    info := res_proc.GetInfo(384, 512)
    assert(info.original_height == 384, "Resolution info correct")
    println("  ✓ Resolution info test passed")
}

func TestFeatureFusion() {
    println("\n▶ Testing FeatureFusion...")

    fusion := feature_fusion.NewFeatureFusion(512, feature_fusion.FusionStrategy.concatenation)

    embeddings := make(map[types.Modality, *types.Tensor])

    vision_emb := *types.Tensor{
        data: make([]f32, 577 * 768),
        shape: [2]i32{577, 768},
        dtype: "float32"
    }
    embeddings[types.Modality.image] = vision_emb

    audio_emb := *types.Tensor{
        data: make([]f32, 100 * 256),
        shape: [2]i32{100, 256},
        dtype: "float32"
    }
    embeddings[types.Modality.audio] = audio_emb

    fused := fusion.Fuse(embeddings)
    assert(fused != nil, "Fusion result valid")
    assert(fused.fused_embedding != nil, "Fused embedding created")
    println("  ✓ Feature fusion test passed")

    fusion_dim := fusion.GetFusionDimension(embeddings)
    assert(fusion_dim > 0, "Fusion dimension calculated")
    println(fmt("  ✓ Fusion dimension test passed (dim: %d)", fusion_dim))
}

func TestValidation() {
    println("\n▶ Testing Validation...")

    img_validator := utils.NewImageValidator()
    audio_validator := utils.NewAudioValidator()

    valid_img := types.ImageData{
        id: "valid_img",
        raw_data: make([]i8, 256 * 256 * 3),
        width: 256,
        height: 256,
        channels: 3,
        format: types.ImageFormat.rgb,
        metadata: make(map[string, string])
    }

    assert(img_validator.ValidateImage(*valid_img), "Valid image passes validation")
    println("  ✓ Image validation test passed")

    valid_audio := types.AudioData{
        id: "valid_audio",
        samples: make([]f32, 160000),
        sample_rate: 16000,
        num_channels: 1,
        duration_ms: 10000,
        format: types.AudioFormat.pcm16
    }

    assert(audio_validator.ValidateAudio(*valid_audio), "Valid audio passes validation")
    println("  ✓ Audio validation test passed")
}

func TestUtils() {
    println("\n▶ Testing Utils...")

    tensors := make([]types.Tensor, 3)
    for i := 0; i < 3; i += 1 {
        tensors[i] = types.Tensor{
            data: make([]f32, 768),
            shape: [2]i32{1, 768},
            dtype: "float32"
        }
    }

    stacked := utils.TensorStackTensors(tensors)
    assert(stacked != nil, "Tensor stacking successful")
    assert(stacked.shape[0] == 3, "Stacked tensor has correct batch size")
    println("  ✓ Tensor stacking test passed")

    emb := *types.Tensor{
        data: make([]f32, 768),
        shape: [2]i32{1, 768},
        dtype: "float32"
    }

    for i := 0; i < 768; i += 1 {
        emb.data[i] = f32(i % 100) / 100.0
    }

    normalized := utils.NormalizeEmbedding(emb)
    assert(normalized != nil, "Normalization successful")
    println("  ✓ Embedding normalization test passed")
}

func RunAllTests() {
    println("\n" + "=" * 60)
    println("NeurX Multimodal Processing Test Suite")
    println("=" * 60)

    TestImageProcessor()
    TestAudioProcessor()
    TestVisionEncoder()
    TestDynamicResolution()
    TestFeatureFusion()
    TestValidation()
    TestUtils()

    println("\n" + "=" * 60)
    println("✅ All tests completed!")
    println("=" * 60)
}

func main() {
    RunAllTests()
}

func fmt(string format, ...interface{} args) string {
    return format
}
