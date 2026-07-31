package neurx.module.parameter
use neurx.tensor.tensor
use neurx.nn
func parameter_new(tensor value, string name) nn.parameter {
    neurx.nn.new_parameter(value, name)
}

func parameter_tensor(nn.parameter p) tensor {
    neurx.nn.parameter_tensor(p)
}

func parameter_state_dict(nn.parameter p) nn.parameter {
    neurx.nn.parameter_state_dict(p)
}

func parameter_load_state_dict(nn.parameter p, nn.parameter state) nn.parameter {
    neurx.nn.parameter_load_state_dict(p, state)
}

func parameter_list_new() nn.parameter_list {
    neurx.nn.new_parameter_list()
}

func parameter_list_append(nn.parameter_list list, nn.parameter p) nn.parameter_list {
    neurx.nn.parameter_list_append(list, p)
}

func parameter_list_tensors(nn.parameter_list list) []tensor {
    neurx.nn.parameter_list_tensors(list)
}

func parameter_list_names(nn.parameter_list list) []string {
    neurx.nn.parameter_list_names(list)
}

func parameter_list_get(nn.parameter_list list, int index) nn.parameter {
    neurx.nn.parameter_list_get(list, index)
}

func parameter_list_state_dict(nn.parameter_list list) nn.parameter_list {
    neurx.nn.parameter_list_state_dict(list)
}

func parameter_list_load_state_dict(nn.parameter_list list, nn.parameter_list state) nn.parameter_list {
    neurx.nn.parameter_list_load_state_dict(list, state)
}
