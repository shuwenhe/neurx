package neurx.ad

use neurx.ad.ir
use neurx.ad.tracer
use neurx.tensor.tensor
use neurx.tensor.autograd
use neurx.engine
use neurx.ad.function

struct grad_record {
    int id
    []int shape
    bool requires_grad
    []float grad
}

struct autograd_state {
    bool grad_enabled
    bool grad_accumulation
    []grad_record records
}

struct dual_record {
    int id
    []int shape
    bool requires_grad
    []float primal
    []float tangent
    []float cotangent
}

struct linearize_state {
    bool forward_mode
    bool reverse_mode
    []dual_record records
}

func copy_float([]float data) []float {
    neurx.engine.copy_float(data)
}

func copy_int([]int data) []int {
    neurx.engine.copy_int(data)
}

func copy_record(grad_record record) grad_record {
    neurx.engine.copy_record(record)
}

func copy_records([]grad_record records) []grad_record {
    neurx.engine.copy_records(records)
}

func new_state() autograd_state {
    neurx.engine.new_state()
}

func set_grad_enabled(autograd_state state, bool enabled) autograd_state {
    neurx.engine.set_grad_enabled(state, enabled)
}

func no_grad(autograd_state state) autograd_state {
    neurx.engine.no_grad(state)
}

func enable_grad(autograd_state state) autograd_state {
    neurx.engine.enable_grad(state)
}

func set_gradient_accumulation(autograd_state state, bool accumulate) autograd_state {
    neurx.engine.set_gradient_accumulation(state, accumulate)
}

func gradient_accumulation(autograd_state state, bool enable) autograd_state {
    neurx.engine.gradient_accumulation(state, enable)
}

func is_grad_enabled(autograd_state state) bool {
    neurx.engine.is_grad_enabled(state)
}

func is_grad_accumulation_enabled(autograd_state state) bool {
    neurx.engine.is_grad_accumulation_enabled(state)
}

func get_gradient_accumulation(autograd_state state) bool {
    neurx.engine.get_gradient_accumulation(state)
}

func set_detect_anomaly(autograd_state state, bool enabled) autograd_state {
    neurx.engine.set_detect_anomaly(state, enabled)
}

func zeros_like([]float data) []float {
    neurx.engine.zeros_like(data)
}

func ones_like([]float data) []float {
    neurx.engine.ones_like(data)
}

func register_tensor(autograd_state state, int id, tensor value) autograd_state {
    neurx.engine.register_tensor(state, id, value)
}

func record_count(autograd_state state) int {
    neurx.engine.record_count(state)
}

func has_record(autograd_state state, int id) bool {
    neurx.engine.has_record(state, id)
}

func set_grad(autograd_state state, int id, []float grad) autograd_state {
    neurx.engine.set_grad(state, id, grad)
}

func clear_grad(autograd_state state, int id) autograd_state {
    neurx.engine.clear_grad(state, id)
}

func zero_grad(autograd_state state) autograd_state {
    neurx.engine.zero_grad(state)
}

func accumulate_grad(autograd_state state, int id, []float grad) autograd_state {
    neurx.engine.accumulate_grad(state, id, grad)
}

func grad_of(autograd_state state, int id) []float {
    neurx.engine.grad_of(state, id)
}

func backward_seed(autograd_state state, int loss_id, tensor loss_tensor) autograd_state {
    neurx.engine.backward_seed(state, loss_id, loss_tensor)
}

func grad_record_state_dict(grad_record record) grad_record {
    neurx.engine.grad_record_state_dict(record)
}

func grad_record_load_state_dict(grad_record record, grad_record other) grad_record {
    neurx.engine.grad_record_load_state_dict(record, other)
}

func autograd_state_dict(autograd_state state) autograd_state {
    neurx.engine.autograd_state_dict(state)
}

func autograd_load_state_dict(autograd_state state, autograd_state other) autograd_state {
    neurx.engine.autograd_load_state_dict(state, other)
}

func grad_enabled_state(autograd_state state) bool {
    neurx.engine.grad_enabled_state(state)
}

func grad_accumulation_state(autograd_state state) bool {
    neurx.engine.grad_accumulation_state(state)
}

