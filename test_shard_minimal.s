use neurx.runtime.io.runtime_env_get
use std.io.println

struct WikipediaConfig {
    string input_bz2_file
    string output_dir
    string manifest_file
    int docs_per_shard
    int max_pages
}

func process_wikipedia(WikipediaConfig config) int {
    println("Processing with config")
    0
}

func main() int {
    string neurx_home = runtime_env_get("NEURX_HOME", ".")

    WikipediaConfig config
    config.input_bz2_file = "test.bz2"
    config.output_dir = "/tmp"
    config.manifest_file = "/tmp/manifest.json"
    config.docs_per_shard = 5000
    config.max_pages = 0

    println("About to call process_wikipedia")
    process_wikipedia(config)
}
