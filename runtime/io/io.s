package neurx.runtime.io
use std.env.get as env_get
use std.fs.read_to_string as fs_read_to_string
use std.fs.write_text_file as fs_write_text_file
use std.process.run_process
use std.process.run_process_output
use std.vec.vec
struct json_value {
}

struct runtime_command_result {
    bool ok
    int exit_code
    string error
}

func trim(string s) string {
    int i = 0
    while i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    string out = ""
    int k = i
    while k <= j {
        out = out + string(s[k])
        k = k + 1
    }
    out
}

func runtime_shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = string(value[i])
        if int(ch) == 39 {
            out = neurx.strings.concat2(out, "'\"'\"'")
        } else {
            out = neurx.strings.concat2(out, ch)
        }
        i = i + 1
    }
    neurx.strings.concat2(out, "'")
}

func runtime_read_text_file(string path) string {
    var out = fs_read_to_string(path)
    if out.is_ok() {
        return out.unwrap()
    }
    ""
}

extern "intrinsic" func __host_read_binary_file(string path) []int

func runtime_read_binary_file(string path) []int {
    __host_read_binary_file(path)
}

func runtime_write_text_file(string path, string content) () {
    fs_write_text_file(path, content)
}

func runtime_append_text_file(string path, string content) () {
    string previous = runtime_read_text_file(path)
    runtime_write_text_file(path, previous + content)
}

func runtime_file_exists(string path) bool {
    string trimmed = trim(path)
    if trimmed == "" {
        return false
    }
    if fs_read_to_string(trimmed).is_ok() {
        return true
    }
    runtime_run_command("test -e " + runtime_shell_escape(trimmed)).ok
}

func runtime_dir_exists(string path) bool {
    string trimmed = trim(path)
    if trimmed == "" {
        return false
    }
    runtime_run_command("test -d " + runtime_shell_escape(trimmed)).ok
}

func runtime_make_dirs(string path) runtime_command_result {
    string trimmed = trim(path)
    if trimmed == "" {
        return runtime_command_result {
            ok: false,
            exit_code: 1,
            error: "empty_path",
        }
    }
    runtime_run_command("mkdir -p " + runtime_shell_escape(trimmed))
}

func runtime_delete_path(string path, bool recursive) runtime_command_result {
    string trimmed = trim(path)
    if trimmed == "" {
        return runtime_command_result {
            ok: false,
            exit_code: 1,
            error: "empty_path",
        }
    }
    string command = ""
    if recursive {
        command = "rm -rf -- " + runtime_shell_escape(trimmed)
    } else {
        command = "rm -f -- " + runtime_shell_escape(trimmed)
    }
    runtime_run_command(command)
}

func runtime_env_get(string name, string default_value) string {
    env_get(name).unwrap_or(default_value)
}

func runtime_env_has(string name) bool {
    env_get(name).is_some()
}

func runtime_run_command(string command) runtime_command_result {
    string cmd = trim(command)
    if cmd == "" {
        return runtime_command_result {
            ok: false,
            exit_code: 1,
            error: "empty_command",
        }
    }
    []string argv = []string{cap: 3}
    argv[0] = "sh"
    argv[1] = "-c"
    argv[2] = cmd
    var out = run_process(argv)
    if out.is_ok() {
        return runtime_command_result {
            ok: true,
            exit_code: 0,
            error: "",
        }
    }
    runtime_command_result {
        ok: false,
        exit_code: 1,
        error: out.unwrap_err().message,
    }
}

func runtime_run_command_output(string command) string {
    string cmd = trim(command)
    if cmd == "" {
        return ""
    }
    []string argv = []string{cap: 3}
    argv[0] = "sh"
    argv[1] = "-c"
    argv[2] = cmd
    var out = run_process_output(argv)
    if out.is_ok() {
        return out.unwrap()
    }
    ""
}
extern func runtime_run_command_exit_code(string command) int
extern func runtime_execute_file(string target_path, string entry_function) int

func runtime_json_parse(string text) json_value {
    json_value {}
}

func runtime_json_stringify(json_value value) string {
    "{}"
}

func runtime_read_json_file(string path) json_value {
    json_value {}
}

func runtime_write_json_file(string path, json_value value) () {
    runtime_write_text_file(path, runtime_json_stringify(value))
}

struct tensor {
    string name
    string dtype
    []int shape
    []float data
}

struct tensor_buffer {
    []byte buffer
    int pos
}

func tensor_buffer_new(int capacity) tensor_buffer {
    tensor_buffer {
        buffer: []byte{cap: capacity},
        pos: 0,
    }
}

func tensor_buffer_write_bytes(tensor_buffer buf, []byte data) () {
    int i = 0
    while i < len(data) {
        if buf.pos >= len(buf.buffer) {
            break
        }
        buf.buffer[buf.pos] = data[i]
        buf.pos = buf.pos + 1
        i = i + 1
    }
}

func tensor_buffer_write_u64_le(tensor_buffer buf, int value) () {
    []byte bytes = []byte{cap: 8}
    int v = value
    int i = 0
    while i < 8 {
        int idx = i
        int remainder = v - (v / 256) * 256
        bytes[idx] = byte(remainder)
        v = v / 256
        i = i + 1
    }
    tensor_buffer_write_bytes(buf, bytes)
}

func tensor_buffer_write_f32_le(tensor_buffer buf, float value) () {
    int bits = 0
    if value >= 0.0 {
        bits = float_to_bits_internal(value)
    } else {
        bits = float_to_bits_internal(value)
    }
    []byte bytes = []byte{cap: 4}
    int v = bits
    bytes[0] = byte(v - (v / 256) * 256)
    v = v / 256
    bytes[1] = byte(v - (v / 256) * 256)
    v = v / 256
    bytes[2] = byte(v - (v / 256) * 256)
    v = v / 256
    bytes[3] = byte(v - (v / 256) * 256)
    tensor_buffer_write_bytes(buf, bytes)
}