func backward(tensor t) tensor {
    neurx.engine.backward(t)
}

func copy_dual_record(dual_record record) dual_record {
    dual_record {
        id: record.id,
        shape: copy_int(record.shape),
        requires_grad: record.requires_grad,
        primal: copy_float(record.primal),
        tangent: copy_float(record.tangent),
        cotangent: copy_float(record.cotangent),
    }
}

func copy_dual_records([]dual_record records) []dual_record {
    []dual_record out = []dual_record{cap: len(records)}
    int i = 0
    while i < len(records) {
        out[i] = copy_dual_record(records[i])
        i = i + 1
    }
    out
}

func new_linearize_state() linearize_state {
    linearize_state {
        forward_mode: true,
        reverse_mode: true,
        records: [],
    }
}

func set_forward_mode(linearize_state state, bool enabled) linearize_state {
    linearize_state {
        forward_mode: enabled,
        reverse_mode: state.reverse_mode,
        records: state.records,
    }
}

func set_reverse_mode(linearize_state state, bool enabled) linearize_state {
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: enabled,
        records: state.records,
    }
}

func forward_mode_enabled(linearize_state state) bool {
    state.forward_mode
}

func reverse_mode_enabled(linearize_state state) bool {
    state.reverse_mode
}

func linearize_ready(linearize_state state) bool {
    state.forward_mode || state.reverse_mode
}

func linearize_tensor(tensor value) dual_record {
    dual_record {
        id: 0,
        shape: copy_int(value.shape),
        requires_grad: value.requires_grad,
        primal: copy_float(value.data),
        tangent: zeros_like(value.data),
        cotangent: zeros_like(value.data),
    }
}

func register_dual_tensor(linearize_state state, int id, tensor value) linearize_state {
    []dual_record records = state.records
    records.push(
        dual_record {
            id: id,
            shape: copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: copy_float(value.data),
            tangent: zeros_like(value.data),
            cotangent: zeros_like(value.data),
        }
    )
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: state.reverse_mode,
        records: records,
    }
}

func linearize_record_count(linearize_state state) int {
    len(state.records)
}

func linearize_has_record(linearize_state state, int id) bool {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return true
        }
        i = i + 1
    }
    false
}

func linearize_shape_of(linearize_state state, int id) []int {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return copy_int(state.records[i].shape)
        }
        i = i + 1
    }
    []
}

func linearize_requires_grad(linearize_state state, int id) bool {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return state.records[i].requires_grad
        }
        i = i + 1
    }
    false
}

func linearize_primal_of(linearize_state state, int id) []float {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return copy_float(state.records[i].primal)
        }
        i = i + 1
    }
    []
}

func linearize_tangent_of(linearize_state state, int id) []float {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return copy_float(state.records[i].tangent)
        }
        i = i + 1
    }
    []
}

func linearize_cotangent_of(linearize_state state, int id) []float {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return copy_float(state.records[i].cotangent)
        }
        i = i + 1
    }
    []
}

func set_linearize_primal(linearize_state state, int id, []float primal) linearize_state {
    []dual_record records = state.records
    int i = 0
    while i < len(records) {
        if records[i].id == id {
            records[i].primal = primal
        }
        i = i + 1
    }
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: state.reverse_mode,
        records: records,
    }
}

func set_linearize_tangent(linearize_state state, int id, []float tangent) linearize_state {
    []dual_record records = state.records
    int i = 0
    while i < len(records) {
        if records[i].id == id {
            records[i].tangent = tangent
        }
        i = i + 1
    }
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: state.reverse_mode,
        records: records,
    }
}

func set_linearize_cotangent(linearize_state state, int id, []float cotangent) linearize_state {
    []dual_record records = state.records
    int i = 0
    while i < len(records) {
        if records[i].id == id {
            records[i].cotangent = cotangent
        }
        i = i + 1
    }
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: state.reverse_mode,
        records: records,
    }
}

