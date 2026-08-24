package neurx.experimental.compiler.ir.value

struct value_type {
    string kind
    int[] shape
    string dtype
}

struct tensor_value {
    int id
    value_type tensor_type
    string name
}

struct scalar_value {
    int id
    value_type scalar_type
    string name
}

struct attr_value {
    string key
    string value_str
}

func value_type_float32(int[] shape) value_type {
    value_type {
        kind: "tensor",
        shape: shape,
        dtype: "float32",
    }
}

func value_type_int32(int[] shape) value_type {
    value_type {
        kind: "tensor",
        shape: shape,
        dtype: "int32",
    }
}

func value_type_int64(int[] shape) value_type {
    value_type {
        kind: "tensor",
        shape: shape,
        dtype: "int64",
    }
}

func value_type_bool(int[] shape) value_type {
    value_type {
        kind: "tensor",
        shape: shape,
        dtype: "bool",
    }
}

func value_type_scalar_float() value_type {
    value_type {
        kind: "scalar",
        shape: new int[0],
        dtype: "float32",
    }
}

func value_type_scalar_int32() value_type {
    value_type {
        kind: "scalar",
        shape: new int[0],
        dtype: "int32",
    }
}

func new_tensor_value(int id, int[] shape, string dtype, string name) tensor_value {
    tensor_value {
        id: id,
        tensor_type: value_type {
            kind: "tensor",
            shape: shape,
            dtype: dtype,
        },
        name: name,
    }
}

func new_scalar_value(int id, string dtype, string name) scalar_value {
    scalar_value {
        id: id,
        scalar_type: value_type {
            kind: "scalar",
            shape: new int[0],
            dtype: dtype,
        },
        name: name,
    }
}

func (value_type* vt) total_elements() int {
    int total = 1
    for i in vt.shape {
        total = total * i
    }
    total
}

func (value_type* vt) memory_bytes() int {
    int element_size = match vt.dtype {
        "float32": 4,
        "int32": 4,
        "int64": 8,
        "bool": 1,
        default: 4,
    }
    vt.total_elements() * element_size
}

func (value_type* vt) shape_str() string {
    string s = "["
    for i, dim in vt.shape {
        if i > 0 {
            s = s + ", "
        }
        s = s + dim as string
    }
    s + "]"
}
