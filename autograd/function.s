package neurx.autograd.function
use neurx.autograd.eqn
use neurx.strings
struct function_record {
    string name
    bool forward_enabled
    bool backward_enabled
    bool apply_enabled
    bool linearized
    int arity
    []string params
    []string tags
}

struct transform_chain {
    []string steps
    []string params
    []string inputs
    []string outputs
    []jaxpr_eqn eqns
    bool ready
    bool linearized
}

struct backward_rule {
    string op
    tensor primal_a
    tensor primal_b
    tensor upstream
    tensor grad_a
    tensor grad_b
    bool ready
}
func copy_eqns([]jaxpr_eqn values) []jaxpr_eqn {
    neurx.autograd.eqn.copy_eqns(values)
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

func new_function(string name, int arity) function_record {
    function_record {
        name: name,
        forward_enabled: false,
        backward_enabled: false,
        apply_enabled: false,
        linearized: false,
        arity: arity,
        params: [],
        tags: [],
    }
}

func new_transform_chain() transform_chain {
    transform_chain {
        steps: [],
        params: [],
        inputs: [],
        outputs: [],
        eqns: [],
        ready: false,
        linearized: false,
    }
}

func same_shape(tensor a, tensor b) bool {
    if len(a.shape) != len(b.shape) {
        return false
    }
    int i = 0
    while i < len(a.shape) {
        if a.shape[i] != b.shape[i] {
            return false
        }
        i = i + 1
    }
    true
}

func scalar_tensor(float value) tensor {
    neurx.tensor.tensor.new([value], [1], false)
}

func scale_tensor(tensor value, float scale) tensor {
    neurx.tensor.tensor.mul(value, scalar_tensor(scale))
}

func backward_rule_ready(backward_rule rule) bool {
    rule.ready
}

func backward_rule_op(backward_rule rule) string {
    rule.op
}

func backward_rule_grad_a(backward_rule rule) tensor {
    rule.grad_a
}

func backward_rule_grad_b(backward_rule rule) tensor {
    rule.grad_b
}

func backward_rule_add(tensor a, tensor b, tensor upstream) backward_rule {
    bool ready = same_shape(a, b) && same_shape(a, upstream)
    backward_rule {
        op: "add",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: neurx.tensor.tensor.clone(upstream),
        grad_b: neurx.tensor.tensor.clone(upstream),
        ready: ready,
    }
}

func backward_rule_mul(tensor a, tensor b, tensor upstream) backward_rule {
    bool ready = same_shape(a, b) && same_shape(a, upstream)
    backward_rule {
        op: "mul",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: neurx.tensor.tensor.mul(upstream, b),
        grad_b: neurx.tensor.tensor.mul(upstream, a),
        ready: ready,
    }
}

func backward_rule_matmul(tensor a, tensor b, tensor upstream) backward_rule {
    int ndim_a = len(a.shape)
    int ndim_b = len(b.shape)
    bool ready = false
    tensor grad_a = neurx.tensor.tensor.zeros_like(a)
    tensor grad_b = neurx.tensor.tensor.zeros_like(b)
    if ndim_a == 1 && ndim_b == 1 {
        ready = len(upstream.shape) == 1
        grad_a = scale_tensor(b, upstream.data[0])
        grad_b = scale_tensor(a, upstream.data[0])
    } else {
        if ndim_a == 2 && ndim_b == 2 {
            ready = len(upstream.shape) == 2
            grad_a = neurx.tensor.tensor.matmul(upstream, neurx.tensor.tensor.transpose(b, 0, 1))
            grad_b = neurx.tensor.tensor.matmul(neurx.tensor.tensor.transpose(a, 0, 1), upstream)
        } else {
            if ndim_a == 2 && ndim_b == 1 {
                ready = len(upstream.shape) == 1
                grad_b = neurx.tensor.tensor.matmul(neurx.tensor.tensor.transpose(a, 0, 1), upstream)
            }
        }
    }
    backward_rule {
        op: "matmul",
        primal_a: a,
        primal_b: b,
        upstream: upstream,
        grad_a: grad_a,
        grad_b: grad_b,
        ready: ready,
    }
}

func backward_rule_sum(tensor a, tensor upstream) backward_rule {
    bool ready = len(upstream.data) == 1
    backward_rule {
        op: "sum",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: neurx.tensor.tensor.fill_like(a, upstream.data[0]),
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: ready,
    }
}

func backward_rule_mean(tensor a, tensor upstream) backward_rule {
    float denom = len(a.data)
    bool ready = len(upstream.data) == 1
    backward_rule {
        op: "mean",
        primal_a: a,
        primal_b: neurx.tensor.tensor.zeros_like(a),
        upstream: upstream,
        grad_a: neurx.tensor.tensor.fill_like(a, upstream.data[0] / denom),
        grad_b: neurx.tensor.tensor.zeros_like(a),
        ready: ready,
    }
}

func copy_transform_steps([]string steps) []string {
    copy_strings(steps)
}

func transform_chain_step_count(transform_chain chain) int {
    len(chain.steps)
}

func transform_chain_param_count(transform_chain chain) int {
    len(chain.params)
}

func get_transform_step(transform_chain chain, int index) string {
    chain.steps[index]
}

func transform_chain_has_step(transform_chain chain, string step) bool {
    int i = 0
    while i < len(chain.steps) {
        string s = get_transform_step(chain, i)
        if s == step {
            return true
        }
        i = i + 1
    }
    false
}

func transform_chain_ready(transform_chain chain) bool {
    chain.ready
}

func transform_chain_is_linearized(transform_chain chain) bool {
    chain.linearized
}

func transform_chain_add_step(transform_chain chain, string step) transform_chain {
    []string steps = copy_transform_steps(chain.steps)
    steps.push(step)
    transform_chain {
        steps: steps,
        params: copy_transform_steps(chain.params),
        inputs: copy_transform_steps(chain.inputs),
        outputs: copy_transform_steps(chain.outputs),
        eqns: copy_eqns(chain.eqns),
        ready: chain.ready || len(steps) > 0,
        linearized: chain.linearized,
    }
}

func transform_chain_add_step_with_param(transform_chain chain, string step, string param) transform_chain {
    []string steps = copy_transform_steps(chain.steps)
    []string params = copy_transform_steps(chain.params)
    steps.push(step)
    params.push(param)
    transform_chain {
        steps: steps,
        params: params,
        inputs: copy_transform_steps(chain.inputs),
        outputs: copy_transform_steps(chain.outputs),
        eqns: copy_eqns(chain.eqns),
        ready: chain.ready || len(steps) > 0,
        linearized: chain.linearized,
    }
}

func transform_chain_with_op(transform_chain chain, string op) transform_chain {
    transform_chain_add_step(chain, op)
}

func transform_chain_add(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "add")
}