func accumulate_linearize_tangent(linearize_state state, int id, []float tangent) linearize_state {
    []dual_record records = state.records
    int i = 0
    while i < len(records) {
        if records[i].id == id {
            int n = len(records[i].tangent)
            if n == len(tangent) {
                int j = 0
                while j < n {
                    records[i].tangent[j] = records[i].tangent[j] + tangent[j]
                    j = j + 1
                }
            }
        }
        i = i + 1
    }
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: state.reverse_mode,
        records: records,
    }
}

func accumulate_linearize_cotangent(linearize_state state, int id, []float cotangent) linearize_state {
    []dual_record records = state.records
    int i = 0
    while i < len(records) {
        if records[i].id == id {
            int n = len(records[i].cotangent)
            if n == len(cotangent) {
                int j = 0
                while j < n {
                    records[i].cotangent[j] = records[i].cotangent[j] + cotangent[j]
                    j = j + 1
                }
            }
        }
        i = i + 1
    }
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: state.reverse_mode,
        records: records,
    }
}

func linearize_state_dict(linearize_state state) linearize_state {
    linearize_state {
        forward_mode: state.forward_mode,
        reverse_mode: state.reverse_mode,
        records: copy_dual_records(state.records),
    }
}

func linearize_load_state_dict(linearize_state state, linearize_state other) linearize_state {
    other
}

func jvp_seed_data(tensor value) []float {
    if value.requires_grad {
        return ones_like(value.data)
    }
    zeros_like(value.data)
}

func vjp_seed_state(linearize_state state, int loss_id, tensor loss_tensor) linearize_state {
    if !loss_tensor.requires_grad {
        return state
    }
    set_linearize_cotangent(state, loss_id, ones_like(loss_tensor.data))
}

func linearize_backward_state(linearize_state state, int loss_id, tensor loss_tensor) linearize_state {
    vjp_seed_state(state, loss_id, loss_tensor)
}

func function_state(function_record f) function_record {
    neurx.ad.function.function_state_dict(f)
}

func function_linearized(function_record f) function_record {
    neurx.ad.function.set_linearized(f, true)
}

func function_enable_forward(function_record f) function_record {
    neurx.ad.function.enable_forward(f)
}

func function_enable_backward(function_record f) function_record {
    neurx.ad.function.enable_backward(f)
}

func function_enable_apply(function_record f) function_record {
    neurx.ad.function.enable_apply(f)
}

func function_linearize(function_record f) function_record {
    neurx.ad.function.linearize(f)
}

func function_jvp(function_record f) function_record {
    neurx.ad.function.jvp(f)
}

func function_vjp(function_record f) function_record {
    neurx.ad.function.vjp(f)
}

func function_grad(function_record f) function_record {
    neurx.ad.function.grad(f)
}

func function_value_and_grad(function_record f) function_record {
    neurx.ad.function.value_and_grad(f)
}

func function_tag_flow(function_record f, string tag) function_record {
    neurx.ad.function.tag_flow(f, tag)
}

func function_param_count(function_record f) int {
    neurx.ad.function.function_param_count(f)
}

func function_has_param(function_record f, string param) bool {
    neurx.ad.function.function_has_param(f, param)
}

func add_function_param(function_record f, string param) function_record {
    neurx.ad.function.add_function_param(f, param)
}

func clear_function_params(function_record f) function_record {
    neurx.ad.function.clear_function_params(f)
}

func function_backward_pass(function_record f) function_record {
    neurx.ad.function.backward_pass(f)
}

func function_backward_pass_state(function_record f) function_record {
    neurx.ad.function.backward_pass_state(f)
}

func function_tagged_linearize(function_record f, string tag, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: copy_float(value.data),
            tangent: jvp_seed_data(value),
            cotangent: ones_like(value.data),
        }
    )
    linearize_state {
        forward_mode: neurx.ad.function.function_ready(neurx.ad.function.tag_flow(f, tag)),
        reverse_mode: neurx.ad.function.function_is_linearized(neurx.ad.function.backward_pass_state(f)),
        records: records,
    }
}

func function_transform_chain(function_record f) transform_chain {
    neurx.ad.function.function_transform_chain(f)
}

func transform_chain_to_function(transform_chain chain, string name, int arity) function_record {
    neurx.ad.function.transform_chain_to_function(chain, name, arity)
}