func tensor_buffer_write_string(tensor_buffer buf, string s) () {
    int i = 0
    while i < len(s) {
        if buf.pos >= len(buf.buffer) {
            break
        }
        buf.buffer[buf.pos] = s[i]
        buf.pos = buf.pos + 1
        i = i + 1
    }
}

func tensor_buffer_len(tensor_buffer buf) int {
    buf.pos
}

func tensor_buffer_slice(tensor_buffer buf) []byte {
    []byte result = []byte{cap: buf.pos}
    int i = 0
    while i < buf.pos {
        result[i] = buf.buffer[i]
        i = i + 1
    }
    result
}

func float_to_bits_internal(float f) int {
    if f == 0.0 {
        return 0
    }
    bool sign = f < 0.0
    float abs_f = f
    if sign {
        abs_f = 0.0 - f
    }
    int exp = 127
    float mantissa_f = abs_f
    while mantissa_f >= 2.0 {
        mantissa_f = mantissa_f / 2.0
        exp = exp + 1
    }
    while mantissa_f < 1.0 && exp > 0 {
        mantissa_f = mantissa_f * 2.0
        exp = exp - 1
    }
    int mantissa = int((mantissa_f - 1.0) * 8388608.0)
    int bits = 0
    if sign {
        bits = bits + 2147483648
    }
    bits = bits + exp * 8388608
    bits = bits + mantissa
    bits
}

struct safetensors_writer {
    string filepath
    []tensor tensors
    int tensor_count
    int total_data_size
}

func safetensors_writer_new(string filepath) safetensors_writer {
    safetensors_writer {
        filepath: filepath,
        tensors: []tensor{cap: 100},
        tensor_count: 0,
        total_data_size: 0,
    }
}

func safetensors_writer_add_tensor(safetensors_writer w, tensor t) () {
    int data_size = 0
    int i = 0
    while i < t.shape_count {
        if data_size == 0 {
            data_size = 1
        }
        data_size = data_size * t.shape[i]
        i = i + 1
    }
    if t.dtype == "F32" {
        data_size = data_size * 4
    }
    w.tensors[w.tensor_count] = t
    w.tensor_count = w.tensor_count + 1
    w.total_data_size = w.total_data_size + data_size
}

func safetensors_writer_build_header(safetensors_writer w) string {
    string header = "{"
    int offset = 0
    int idx = 0
    while idx < w.tensor_count {
        if idx > 0 {
            header = header + ","
        }
        tensor t = w.tensors[idx]
        header = header + "\"" + t.name + "\":{"
        header = header + "\"dtype\":\"" + t.dtype + "\""
        header = header + ",\"shape\":["
        int shape_idx = 0
        while shape_idx < t.shape_count {
            if shape_idx > 0 {
                header = header + ","
            }
            header = header + int_to_str_json_internal(t.shape[shape_idx])
            shape_idx = shape_idx + 1
        }
        header = header + "]"
        int tensor_size = 1
        int si = 0
        while si < t.shape_count {
            tensor_size = tensor_size * t.shape[si]
            si = si + 1
        }
        if t.dtype == "F32" {
            tensor_size = tensor_size * 4
        }
        header = header + ",\"data_offsets\":[" + int_to_str_json_internal(offset) + "," + int_to_str_json_internal(offset + tensor_size) + "]"
        header = header + "}"
        offset = offset + tensor_size
        idx = idx + 1
    }
    header = header + "}"
    header
}

func int_to_str_json_internal(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    int val = n
    if neg {
        val = 0 - val
    }
    string digits = ""
    while val > 0 {
        int digit = val - (val / 10) * 10
        string ch = ""
        if digit == 0 { ch = "0" }
        if digit == 1 { ch = "1" }
        if digit == 2 { ch = "2" }
        if digit == 3 { ch = "3" }
        if digit == 4 { ch = "4" }
        if digit == 5 { ch = "5" }
        if digit == 6 { ch = "6" }
        if digit == 7 { ch = "7" }
        if digit == 8 { ch = "8" }
        if digit == 9 { ch = "9" }
        digits = ch + digits
        val = val / 10
    }
    if neg {
        digits = "-" + digits
    }
    digits
}

func safetensors_writer_finish(safetensors_writer w) bool {
    string header = safetensors_writer_build_header(w)
    int header_size = len(header)
    tensor_buffer buf = tensor_buffer_new(8 + header_size + w.total_data_size + 1024)
    tensor_buffer_write_u64_le(buf, header_size)
    tensor_buffer_write_string(buf, header)
    int tidx = 0
    while tidx < w.tensor_count {
        tensor t = w.tensors[tidx]
        int data_len = 1
        int sidx = 0
        while sidx < t.shape_count {
            data_len = data_len * t.shape[sidx]
            sidx = sidx + 1
        }
        int didx = 0
        while didx < data_len {
            if didx < t.data_count {
                tensor_buffer_write_f32_le(buf, t.data[didx])
            } else {
                tensor_buffer_write_f32_le(buf, 0.0)
            }
            didx = didx + 1
        }
        tidx = tidx + 1
    }
    []byte file_data = tensor_buffer_slice(buf)
    runtime_write_binary_file(w.filepath, file_data)
    true
}

extern "intrinsic" func __host_write_binary_file(string path, []byte data) ()

func runtime_write_binary_file(string path, []byte data) () {
    __host_write_binary_file(path, data)
}
