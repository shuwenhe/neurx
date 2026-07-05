package neurx.nn

use neurx.tensor.tensor
use neurx.nn.conv

struct parameter {
    tensor value
    string name
    bool trainable
}

struct module {
    string name
    bool training
    []parameter parameters
    []string parameter_names
    []tensor buffers
    []string buffer_names
    []module children
    []string child_names
}

struct parameter_list {
    []parameter items
}

struct module_list {
    []module items
}

struct sequential {
    module root
}

struct embedding_layer {
    int vocab_size
    int embedding_dim
    int padding_idx
    tensor weight
    bool trainable
}

struct layer_norm_layer {
    int normalized_dims
    float eps
    tensor weight
    tensor bias
    bool trainable
}

struct rms_norm_layer {
    int normalized_dims
    float eps
    tensor weight
    tensor bias
    bool trainable
}

struct batch_norm_layer {
    int num_features
    float eps
    float momentum
    tensor weight
    tensor bias
    tensor running_mean
    tensor running_var
    bool training
    bool track_running_stats
}

struct sync_batch_norm_layer {
    int num_features
    float eps
    float momentum
    int world_size
    int rank
    tensor weight
    tensor bias
    tensor running_mean
    tensor running_var
    bool training
    bool track_running_stats
}

struct group_norm_layer {
    int num_groups
    int num_channels
    float eps
    tensor weight
    tensor bias
    bool trainable
}

struct instance_norm_layer {
    int num_features
    float eps
    float momentum
    tensor weight
    tensor bias
    tensor running_mean
    tensor running_var
    bool training
    bool track_running_stats
}

struct conv1d_layer {
    neurx.nn.conv.conv1d_state state
}

struct conv2d_layer {
    neurx.nn.conv.conv2d_state state
}

struct convtranspose1d_layer {
    neurx.nn.conv.convtranspose1d_state state
}

struct convtranspose2d_layer {
    neurx.nn.conv.convtranspose2d_state state
}

struct dropout_layer {
    float p
    bool training
}

struct alpha_dropout_layer {
    float p
    bool training
}

struct lazy_linear_layer {
    int out_features
    bool use_bias
    bool initialized
    linear layer
}

struct lazy_conv1d_layer {
    int out_channels
    int kernel_size
    int stride
    int padding
    int dilation
    bool use_bias
    bool initialized
    conv1d_layer layer
}

struct lazy_conv2d_layer {
    int out_channels
    int kernel_h
    int kernel_w
    int stride_h
    int stride_w
    int pad_h
    int pad_w
    int dil_h
    int dil_w
    bool use_bias
    bool initialized
    conv2d_layer layer
}

struct parameter_dict {
    []string keys
    []parameter values
}

struct module_dict {
    []string keys
    []module values
}

func copy_parameter(parameter p) parameter {
    parameter {
        value: neurx.tensor.clone(p.value),
        name: p.name,
        trainable: p.trainable,
    }
}

func copy_parameters([]parameter params) []parameter {
    []parameter out = []parameter{cap: len(params)}
    int i = 0
    while i < len(params) {
        out[i] = copy_parameter(params[i])
        i = i + 1
    }
    return out
}

func copy_tensors([]tensor values) []tensor {
    []tensor out = []tensor{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = neurx.tensor.clone(values[i])
        i = i + 1
    }
    return out
}

func copy_modules([]module children) []module {
    []module out = []module{cap: len(children)}
    int i = 0
    while i < len(children) {
        out[i] = module_state_dict(children[i])
        i = i + 1
    }
    return out
}

func new_parameter(tensor value, string name) parameter {
    parameter {
        value: neurx.tensor.requires_grad_(value, true),
        name: name,
        trainable: true,
    }
}

func parameter_tensor(parameter p) tensor {
    return p.value
}

func parameter_state_dict(parameter p) parameter {
    return copy_parameter(p)
}

func parameter_load_state_dict(parameter p, parameter other) parameter {
    return copy_parameter(other)
}

func new_module(string name) module {
    module {
        name: name,
        training: true,
        parameters: []parameter{cap: 0},
        parameter_names: []string{cap: 0},
        buffers: []tensor{cap: 0},
        buffer_names: []string{cap: 0},
        children: []module{cap: 0},
        child_names: []string{cap: 0},
    }
}

func module_train(module m) module {
    module next = module_state_dict(m)
    next.training = true
    int i = 0
    while i < len(next.children) {
        next.children[i] = module_train(next.children[i])
        i = i + 1
    }
    return next
}

func module_eval(module m) module {
    module next = module_state_dict(m)
    next.training = false
    int i = 0
    while i < len(next.children) {
        next.children[i] = module_eval(next.children[i])
        i = i + 1
    }
    return next
}

