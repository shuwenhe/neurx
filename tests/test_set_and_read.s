package main

struct Data {
    int value
}

func main() {
    Data obj
    obj.value = 42
    int val = obj.value
    println("Value: " + int_to_str(val))
    0
}
