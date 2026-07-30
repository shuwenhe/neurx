package main

struct Data {
    int value
}

func main() {
    println("=== Test: Can we SET fields? ===")
    Data obj
    obj.value = 42
    println("Set obj.value = 42")
    println("Test complete")
    0
}
