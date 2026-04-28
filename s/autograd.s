package neurx.autograd

use neurx.tensor.tensor

struct grad_fn {
}

struct grad_record {
	int id
	[]int shape
	bool requires_grad
	[]float grad
}

struct autograd_state {
	[]grad_record records
}

func new_state() autograd_state {
	autograd_state {
		records: [],
	}
}

func zeros_like([]float data) []float {
	let n = len(data)
	let mut out = []float{cap: n}
	for i in 0..n {
		out.push(0.0)
	}
	out
}

func ones_like([]float data) []float {
	let n = len(data)
	let mut out = []float{cap: n}
	for i in 0..n {
		out.push(1.0)
	}
	out
}

func register_tensor(autograd_state state, int id, tensor value) autograd_state {
	let mut records = state.records
	let grad_data = zeros_like(value.data)
	records.push(
		grad_record {
			id: id,
			shape: value.shape,
			requires_grad: value.requires_grad,
			grad: grad_data,
		}
	)

	autograd_state {
		records: records,
	}
}

func set_grad(autograd_state state, int id, []float grad) autograd_state {
	let mut records = state.records
	let n = len(records)
	for i in 0..n {
		if records[i].id == id {
			records[i].grad = grad
		}
	}

	autograd_state {
		records: records,
	}
}

func accumulate_grad(autograd_state state, int id, []float grad) autograd_state {
	let mut records = state.records
	let n = len(records)
	for i in 0..n {
		if records[i].id == id {
			let m = len(records[i].grad)
			if m == len(grad) {
				for j in 0..m {
					records[i].grad[j] = records[i].grad[j] + grad[j]
				}
			}
		}
	}

	autograd_state {
		records: records,
	}
}

func grad_of(autograd_state state, int id) []float {
	let n = len(state.records)
	for i in 0..n {
		if state.records[i].id == id {
			return state.records[i].grad
		}
	}
	[]
}

func backward_seed(autograd_state state, int loss_id, tensor loss_tensor) autograd_state {
	if !loss_tensor.requires_grad {
		return state
	}

	set_grad(state, loss_id, ones_like(loss_tensor.data))
}

func backward(tensor t) () {
}
