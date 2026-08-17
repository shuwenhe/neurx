package main
use neurx.inference.runtime.model_manifest

func main() {
    hf_model_manifest manifest = neurx.inference.runtime.model_manifest.load_hf_model_manifest("/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    if !manifest.valid {
        println("FAIL model manifest: " + manifest.error_message)
        return 1
    }
    if manifest.config.model_type != "qwen2" || manifest.config.hidden_size != 896 || manifest.config.num_layers != 24 || manifest.config.num_attention_heads != 14 || manifest.config.num_kv_heads != 2 {
        println("FAIL model config")
        return 1
    }
    if manifest.tensor_count < 200 || manifest.weight_bytes <= 900000000 {
        println("FAIL model weights")
        return 1
    }
    println("PASS model manifest")
    0
}
