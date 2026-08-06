package main

struct data {
    int value
}

func main() {
    println("=== Test: Can we SET fields? ===")
    data obj
    obj.value = 42
    println("Set obj.value = 42")
    println("Test complete")
    0
}