func transform_chain_mul(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "mul")
}

func transform_chain_matmul(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "matmul")
}

func transform_chain_sum(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "sum")
}

func transform_chain_mean(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "mean")
}

func transform_chain_relu(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "relu")
}

func transform_chain_exp(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "exp")
}

func transform_chain_log(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "log")
}

func transform_chain_sqrt(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "sqrt")
}

func transform_chain_tanh(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "tanh")
}

func transform_chain_sigmoid(transform_chain chain) transform_chain {
    transform_chain_with_op(chain, "sigmoid")
}

func transform_chain_set_ready(transform_chain chain, bool ready) transform_chain {
    transform_chain {
        steps: copy_transform_steps(chain.steps),
        params: copy_transform_steps(chain.params),
        inputs: copy_transform_steps(chain.inputs),
        outputs: copy_transform_steps(chain.outputs),
        eqns: copy_eqns(chain.eqns),
        ready: ready,
        linearized: chain.linearized,
    }
}

func transform_chain_set_linearized(transform_chain chain, bool linearized) transform_chain {
    transform_chain {
        steps: copy_transform_steps(chain.steps),
        params: copy_transform_steps(chain.params),
        inputs: copy_transform_steps(chain.inputs),
        outputs: copy_transform_steps(chain.outputs),
        eqns: copy_eqns(chain.eqns),
        ready: chain.ready,
        linearized: linearized,
    }
}

func transform_chain_state_dict(transform_chain chain) transform_chain {
    transform_chain {
        steps: copy_transform_steps(chain.steps),
        params: copy_transform_steps(chain.params),
        inputs: copy_transform_steps(chain.inputs),
        outputs: copy_transform_steps(chain.outputs),
        eqns: copy_eqns(chain.eqns),
        ready: chain.ready,
        linearized: chain.linearized,
    }
}

