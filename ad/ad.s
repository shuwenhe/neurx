package neurx.ad

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

func _copy_float([]float data) []float {
    neurx.engine._copy_float(data)
}

func _copy_int([]int data) []int {
    neurx.engine._copy_int(data)
}

func _copy_record(grad_record record) grad_record {
    neurx.engine._copy_record(record)
}

func _copy_records([]grad_record records) []grad_record {
    neurx.engine._copy_records(records)
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

func _copy_dual_record(dual_record record) dual_record {
    dual_record {
        id: record.id,
        shape: _copy_int(record.shape),
        requires_grad: record.requires_grad,
        primal: _copy_float(record.primal),
        tangent: _copy_float(record.tangent),
        cotangent: _copy_float(record.cotangent),
    }
}

func _copy_dual_records([]dual_record records) []dual_record {
    []dual_record out = []dual_record{cap: len(records)}
    int i = 0
    while i < len(records) {
        out[i] = _copy_dual_record(records[i])
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
        shape: _copy_int(value.shape),
        requires_grad: value.requires_grad,
        primal: _copy_float(value.data),
        tangent: zeros_like(value.data),
        cotangent: zeros_like(value.data),
    }
}

func register_dual_tensor(linearize_state state, int id, tensor value) linearize_state {
    []dual_record records = state.records
    records.push(
        dual_record {
            id: id,
            shape: _copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: _copy_float(value.data),
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
            return _copy_int(state.records[i].shape)
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
            return _copy_float(state.records[i].primal)
        }
        i = i + 1
    }
    []
}

func linearize_tangent_of(linearize_state state, int id) []float {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return _copy_float(state.records[i].tangent)
        }
        i = i + 1
    }
    []
}

func linearize_cotangent_of(linearize_state state, int id) []float {
    int i = 0
    while i < len(state.records) {
        if state.records[i].id == id {
            return _copy_float(state.records[i].cotangent)
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
        records: _copy_dual_records(state.records),
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
            shape: _copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: _copy_float(value.data),
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

func function_ready_for_linearize(function_record f, linearize_state state) bool {
    neurx.ad.function.function_ready(f) && linearize_ready(state)
}

func function_to_linearize_state(function_record f, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: _copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: _copy_float(value.data),
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
        tags: [],
    }
}

func function_capture(function_record f, tensor value) linearize_state {
    []dual_record records = []dual_record{cap: 1}
    records.push(
        dual_record {
            id: 0,
            shape: _copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: _copy_float(value.data),
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
            shape: _copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: _copy_float(value.data),
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
            shape: _copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: _copy_float(value.data),
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
            shape: _copy_int(value.shape),
            requires_grad: value.requires_grad,
            primal: _copy_float(value.data),
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
