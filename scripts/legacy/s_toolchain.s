package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.env.args as host_args
use std.io.println

func main() {
    let args = host_args()
    let cmd = toolchain_command(args)
    if cmd == "status" {
        return toolchain_status()
    }
    if cmd == "roadmap" {
        return toolchain_roadmap()
    }
    if cmd == "all" {
        return toolchain_all()
    }
    if cmd == "help" {
        return toolchain_help()
    }
    println("error: unknown command: " + cmd)
    println("run with TOOLCHAIN_CMD=status|roadmap|all|help")
    return 2
}

func toolchain_command([]string args) string {
    let env_cmd = runtime_env_get("TOOLCHAIN_CMD", "")
    if env_cmd != "" {
        return env_cmd
    }
    if args.len() >= 2 {
        return args[1]
    }
    "status"
}

func toolchain_status() int {
    println("NeurX S-Only Toolchain status")
    println("")
    print_flag("scripts/legacy/data_clean.s", runtime_file_exists("scripts/legacy/data_clean.s"))
    print_flag("scripts/legacy/data_shard.s", runtime_file_exists("scripts/legacy/data_shard.s"))
    print_flag("scripts/legacy/scripts.s", runtime_file_exists("scripts/legacy/scripts.s"))
    print_flag("data/tools/verify_dataset.s", runtime_file_exists("data/tools/verify_dataset.s"))
    print_flag("scripts/legacy/industrial_ops_runner.s", runtime_file_exists("scripts/legacy/industrial_ops_runner.s"))
    print_flag("scripts/legacy/s_toolchain.s", runtime_file_exists("scripts/legacy/s_toolchain.s"))
    println("")
    println("Available migration targets:")
    println("  build-data-scripts")
    println("  clean-s")
    println("  shard-s")
    println("  data-pipeline-s")
    println("  verify-dataset-s")
    println("  build-industrial-ops")
    println("  industrial-ops")
    println("  toolchain-s")
    0
}-----------

func toolchain_roadmap() int {
    println("NeurX S-Only Toolchain Roadmap")
    println("")
    println("Phase 1: centralize the current S entrypoints")
    println("Phase 2: move data verification and analysis into S")
    println("Phase 3: replace remaining shell wrappers with S modules")
    println("Phase 4: add an S-native build/test dispatcher")
    println("Phase 5: keep shell only as compatibility fallback")
    println("")
    println("Immediate acceptance criteria:")
    println("  - toolchain-s runs")
    println("  - status output is stable")
    println("  - roadmap output is stable")
    0
}

func toolchain_all() int {
    println("toolchain-all is staged behind the build dispatcher")
    println("Use make build-data-scripts / make verify-dataset-s / make industrial-ops")
    0
}

func toolchain_help() int {
    println("NeurX S-Only Toolchain Coordinator")
    println("")
    println("Commands:")
    println("  status   Show S-only migration status")
    println("  roadmap  Show the S-only plan")
    println("  all      Show staged orchestration guidance")
    println("  help     Show this message")
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("  - " + name + ": ready")
    } else {
        println("  - " + name + ": missing")
    }
}