func function_transform_chain_jvp(function_record f) transform_chain {
    neurx.ad.function.transform_chain_jvp(neurx.ad.function.function_transform_chain(f))
}

func function_transform_chain_vjp(function_record f) transform_chain {
    neurx.ad.function.transform_chain_vjp(neurx.ad.function.function_transform_chain(f))
}

func function_transform_chain_grad(function_record f) transform_chain {
    neurx.ad.function.transform_chain_grad(neurx.ad.function.function_transform_chain(f))
}

func function_transform_chain_value_and_grad(function_record f) transform_chain {
    neurx.ad.function.transform_chain_value_and_grad(neurx.ad.function.function_transform_chain(f))
}

func function_add(function_record f) function_record {
    neurx.ad.function.function_add(f)
}

func function_mul(function_record f) function_record {
    neurx.ad.function.function_mul(f)
}

func function_matmul(function_record f) function_record {
    neurx.ad.function.function_matmul(f)
}

func function_sum(function_record f) function_record {
    neurx.ad.function.function_sum(f)
}

func function_mean(function_record f) function_record {
    neurx.ad.function.function_mean(f)
}

func function_add_op(function_record f) function_record {
    neurx.ad.function.add(f)
}

func function_mul_op(function_record f) function_record {
    neurx.ad.function.mul(f)
}

func function_matmul_op(function_record f) function_record {
    neurx.ad.function.matmul(f)
}

func function_sum_op(function_record f) function_record {
    neurx.ad.function.sum(f)
}

func function_mean_op(function_record f) function_record {
    neurx.ad.function.mean(f)
}

func function_transform_chain_add(function_record f) transform_chain {
    neurx.ad.function.transform_chain_add(neurx.ad.function.function_transform_chain(f))
}

func function_transform_chain_mul(function_record f) transform_chain {
    neurx.ad.function.transform_chain_mul(neurx.ad.function.function_transform_chain(f))
}

func function_transform_chain_matmul(function_record f) transform_chain {
    neurx.ad.function.transform_chain_matmul(neurx.ad.function.function_transform_chain(f))
}

func function_transform_chain_sum(function_record f) transform_chain {
    neurx.ad.function.transform_chain_sum(neurx.ad.function.function_transform_chain(f))
}

func function_transform_chain_mean(function_record f) transform_chain {
    neurx.ad.function.transform_chain_mean(neurx.ad.function.function_transform_chain(f))
}

func backward_rule_add(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_add(a, b, upstream)
}

func backward_rule_mul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_mul(a, b, upstream)
}

func backward_rule_matmul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_matmul(a, b, upstream)
}

func backward_rule_sum(tensor a, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_sum(a, upstream)
}

func backward_rule_mean(tensor a, tensor upstream) backward_rule {
    neurx.ad.function.backward_rule_mean(a, upstream)
}

func tensor_backward_rule_sub(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_sub(a, b, upstream)
}

func tensor_backward_rule_div(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_div(a, b, upstream)
}

func tensor_backward_rule_add(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_add(a, b, upstream)
}

func tensor_backward_rule_mul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_mul(a, b, upstream)
}

func tensor_backward_rule_matmul(tensor a, tensor b, tensor upstream) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_matmul(a, b, upstream)
}

func tensor_backward_rule_sum(tensor a, tensor upstream) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_sum(a, upstream)
}

func tensor_backward_rule_mean(tensor a, tensor upstream) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_mean(a, upstream)
}

func tensor_backward_rule_sum_dim(tensor a, tensor upstream, int dim, bool keepdim) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_sum_dim(a, upstream, dim, keepdim)
}

func tensor_backward_rule_mean_dim(tensor a, tensor upstream, int dim, bool keepdim) backward_rule {
    neurx.tensor.autograd.tensor_backward_rule_mean_dim(a, upstream, dim, keepdim)
}

func tensor_transform_chain_add() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_add()
}

func tensor_transform_chain_mul() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_mul()
}

func tensor_transform_chain_sub() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_sub()
}

func tensor_transform_chain_div() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_div()
}

func tensor_transform_chain_matmul() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_matmul()
}

func tensor_transform_chain_sum() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_sum()
}

func tensor_transform_chain_mean() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_mean()
}

