package neurx.runtime.io

struct json_value {
}

func runtime_read_text_file(string path) string {
    read_text_file(path)
}

func runtime_write_text_file(string path, string content) () {
    write_text_file(path, content)
}

func runtime_append_text_file(string path, string content) () {
    append_text_file(path, content)
}

func runtime_file_exists(string path) bool {
    file_exists(path)
}

func runtime_env_get(string name, string default_value) string {
    env_get(name, default_value)
}

func runtime_env_has(string name) bool {
    env_has(name)
}

func runtime_json_parse(string text) json_value {
    json_parse(text)
}

func runtime_json_stringify(json_value value) string {
    json_stringify(value)
}

func runtime_read_json_file(string path) json_value {
    json_parse(read_text_file(path))
}

func runtime_write_json_file(string path, json_value value) () {
    write_text_file(path, json_stringify(value))
}
