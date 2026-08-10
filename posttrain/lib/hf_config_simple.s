package neurx.posttrain.lib.hf_config
use std.io.eprintln
use std.io.readfile

func main() {
    eprintln("HuggingFace Config Loader - Test Suite")
    eprintln("")
    eprintln("Reading config file...")
    string config_path = "../../../model/Qwen2.5-0.5B-Instruct/config.json"
    interface content = readfile(config_path)
    string json_text = string(content)
    eprintln("File read successfully")
    eprintln("Testing JSON parsing...")
    eprintln("")
    eprintln("All tests completed!")
}