func tensor_transform_chain_sum_dim() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_sum_dim()
}

func tensor_transform_chain_mean_dim() transform_chain {
    neurx.tensor.autograd.tensor_transform_chain_mean_dim()
}

func build_causal_mask(tensor scores) tensor {
    int rows = scores.shape[0]
    int cols = scores.shape[1]
    tensor mask = neurx.tensor.tensor.zeros_like(scores)
    int r = 0
    while r < rows {
        int c = r + 1
        while c < cols {
            mask.data[r * cols + c] = 1.0
            c = c + 1
        }
        r = r + 1
    }
    mask
}

func scaled_dot_product_attention(tensor query, tensor key, tensor value, tensor mask, bool has_mask) tensor {
    int ndim_q = len(query.shape)
    int ndim_k = len(key.shape)
    int ndim_v = len(value.shape)
    if ndim_q < 2 || ndim_k < 2 || ndim_v < 2 {
        return neurx.tensor.tensor.clone(query)
    }

    tensor key_t = neurx.tensor.tensor.transpose(key, 0, 1)
    tensor scores = neurx.tensor.tensor.matmul(query, key_t)
    tensor head_dim_tensor = neurx.tensor.tensor.sqrt(
        neurx.tensor.tensor.new([float(query.shape[1])], [1], false)
    )
    tensor scaled_scores = neurx.tensor.tensor.div(scores, head_dim_tensor)
    if has_mask {
        scaled_scores = neurx.indexing.masked_fill(scaled_scores, mask, -1000000000.0)
    }
    tensor weights = neurx.tensor.tensor.softmax(scaled_scores, -1)
    neurx.tensor.tensor.matmul(weights, value)
}

func causal_attention(tensor query, tensor key, tensor value) tensor {
    tensor key_t = neurx.tensor.tensor.transpose(key, 0, 1)
    tensor scores = neurx.tensor.tensor.matmul(query, key_t)
    tensor mask = build_causal_mask(scores)
    scaled_dot_product_attention(query, key, value, mask, true)
}

func function_ready_for_linearize(function_record f, linearize_state state) bool {
    neurx.ad.function.function_ready(f) && linearize_ready(state)
}

func function_to_linearize_state(function_record f, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: copy_float(value.data),
            tangent: jvp_seed_data(value),
            cotangent: zeros_like(value.data),
        }
    )
    linearize_state {
        forward_mode: neurx.ad.function.function_ready(f),
        reverse_mode: neurx.ad.function.function_is_linearized(f),
        records: records,
    }
}

func linearize_state_to_function(linearize_state state, string name, int arity) function_record {
    function_record {
        name: name,
        forward_enabled: state.forward_mode,
        backward_enabled: state.reverse_mode,
        apply_enabled: state.forward_mode && state.reverse_mode,
        linearized: true,
        arity: arity,
        params: [],
        tags: [],
    }
}

func function_capture(function_record f, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: copy_float(value.data),
            tangent: jvp_seed_data(value),
            cotangent: zeros_like(value.data),
        }
    )
    linearize_state {
        forward_mode: neurx.ad.function.function_ready(f),
        reverse_mode: neurx.ad.function.function_is_linearized(f),
        records: records,
    }
}

func function_jvp_capture(function_record f, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: copy_float(value.data),
            tangent: jvp_seed_data(value),
            cotangent: zeros_like(value.data),
        }
    )
    linearize_state {
        forward_mode: true,
        reverse_mode: neurx.ad.function.function_is_linearized(f),
        records: records,
    }
}

func function_vjp_capture(function_record f, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: copy_float(value.data),
            tangent: zeros_like(value.data),
            cotangent: ones_like(value.data),
        }
    )
    linearize_state {
        forward_mode: neurx.ad.function.function_ready(f),
        reverse_mode: true,
        records: records,
    }
}

func function_linearize_capture(function_record f, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: copy_float(value.data),
            tangent: jvp_seed_data(value),
            cotangent: ones_like(value.data),
        }
    )
    linearize_state {
        forward_mode: true,
        reverse_mode: true,
        records: records,
    }
}

