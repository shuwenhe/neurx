package neurx.module
use neurx.tensor.tensor
use neurx.nn

func module_new(string name) nn.module {
    neurx.nn.new_module(name)
}

func parameter_new(tensor value, string name) nn.parameter {
    neurx.nn.new_parameter(value, name)
}

func module_register_parameter(nn.module m, string name, nn.parameter p) nn.module {
    neurx.nn.module_register_parameter(m, name, p)
}

func module_add_parameter(nn.module m, string name, tensor value) nn.module {
    neurx.nn.module_add_parameter(m, name, value)
}

func module_register_buffer(nn.module m, string name, tensor value) nn.module {
    neurx.nn.module_register_buffer(m, name, value)
}

func module_add_buffer(nn.module m, string name, tensor value) nn.module {
    neurx.nn.module_add_buffer(m, name, value)
}

func module_register_child(nn.module m, string name, nn.module child) nn.module {
    neurx.nn.module_register_child(m, name, child)
}

func module_add_child(nn.module m, string name, nn.module child) nn.module {
    neurx.nn.module_add_child(m, name, child)
}

func module_parameters(nn.module m) []tensor {
    neurx.nn.module_parameters(m)
}

func module_named_parameters(nn.module m) []string {
    neurx.nn.module_named_parameters(m)
}

func module_buffers(nn.module m) []tensor {
    neurx.nn.module_buffers(m)
}

func module_named_buffers(nn.module m) []string {
    neurx.nn.module_named_buffers(m)
}

func module_children(nn.module m) []nn.module {
    neurx.nn.module_children(m)
}

func module_named_children(nn.module m) []string {
    neurx.nn.module_named_children(m)
}

func module_train(nn.module m) nn.module {
    neurx.nn.module_train(m)
}

func module_eval(nn.module m) nn.module {
    neurx.nn.module_eval(m)
}

func module_freeze(nn.module m) nn.module {
    neurx.nn.module_set_trainable(m, false)
}

func module_unfreeze(nn.module m) nn.module {
    neurx.nn.module_set_trainable(m, true)
}

func module_state_dict(nn.module m) nn.module {
    neurx.nn.module_state_dict(m)
}

func module_load_state_dict(nn.module m, nn.module state) nn.module {
    neurx.nn.module_load_state_dict(m, state)
}

func module_parameter_count(nn.module m) int {
    neurx.nn.module_parameter_count(m)
}

func module_buffer_count(nn.module m) int {
    neurx.nn.module_buffer_count(m)
}

func module_child_count(nn.module m) int {
    neurx.nn.module_child_count(m)
}

func module_get_parameter(nn.module m, string name) tensor {
    neurx.nn.module_get_parameter(m, name)
}

func module_get_buffer(nn.module m, string name) tensor {
    neurx.nn.module_get_buffer(m, name)
}

func module_get_child(nn.module m, string name) nn.module {
    neurx.nn.module_get_child(m, name)
}

func module_has_parameter(nn.module m, string name) bool {
    neurx.nn.module_has_parameter(m, name)
}

func module_has_buffer(nn.module m, string name) bool {
    neurx.nn.module_has_buffer(m, name)
}

func module_has_child(nn.module m, string name) bool {
    neurx.nn.module_has_child(m, name)
}

func module_first_parameter(nn.module m) tensor {
    neurx.nn.module_first_parameter(m)
}

func sequential_new() nn.sequential {
    neurx.nn.sequential_new()
}

func sequential_add(nn.sequential seq, nn.module child) nn.sequential {
    neurx.nn.sequential_add(seq, child)
}

func sequential_from_modules([]nn.module layers) nn.sequential {
    neurx.nn.sequential_from_modules(layers)
}

func sequential_module(nn.sequential seq) nn.module {
    neurx.nn.sequential_module(seq)
}
