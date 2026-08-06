package neurx.nn.containers

struct sequential_module {
    []string layer_names
    []string layer_types
    int num_layers
}

func new_sequential() sequential_module {
    sequential_module {
        layer_names: make([]string, 0),
        layer_types: make([]string, 0),
        num_layers: 0,
    }
}

func sequential_add_layer(sequential_module seq, string name, string layer_type) sequential_module {
    seq.layer_names = append(seq.layer_names, name)
    seq.layer_types = append(seq.layer_types, layer_type)
    seq.num_layers = seq.num_layers + 1
    return seq
}

func sequential_get_layer_index(sequential_module seq, string name) int {
    int i = 0
    while i < len(seq.layer_names) {
        if seq.layer_names[i] == name {
            return i
        }
        i = i + 1
    }
    return -1
}

struct module_list {
    []string module_names
    []string module_types
    int num_modules
}

func new_module_list() module_list {
    module_list {
        module_names: make([]string, 0),
        module_types: make([]string, 0),
        num_modules: 0,
    }
}

func module_list_append(module_list ml, string name, string module_type) module_list {
    ml.module_names = append(ml.module_names, name)
    ml.module_types = append(ml.module_types, module_type)
    ml.num_modules = ml.num_modules + 1
    return ml
}

func module_list_get_module(module_list ml, int index) string {
    if index < 0 {
        return ""
    }
    if index >= len(ml.module_names) {
        return ""
    }
    return ml.module_names[index]
}

struct module_dict {
    []string module_keys
    []string module_types
    int num_modules
}

func new_module_dict() module_dict {
    module_dict {
        module_keys: make([]string, 0),
        module_types: make([]string, 0),
        num_modules: 0,
    }
}

func module_dict_add(module_dict md, string key, string module_type) module_dict {
    int idx = module_dict_index_of(md, key)
    if idx >= 0 {
        md.module_types[idx] = module_type
        return md
    }
    md.module_keys = append(md.module_keys, key)
    md.module_types = append(md.module_types, module_type)
    md.num_modules = md.num_modules + 1
    return md
}

func module_dict_get(module_dict md, string key) string {
    int idx = module_dict_index_of(md, key)
    if idx < 0 {
        return ""
    }
    return md.module_types[idx]
}

func module_dict_index_of(module_dict md, string key) int {
    int i = 0
    while i < len(md.module_keys) {
        if md.module_keys[i] == key {
            return i
        }
        i = i + 1
    }
    return -1
}
