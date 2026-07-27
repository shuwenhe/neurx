package main
use std.io.println
func main() int {
    println("NeurX S CLI Quick Reference")
    println("")
    println("Training")
    println("  train_foundation_model.sh -> neurx train <scale> <gpus>")
    println("  START_7B_TRAINING.sh -> neurx launch-7b")
    println("  LAUNCH_70B_TRAINING.sh -> neurx launch-70b")
    println("  LAUNCH_1T_TRAINING.sh -> neurx launch-1t")
    println("")
    println("Build / Data / Inference")
    println("  build_transformer_e2e_bundle.sh -> S build packaging")
    println("  fetch_github_datasets.sh -> neurx fetch-data github")
    println("  run_inference*.sh -> neurx inference")
    println("  chat.sh -> neurx chat")
    println("")
    println("Utilities")
    println("  tools/watch-auto-commit-push.sh -> watch-auto-commit-push.s")
    println("  tools/rewrite-commit-messages.sh -> rewrite-commit-messages.s")
    println("  tools/cleanup-old-commits.sh -> cleanup-old-commits.s")
    0
}