func module_register_parameter(module m, string name, parameter p) module {
    module next = module_state_dict(m)
    int i = 0
    bool replaced = false
    while i < len(next.parameter_names) {
        if next.parameter_names[i] == name {
            next.parameters[i] = copy_parameter(p)
            replaced = true
        }
        i = i + 1
    }
    if !replaced {
        next.parameter_names.push(name)
        next.parameters.push(copy_parameter(p))
    }
    return next
}

func module_register_buffer(module m, string name, tensor value) module {
    module next = module_state_dict(m)
    int i = 0
    bool replaced = false
    while i < len(next.buffer_names) {
        if next.buffer_names[i] == name {
            next.buffers[i] = neurx.tensor.clone(value)
            replaced = true
        }
        i = i + 1
    }
    if !replaced {
        next.buffer_names.push(name)
        next.buffers.push(neurx.tensor.clone(value))
    }
    return next
}

func module_register_child(module m, string name, module child) module {
    module next = module_state_dict(m)
    int i = 0
    bool replaced = false
    while i < len(next.child_names) {
        if next.child_names[i] == name {
            next.children[i] = module_state_dict(child)
            replaced = true
        }
        i = i + 1
    }
    if !replaced {
        next.child_names.push(name)
        next.children.push(module_state_dict(child))
    }
    return next
}

func module_parameters(module m) []tensor {
    []tensor out = []tensor{cap: 0}
    int i = 0
    while i < len(m.parameters) {
        out.push(parameter_tensor(m.parameters[i]))
        i = i + 1
    }
    int j = 0
    while j < len(m.children) {
        []tensor child_params = module_parameters(m.children[j])
        int k = 0
        while k < len(child_params) {
            out.push(child_params[k])
            k = k + 1
        }
        j = j + 1
    }
    return out
}

func module_buffers(module m) []tensor {
    return copy_tensors(m.buffers)
}

func module_children(module m) []module {
    return copy_modules(m.children)
}

func module_state_dict(module m) module {
    return module {
        name: m.name,
        training: m.training,
        parameters: copy_parameters(m.parameters),
        parameter_names: copy_strings(m.parameter_names),
        buffers: copy_tensors(m.buffers),
        buffer_names: copy_strings(m.buffer_names),
        children: copy_modules(m.children),
        child_names: copy_strings(m.child_names),
    }
}

func module_load_state_dict(module m, module other) module {
    return module {
        name: other.name,
        training: other.training,
        parameters: copy_parameters(other.parameters),
        parameter_names: copy_strings(other.parameter_names),
        buffers: copy_tensors(other.buffers),
        buffer_names: copy_strings(other.buffer_names),
        children: copy_modules(other.children),
        child_names: copy_strings(other.child_names),
    }
}

func module_parameter_count(module m) int {
    int count = len(m.parameters)
    int i = 0
    while i < len(m.children) {
        count = count + module_parameter_count(m.children[i])
        i = i + 1
    }
    return count
}

func module_buffer_count(module m) int {
    return len(m.buffers)
}

func module_child_count(module m) int {
    return len(m.children)
}

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    return out
}

func linear_as_module(linear layer) module {
    module m = new_module("linear")
    tensor weight = neurx.tensor.new(copy_float(layer.weight), shape2(layer.in_features, layer.out_features), true)
    m = module_register_parameter(m, "weight", new_parameter(weight, "weight"))
    if layer.has_bias {
        tensor bias = neurx.tensor.new(copy_float(layer.bias), shape1(layer.out_features), true)
        m = module_register_parameter(m, "bias", new_parameter(bias, "bias"))
    }
    return m
}

func module_first_parameter(module m) tensor {
    if len(m.parameters) > 0 {
        return parameter_tensor(m.parameters[0])
    }
    int i = 0
    while i < len(m.children) {
        tensor child_first = module_first_parameter(m.children[i])
        if len(child_first.data) > 0 {
            return child_first
        }
        i = i + 1
    }
    []float empty_data = []float{cap: 0}
    []int empty_shape = []int{cap: 1}
    empty_shape[0] = 0
    return neurx.tensor.new(empty_data, empty_shape, false)
}

func module_named_parameters(module m) []string {
    []string names = copy_strings(m.parameter_names)
    int i = 0
    while i < len(m.children) {
        []string child_names = module_named_parameters(m.children[i])
        int j = 0
        while j < len(child_names) {
            names.push(m.child_names[i] + "." + child_names[j])
            j = j + 1
        }
        i = i + 1
    }
    return names
}

func module_named_buffers(module m) []string {
    []string names = copy_strings(m.buffer_names)
    int i = 0
    while i < len(m.children) {
        []string child_names = module_named_buffers(m.children[i])
        int j = 0
        while j < len(child_names) {
            names.push(m.child_names[i] + "." + child_names[j])
            j = j + 1
        }
        i = i + 1
    }
    return names
}

func module_named_children(module m) []string {
    return copy_strings(m.child_names)
}

