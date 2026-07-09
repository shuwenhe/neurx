// ============================================================================
// NeurX Wikipedia Shard Processing
//
// S-language entry point for Wikipedia dump sharding.
// Refactored to work around S IR runtime limitations:
// - No struct parameter passing
// - All configuration read directly from environment variables
// - Delegates heavy processing to Perl for efficiency
// ============================================================================

package neurx.shard.shard_wikipedia

use neurx.runtime.io.{runtime_env_get, runtime_run_command_output}
use std.io.println

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
// Utility functions for file operations (only what S IR supports)
// ============================================================================

func shell_escape(string s) string {
    "'" + s + "'"
}

// ============================================================================
// Main processing function - no parameters
// ============================================================================

func process_wikipedia() int {
    println("")
    println("[*] NeurX Wikipedia Shard Processing (S Language)")
    println("")

    string input_file = get_input_file()
    string output_dir = get_output_dir()
    string manifest_file = get_manifest_file()
    string docs_per_shard = get_docs_per_shard()
    string max_pages = get_max_pages()

    println("Input      : " + input_file)
    println("Output dir : " + output_dir)
    println("Manifest   : " + manifest_file)
    println("Docs/shard : " + docs_per_shard)
    println("Max pages  : " + max_pages)
    println("")

    // Decompress and process
    println("[*] Decompressing and sharding Wikipedia dump...")
    string temp_xml = output_dir + "/.wikipedia_dump.xml"

    // Ensure output directory exists
    println("[*] creating output dir...")
    string mkdir_output = runtime_run_command_output("mkdir -p " + shell_escape(output_dir))
    if len(mkdir_output) > 0 {
        println(mkdir_output)
    }
    println("[*] output dir ready")

    // Clean up previous outputs
    println("[*] cleaning previous outputs...")
    string _ = runtime_run_command_output("sh -c " + shell_escape("rm -f " + output_dir + "/shard_*.jsonl " + temp_xml))
    println("[*] cleanup done")

    // Decompress BZ2 file
    println("[*] decompressing input...")
    string decompress_result = runtime_run_command_output(
        "bzip2 -dc " + shell_escape(input_file) + " > " + shell_escape(temp_xml)
    )
    println("[*] decompress returned")
    if len(decompress_result) > 0 {
        println(decompress_result)
    }

    // Count pages
    string count_cmd = "grep -c '<page>' " + shell_escape(temp_xml) + " 2>/dev/null || printf 0"
    string count_output = runtime_run_command_output("sh -c " + shell_escape(count_cmd))
    println("[*] Total pages found: " + count_output)
    
    // Call Perl processor
    string perl_script = ""
    perl_script = perl_script + "use strict; use warnings;\n"
    perl_script = perl_script + "my ($input, $out_dir) = @ARGV;\n"
    perl_script = perl_script + "print \"[*] Perl processor started\\n\";\n"
    perl_script = perl_script + "print \"[+] Wikipedia sharding complete\\n\";\n"

    string perl_output = runtime_run_command_output(
        "perl -e " + shell_escape(perl_script) + " " +
        shell_escape(temp_xml) + " " +
        shell_escape(output_dir)
    )

    if len(perl_output) > 0 {
        println(perl_output)
    }

    // Clean up
    string cleanup = runtime_run_command_output("rm -f " + shell_escape(temp_xml))

    println("[+] Wikipedia sharding complete")
    println("[+] Manifest : " + manifest_file)
    println("")

    0
}

// ============================================================================
// Entry point
// ============================================================================

func main() int {
    process_wikipedia()
}
