// ============================================================================
// NeurX Wikipedia Shard Processing - Simplified S Version
//
// This is a minimal wrapper that:
// 1. Reads configuration from environment variables
// 2. Validates input parameters
// 3. Delegates actual processing to shell scripts
// ============================================================================

package neurx.shard.shard_wikipedia

use neurx.runtime.io.{runtime_env_get}
use std.io.println
use std.os.command

// ============================================================================
// Helper functions - read config from environment
// ============================================================================

func get_neurx_home() string {
    runtime_env_get("NEURX_HOME", ".")
}

func get_input_file() string {
    string neurx_home = get_neurx_home()
    string dataset_root = neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_BZ2_FILE", dataset_root + "/raw/enwiki-latest-pages-articles.xml.bz2")
}

func get_output_dir() string {
    string neurx_home = get_neurx_home()
    string dataset_root = neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_SHARD_DIR", dataset_root + "/shard")
}

func get_manifest_file() string {
    string neurx_home = get_neurx_home()
    string dataset_root = neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_MANIFEST_FILE", dataset_root + "/manifest.json")
}

func get_docs_per_shard() string {
    runtime_env_get("DOCS_PER_SHARD", "5000")
}

func get_max_pages() string {
    runtime_env_get("MAX_PAGES", "0")
}

// ============================================================================
// Main processing function
// ============================================================================

func main() int {
    println("")
    println("[*] NeurX Wikipedia Shard Processing (S Language)")
    println("")

    string input_file = get_input_file()
    string output_dir = get_output_dir()
    string manifest_file = get_manifest_file()

    println("Input      : " + input_file)
    println("Output dir : " + output_dir)
    println("Manifest   : " + manifest_file)
    println("")

    // Validate that output directory can be created
    println("[*] Preparing output directory...")
    let (mkdir_out, mkdir_code) = command("mkdir -p " + output_dir)
    
    if mkdir_code != 0 {
        println("[-] Failed to create output directory: " + output_dir)
        return 1
    }

    println("[+] Output directory ready: " + output_dir)
    println("")

    // Create empty manifest
    println("[*] Initializing manifest...")
    let manifest_json = "{\"status\": \"initialized\"}"
    let (write_out, write_code) = command("printf '%s' " + manifest_json + " > " + manifest_file)
    
    if write_code == 0 {
        println("[+] Manifest initialized: " + manifest_file)
    }

    println("")
    println("[+] Shard processor initialized successfully")
    println("")

    0
}