func new_tracer_state(string name) tracer_state {
    neurx.ad.tracer.new_tracer_state(name)
}

func tracer_name(tracer_state state) string {
    neurx.ad.tracer.tracer_name(state)
}

func tracer_active(tracer_state state) bool {
    neurx.ad.tracer.tracer_active(state)
}

func tracer_linearized(tracer_state state) bool {
    neurx.ad.tracer.tracer_linearized(state)
}

func tracer_op_count(tracer_state state) int {
    neurx.ad.tracer.tracer_op_count(state)
}

func tracer_tag_count(tracer_state state) int {
    neurx.ad.tracer.tracer_tag_count(state)
}

func tracer_param_count(tracer_state state) int {
    neurx.ad.tracer.tracer_param_count(state)
}

func tracer_input_count(tracer_state state) int {
    neurx.ad.tracer.tracer_input_count(state)
}

func tracer_output_count(tracer_state state) int {
    neurx.ad.tracer.tracer_output_count(state)
}

func tracer_eqn_count(tracer_state state) int {
    neurx.ad.tracer.tracer_eqn_count(state)
}

func tracer_has_op(tracer_state state, string op) bool {
    neurx.ad.tracer.tracer_has_op(state, op)
}

func tracer_has_input(tracer_state state, string input) bool {
    neurx.ad.tracer.tracer_has_input(state, input)
}

func tracer_has_output(tracer_state state, string output) bool {
    neurx.ad.tracer.tracer_has_output(state, output)
}

func tracer_has_eqn(tracer_state state, string primitive) bool {
    neurx.ad.tracer.tracer_has_eqn(state, primitive)
}

func tracer_has_tag(tracer_state state, string tag) bool {
    neurx.ad.tracer.tracer_has_tag(state, tag)
}

func tracer_add_op(tracer_state state, string op) tracer_state {
    neurx.ad.tracer.tracer_add_op(state, op)
}

func tracer_add_op_with_param(tracer_state state, string op, string param) tracer_state {
    neurx.ad.tracer.tracer_add_op_with_param(state, op, param)
}

func tracer_add_eqn(tracer_state state, string primitive) tracer_state {
    neurx.ad.tracer.tracer_add_eqn(state, primitive)
}

func tracer_add_eqn_with_param(tracer_state state, string primitive, string param) tracer_state {
    neurx.ad.tracer.tracer_add_eqn_with_param(state, primitive, param)
}

func tracer_add_eqn_with_io(tracer_state state, string primitive, []string params, []string inputs, []string outputs) tracer_state {
    neurx.ad.tracer.tracer_add_eqn_with_io(state, primitive, params, inputs, outputs)
}

func tracer_add_input(tracer_state state, string input) tracer_state {
    neurx.ad.tracer.tracer_add_input(state, input)
}

func tracer_add_output(tracer_state state, string output) tracer_state {
    neurx.ad.tracer.tracer_add_output(state, output)
}

func tracer_add_tag(tracer_state state, string tag) tracer_state {
    neurx.ad.tracer.tracer_add_tag(state, tag)
}

func tracer_clear_tags(tracer_state state) tracer_state {
    neurx.ad.tracer.tracer_clear_tags(state)
}

func tracer_clear_inputs(tracer_state state) tracer_state {
    neurx.ad.tracer.tracer_clear_inputs(state)
}

func tracer_clear_outputs(tracer_state state) tracer_state {
    neurx.ad.tracer.tracer_clear_outputs(state)
}

func tracer_clear_eqns(tracer_state state) tracer_state {
    neurx.ad.tracer.tracer_clear_eqns(state)
}

func tracer_set_active(tracer_state state, bool active) tracer_state {
    neurx.ad.tracer.tracer_set_active(state, active)
}

func tracer_set_linearized(tracer_state state, bool linearized) tracer_state {
    neurx.ad.tracer.tracer_set_linearized(state, linearized)
}

func tracer_state_dict(tracer_state state) tracer_state {
    neurx.ad.tracer.tracer_state_dict(state)
}

func tracer_load_state_dict(tracer_state state, tracer_state other) tracer_state {
    neurx.ad.tracer.tracer_load_state_dict(state, other)
}

