package test.ptr_init

struct config {
    int value
}

func new_config_ptr() config {
    let c = &config{value: 42}
    c
}
