package neurx.autograd.engine
use neurx.strings
use neurx.autograd.ir
use neurx.strings
use neurx.autograd.tracer
use neurx.strings
use neurx.autograd.tensor
use neurx.strings
use neurx.tensor.tensor
use neurx.strings
struct backward_state {
    string name
    bool ready
    bool seeded
    bool executed
    string[] steps
    string[] params
    string[] inputs
    string[] outputs
    string[] tags
    float[] upstream
}

func copy_float(float[] values) float[] {
    float[] out = float[]{cap: len(values)}
    int i = 0
    for i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func new_backward_state(string name) backward_state {
    backward_state {
        name: name,
        ready: false,
        seeded: false,
        executed: false,
        steps: [],
        params: [],
        inputs: [],
        outputs: [],
        tags: [],
        upstream: [],
    }
}

func get_step(backward_state state, int index) string {
    state.steps[index]
}

func get_param(backward_state state, int index) string {
    state.params[index]
}

func get_input(backward_state state, int index) string {
    state.inputs[index]
}

func get_output(backward_state state, int index) string {
    state.outputs[index]
}

func get_tag(backward_state state, int index) string {
    state.tags[index]
}

func backward_rule_add(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_add(a, b, upstream)
}

func backward_rule_mul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_mul(a, b, upstream)
}

func backward_rule_sub(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_sub(a, b, upstream)
}

func backward_rule_div(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_div(a, b, upstream)
}

func backward_rule_matmul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_matmul(a, b, upstream)
}

func backward_rule_sum(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_sum(a, upstream)
}

func backward_rule_mean(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_mean(a, upstream)
}

func backward_rule_relu(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_relu(a, upstream)
}

func backward_rule_exp(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_exp(a, upstream)
}

func backward_rule_log(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_log(a, upstream)
}

func backward_rule_sqrt(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_sqrt(a, upstream)
}

func backward_rule_tanh(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_tanh(a, upstream)
}

func backward_rule_sigmoid(tensor a, tensor upstream) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_sigmoid(a, upstream)
}

func backward_rule_sum_dim(tensor a, tensor upstream, int dim, bool keepdim) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_sum_dim(a, upstream, dim, keepdim)
}

func backward_rule_mean_dim(tensor a, tensor upstream, int dim, bool keepdim) backward_rule {
    neurx.autograd.tensor.tensor_backward_rule_mean_dim(a, upstream, dim, keepdim)
}

func backward_rule_from_op(string op, tensor a, tensor b, tensor upstream) backward_rule {
    if op == "add" {
        return backward_rule_add(a, b, upstream)
    }
    if op == "mul" {
        return backward_rule_mul(a, b, upstream)
    }
    if op == "sub" {
        return backward_rule_sub(a, b, upstream)
    }
    if op == "div" {
        return backward_rule_div(a, b, upstream)
    }
    if op == "matmul" {
        return backward_rule_matmul(a, b, upstream)
    }
    if op == "sum" {
        return backward_rule_sum(a, upstream)
    }
    if op == "mean" {
        return backward_rule_mean(a, upstream)
    }
    if op == "relu" {
        return backward_rule_relu(a, upstream)
    }
    if op == "exp" {
        return backward_rule_exp(a, upstream)
    }
    if op == "log" {
        return backward_rule_log(a, upstream)
    }
    if op == "sqrt" {
        return backward_rule_sqrt(a, upstream)
    }
    if op == "tanh" {
        return backward_rule_tanh(a, upstream)
    }
    if op == "sigmoid" {
        return backward_rule_sigmoid(a, upstream)
    }
    if op == "sum_dim" {
        return backward_rule_sum_dim(a, upstream, 0, false)
    }
    if op == "mean_dim" {
        return backward_rule_mean_dim(a, upstream, 0, false)
    }
    backward_rule_add(a, b, upstream)
}

func backward_rule_sum_dim_from_state(backward_state state, tensor a, tensor upstream) backward_rule {
    backward_rule_sum_dim(a, upstream, 0, false)
}

func backward_rule_mean_dim_from_state(backward_state state, tensor a, tensor upstream) backward_rule {
    backward_rule_mean_dim(a, upstream, 0, false)
}

func backward_rule_from_state(backward_state state, tensor a, tensor b, tensor upstream) backward_rule {
    if len(state.steps) == 0 {
        return backward_rule_add(a, b, upstream)
    }
    if get_step(state, len(state.steps) - 1) == "sum_dim" {
        return backward_rule_sum_dim_from_state(state, a, upstream)
    }
    if get_step(state, len(state.steps) - 1) == "mean_dim" {
        return backward_rule_mean_dim_from_state(state, a, upstream)
    }
    backward_rule_from_op(get_step(state, len(state.steps) - 1), a, b, upstream)
}

func backward_execute_state(backward_state state, tensor a, tensor b, tensor upstream) backward_state {
    backward_state next = backward_set_ready(state, true)
    next = backward_set_seeded(next, true)
    int i = len(state.steps) - 1
    backward_rule rule = backward_rule_add(a, b, upstream)
    for i >= 0 {
        rule = backward_rule_from_op(get_step(state, i), a, b, upstream)
        next = backward_add_tag(next, backward_rule_op(rule))
        i = i - 1
    }
    next = backward_set_executed(next, backward_rule_ready(rule))
    backward_set_upstream(next, rule.upstream.data)
}

func backward_apply_rule(backward_state state, backward_rule rule) backward_state {
    backward_state next = backward_set_executed(state, backward_rule_ready(rule))
    next = backward_set_seeded(next, backward_rule_ready(rule))
    next = backward_set_upstream(next, rule.upstream.data)
    backward_add_tag(next, backward_rule_op(rule))
}

