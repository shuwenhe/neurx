package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_launch_plan}

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
    launch := bridge_launch_plan(state)
    failures := 0
    failures = failures + expect(len(launch) > 0, "launch plan generated")
    failures = failures + expect(launch[0] == 91, "launch prefix")
    if failures == 0 {
        println("PASS cluster launch plan")
        return 0
    }
    println("FAIL cluster launch plan")
    1
}