func module_add_parameter(module m, string name, tensor value) module {
    return module_register_parameter(m, name, new_parameter(value, name))
}

func module_add_buffer(module m, string name, tensor value) module {
    return module_register_buffer(m, name, value)
}

func module_add_child(module m, string name, module child) module {
    return module_register_child(m, name, child)
}

func module_find_parameter_index(module m, string name) int {
    int i = 0
    while i < len(m.parameter_names) {
        if m.parameter_names[i] == name {
            return i
        }
        i = i + 1
    }
    return -1
}

func module_find_buffer_index(module m, string name) int {
    int i = 0
    while i < len(m.buffer_names) {
        if m.buffer_names[i] == name {
            return i
        }
        i = i + 1
    }
    return -1
}

func module_find_child_index(module m, string name) int {
    int i = 0
    while i < len(m.child_names) {
        if m.child_names[i] == name {
            return i
        }
        i = i + 1
    }
    return -1
}

func module_get_parameter(module m, string name) tensor {
    int index = module_find_parameter_index(m, name)
    if index < 0 {
        []float empty_data = []float{cap: 0}
        []int empty_shape = []int{cap: 1}
        empty_shape[0] = 0
        return neurx.tensor.new(empty_data, empty_shape, false)
    }
    return parameter_tensor(m.parameters[index])
}

func module_get_buffer(module m, string name) tensor {
    int index = module_find_buffer_index(m, name)
    if index < 0 {
        []float empty_data = []float{cap: 0}
        []int empty_shape = []int{cap: 1}
        empty_shape[0] = 0
        return neurx.tensor.new(empty_data, empty_shape, false)
    }
    return m.buffers[index]
}

func module_get_child(module m, string name) module {
    int index = module_find_child_index(m, name)
    if index < 0 {
        return new_module(name)
    }
    return module_state_dict(m.children[index])
}

func module_has_parameter(module m, string name) bool {
    return module_find_parameter_index(m, name) >= 0
}

func module_has_buffer(module m, string name) bool {
    return module_find_buffer_index(m, name) >= 0
}

func module_has_child(module m, string name) bool {
    return module_find_child_index(m, name) >= 0
}

func module_set_trainable(module m, bool trainable) module {
    module next = module_state_dict(m)
    int i = 0
    while i < len(next.parameters) {
        next.parameters[i].trainable = trainable
        next.parameters[i].value = neurx.tensor.requires_grad_(next.parameters[i].value, trainable)
        i = i + 1
    }
    i = 0
    while i < len(next.children) {
        next.children[i] = module_set_trainable(next.children[i], trainable)
        i = i + 1
    }
    return next
}

func new_parameter_list() parameter_list {
    parameter_list {
        items: []parameter{cap: 0},
    }
}

func parameter_list_append(parameter_list plist, parameter p) parameter_list {
    parameter_list next = parameter_list_state_dict(plist)
    next.items.push(copy_parameter(p))
    return next
}

func parameter_list_state_dict(parameter_list plist) parameter_list {
    return parameter_list {
        items: copy_parameters(plist.items),
    }
}

func parameter_list_load_state_dict(parameter_list plist, parameter_list other) parameter_list {
    return parameter_list {
        items: copy_parameters(other.items),
    }
}

func parameter_list_tensors(parameter_list plist) []tensor {
    []tensor out = []tensor{cap: len(plist.items)}
    int i = 0
    while i < len(plist.items) {
        out[i] = parameter_tensor(plist.items[i])
        i = i + 1
    }
    return out
}

func parameter_list_names(parameter_list plist) []string {
    []string out = []string{cap: len(plist.items)}
    int i = 0
    while i < len(plist.items) {
        out[i] = plist.items[i].name
        i = i + 1
    }
    return out
}

func new_module_list() module_list {
    module_list {
        items: []module{cap: 0},
    }
}

func module_list_append(module_list list, module child) module_list {
    module_list next = module_list_state_dict(list)
    next.items.push(module_state_dict(child))
    return next
}

func module_list_state_dict(module_list list) module_list {
    return module_list {
        items: copy_modules(list.items),
    }
}

func module_list_load_state_dict(module_list list, module_list other) module_list {
    return module_list {
        items: copy_modules(other.items),
    }
}

func module_list_names(module_list list) []string {
    []string out = []string{cap: len(list.items)}
    int i = 0
    while i < len(list.items) {
        out[i] = list.items[i].name
        i = i + 1
    }
    return out
}

func parameter_list_get(parameter_list plist, int index) parameter {
    if index < 0 || index >= len(plist.items) {
        return new_parameter(neurx.tensor.new([]float{cap: 0}, []int{cap: 1}, false), "")
    }
    return copy_parameter(plist.items[index])
}

func module_list_get(module_list list, int index) module {
    if index < 0 || index >= len(list.items) {
        return new_module("empty")
    }
    return module_state_dict(list.items[index])
}

