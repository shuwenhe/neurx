package test.simple_struct

struct config {
    int value
}

func new_config() config {
    config {
        value: 42
    }
}
