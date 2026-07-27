package neurx.tensor.batch
use neurx.strings
use neurx.autograd.function
use neurx.strings
use neurx.tensor.tensor
use neurx.strings
struct batch_state {
    string name
    bool active
    int batch_size
    int batch_dim
    []string primitives
    []string params
}

func join_strings([]string values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + values[i]
        i = i + 1
    }
    out
}

func copy_shape_tail(tensor a) []int {
    int ndim = len(a.shape)
    []int shape = []int{cap: ndim}
    int i = 1
    int out_i = 1
    while i < ndim {
        shape[out_i] = a.shape[i]
        out_i = out_i + 1
        i = i + 1
    }
    if len(shape) == 0 {
        shape[0] = 1
    }
    shape
}

func slice_axis0(tensor a, int index) tensor {
    int ndim = len(a.shape)
    if ndim == 0 {
        return neurx.tensor.tensor.clone(a)
    }
    int slice_size = 1
    int i = 1
    while i < ndim {
        slice_size = slice_size * a.shape[i]
        i = i + 1
    }
    []float out = []float{cap: slice_size}
    int start = index * slice_size
    i = 0
    while i < slice_size {
        out[i] = a.data[start + i]
        i = i + 1
    }
    neurx.tensor.tensor.new(out, copy_shape_tail(a), a.requires_grad)
}

func batch_reduce_scalar(tensor a, int mode) tensor {
    int batch = a.shape[0]
    []float out = []float{cap: batch}
    int i = 0
    while i < batch {
        tensor slice = slice_axis0(a, i)
        tensor reduced = neurx.tensor.tensor.sum(slice)
        if mode == 1 {
            reduced = neurx.tensor.tensor.mean(slice)
        }
        float value = 0.0
        if len(reduced.data) > 0 {
            value = reduced.data[0]
        }
        out[i] = value
        i = i + 1
    }
    neurx.tensor.tensor.new(out, [batch], a.requires_grad)
}

func batch_matmul(tensor a, tensor b) tensor {
    int ndim_a = len(a.shape)
    int ndim_b = len(b.shape)
    if ndim_a < 3 && ndim_b < 3 {
        return neurx.tensor.tensor.matmul(a, b)
    }
    bool batch_a = ndim_a >= 3
    bool batch_b = ndim_b >= 3
    int batch = 1
    if batch_a {
        batch = a.shape[0]
    } else {
        batch = b.shape[0]
    }
    if batch_a && batch_b && a.shape[0] != b.shape[0] {
        return neurx.tensor.tensor.matmul(a, b)
    }
    tensor first_a = a
    tensor first_b = b
    if batch_a {
        first_a = slice_axis0(a, 0)
    }
    if batch_b {
        first_b = slice_axis0(b, 0)
    }
    tensor first_out = neurx.tensor.tensor.matmul(first_a, first_b)
    []int out_shape = []int{cap: len(first_out.shape) + 1}
    out_shape[0] = batch
    int j = 0
    while j < len(first_out.shape) {
        out_shape[j + 1] = first_out.shape[j]
        j = j + 1
    }
    int slice_size = len(first_out.data)
    []float out = []float{cap: batch * slice_size}
    int k = 0
    while k < slice_size {
        out[k] = first_out.data[k]
        k = k + 1
    }
    int batch_index = 1
    while batch_index < batch {
        tensor slice_a = a
        tensor slice_b = b
        if batch_a {
            slice_a = slice_axis0(a, batch_index)
        }
        if batch_b {
            slice_b = slice_axis0(b, batch_index)
        }
        tensor slice_out = neurx.tensor.tensor.matmul(slice_a, slice_b)
        int offset = batch_index * slice_size
        int m = 0
        while m < slice_size {
            out[offset + m] = slice_out.data[m]
            m = m + 1
        }
        batch_index = batch_index + 1
    }
    neurx.tensor.tensor.new(out, out_shape, a.requires_grad || b.requires_grad)
}