func transform_chain_load_state_dict(transform_chain chain, transform_chain other) transform_chain {
    other
}

func function_name(function_record f) string {
    f.name
}

func function_arity(function_record f) int {
    f.arity
}

func function_tag_count(function_record f) int {
    len(f.tags)
}

func function_param_count(function_record f) int {
    len(f.params)
}

func get_function_tag(function_record f, int index) string {
    f.tags[index]
}

func get_function_param(function_record f, int index) string {
    f.params[index]
}

func function_has_tag(function_record f, string tag) bool {
    int i = 0
    while i < len(f.tags) {
        string t = get_function_tag(f, i)
        if t == tag {
            return true
        }
        i = i + 1
    }
    false
}

func function_has_param(function_record f, string param) bool {
    int i = 0
    while i < len(f.params) {
        string p = get_function_param(f, i)
        if p == param {
            return true
        }
        i = i + 1
    }
    false
}

func add_function_tag(function_record f, string tag) function_record {
    []string tags = copy_strings(f.tags)
    tags.push(tag)
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: f.backward_enabled,
        apply_enabled: f.apply_enabled,
        linearized: f.linearized,
        arity: f.arity,
        params: copy_strings(f.params),
        tags: tags,
    }
}

func add_function_param(function_record f, string param) function_record {
    []string params = copy_strings(f.params)
    params.push(param)
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: f.backward_enabled,
        apply_enabled: f.apply_enabled,
        linearized: f.linearized,
        arity: f.arity,
        params: params,
        tags: copy_strings(f.tags),
    }
}

func clear_function_tags(function_record f) function_record {
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: f.backward_enabled,
        apply_enabled: f.apply_enabled,
        linearized: f.linearized,
        arity: f.arity,
        params: copy_strings(f.params),
        tags: [],
    }
}

func clear_function_params(function_record f) function_record {
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: f.backward_enabled,
        apply_enabled: f.apply_enabled,
        linearized: f.linearized,
        arity: f.arity,
        params: [],
        tags: copy_strings(f.tags),
    }
}

func enable_forward(function_record f) function_record {
    function_record {
        name: f.name,
        forward_enabled: true,
        backward_enabled: f.backward_enabled,
        apply_enabled: f.apply_enabled,
        linearized: f.linearized,
        arity: f.arity,
        params: copy_strings(f.params),
        tags: copy_strings(f.tags),
    }
}

func enable_backward(function_record f) function_record {
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: true,
        apply_enabled: f.apply_enabled,
        linearized: f.linearized,
        arity: f.arity,
        params: copy_strings(f.params),
        tags: copy_strings(f.tags),
    }
}

func enable_apply(function_record f) function_record {
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: f.backward_enabled,
        apply_enabled: true,
        linearized: f.linearized,
        arity: f.arity,
        params: copy_strings(f.params),
        tags: copy_strings(f.tags),
    }
}

func set_linearized(function_record f, bool linearized) function_record {
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: f.backward_enabled,
        apply_enabled: f.apply_enabled,
        linearized: linearized,
        arity: f.arity,
        params: copy_strings(f.params),
        tags: copy_strings(f.tags),
    }
}

func function_ready(function_record f) bool {
    f.forward_enabled && f.backward_enabled && f.apply_enabled
}

func function_is_linearized(function_record f) bool {
    f.linearized
}

func function_state_dict(function_record f) function_record {
    function_record {
        name: f.name,
        forward_enabled: f.forward_enabled,
        backward_enabled: f.backward_enabled,
        apply_enabled: f.apply_enabled,
        linearized: f.linearized,
        arity: f.arity,
        params: copy_strings(f.params),
        tags: copy_strings(f.tags),
    }
}

func function_load_state_dict(function_record f, function_record other) function_record {
    other
}

