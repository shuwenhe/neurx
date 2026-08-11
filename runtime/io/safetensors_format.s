package neurx.runtime.io
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
            header = header + int_to_str_for_json(t.shape[shape_idx])
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
        header = header + ",\"data_offsets\":[" + int_to_str_for_json(offset) + "," + int_to_str_for_json(offset + tensor_size) + "]"
        header = header + "}"
        offset = offset + tensor_size
        idx = idx + 1
    }
    header = header + "}"
    header
}

func int_to_str_for_json(int n) string {
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
