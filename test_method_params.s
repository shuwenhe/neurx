package test.method_params

struct config {
    int value
}

func (c config*) update(x int) {
    c.value = x
}
