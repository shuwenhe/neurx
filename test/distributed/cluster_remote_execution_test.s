package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_remote_execution_commands}

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
    ssh_script := bridge_remote_execution_commands(state, true)
    local_script := bridge_remote_execution_commands(state, false)
    failures := 0
    failures = failures + expect(len(ssh_script) > 0, "ssh script generated")
    failures = failures + expect(len(local_script) > 0, "local script generated")
    failures = failures + expect(ssh_script[0] == 91, "ssh prefix")
    if failures == 0 {
        println("PASS cluster remote execution")
        return 0
    }
    println("FAIL cluster remote execution")
    1
}
