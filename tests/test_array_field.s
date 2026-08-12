package main
struct data {
    int value
}


func main() {
    println("=== Test 1: Local struct field access ===")
    data local
    local.value = 42
    int val1 = local.value
    println("Local: " + int_to_str(val1))
    println("")
    println("=== Test 2: Array element field access ===")
    []data arr = []data{cap: 1}
    arr[0].value = 99
    data elem = arr[0]
    int val2 = elem.value
    println("From array: " + int_to_str(val2))
    0
}