func new_batch_state(string name, int batch_size, int batch_dim) batch_state {
    batch_state {
        name: name,
        active: false,
        batch_size: batch_size,
        batch_dim: batch_dim,
        primitives: [],
        params: [],
    }
}

func batch_name(batch_state state) string {
    state.name
}

func batch_active(batch_state state) bool {
    state.active
}

func batch_batch_size(batch_state state) int {
    state.batch_size
}

func batch_batch_dim(batch_state state) int {
    state.batch_dim
}

func batch_primitive_count(batch_state state) int {
    len(state.primitives)
}

func batch_param_count(batch_state state) int {
    len(state.params)
}

func batch_has_primitive(batch_state state, string primitive) bool {
    int i = 0
    while i < len(state.primitives) {
        if neurx.strings.strings_eq(neurx.strings.string_at(state.primitives, i), primitive) {
            return true
        }
        i = i + 1
    }
    false
}

func batch_has_param(batch_state state, string param) bool {
    int i = 0
    while i < len(state.params) {
        if neurx.strings.strings_eq(neurx.strings.string_at(state.params, i), param) {
            return true
        }
        i = i + 1
    }
    false
}

func batch_add_primitive(batch_state state, string primitive) batch_state {
    []string primitives = copy_strings(state.primitives)
    int n = len(primitives)
    []string next = []string{cap: n + 1}
    int i = 0
    while i < n {
        next[i] = primitives[i]
        i = i + 1
    }
    next[n] = primitive
    batch_state {
        name: state.name,
        active: true,
        batch_size: state.batch_size,
        batch_dim: state.batch_dim,
        primitives: next,
        params: copy_strings(state.params),
    }
}

func batch_add_param(batch_state state, string param) batch_state {
    []string params = copy_strings(state.params)
    int n = len(params)
    []string next = []string{cap: n + 1}
    int i = 0
    while i < n {
        next[i] = params[i]
        i = i + 1
    }
    next[n] = param
    batch_state {
        name: state.name,
        active: true,
        batch_size: state.batch_size,
        batch_dim: state.batch_dim,
        primitives: copy_strings(state.primitives),
        params: next,
    }
}

func batch_set_active(batch_state state, bool active) batch_state {
    batch_state {
        name: state.name,
        active: active,
        batch_size: state.batch_size,
        batch_dim: state.batch_dim,
        primitives: copy_strings(state.primitives),
        params: copy_strings(state.params),
    }
}

func batch_set_batch_size(batch_state state, int batch_size) batch_state {
    batch_state {
        name: state.name,
        active: state.active,
        batch_size: batch_size,
        batch_dim: state.batch_dim,
        primitives: copy_strings(state.primitives),
        params: copy_strings(state.params),
    }
}

func batch_set_batch_dim(batch_state state, int batch_dim) batch_state {
    batch_state {
        name: state.name,
        active: state.active,
        batch_size: state.batch_size,
        batch_dim: batch_dim,
        primitives: copy_strings(state.primitives),
        params: copy_strings(state.params),
    }
}

func batch_clear_primitives(batch_state state) batch_state {
    batch_state {
        name: state.name,
        active: state.active,
        batch_size: state.batch_size,
        batch_dim: state.batch_dim,
        primitives: [],
        params: copy_strings(state.params),
    }
}

func batch_clear_params(batch_state state) batch_state {
    batch_state {
        name: state.name,
        active: state.active,
        batch_size: state.batch_size,
        batch_dim: state.batch_dim,
        primitives: copy_strings(state.primitives),
        params: [],
    }
}

func batch_state_dict(batch_state state) batch_state {
    batch_state {
        name: state.name,
        active: state.active,
        batch_size: state.batch_size,
        batch_dim: state.batch_dim,
        primitives: copy_strings(state.primitives),
        params: copy_strings(state.params),
    }
}

func batch_load_state_dict(batch_state state, batch_state other) batch_state {
    other
}

