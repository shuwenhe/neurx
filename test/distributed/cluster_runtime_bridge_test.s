package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state, new_cluster_deployment_spec}
use neurx.deployment.cluster_runtime_bridge.{bridge_probe_runtime, bridge_deployment_summary}

func expect(bool condition, string name) int {
    if condition {
        print("PASS ")
        print(name)
        return 0
    }
    print("FAIL ")
    print(name)
    return 1
}

func main() int {
    state := new_demo_cluster_state()
    spec := new_cluster_deployment_spec("neurx-prod", "neurx:latest", "nccl", "node-0", 29500, 4, 32, "./artifact/checkpoints", "./dataset/pretrain", "./artifact/train_output")
    probe := bridge_probe_runtime(state)
    failures := 0
    failures = failures + expect(probe.ready, "bridge probe ready")
    failures = failures + expect(len(bridge_deployment_summary(state, spec)) > 0, "bridge summary generated")
    if failures == 0 {
        println("PASS cluster bridge")
        return 0
    }
    println("FAIL cluster bridge")
    1
}
