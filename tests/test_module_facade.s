package neurx.tests.test_module_facade
use neurx.tensor.tensor
use neurx.module
use neurx.module.state_dict
use neurx.nn
func test_module_facade_basic() bool {
    tensor weight = neurx.tensor.new([1.0, 2.0, 3.0, 4.0], [2, 2], true)
    tensor bias = neurx.tensor.new([0.1, 0.2], [2], true)
    nn.module root = neurx.module.module_new("root")
    root = neurx.module.module_add_parameter(root, "weight", weight)
    root = neurx.module.module_add_buffer(root, "running_mean", bias)
    nn.module child = neurx.module.module_new("child")
    child = neurx.module.module_add_parameter(child, "bias", bias)
    root = neurx.module.module_add_child(root, "linear", child)
    if neurx.module.module_parameter_count(root) != 2 {
        return false
    }
    if neurx.module.module_buffer_count(root) != 1 {
        return false
    }
    if neurx.module.module_child_count(root) != 1 {
        return false
    }
    []string names = neurx.module.module_named_parameters(root)
    if len(names) != 2 {
        return false
    }
    if names[0] != "weight" {
        return false
    }
    if names[1] != "linear.bias" {
        return false
    }
    state_dict.module_state state = neurx.module.state_dict.module_state_dict(root)
    nn.module loaded = neurx.module.module_load_state_dict(neurx.module.module_new("empty"), state.root)
    if neurx.module.module_parameter_count(loaded) != 2 {
        return false
    }
    nn.module frozen = neurx.module.module_freeze(loaded)
    []tensor params = neurx.module.module_parameters(frozen)
    int i = 0
    while i < len(params) {
        if params[i].requires_grad {
            return false
        }
        i = i + 1
    }
    nn.module train_mode = neurx.module.module_train(frozen)
    nn.module eval_mode = neurx.module.module_eval(train_mode)
    return train_mode.training && !eval_mode.training
}

