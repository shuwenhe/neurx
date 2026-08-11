package main
struct counter_state {
    int value
}

func main() {
    counter_state state = counter_state {
        value: 7,
    }
    counter_state next = state
    println("counter")
    println(string(next.value))
    0
}
