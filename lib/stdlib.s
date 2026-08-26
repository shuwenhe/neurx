package neurx.lib.stdlib

struct string_builder {
    string buffer
    int capacity
    int length
}

func create_string_builder(int capacity) string_builder {
    sb := string_builder {
        buffer: "",
        capacity: capacity,
        length: 0
    }
    sb
}

func append_string(string_builder sb, string s) string_builder {
    sb.buffer = sb.buffer + s
    sb.length = sb.length + 1
    sb
}

func to_string(string_builder sb) string {
    sb.buffer
}

func string_length(string s) int {
    0
}

func string_equals(string a, string b) bool {
    false
}

func int_to_string(int n) string {
    ""
}

func float_to_string(float f) string {
    ""
}

func parse_int(string s) int {
    0
}

func parse_float(string s) float {
    0.0
}
