package test.init_ptr

struct config {
    int value
}

func new_config() config {
    config {
        value: 42
    }
}

func test() (config*, bool) {
    let cfg = &config{value: 42}
    cfg, true
}