func module_int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    int n = value
    bool negative = false
    if n < 0 {
        negative = true
        n = 0 - n
    }
    string out = ""
    while n > 0 {
        int digit = n - (n / 10) * 10
        out = string(digit + 48) + out
        n = n / 10
    }
    if negative {
        out = "-" + out
    }
    return out
}

func sequential_new() sequential {
    sequential {
        root: new_module("sequential"),
    }
}

func sequential_from_modules([]module layers) sequential {
    sequential seq = sequential_new()
    int i = 0
    while i < len(layers) {
        seq.root = module_add_child(seq.root, "layer_" + module_int_to_string(i), layers[i])
        i = i + 1
    }
    return seq
}

func sequential_module(sequential seq) module {
    return module_state_dict(seq.root)
}

func sequential_add(sequential seq, module child) sequential {
    sequential next = sequential {
        root: module_state_dict(seq.root),
    }
    next.root = module_add_child(next.root, "layer_" + module_int_to_string(len(next.root.children)), child)
    return next
}

func identity_module() module {
    return new_module("identity")
}

func flatten_module() module {
    return new_module("flatten")
}

func new_embedding_layer(int vocab_size, int embedding_dim, int padding_idx) embedding_layer {
    int total = vocab_size * embedding_dim
    []float weight_data = []float{cap: total}
    int i = 0
    while i < total {
        weight_data[i] = 0.0
        i = i + 1
    }
    return embedding_layer {
        vocab_size: vocab_size,
        embedding_dim: embedding_dim,
        padding_idx: padding_idx,
        weight: neurx.tensor.new(weight_data, shape2(vocab_size, embedding_dim), true),
        trainable: true,
    }
}

func embedding_layer_forward(embedding_layer layer, tensor input_ids) tensor {
    return embedding_lookup(layer.weight, input_ids, layer.padding_idx)
}

func embedding_layer_state_dict(embedding_layer layer) embedding_layer {
    return embedding_layer {
        vocab_size: layer.vocab_size,
        embedding_dim: layer.embedding_dim,
        padding_idx: layer.padding_idx,
        weight: neurx.tensor.clone(layer.weight),
        trainable: layer.trainable,
    }
}

func embedding_layer_load_state_dict(embedding_layer layer, embedding_layer other) embedding_layer {
    return embedding_layer_state_dict(other)
}

func embedding_layer_module(embedding_layer layer) module {
    module m = new_module("embedding")
    m = module_add_parameter(m, "weight", layer.weight)
    return m
}

func embedding_layer_train(embedding_layer layer) embedding_layer {
    return embedding_layer_state_dict(layer)
}

func embedding_layer_eval(embedding_layer layer) embedding_layer {
    return embedding_layer_state_dict(layer)
}

func new_layer_norm_layer(int normalized_dims, float eps, int hidden_size) layer_norm_layer {
    []float weight_data = []float{cap: hidden_size}
    []float bias_data = []float{cap: hidden_size}
    int i = 0
    while i < hidden_size {
        weight_data[i] = 1.0
        bias_data[i] = 0.0
        i = i + 1
    }
    return layer_norm_layer {
        normalized_dims: normalized_dims,
        eps: eps,
        weight: neurx.tensor.new(weight_data, shape1(hidden_size), true),
        bias: neurx.tensor.new(bias_data, shape1(hidden_size), true),
        trainable: true,
    }
}

func layer_norm_layer_forward(layer_norm_layer layer, tensor input) tensor {
    return layer_norm(input, layer.weight, layer.bias, layer.normalized_dims, layer.eps)
}

func layer_norm_layer_state_dict(layer_norm_layer layer) layer_norm_layer {
    return layer_norm_layer {
        normalized_dims: layer.normalized_dims,
        eps: layer.eps,
        weight: neurx.tensor.clone(layer.weight),
        bias: neurx.tensor.clone(layer.bias),
        trainable: layer.trainable,
    }
}

func layer_norm_layer_module(layer_norm_layer layer) module {
    module m = new_module("layer_norm")
    m = module_add_parameter(m, "weight", layer.weight)
    m = module_add_parameter(m, "bias", layer.bias)
    return m
}

func layer_norm_layer_train(layer_norm_layer layer) layer_norm_layer {
    return layer_norm_layer_state_dict(layer)
}

func layer_norm_layer_eval(layer_norm_layer layer) layer_norm_layer {
    return layer_norm_layer_state_dict(layer)
}

func new_rms_norm_layer(int normalized_dims, float eps, int hidden_size) rms_norm_layer {
    []float weight_data = []float{cap: hidden_size}
    []float bias_data = []float{cap: hidden_size}
    int i = 0
    while i < hidden_size {
        weight_data[i] = 1.0
        bias_data[i] = 0.0
        i = i + 1
    }
    return rms_norm_layer {
        normalized_dims: normalized_dims,
        eps: eps,
        weight: neurx.tensor.new(weight_data, shape1(hidden_size), true),
        bias: neurx.tensor.new(bias_data, shape1(hidden_size), true),
        trainable: true,
    }
}