func batch_to_transform_chain(batch_state state) transform_chain {
    transform_chain {
        steps: copy_strings(state.primitives),
        params: copy_strings(state.params),
        inputs: [],
        outputs: [],
        eqns: [],
        ready: state.active || len(state.primitives) > 0,
        linearized: false,
    }
}

func transform_chain_to_batch(transform_chain chain, string name, int batch_size, int batch_dim) batch_state {
    batch_state {
        name: name,
        active: chain.ready,
        batch_size: batch_size,
        batch_dim: batch_dim,
        primitives: copy_strings(chain.steps),
        params: copy_strings(chain.params),
    }
}

func vmap_unary(string primitive, tensor a) tensor {
    if primitive == "negative" {
        return neurx.tensor.tensor.negative(a)
    }
    if primitive == "abs" {
        return neurx.tensor.tensor.abs(a)
    }
    if primitive == "square" {
        return neurx.tensor.tensor.square(a)
    }
    if primitive == "reciprocal" {
        return neurx.tensor.tensor.reciprocal(a)
    }
    if primitive == "sum" {
        return batch_reduce_scalar(a, 0)
    }
    if primitive == "mean" {
        return batch_reduce_scalar(a, 1)
    }
    neurx.tensor.tensor.clone(a)
}

func vmap_binary(string primitive, tensor a, tensor b) tensor {
    if primitive == "add" {
        return neurx.tensor.tensor.add(a, b)
    }
    if primitive == "sub" {
        return neurx.tensor.tensor.sub(a, b)
    }
    if primitive == "mul" {
        return neurx.tensor.tensor.mul(a, b)
    }
    if primitive == "div" {
        return neurx.tensor.tensor.div(a, b)
    }
    if primitive == "maximum" {
        return neurx.tensor.tensor.maximum(a, b)
    }
    if primitive == "minimum" {
        return neurx.tensor.tensor.minimum(a, b)
    }
    if primitive == "matmul" {
        return batch_matmul(a, b)
    }
    if primitive == "concatenate" {
        return neurx.tensor.tensor.concatenate(a, b, 0)
    }
    if primitive == "stack" {
        return neurx.tensor.tensor.stack(a, b, 0)
    }
    neurx.tensor.tensor.add(a, b)
}

func vmap_ternary(string primitive, tensor condition, tensor x, tensor y) tensor {
    if primitive == "where" {
        return neurx.tensor.tensor.where(condition, x, y)
    }
    neurx.tensor.tensor.where(condition, x, y)
}

func vmap_add(tensor a, tensor b) tensor {
    vmap_binary("add", a, b)
}

func vmap_sub(tensor a, tensor b) tensor {
    vmap_binary("sub", a, b)
}

func vmap_mul(tensor a, tensor b) tensor {
    vmap_binary("mul", a, b)
}

func vmap_div(tensor a, tensor b) tensor {
    vmap_binary("div", a, b)
}

func vmap_maximum(tensor a, tensor b) tensor {
    vmap_binary("maximum", a, b)
}

func vmap_minimum(tensor a, tensor b) tensor {
    vmap_binary("minimum", a, b)
}

func vmap_matmul(tensor a, tensor b) tensor {
    vmap_binary("matmul", a, b)
}

func vmap_sum(tensor a) tensor {
    vmap_unary("sum", a)
}

func vmap_mean(tensor a) tensor {
    vmap_unary("mean", a)
}

func vmap_negative(tensor a) tensor {
    vmap_unary("negative", a)
}

func vmap_abs(tensor a) tensor {
    vmap_unary("abs", a)
}

func vmap_square(tensor a) tensor {
    vmap_unary("square", a)
}

func vmap_reciprocal(tensor a) tensor {
    vmap_unary("reciprocal", a)
}

func vmap_where(tensor condition, tensor x, tensor y) tensor {
    vmap_ternary("where", condition, x, y)
}
