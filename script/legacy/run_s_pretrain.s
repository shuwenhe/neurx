package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let output_dir = runtime_env_get("NEURX_S_PRETRAIN_OUTPUT_DIR", project_root + "/artifact/checkpoints/llm_s_pretrain")
    let manifest = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    let steps = runtime_env_get("NEURX_S_PRETRAIN_STEPS", "50")
    let warmup = runtime_env_get("NEURX_S_PRETRAIN_WARMUP_STEPS", "10")
    let source_file = resolve_source(project_root)
    println("NeurX S Pretrain Orchestrator (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("Source file  : " + source_file)
    println("Output dir   : " + output_dir)
    println("manifest     : " + manifest)
    println("Steps        : " + steps)
    println("Warmup steps : " + warmup)
    println("")
    print_flag("source file", runtime_file_exists(source_file))
    print_flag("output dir", runtime_file_exists(output_dir))
    print_flag("manifest", runtime_file_exists(manifest))
    println("")
    println("This S entrypoint centralizes the pretrain selection/status layer.")
    println("Backend compilation and checkpoint materialization remain delegated.")
    0
}

func resolve_source(string project_root) string {
    let candidate_a = project_root + "/train/train_llm_jsonl.s"
    if runtime_file_exists(candidate_a) {
        return candidate_a
    }
    let candidate_b = project_root + "/train/train_llm.s"
    if runtime_file_exists(candidate_b) {
        return candidate_b
    }
    let candidate_c = project_root + "/train_llm_jsonl.s"
    if runtime_file_exists(candidate_c) {
        return candidate_c
    }
    let candidate_d = project_root + "/train_llm.s"
    if runtime_file_exists(candidate_d) {
        return candidate_d
    }
    project_root + "/src/train_llm.s"
}

func print_flag(string name, bool ok) {
    if ok {
        println("  - " + name + ": ready")
    } else {
        println("  - " + name + ": missing")
    }
}
