package neurx.module.state_dict
use neurx.tensor.tensor
use neurx.nn
struct named_tensor {
    string name
    tensor value
}
struct module_state {
    nn.module root
    []string parameter_names
    []string buffer_names
    int parameter_count
    int buffer_count
    int child_count
}
func module_state_dict(nn.module m) module_state {
    module_state {
        root: neurx.nn.module_state_dict(m),
        parameter_names: neurx.nn.module_named_parameters(m),
        buffer_names: neurx.nn.module_named_buffers(m),
        parameter_count: neurx.nn.module_parameter_count(m),
        buffer_count: neurx.nn.module_buffer_count(m),
        child_count: neurx.nn.module_child_count(m),
    }
}
func module_load_state_dict(nn.module m, module_state state) nn.module {
    neurx.nn.module_load_state_dict(m, state.root)
}
func module_named_parameter_tensors(nn.module m) []named_tensor {
    []string names = neurx.nn.module_named_parameters(m)
    []tensor values = neurx.nn.module_parameters(m)
    int n = len(names)
    if len(values) < n {
        n = len(values)
    }
    []named_tensor out = []named_tensor{cap: n}
    int i = 0
    while i < n {
        out[i] = named_tensor {
            name: names[i],
            value: values[i],
        }
        i = i + 1
    }
    out
}
func module_named_buffer_tensors(nn.module m) []named_tensor {
    []string names = neurx.nn.module_named_buffers(m)
    []tensor values = neurx.nn.module_buffers(m)
    int n = len(names)
    if len(values) < n {
        n = len(values)
    }
    []named_tensor out = []named_tensor{cap: n}
    int i = 0
    while i < n {
        out[i] = named_tensor {
            name: names[i],
            value: values[i],
        }
        i = i + 1
    }
    out
}
func module_state_parameter_count(module_state state) int {
    state.parameter_count
}
func module_state_buffer_count(module_state state) int {
    state.buffer_count
}
func module_state_child_count(module_state state) int {
    state.child_count
}