func rms_norm_layer_forward(rms_norm_layer layer, tensor input) tensor {
    return rms_norm(input, layer.weight, layer.bias, layer.normalized_dims, layer.eps)
}

func rms_norm_layer_state_dict(rms_norm_layer layer) rms_norm_layer {
    return rms_norm_layer {
        normalized_dims: layer.normalized_dims,
        eps: layer.eps,
        weight: neurx.tensor.clone(layer.weight),
        bias: neurx.tensor.clone(layer.bias),
        trainable: layer.trainable,
    }
}

func rms_norm_layer_module(rms_norm_layer layer) module {
    module m = new_module("rms_norm")
    m = module_add_parameter(m, "weight", layer.weight)
    m = module_add_parameter(m, "bias", layer.bias)
    return m
}

func rms_norm_layer_train(rms_norm_layer layer) rms_norm_layer {
    return rms_norm_layer_state_dict(layer)
}

func rms_norm_layer_eval(rms_norm_layer layer) rms_norm_layer {
    return rms_norm_layer_state_dict(layer)
}

func new_batch_norm_layer(int num_features, float eps, float momentum, bool track_running_stats) batch_norm_layer {
    []float weight_data = []float{cap: num_features}
    []float bias_data = []float{cap: num_features}
    []float running_mean_data = []float{cap: num_features}
    []float running_var_data = []float{cap: num_features}
    int i = 0
    while i < num_features {
        weight_data[i] = 1.0
        bias_data[i] = 0.0
        running_mean_data[i] = 0.0
        running_var_data[i] = 1.0
        i = i + 1
    }
    return batch_norm_layer {
        num_features: num_features,
        eps: eps,
        momentum: momentum,
        weight: neurx.tensor.new(weight_data, shape1(num_features), true),
        bias: neurx.tensor.new(bias_data, shape1(num_features), true),
        running_mean: neurx.tensor.new(running_mean_data, shape1(num_features), false),
        running_var: neurx.tensor.new(running_var_data, shape1(num_features), false),
        training: true,
        track_running_stats: track_running_stats,
    }
}

func batch_norm_layer_forward(batch_norm_layer layer, tensor input) tensor {
    return batch_norm(input, layer.weight, layer.bias, layer.running_mean, layer.running_var, layer.training, layer.eps)
}

func batch_norm_layer_state_dict(batch_norm_layer layer) batch_norm_layer {
    return batch_norm_layer {
        num_features: layer.num_features,
        eps: layer.eps,
        momentum: layer.momentum,
        weight: neurx.tensor.clone(layer.weight),
        bias: neurx.tensor.clone(layer.bias),
        running_mean: neurx.tensor.clone(layer.running_mean),
        running_var: neurx.tensor.clone(layer.running_var),
        training: layer.training,
        track_running_stats: layer.track_running_stats,
    }
}

func batch_norm_layer_module(batch_norm_layer layer) module {
    module m = new_module("batch_norm")
    m = module_add_parameter(m, "weight", layer.weight)
    m = module_add_parameter(m, "bias", layer.bias)
    m = module_add_buffer(m, "running_mean", layer.running_mean)
    m = module_add_buffer(m, "running_var", layer.running_var)
    return m
}

func batch_norm_layer_train(batch_norm_layer layer) batch_norm_layer {
    batch_norm_layer next = batch_norm_layer_state_dict(layer)
    next.training = true
    return next
}

func batch_norm_layer_eval(batch_norm_layer layer) batch_norm_layer {
    batch_norm_layer next = batch_norm_layer_state_dict(layer)
    next.training = false
    return next
}

func new_sync_batch_norm_layer(int num_features, float eps, float momentum, int world_size, int rank, bool track_running_stats) sync_batch_norm_layer {
    []float weight_data = []float{cap: num_features}
    []float bias_data = []float{cap: num_features}
    []float running_mean_data = []float{cap: num_features}
    []float running_var_data = []float{cap: num_features}
    int i = 0
    while i < num_features {
        weight_data[i] = 1.0
        bias_data[i] = 0.0
        running_mean_data[i] = 0.0
        running_var_data[i] = 1.0
        i = i + 1
    }
    return sync_batch_norm_layer {
        num_features: num_features,
        eps: eps,
        momentum: momentum,
        world_size: world_size,
        rank: rank,
        weight: neurx.tensor.new(weight_data, shape1(num_features), true),
        bias: neurx.tensor.new(bias_data, shape1(num_features), true),
        running_mean: neurx.tensor.new(running_mean_data, shape1(num_features), false),
        running_var: neurx.tensor.new(running_var_data, shape1(num_features), false),
        training: true,
        track_running_stats: track_running_stats,
    }
}

