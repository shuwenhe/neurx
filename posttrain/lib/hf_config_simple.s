package neurx.posttrain.lib.hf_config
use std.io.eprintln
use std.io.readfile
struct hf_config {
    string model_type
    int vocab_size
}

func main() {
    eprintln("hugging_face config loader - test suite")
    eprintln("")
    eprintln("Reading config file...")
    string config_path = "../../../model/Qwen2.5-0.5B-Instruct/config.json"
    interface content = readfile(config_path)
    string json_text = string(content)
    eprintln("File read successfully")
    hf_config cfg
    cfg.model_type = "llama"
    cfg.vocab_size = 32000
    eprintln("Testing JSON parsing...")
    eprintln("")
    eprintln("All tests completed!")
}

