package test.complex

struct item {
    int pid
    string name
}

struct complex_struct {
    item* ptr
    int[] array
    item[] items
}