func tracer_capture(tracer_state state, string op) tracer_state {
    neurx.ad.tracer.tracer_capture(state, op)
}

func tracer_capture_with_param(tracer_state state, string op, string param) tracer_state {
    neurx.ad.tracer.tracer_capture_with_param(state, op, param)
}

func tracer_capture_with_io(tracer_state state, string op, []string params, []string inputs, []string outputs) tracer_state {
    neurx.ad.tracer.tracer_capture_with_io(state, op, params, inputs, outputs)
}

func tracer_to_transform_chain(tracer_state state) transform_chain {
    neurx.ad.tracer.tracer_to_transform_chain(state)
}

func transform_chain_to_tracer(transform_chain chain, string name) tracer_state {
    neurx.ad.tracer.transform_chain_to_tracer(chain, name)
}

func new_ir_graph(string name) ir_graph {
    neurx.ad.ir.new_ir_graph(name)
}

func ir_name(ir_graph graph) string {
    neurx.ad.ir.ir_name(graph)
}

func ir_eqn_count(ir_graph graph) int {
    neurx.ad.ir.ir_eqn_count(graph)
}

func ir_primitive_count(ir_graph graph) int {
    neurx.ad.ir.ir_primitive_count(graph)
}

func ir_param_count(ir_graph graph) int {
    neurx.ad.ir.ir_param_count(graph)
}

func ir_input_count(ir_graph graph) int {
    neurx.ad.ir.ir_input_count(graph)
}

func ir_output_count(ir_graph graph) int {
    neurx.ad.ir.ir_output_count(graph)
}

func ir_has_primitive(ir_graph graph, string primitive) bool {
    neurx.ad.ir.ir_has_primitive(graph, primitive)
}

func ir_ready(ir_graph graph) bool {
    neurx.ad.ir.ir_ready(graph)
}

func ir_is_linearized(ir_graph graph) bool {
    neurx.ad.ir.ir_is_linearized(graph)
}

func ir_add_eqn(ir_graph graph, string primitive) ir_graph {
    neurx.ad.ir.ir_add_eqn(graph, primitive)
}

func ir_add_eqn_with_params(ir_graph graph, string primitive, []string params) ir_graph {
    neurx.ad.ir.ir_add_eqn_with_params(graph, primitive, params)
}

func ir_add_eqn_with_io(ir_graph graph, string primitive, []string params, []string inputs, []string outputs) ir_graph {
    neurx.ad.ir.ir_add_eqn_with_io(graph, primitive, params, inputs, outputs)
}

func ir_add_input(ir_graph graph, string input) ir_graph {
    neurx.ad.ir.ir_add_input(graph, input)
}

func ir_add_output(ir_graph graph, string output) ir_graph {
    neurx.ad.ir.ir_add_output(graph, output)
}

func ir_state_dict(ir_graph graph) ir_graph {
    neurx.ad.ir.ir_state_dict(graph)
}

func ir_load_state_dict(ir_graph graph, ir_graph other) ir_graph {
    neurx.ad.ir.ir_load_state_dict(graph, other)
}

func ir_from_tracer(tracer_state state, string name) ir_graph {
    neurx.ad.ir.ir_from_tracer(state, name)
}

func ir_to_tracer(ir_graph graph) tracer_state {
    neurx.ad.ir.ir_to_tracer(graph)
}

func ir_capture(ir_graph graph, string primitive) ir_graph {
    neurx.ad.ir.ir_capture(graph, primitive)
}

func ir_capture_with_params(ir_graph graph, string primitive, []string params) ir_graph {
    neurx.ad.ir.ir_capture_with_params(graph, primitive, params)
}

func ir_capture_with_io(ir_graph graph, string primitive, []string params, []string inputs, []string outputs) ir_graph {
    neurx.ad.ir.ir_capture_with_io(graph, primitive, params, inputs, outputs)
}

func ir_to_transform_chain(ir_graph graph) transform_chain {
    neurx.ad.ir.ir_to_transform_chain(graph)
}

func transform_chain_to_jaxpr(transform_chain chain, string name) ir_graph {
    neurx.ad.ir.transform_chain_to_jaxpr(chain, name)
}
