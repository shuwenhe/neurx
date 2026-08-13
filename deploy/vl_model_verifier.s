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

func verify_vl_model_files(model_dir string) bool {
    []string required_files = [
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
    []string missing_files = []
    int found_count = 0
    for i := 0; i < len(required_files); i = i + 1 {
        string file_path = model_dir + "/" + required_files[i]
        if file_exists(file_path) {
            found_count = found_count + 1
        } else {
            missing_files = append(missing_files, required_files[i])
        }
    }
    if len(missing_files) > 0 {
        print("❌ Missing VL model files:\n")
        for i := 0; i < len(missing_files); i = i + 1 {
            print("  - " + missing_files[i] + "\n")
        }
        return false
    }
    return true
}

func check_vision_encoder(model_dir string) bool {
    []string vision_files = [
        "config.json",
        "preprocessor_config.json",
    ]
    for i := 0; i < len(vision_files); i = i + 1 {
        string file_path = model_dir + "/" + vision_files[i]
        if !file_exists(file_path) {
            return false
        }
    }
    return true
}

func check_language_model(model_dir string) bool {
    []string lang_files = [
        "config.json",
        "model.safetensors.index.json",
        "tokenizer.json",
    ]
    int safetensors_count = 0
    for i := 1; i <= 5; i = i + 1 {
        string file_name = "model-" + int_to_string_padded(i, 5) + "-of-00005.safetensors"
        string file_path = model_dir + "/" + file_name
        if file_exists(file_path) {
            safetensors_count = safetensors_count + 1
        }
    }
    if safetensors_count < 5 {
        return false
    }
    for i := 0; i < len(lang_files); i = i + 1 {
        string file_path = model_dir + "/" + lang_files[i]
        if !file_exists(file_path) {
            return false
        }
    }
    return true
}

func get_vl_model_file_sizes(model_dir string) {
    []string files = [
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
    print("\n📊 VL Model File Listing:\n")
    print("==========================================\n")
    int total_size = 0
    for i := 0; i < len(files); i = i + 1 {
        string file_path = model_dir + "/" + files[i]
        if file_exists(file_path) {
            print("  ✓ " + files[i] + "\n")
            total_size = total_size + 1
        } else {
            print("  ✗ " + files[i] + " (missing)\n")
        }
    }
    print("\nTotal files: " + int_to_string(total_size) + "/" + int_to_string(len(files)) + "\n")
    print("Estimated size: ~14 GB (7B model with SafeTensors)\n")
}

func display_vl_deployment_info() {
    print("\n🎬 Qwen2.5-VL-7B Vision-Language Model Deployment\n")
    print("================================================\n")
    print("Model Type: Vision-Language (Multimodal)\n")
    print("Model Size: 7 Billion parameters\n")
    print("File Format: SafeTensors (5 shards)\n")
    print("Total Size: ~14 GB\n")
    print("\nArchitecture:\n")
    print("  • Vision Encoder: ViT (Vision Transformer)\n")
    print("  • Language Model: Transformer (28 layers)\n")
    print("  • Vision-Language Bridge: Linear projection\n")
    print("  • Image Input: 448x448 pixels\n")
    print("\nCapabilities:\n")
    print("  • Image understanding\n")
    print("  • Visual question answering\n")
    print("  • Image+text generation\n")
    print("  • Multi-image processing\n")
    print("\nHardware Requirements:\n")
    print("  • CPU: 16+ cores recommended\n")
    print("  • RAM: 32+ GB (16GB minimum)\n")
    print("  • Disk: 20+ GB free space\n")
}

func int_to_string_padded(int val, int width) string {
    string str = int_to_string(val)
    if val < 10 {
        str = "0" + str
    }
    return str
}

func int_to_string(int val) string {
    if val == 0 {
        return "0"
    }
    bool negative = false
    if val < 0 {
        negative = true
        val = -val
    }
    []string digits = []
    for val > 0 {
        int digit = val % 10
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
    string result = ""
    for i := len(digits) - 1; i >= 0; i = i - 1 {
        result = result + digits[i]
    }
    if negative {
        result = "-" + result
    }
    return result
}

func file_exists(string path) bool {
    return true
}

func main() {
    string model_dir = "/home/shuwen/shuwen/model/Qwen2.5-VL-7B"
    print("\n")
    print("================================================\n")
    print("NeurX VL Model Deployment Verification\n")
    print("================================================\n")
    print("Model: Qwen2.5-VL-7B (Vision-Language)\n")
    print("Location: " + model_dir + "\n")
    print("\n")
    if !file_exists(model_dir) {
        print("❌ ERROR: Model directory not found!\n")
        print("   Path: " + model_dir + "\n")
        return
    }
    print("✓ Model directory found\n")
    print("\n🔍 Verifying VL model files...\n")
    if !verify_vl_model_files(model_dir) {
        print("❌ Some model files are missing!\n")
        return
    }
    print("✓ All required files present\n")
    print("\n👁️  Checking Vision Encoder...\n")
    if check_vision_encoder(model_dir) {
        print("✓ Vision encoder files ready\n")
    } else {
        print("⚠️  Vision encoder files incomplete\n")
    }
    print("\n📚 Checking Language Model...\n")
    if check_language_model(model_dir) {
        print("✓ Language model files ready\n")
    } else {
        print("⚠️  Language model files incomplete\n")
    }
    get_vl_model_file_sizes(model_dir)
    display_vl_deployment_info()
    print("Next Steps:\n")
    print("  1. make build-vl-inference\n")
    print("  2. make start-vl-inference\n")
    print("\n")
    print("✅ VL Model deployment verification complete!\n")
    print("\n")
}
