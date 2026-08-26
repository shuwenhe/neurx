package test.return_types

struct config {
    int value
}

func new_config() (*config, bool) {
    let cfg = &config{
        value: 42
    }
    cfg, true
}
