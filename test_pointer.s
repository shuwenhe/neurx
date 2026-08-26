package test.pointer

struct inner {
    int value
}

struct outer {
    inner* ptr
}
