// ============================================================================
// NeurX Data Processing Scripts Entry Point
// 
// This module provides a unified CLI for all data processing tasks,
// replacing the original shell scripts:
//   - clean_data.sh
//   - generate_shards.sh
//
// Usage:
//   ./neurx_data_scripts.bin clean [options]
//   ./neurx_data_scripts.bin shard [options]
//   ./neurx_data_scripts.bin clean-and-shard [options]
// ============================================================================

package neurx.script.scripts

use neurx.runtime.io.{runtime_env_get}
use neurx.script.data_clean.{clean_data, new_clean_config_from_env}
use neurx.script.data_shard.{generate_shards, new_shard_config_from_env}
use neurx.script.data_utils.{log_info, log_error, log_success}

// ============================================================================
// Command Handlers
// ============================================================================

func cmd_clean() i32 {
    log_info("")
    log_info("==================================================")
    log_info("  NeurX Data Cleaning Script (S Language)")
    log_info("==================================================")
    log_info("")
    
    let config = new_clean_config_from_env()
    
    if clean_data(config) {
        log_success("✓ Data cleaning completed successfully")
        i32(0)
    } else {
        log_error("✗ Data cleaning failed")
        i32(1)
    }
}

func cmd_shard() i32 {
    log_info("")
    log_info("==================================================")
    log_info("  NeurX Data Sharding Script (S Language)")
    log_info("==================================================")
    log_info("")
    
    let config = new_shard_config_from_env()
    
    if generate_shards(config) {
        log_success("✓ Data sharding completed successfully")
        i32(0)
    } else {
        log_error("✗ Data sharding failed")
        i32(1)
    }
}

func cmd_clean_and_shard() i32 {
    log_info("")
    log_info("==================================================")
    log_info("  NeurX Data Pipeline (Clean + Shard)")
    log_info("==================================================")
    log_info("")
    
    // Step 1: Clean
    log_info("Step 1/2: Cleaning data...")
    let clean_exit = cmd_clean()
    if clean_exit != i32(0) {
        log_error("Data cleaning failed, aborting")
        return i32(1)
    }
    
    log_info("")
    log_info("Step 2/2: Generating shards...")
    
    // Step 2: Shard
    cmd_shard()
}

func cmd_help() i32 {
    log_info("NeurX Data Processing Scripts (S Language)")
    log_info("")
    log_info("Usage: neurx_data_scripts <command> [options]")
    log_info("")
    log_info("Commands:")
    log_info("  clean              Clean raw data files")
    log_info("  shard              Generate data shards from cleaned data")
    log_info("  clean-and-shard    Run both clean and shard in sequence")
    log_info("  help               Show this help message")
    log_info("")
    log_info("Options:")
    log_info("  --raw-dir=<path>           Path to raw data directory")
    log_info("  --cleaned-dir=<path>       Path to cleaned data directory")
    log_info("  --output-file=<path>       Path to output file")
    log_info("  --input-file=<path>        Path to input file for sharding")
    log_info("  --shard-dir=<path>         Path to shard output directory")
    log_info("  --manifest-file=<path>     Path to manifest.json")
    log_info("")
    log_info("Examples:")
    log_info("  # Clean with defaults from environment")
    log_info("  ./neurx_data_scripts.bin clean")
    log_info("")
    log_info("  # Clean with custom paths")
    log_info("  ./neurx_data_scripts.bin clean --raw-dir=/custom/raw --cleaned-dir=/custom/cleaned")
    log_info("")
    log_info("  # Generate shards")
    log_info("  ./neurx_data_scripts.bin shard")
    log_info("")
    log_info("  # Run full pipeline")
    log_info("  ./neurx_data_scripts.bin clean-and-shard")
    log_info("")
    i32(0)
}

// ============================================================================
// Main Dispatch
// ============================================================================

func main(args []string) i32 {
    let cmd = runtime_env_get("NEURX_SCRIPTS_CMD", "help")
    
    if cmd == "clean" {
        return cmd_clean()
    } else if cmd == "shard" {
        return cmd_shard()
    } else if cmd == "clean-and-shard" {
        return cmd_clean_and_shard()
    } else if cmd == "help" {
        return cmd_help()
    } else {
        log_error("Unknown command: " + cmd)
        log_info("Run with 'help' for usage information")
        return i32(1)
    }
}