func sync_batch_norm_layer_forward(sync_batch_norm_layer layer, tensor input) tensor {
    return sync_batch_norm(input, layer.weight, layer.bias, layer.running_mean, layer.running_var, layer.training, layer.eps, layer.world_size, layer.rank)
}

func sync_batch_norm_layer_state_dict(sync_batch_norm_layer layer) sync_batch_norm_layer {
    return sync_batch_norm_layer {
        num_features: layer.num_features,
        eps: layer.eps,
        momentum: layer.momentum,
        world_size: layer.world_size,
        rank: layer.rank,
        weight: neurx.tensor.clone(layer.weight),
        bias: neurx.tensor.clone(layer.bias),
        running_mean: neurx.tensor.clone(layer.running_mean),
        running_var: neurx.tensor.clone(layer.running_var),
        training: layer.training,
        track_running_stats: layer.track_running_stats,
    }
}

func sync_batch_norm_layer_module(sync_batch_norm_layer layer) module {
    module m = new_module("sync_batch_norm")
    m = module_add_parameter(m, "weight", layer.weight)
    m = module_add_parameter(m, "bias", layer.bias)
    m = module_add_buffer(m, "running_mean", layer.running_mean)
    m = module_add_buffer(m, "running_var", layer.running_var)
    return m
}

func sync_batch_norm_layer_train(sync_batch_norm_layer layer) sync_batch_norm_layer {
    sync_batch_norm_layer next = sync_batch_norm_layer_state_dict(layer)
    next.training = true
    return next
}

func sync_batch_norm_layer_eval(sync_batch_norm_layer layer) sync_batch_norm_layer {
    sync_batch_norm_layer next = sync_batch_norm_layer_state_dict(layer)
    next.training = false
    return next
}

func new_group_norm_layer(int num_groups, int num_channels, float eps) group_norm_layer {
    []float weight_data = []float{cap: num_channels}
    []float bias_data = []float{cap: num_channels}
    int i = 0
    while i < num_channels {
        weight_data[i] = 1.0
        bias_data[i] = 0.0
        i = i + 1
    }
    return group_norm_layer {
        num_groups: num_groups,
        num_channels: num_channels,
        eps: eps,
        weight: neurx.tensor.new(weight_data, shape1(num_channels), true),
        bias: neurx.tensor.new(bias_data, shape1(num_channels), true),
        trainable: true,
    }
}

func group_norm_layer_forward(group_norm_layer layer, tensor input) tensor {
    return group_norm(input, layer.weight, layer.bias, layer.num_groups, layer.eps)
}

func group_norm_layer_state_dict(group_norm_layer layer) group_norm_layer {
    return group_norm_layer {
        num_groups: layer.num_groups,
        num_channels: layer.num_channels,
        eps: layer.eps,
        weight: neurx.tensor.clone(layer.weight),
        bias: neurx.tensor.clone(layer.bias),
        trainable: layer.trainable,
    }
}

func group_norm_layer_module(group_norm_layer layer) module {
    module m = new_module("group_norm")
    m = module_add_parameter(m, "weight", layer.weight)
    m = module_add_parameter(m, "bias", layer.bias)
    return m
}

func new_instance_norm_layer(int num_features, float eps, float momentum, bool track_running_stats) instance_norm_layer {
    []float weight_data = []float{cap: num_features}
    []float bias_data = []float{cap: num_features}
    []float running_mean_data = []float{cap: num_features}
    []float running_var_data = []float{cap: num_features}
    int i = 0
    while i < num_features {
        weight_data[i] = 1.0
        bias_data[i] = 0.0
        running_mean_data[i] = 0.0
        running_var_data[i] = 1.0
        i = i + 1
    }
    return instance_norm_layer {
        num_features: num_features,
        eps: eps,
        momentum: momentum,
        weight: neurx.tensor.new(weight_data, shape1(num_features), true),
        bias: neurx.tensor.new(bias_data, shape1(num_features), true),
        running_mean: neurx.tensor.new(running_mean_data, shape1(num_features), false),
        running_var: neurx.tensor.new(running_var_data, shape1(num_features), false),
        training: true,
        track_running_stats: track_running_stats,
    }
}

func instance_norm_layer_forward(instance_norm_layer layer, tensor input) tensor {
    return instance_norm(input, layer.weight, layer.bias, layer.eps)
}

func instance_norm_layer_state_dict(instance_norm_layer layer) instance_norm_layer {
    return instance_norm_layer {
        num_features: layer.num_features,
        eps: layer.eps,
        momentum: layer.momentum,
        weight: neurx.tensor.clone(layer.weight),
        bias: neurx.tensor.clone(layer.bias),
        running_mean: neurx.tensor.clone(layer.running_mean),
        running_var: neurx.tensor.clone(layer.running_var),
        training: layer.training,
        track_running_stats: layer.track_running_stats,
    }
}

