package neurx.ad

use neurx.tensor.tensor
use neurx.engine

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
