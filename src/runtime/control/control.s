package neurx.runtime.control
use neurx.strings
use neurx.tensor.tensor
use neurx.strings

struct control_state {
    string name
    bool cond_enabled
    bool loop_enabled
    bool scan_enabled
    int iterations
    []string branches
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

func new_control_state(string name, int iterations) control_state {
    control_state {
        name: name,
        cond_enabled: false,
        loop_enabled: false,
        scan_enabled: false,
        iterations: iterations,
        branches: [],
        params: [],
    }
}

func control_name(control_state state) string {
    state.name
}

func control_cond_enabled(control_state state) bool {
    state.cond_enabled
}

func control_loop_enabled(control_state state) bool {
    state.loop_enabled
}

func control_scan_enabled(control_state state) bool {
    state.scan_enabled
}

func control_iterations(control_state state) int {
    state.iterations
}

func control_branch_count(control_state state) int {
    len(state.branches)
}

func control_param_count(control_state state) int {
    len(state.params)
}

func control_has_branch(control_state state, string branch) bool {
    int i = 0
    while i < len(state.branches) {
        if neurx.strings.strings_eq(state.branches[i], branch) {
            return true
        }
        i = i + 1
    }
    false
}

func control_has_param(control_state state, string param) bool {
    int i = 0
    while i < len(state.params) {
        if neurx.strings.strings_eq(state.params[i], param) {
            return true
        }
        i = i + 1
    }
    false
}

func control_add_branch(control_state state, string branch) control_state {
    []string branches = copy_strings(state.branches)
    branches.push(branch)
    control_state {
        name: state.name,
        cond_enabled: true,
        loop_enabled: state.loop_enabled,
        scan_enabled: state.scan_enabled,
        iterations: state.iterations,
        branches: branches,
        params: copy_strings(state.params),
    }
}

func control_add_param(control_state state, string param) control_state {
    []string params = copy_strings(state.params)
    params.push(param)
    control_state {
        name: state.name,
        cond_enabled: state.cond_enabled,
        loop_enabled: state.loop_enabled,
        scan_enabled: state.scan_enabled,
        iterations: state.iterations,
        branches: copy_strings(state.branches),
        params: params,
    }
}

func control_set_cond_enabled(control_state state, bool enabled) control_state {
    control_state {
        name: state.name,
        cond_enabled: enabled,
        loop_enabled: state.loop_enabled,
        scan_enabled: state.scan_enabled,
        iterations: state.iterations,
        branches: copy_strings(state.branches),
        params: copy_strings(state.params),
    }
}

func control_set_loop_enabled(control_state state, bool enabled) control_state {
    control_state {
        name: state.name,
        cond_enabled: state.cond_enabled,
        loop_enabled: enabled,
        scan_enabled: state.scan_enabled,
        iterations: state.iterations,
        branches: copy_strings(state.branches),
        params: copy_strings(state.params),
    }
}

func control_set_scan_enabled(control_state state, bool enabled) control_state {
    control_state {
        name: state.name,
        cond_enabled: state.cond_enabled,
        loop_enabled: state.loop_enabled,
        scan_enabled: enabled,
        iterations: state.iterations,
        branches: copy_strings(state.branches),
        params: copy_strings(state.params),
    }
}

func control_set_iterations(control_state state, int iterations) control_state {
    control_state {
        name: state.name,
        cond_enabled: state.cond_enabled,
        loop_enabled: state.loop_enabled,
        scan_enabled: state.scan_enabled,
        iterations: iterations,
        branches: copy_strings(state.branches),
        params: copy_strings(state.params),
    }
}

func control_clear_branches(control_state state) control_state {
    control_state {
        name: state.name,
        cond_enabled: state.cond_enabled,
        loop_enabled: state.loop_enabled,
        scan_enabled: state.scan_enabled,
        iterations: state.iterations,
        branches: [],
        params: copy_strings(state.params),
    }
}

func control_clear_params(control_state state) control_state {
    control_state {
        name: state.name,
        cond_enabled: state.cond_enabled,
        loop_enabled: state.loop_enabled,
        scan_enabled: state.scan_enabled,
        iterations: state.iterations,
        branches: copy_strings(state.branches),
        params: [],
    }
}

func control_state_dict(control_state state) control_state {
    control_state {
        name: state.name,
        cond_enabled: state.cond_enabled,
        loop_enabled: state.loop_enabled,
        scan_enabled: state.scan_enabled,
        iterations: state.iterations,
        branches: copy_strings(state.branches),
        params: copy_strings(state.params),
    }
}

func control_load_state_dict(control_state state, control_state other) control_state {
    other
}

func cond(control_state state, bool predicate, tensor on_true, tensor on_false) tensor {
    del state
    if predicate {
        on_true
    } else {
        on_false
    }
}

func control_select(control_state state, bool predicate, tensor on_true, tensor on_false) tensor {
    cond(state, predicate, on_true, on_false)
}

func while_loop(control_state state, tensor value, int steps, string op) tensor {
    del state
    tensor current = value
    int i = 0
    while i < steps {
        if op == "add" {
            current = neurx.tensor.tensor.add(current, neurx.tensor.tensor.ones_like(current))
        } else {
            if op == "mul" {
                current = neurx.tensor.tensor.mul(current, neurx.tensor.tensor.new([2.0], [1], false))
            } else {
                if op == "negate" {
                    current = neurx.tensor.tensor.negative(current)
                } else {
                    if op == "square" {
                        current = neurx.tensor.tensor.square(current)
                    }
                }
            }
        }
        i = i + 1
    }
    current
}

func scan_sum(control_state state, tensor value) tensor {
    del state
    int n = len(value.data)
    []float out = []float{cap: n}
    float acc = 0.0
    int i = 0
    while i < n {
        acc = acc + value.data[i]
        out[i] = acc
        i = i + 1
    }
    neurx.tensor.tensor.new(out, value.shape, value.requires_grad)
}

func scan_prod(control_state state, tensor value) tensor {
    del state
    int n = len(value.data)
    []float out = []float{cap: n}
    float acc = 1.0
    int i = 0
    while i < n {
        acc = acc * value.data[i]
        out[i] = acc
        i = i + 1
    }
    neurx.tensor.tensor.new(out, value.shape, value.requires_grad)
}

func control_to_transform_chain(control_state state) transform_chain {
    transform_chain chain = neurx.autograd.function.new_transform_chain()
    int i = 0
    while i < len(state.branches) {
        string param = neurx.strings.string_at(state.params, i)
        if param != "" {
            chain = neurx.autograd.function.transform_chain_add_step_with_param(chain, state.branches[i], param)
        } else {
            chain = neurx.autograd.function.transform_chain_add_step(chain, state.branches[i])
        }
        i = i + 1
    }
    chain = neurx.autograd.function.transform_chain_set_ready(chain, state.cond_enabled || state.loop_enabled || state.scan_enabled || len(state.branches) > 0)
    chain = neurx.autograd.function.transform_chain_set_linearized(chain, state.loop_enabled || state.scan_enabled)
    chain
}

func transform_chain_to_control(transform_chain chain, string name, int iterations) control_state {
    []string branches = copy_strings(chain.steps)
    []string params = copy_strings(chain.params)
    if len(chain.eqns) > 0 {
        branches = []string{cap: len(chain.eqns)}
        params = []string{cap: len(chain.eqns)}
        int i = 0
        while i < len(chain.eqns) {
            branches[i] = chain.eqns[i].primitive
            params[i] = join_strings(chain.eqns[i].params)
            i = i + 1
        }
    }
    bool cond_enabled = false
    bool loop_enabled = false
    bool scan_enabled = false
    int i = 0
    while i < len(branches) {
        if neurx.strings.strings_eq(branches[i], "cond") {
            cond_enabled = true
        }
        if neurx.strings.strings_eq(branches[i], "while_loop") {
            loop_enabled = true
        }
        if neurx.strings.strings_eq(branches[i], "scan") {
            scan_enabled = true
        }
        i = i + 1
    }
    control_state {
        name: name,
        cond_enabled: cond_enabled || len(branches) > 0,
        loop_enabled: loop_enabled,
        scan_enabled: scan_enabled,
        iterations: iterations,
        branches: branches,
        params: params,
    }
}