func instance_norm_layer_module(instance_norm_layer layer) module {
    module m = new_module("instance_norm")
    m = module_add_parameter(m, "weight", layer.weight)
    m = module_add_parameter(m, "bias", layer.bias)
    m = module_add_buffer(m, "running_mean", layer.running_mean)
    m = module_add_buffer(m, "running_var", layer.running_var)
    return m
}

func group_norm_layer_train(group_norm_layer layer) group_norm_layer {
    return group_norm_layer_state_dict(layer)
}

func group_norm_layer_eval(group_norm_layer layer) group_norm_layer {
    return group_norm_layer_state_dict(layer)
}

func instance_norm_layer_train(instance_norm_layer layer) instance_norm_layer {
    instance_norm_layer next = instance_norm_layer_state_dict(layer)
    next.training = true
    return next
}

func instance_norm_layer_eval(instance_norm_layer layer) instance_norm_layer {
    instance_norm_layer next = instance_norm_layer_state_dict(layer)
    next.training = false
    return next
}

func new_conv1d_layer(int in_channels, int out_channels, int kernel_size, int stride, int padding, int dilation, bool use_bias) conv1d_layer {
    return conv1d_layer {
        state: neurx.nn.conv.new_conv1d(in_channels, out_channels, kernel_size, stride, padding, dilation, use_bias),
    }
}

func conv1d_layer_forward(conv1d_layer layer, tensor input) tensor {
    return neurx.nn.conv.conv1d_forward(layer.state, input)
}

func conv1d_layer_state_dict(conv1d_layer layer) conv1d_layer {
    return conv1d_layer {
        state: layer.state,
    }
}

func conv1d_layer_module(conv1d_layer layer) module {
    module m = new_module("conv1d")
    return m
}

func new_conv2d_layer(int in_channels, int out_channels, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w, int dil_h, int dil_w, bool use_bias) conv2d_layer {
    return conv2d_layer {
        state: neurx.nn.conv.new_conv2d(in_channels, out_channels, kernel_h, kernel_w, stride_h, stride_w, pad_h, pad_w, dil_h, dil_w, use_bias),
    }
}

func conv2d_layer_forward(conv2d_layer layer, tensor input) tensor {
    return neurx.nn.conv.conv2d_forward(layer.state, input)
}

func conv2d_layer_state_dict(conv2d_layer layer) conv2d_layer {
    return conv2d_layer {
        state: layer.state,
    }
}

func conv2d_layer_module(conv2d_layer layer) module {
    module m = new_module("conv2d")
    return m
}

func new_convtranspose1d_layer(int in_channels, int out_channels, int kernel_size, int stride, int padding, int output_padding, int dilation, bool use_bias) convtranspose1d_layer {
    return convtranspose1d_layer {
        state: neurx.nn.conv.new_convtranspose1d(in_channels, out_channels, kernel_size, stride, padding, output_padding, dilation, use_bias),
    }
}

func convtranspose1d_layer_forward(convtranspose1d_layer layer, tensor input) tensor {
    return neurx.nn.conv.convtranspose1d_forward(layer.state, input)
}

func convtranspose1d_layer_state_dict(convtranspose1d_layer layer) convtranspose1d_layer {
    return convtranspose1d_layer {
        state: layer.state,
    }
}

func convtranspose1d_layer_module(convtranspose1d_layer layer) module {
    module m = new_module("convtranspose1d")
    return m
}

func new_convtranspose2d_layer(int in_channels, int out_channels, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w, int output_pad_h, int output_pad_w, int dil_h, int dil_w, bool use_bias) convtranspose2d_layer {
    return convtranspose2d_layer {
        state: neurx.nn.conv.new_convtranspose2d(in_channels, out_channels, kernel_h, kernel_w, stride_h, stride_w, pad_h, pad_w, output_pad_h, output_pad_w, dil_h, dil_w, use_bias),
    }
}

func convtranspose2d_layer_forward(convtranspose2d_layer layer, tensor input) tensor {
    return neurx.nn.conv.convtranspose2d_forward(layer.state, input)
}

func convtranspose2d_layer_state_dict(convtranspose2d_layer layer) convtranspose2d_layer {
    return convtranspose2d_layer {
        state: layer.state,
    }
}

func convtranspose2d_layer_module(convtranspose2d_layer layer) module {
    module m = new_module("convtranspose2d")
    return m
}

func new_dropout_layer(float p) dropout_layer {
    return dropout_layer {
        p: p,
        training: true,
    }
}

func dropout_layer_forward(dropout_layer layer, tensor input) tensor {
    return dropout(input, layer.p, layer.training)
}

func dropout_layer_state_dict(dropout_layer layer) dropout_layer {
    return dropout_layer {
        p: layer.p,
        training: layer.training,
    }
}

func dropout_layer_module(dropout_layer layer) module {
    return new_module("dropout")
}