func function_transform_chain(function_record f) transform_chain {
    []jaxpr_eqn eqns = []jaxpr_eqn{cap: len(f.tags)}
    int i = 0
    while i < len(f.tags) {
        []string params = []string{cap: 0}
        string param_val = get_function_param(f, i)
        if i < len(f.params) && param_val != "" {
            params = []string{cap: 1}
            params[0] = param_val
        }
        string tag_val = get_function_tag(f, i)
        eqns[i] = jaxpr_eqn {
            primitive: tag_val,
            params: params,
            inputs: [],
            outputs: [],
        }
        i = i + 1
    }
    transform_chain {
        steps: copy_strings(f.tags),
        params: copy_strings(f.params),
        inputs: [],
        outputs: [],
        eqns: eqns,
        ready: function_ready(f),
        linearized: function_is_linearized(f),
    }
}

func transform_chain_to_function(transform_chain chain, string name, int arity) function_record {
    []string params = copy_strings(chain.params)
    []string tags = copy_strings(chain.steps)
    if len(chain.eqns) > 0 {
        params = []string{cap: len(chain.eqns)}
        tags = []string{cap: len(chain.eqns)}
        int i = 0
        while i < len(chain.eqns) {
            tags[i] = chain.eqns[i].primitive
            params[i] = join_strings(chain.eqns[i].params)
            i = i + 1
        }
    }
    function_record {
        name: name,
        forward_enabled: chain.ready,
        backward_enabled: chain.ready || chain.linearized,
        apply_enabled: chain.ready && chain.linearized,
        linearized: chain.linearized,
        arity: arity,
        params: params,
        tags: tags,
    }
}

func tag_flow(function_record f, string tag) function_record {
    add_function_tag(f, tag)
}

func backward_pass(function_record f) function_record {
    add_function_tag(set_linearized(enable_backward(f), true), "backward_pass")
}

func backward_pass_state(function_record f) function_record {
    set_linearized(enable_backward(f), true)
}

func forward(function_record f) function_record {
    enable_forward(f)
}

func backward(function_record f) function_record {
    enable_backward(f)
}

func apply(function_record f) function_record {
    set_linearized(enable_apply(enable_backward(enable_forward(f))), true)
}

func linearize(function_record f) function_record {
    set_linearized(enable_backward(enable_forward(f)), true)
}

func jvp(function_record f) function_record {
    add_function_tag(set_linearized(enable_forward(f), true), "jvp")
}

func vjp(function_record f) function_record {
    add_function_tag(set_linearized(enable_backward(f), true), "vjp")
}

func grad(function_record f) function_record {
    add_function_tag(set_linearized(enable_backward(enable_forward(f)), true), "grad")
}

func value_and_grad(function_record f) function_record {
    add_function_tag(set_linearized(enable_backward(enable_forward(f)), true), "value_and_grad")
}

func transform_chain_jvp(transform_chain chain) transform_chain {
    transform_chain_set_linearized(transform_chain_set_ready(transform_chain_add_step(chain, "jvp"), true), true)
}

func transform_chain_vjp(transform_chain chain) transform_chain {
    transform_chain_set_linearized(transform_chain_set_ready(transform_chain_add_step(chain, "vjp"), true), true)
}

func transform_chain_grad(transform_chain chain) transform_chain {
    transform_chain_set_linearized(transform_chain_set_ready(transform_chain_add_step(chain, "grad"), true), true)
}

func transform_chain_value_and_grad(transform_chain chain) transform_chain {
    transform_chain_set_linearized(transform_chain_set_ready(transform_chain_add_step(chain, "value_and_grad"), true), true)
}

func function_add(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=add"), "add")
}

func function_mul(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=mul"), "mul")
}

func function_matmul(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=matmul"), "matmul")
}

func function_sum(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=sum"), "sum")
}

func function_mean(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=mean"), "mean")
}

func add(function_record f) function_record {
    function_add(f)
}

func mul(function_record f) function_record {
    function_mul(f)
}

func matmul(function_record f) function_record {
    function_matmul(f)
}

func sum(function_record f) function_record {
    function_sum(f)
}

func mean(function_record f) function_record {
    function_mean(f)
}

func function_relu(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=relu"), "relu")
}

func function_exp(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=exp"), "exp")
}

func function_log(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=log"), "log")
}

func function_sqrt(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=sqrt"), "sqrt")
}

func function_tanh(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=tanh"), "tanh")
}

func function_sigmoid(function_record f) function_record {
    add_function_tag(add_function_param(set_linearized(enable_forward(f), true), "op=sigmoid"), "sigmoid")
}
