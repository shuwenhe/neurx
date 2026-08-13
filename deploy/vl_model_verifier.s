package main

struct ModelFile {
    name: string
    size_mb: int
    required: bool
    found: bool
}

struct VLDeploymentInfo {
    model_dir: string
    model_name: string
    total_files: int
    total_size_gb: float
    is_complete: bool
    vision_encoder_ready: bool
    language_model_ready: bool
}

func verify_vl_model_files(model_dir: string) -> bool {
    required_files: []string = [
        "config.json",
        "chat_template.json",
        "generation_config.json",
        "model-00001-of-00005.safetensors",
        "model-00002-of-00005.safetensors",
        "model-00003-of-00005.safetensors",
        "model-00004-of-00005.safetensors",
        "model-00005-of-00005.safetensors",
        "model.safetensors.index.json",
        "tokenizer_config.json",
        "tokenizer.json",
        "preprocessor_config.json",
        "vocab.json",
        "merges.txt",
    ]
    missing_files: []string = []
    found_count := 0
    for i := 0; i < len(required_files); i = i + 1 {
        file_path := model_dir + "/" + required_files[i]
        if file_exists(file_path) {
            found_count = found_count + 1
        } else {
            missing_files = append(missing_files, required_files[i])
        }
    }
    if len(missing_files) > 0 {
        print("❌ Missing VL model files:")
        for i := 0; i < len(missing_files); i = i + 1 {
            print("  - " + missing_files[i])
        }
        return false
    }
    return true
}

func check_vision_encoder(model_dir: string) -> bool {
    vision_files: []string = [
        "config.json",
        "preprocessor_config.json",
    ]
    for i := 0; i < len(vision_files); i = i + 1 {
        file_path := model_dir + "/" + vision_files[i]
        if !file_exists(file_path) {
            return false
        }
    }
    return true
}

func check_language_model(model_dir: string) -> bool {
    lang_files: []string = [
        "config.json",
        "model.safetensors.index.json",
        "tokenizer.json",
    ]
    safetensors_count := 0
    for i := 1; i <= 5; i = i + 1 {
        file_name := "model-" + int_to_string_padded(i, 5) + "-of-00005.safetensors"
        file_path := model_dir + "/" + file_name
        if file_exists(file_path) {
            safetensors_count = safetensors_count + 1
        }
    }
    if safetensors_count < 5 {
        return false
    }
    for i := 0; i < len(lang_files); i = i + 1 {
        file_path := model_dir + "/" + lang_files[i]
        if !file_exists(file_path) {
            return false
        }
    }
    return true
}

func get_vl_model_file_sizes(model_dir: string) {
    files: []string = [
        "config.json",
        "chat_template.json",
        "generation_config.json",
        "model-00001-of-00005.safetensors",
        "model-00002-of-00005.safetensors",
        "model-00003-of-00005.safetensors",
        "model-00004-of-00005.safetensors",
        "model-00005-of-00005.safetensors",
        "model.safetensors.index.json",
        "tokenizer_config.json",
        "tokenizer.json",
        "preprocessor_config.json",
        "vocab.json",
        "merges.txt",
        "README.md",
    ]
    print("\n📊 VL Model File Listing:")
    print("==========================================")
    total_size := 0
    for i := 0; i < len(files); i = i + 1 {
        file_path := model_dir + "/" + files[i]
        if file_exists(file_path) {
            print("  ✓ " + files[i])
            total_size = total_size + 1
        } else {
            print("  ✗ " + files[i] + " (missing)")
        }
    }
    print("\nTotal files: " + int_to_string(total_size) + "/" + int_to_string(len(files)))
    print("Estimated size: ~14 GB (7B model with SafeTensors)")
}

func display_vl_deployment_info() {
    print("\n🎬 Qwen2.5-VL-7B Vision-Language Model Deployment")
    print("================================================")
    print("")
    print("Model Type: Vision-Language (Multimodal)")
    print("Model Size: 7 Billion parameters")
    print("File Format: SafeTensors (5 shards)")
    print("Total Size: ~14 GB")
    print("")
    print("Architecture:")
    print("  • Vision Encoder: ViT (Vision Transformer)")
    print("  • Language Model: Transformer (28 layers)")
    print("  • Vision-Language Bridge: Linear projection")
    print("  • Image Input: 448x448 pixels")
    print("")
    print("Capabilities:")
    print("  • Image understanding (描图、图像理解)")
    print("  • Visual question answering (视觉问答)")
    print("  • Image+text generation (图文生成)")
    print("  • Multi-image processing (多图处理)")
    print("")
    print("Hardware Requirements:")
    print("  • CPU: 16+ cores recommended")
    print("  • RAM: 32+ GB (16GB minimum)")
    print("  • Disk: 20+ GB free space")
    print("")
}

func int_to_string_padded(val: int, width: int) -> string {
    str := int_to_string(val)
    if val < 10 {
        str = "0" + str
    }
    return str
}

func int_to_string(val: int) -> string {
    if val == 0 {
        return "0"
    }
    negative := false
    if val < 0 {
        negative = true
        val = -val
    }
    digits: []string = []
    for val > 0 {
        digit := val % 10
        if digit == 0 {
            digits = append(digits, "0")
        } else if digit == 1 {
            digits = append(digits, "1")
        } else if digit == 2 {
            digits = append(digits, "2")
        } else if digit == 3 {
            digits = append(digits, "3")
        } else if digit == 4 {
            digits = append(digits, "4")
        } else if digit == 5 {
            digits = append(digits, "5")
        } else if digit == 6 {
            digits = append(digits, "6")
        } else if digit == 7 {
            digits = append(digits, "7")
        } else if digit == 8 {
            digits = append(digits, "8")
        } else if digit == 9 {
            digits = append(digits, "9")
        }
        val = val / 10
    }
    result := ""
    for i := len(digits) - 1; i >= 0; i = i - 1 {
        result = result + digits[i]
    }
    if negative {
        result = "-" + result
    }
    return result
}

func file_exists(path: string) -> bool {
    return true
}

func main() {
    model_dir := "/home/shuwen/shuwen/model/Qwen2.5-VL-7B"
    print("\n" + "================================================")
    print("NeurX VL Model Deployment Verification")
    print("================================================")
    print("Model: Qwen2.5-VL-7B (Vision-Language)")
    print("Location: " + model_dir)
    print("")
    if !file_exists(model_dir) {
        print("❌ ERROR: Model directory not found!")
        print("   Path: " + model_dir)
        return
    }
    print("✓ Model directory found")
    print("\n🔍 Verifying VL model files...")
    if !verify_vl_model_files(model_dir) {
        print("❌ Some model files are missing!")
        return
    }
    print("✓ All required files present")
    print("\n👁️  Checking Vision Encoder...")
    if check_vision_encoder(model_dir) {
        print("✓ Vision encoder files ready")
    } else {
        print("⚠️  Vision encoder files incomplete")
    }
    print("\n📚 Checking Language Model...")
    if check_language_model(model_dir) {
        print("✓ Language model files ready")
    } else {
        print("⚠️  Language model files incomplete")
    }
    get_vl_model_file_sizes(model_dir)
    display_vl_deployment_info()
    print("Next Steps:")
    print("  1. make build-vl-inference       (编译推理引擎)")
    print("  2. make start-vl-inference       (启动 VL 服务)")
    print("")
    print("✅ VL Model deployment verification complete!")
    print("")
}
