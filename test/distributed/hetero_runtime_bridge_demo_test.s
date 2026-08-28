package main

use neurx.deployment.hetero_runtime_bridge.{bridge_hetero_demo_script}

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
    script := bridge_hetero_demo_script("neurx-worker", "127.0.0.1", 29500)
    failures := 0
    failures = failures + expect(len(script) > 0, "demo script generated")
    failures = failures + expect(script[0] == 35, "demo shebang")
    if failures == 0 {
        println("PASS hetero runtime bridge demo")
        return 0
    }
    println("FAIL hetero runtime bridge demo")
    1
}
