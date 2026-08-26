package test.method_syntax

struct counter {
    int value
}

func new_counter() counter {
    counter { value: 0 }
}

func (counter c) get() int {
    c.value
}

func (counter* c) set(int v) {
    c.value = v
}