func dropout_layer_train(dropout_layer layer) dropout_layer {
    dropout_layer next = dropout_layer_state_dict(layer)
    next.training = true
    return next
}

func dropout_layer_eval(dropout_layer layer) dropout_layer {
    dropout_layer next = dropout_layer_state_dict(layer)
    next.training = false
    return next
}

func new_alpha_dropout_layer(float p) alpha_dropout_layer {
    return alpha_dropout_layer {
        p: p,
        training: true,
    }
}

func alpha_dropout_layer_forward(alpha_dropout_layer layer, tensor input) tensor {
    return alpha_dropout(input, layer.p, layer.training)
}

func alpha_dropout_layer_state_dict(alpha_dropout_layer layer) alpha_dropout_layer {
    return alpha_dropout_layer {
        p: layer.p,
        training: layer.training,
    }
}

func alpha_dropout_layer_module(alpha_dropout_layer layer) module {
    return new_module("alpha_dropout")
}

func alpha_dropout_layer_train(alpha_dropout_layer layer) alpha_dropout_layer {
    alpha_dropout_layer next = alpha_dropout_layer_state_dict(layer)
    next.training = true
    return next
}

func alpha_dropout_layer_eval(alpha_dropout_layer layer) alpha_dropout_layer {
    alpha_dropout_layer next = alpha_dropout_layer_state_dict(layer)
    next.training = false
    return next
}

func new_parameter_dict() parameter_dict {
    return parameter_dict {
        keys: []string{cap: 0},
        values: []parameter{cap: 0},
    }
}

func parameter_dict_find(parameter_dict dict, string key) int {
    int i = 0
    while i < len(dict.keys) {
        if dict.keys[i] == key {
            return i
        }
        i = i + 1
    }
    return -1
}

func parameter_dict_set(parameter_dict dict, string key, tensor value) parameter_dict {
    parameter_dict next = parameter_dict {
        keys: copy_strings(dict.keys),
        values: copy_parameters(dict.values),
    }
    int index = parameter_dict_find(next, key)
    parameter p = new_parameter(value, key)
    if index >= 0 {
        next.values[index] = p
        return next
    }
    next.keys.push(key)
    next.values.push(p)
    return next
}

func parameter_dict_get(parameter_dict dict, string key) tensor {
    int index = parameter_dict_find(dict, key)
    if index < 0 {
        []float empty_data = []float{cap: 0}
        []int empty_shape = []int{cap: 1}
        empty_shape[0] = 0
        return neurx.tensor.new(empty_data, empty_shape, false)
    }
    return parameter_tensor(dict.values[index])
}

func parameter_dict_has(parameter_dict dict, string key) bool {
    return parameter_dict_find(dict, key) >= 0
}

func parameter_dict_state_dict(parameter_dict dict) parameter_dict {
    return parameter_dict {
        keys: copy_strings(dict.keys),
        values: copy_parameters(dict.values),
    }
}

func parameter_dict_load_state_dict(parameter_dict dict, parameter_dict other) parameter_dict {
    return parameter_dict_state_dict(other)
}

func parameter_dict_keys(parameter_dict dict) []string {
    return copy_strings(dict.keys)
}

func parameter_dict_tensors(parameter_dict dict) []tensor {
    []tensor out = []tensor{cap: len(dict.values)}
    int i = 0
    while i < len(dict.values) {
        out[i] = parameter_tensor(dict.values[i])
        i = i + 1
    }
    return out
}

func new_module_dict() module_dict {
    return module_dict {
        keys: []string{cap: 0},
        values: []module{cap: 0},
    }
}

func module_dict_find(module_dict dict, string key) int {
    int i = 0
    while i < len(dict.keys) {
        if dict.keys[i] == key {
            return i
        }
        i = i + 1
    }
    return -1
}

func module_dict_set(module_dict dict, string key, module value) module_dict {
    module_dict next = module_dict {
        keys: copy_strings(dict.keys),
        values: copy_modules(dict.values),
    }
    int index = module_dict_find(next, key)
    module m = module_state_dict(value)
    if index >= 0 {
        next.values[index] = m
        return next
    }
    next.keys.push(key)
    next.values.push(m)
    return next
}

func module_dict_get(module_dict dict, string key) module {
    int index = module_dict_find(dict, key)
    if index < 0 {
        return new_module(key)
    }
    return module_state_dict(dict.values[index])
}

func module_dict_has(module_dict dict, string key) bool {
    return module_dict_find(dict, key) >= 0
}

func module_dict_state_dict(module_dict dict) module_dict {
    return module_dict {
        keys: copy_strings(dict.keys),
        values: copy_modules(dict.values),
    }
}

func module_dict_load_state_dict(module_dict dict, module_dict other) module_dict {
    return module_dict_state_dict(other)
}

func module_dict_keys(module_dict dict) []string {
    return copy_strings(dict.keys)
}