func backward_name(backward_state state) string {
    state.name
}

func backward_ready(backward_state state) bool {
    state.ready
}

func backward_seeded(backward_state state) bool {
    state.seeded
}

func backward_executed(backward_state state) bool {
    state.executed
}

func backward_step_count(backward_state state) int {
    len(state.steps)
}

func backward_param_count(backward_state state) int {
    len(state.params)
}

func backward_input_count(backward_state state) int {
    len(state.inputs)
}

func backward_output_count(backward_state state) int {
    len(state.outputs)
}

func backward_tag_count(backward_state state) int {
    len(state.tags)
}

func backward_has_step(backward_state state, string step) bool {
    int i = 0
    for i < len(state.steps) {
        if get_step(state, i) == step {
            return true
        }
        i = i + 1
    }
    false
}

func backward_has_param(backward_state state, string param) bool {
    int i = 0
    for i < len(state.params) {
        if get_param(state, i) == param {
            return true
        }
        i = i + 1
    }
    false
}

func backward_has_input(backward_state state, string input) bool {
    int i = 0
    for i < len(state.inputs) {
        if get_input(state, i) == input {
            return true
        }
        i = i + 1
    }
    false
}

func backward_has_output(backward_state state, string output) bool {
    int i = 0
    for i < len(state.outputs) {
        if get_output(state, i) == output {
            return true
        }
        i = i + 1
    }
    false
}

func backward_has_tag(backward_state state, string tag) bool {
    int i = 0
    for i < len(state.tags) {
        if get_tag(state, i) == tag {
            return true
        }
        i = i + 1
    }
    false
}

func backward_add_step(backward_state state, string step) backward_state {
    string[] steps = copy_strings(state.steps)
    steps = append(steps, step)
    backward_state {
        name: state.name,
        ready: true,
        seeded: state.seeded,
        executed: state.executed,
        steps: steps,
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_add_step_with_param(backward_state state, string step, string param) backward_state {
    string[] steps = copy_strings(state.steps)
    string[] params = copy_strings(state.params)
    steps = append(steps, step)
    params = append(params, param)
    backward_state {
        name: state.name,
        ready: true,
        seeded: state.seeded,
        executed: state.executed,
        steps: steps,
        params: params,
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_add_input(backward_state state, string input) backward_state {
    string[] inputs = copy_strings(state.inputs)
    inputs = append(inputs, input)
    backward_state {
        name: state.name,
        ready: true,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: inputs,
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_add_output(backward_state state, string output) backward_state {
    string[] outputs = copy_strings(state.outputs)
    outputs = append(outputs, output)
    backward_state {
        name: state.name,
        ready: true,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: outputs,
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_add_tag(backward_state state, string tag) backward_state {
    string[] tags = copy_strings(state.tags)
    tags = append(tags, tag)
    backward_state {
        name: state.name,
        ready: true,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: tags,
        upstream: copy_float(state.upstream),
    }
}

func backward_clear_steps(backward_state state) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: [],
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_clear_params(backward_state state) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: [],
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_clear_inputs(backward_state state) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: [],
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_clear_outputs(backward_state state) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: [],
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_clear_tags(backward_state state) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: [],
        upstream: copy_float(state.upstream),
    }
}

func backward_set_ready(backward_state state, bool ready) backward_state {
    backward_state {
        name: state.name,
        ready: ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_set_seeded(backward_state state, bool seeded) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_set_executed(backward_state state, bool executed) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_set_upstream(backward_state state, float[] upstream) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(upstream),
    }
}

func backward_state_dict(backward_state state) backward_state {
    backward_state {
        name: state.name,
        ready: state.ready,
        seeded: state.seeded,
        executed: state.executed,
        steps: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: copy_float(state.upstream),
    }
}

func backward_load_state_dict(backward_state state, backward_state other) backward_state {
    other
}

func backward_to_tracer(backward_state state) tracer_state {
    tracer_state {
        name: state.name,
        active: state.ready,
        linearized: state.seeded || state.executed,
        op_count: len(state.steps),
        ops: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: [],
        tags: copy_strings(state.tags),
    }
}

func tracer_to_backward(tracer_state state, string name) backward_state {
    backward_state {
        name: name,
        ready: tracer.tracer_active(state),
        seeded: tracer.tracer_linearized(state),
        executed: false,
        steps: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        tags: copy_strings(state.tags),
        upstream: [],
    }
}

func backward_to_jaxpr(backward_state state) ir_graph {
    ir_graph {
        name: state.name,
        eqn_count: len(state.steps),
        primitives: copy_strings(state.steps),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: [],
        ready: state.ready,
        linearized: state.seeded || state.executed,
    }
}

func ir_to_backward(ir_graph graph) backward_state {
    backward_state {
        name: graph.name,
        ready: graph.ready,
        seeded: graph.linearized,
        executed: false,
        steps: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        tags: [],
        upstream: [],
    }
}

func backward_seed_state(backward_state state, tensor loss) backward_state {
    if !loss.requires_grad {
        return state
    }
    backward_state seeded = backward_set_ready(state, true)
    seeded = backward_set_seeded(seeded, true)
    backward_set_upstream(seeded, neurx.tensor.tensor.ones_like(loss).data)
}

func backward_pass_state(backward_state state, tensor loss) backward_state {
    backward_state seeded = backward_seed_state(state, loss)
    backward_set_executed(seeded, true)
}

func backward_pass(backward_state state, tensor loss) tensor {
    if !loss.requires_grad {
        return neurx.tensor.tensor.zeros_like(loss)
    }
    neurx.tensor.tensor.ones_like(loss)
}

func backward(tensor t) tensor {
    backward_pass(new_backward_state("backward"), t)
}
