package main

struct Inner {
    int value
}

struct Outer {
    Inner data
}

func main() {
    println("=== Test 1: Extract inner first ===")
    Outer obj
    obj.data.value = 42
    
    Inner inner = obj.data
    int val = inner.value
    println("Extracted: " + int_to_str(val))
    
    println("")
    println("=== Test 2: Direct nested access ===")
    println("obj.data.value = " + int_to_str(obj.data.value))
    
    0
}
