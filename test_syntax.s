package test.simple

struct test_struct {
    int value
    string name
}

func new_test() test_struct {
    test_struct {
        value: 42,
        name: "test"
    }
}

func (t: test_struct) get_value() int {
    t.value
}
