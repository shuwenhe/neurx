package neurx.runtime.io

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
        bits = float_to_bits(value)
    } else {
        bits = float_to_bits(value)
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

func float_to_bits(float f) int {
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
