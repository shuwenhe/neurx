package neurx.indexing

struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func _clone(tensor a) tensor {
    tensor {
        data: a.data,
        shape: a.shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func _copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func _shape_prod([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    n
}

func index_select(tensor a, int dim, []int indices) tensor {
    _clone(a)
}

func masked_select(tensor a, tensor mask) tensor {
    _clone(a)
}

func masked_fill(tensor a, tensor mask, float value) tensor {
    _clone(a)
}

func masked_scatter(tensor a, tensor mask, tensor source) tensor {
    _clone(a)
}

func nonzero(tensor a) tensor {
    _clone(a)
}

func repeat_interleave(tensor a, int repeats) tensor {
    _clone(a)
}

func where(tensor condition, tensor x, tensor y) tensor {
    _clone(x)
}

func cat([]tensor tensors, int dim) tensor {
    if len(tensors) == 0 {
        tensor { data: []float{cap: 0}, shape: []int{cap: 0}, requires_grad: false, grad: none }
    } else {
        int axis = dim
        if axis < 0 {
            axis = axis + len(tensors[0].shape)
        }
        if axis != 0 {
            return _clone(tensors[0])
        }
        int total = 0
        int i = 0
        while i < len(tensors) {
            total = total + len(tensors[i].data)
            i = i + 1
        }
        []float out = []float{cap: total}
        int cursor = 0
        i = 0
        while i < len(tensors) {
            int j = 0
            while j < len(tensors[i].data) {
                out[cursor] = tensors[i].data[j]
                cursor = cursor + 1
                j = j + 1
            }
            i = i + 1
        }
        []int shape = _copy_int(tensors[0].shape)
        shape[axis] = 0
        i = 0
        while i < len(tensors) {
            shape[axis] = shape[axis] + tensors[i].shape[axis]
            i = i + 1
        }
        tensor {
            data: out,
            shape: shape,
            requires_grad: false,
            grad: none,
        }
    }
}

func split(tensor a, int sections) tensor {
    _clone(a)
}

func chunk(tensor a, int chunks) tensor {
    _clone(a)
}

func stack([]tensor tensors, int dim) tensor {
    if len(tensors) == 0 {
        tensor { data: []float{cap: 0}, shape: []int{cap: 0}, requires_grad: false, grad: none }
    } else {
        int axis = dim
        int n = len(tensors)
        int base_ndim = len(tensors[0].shape)
        if axis < 0 {
            axis = axis + base_ndim + 1
        }
        if axis != 0 {
            return _clone(tensors[0])
        }
        int total = 0
        int i = 0
        while i < n {
            total = total + len(tensors[i].data)
            i = i + 1
        }
        []float out = []float{cap: total}
        int cursor = 0
        i = 0
        while i < n {
            int j = 0
            while j < len(tensors[i].data) {
                out[cursor] = tensors[i].data[j]
                cursor = cursor + 1
                j = j + 1
            }
            i = i + 1
        }
        []int shape = []int{cap: base_ndim + 1}
        shape[0] = n
        i = 0
        while i < base_ndim {
            shape[i + 1] = tensors[0].shape[i]
            i = i + 1
        }
        tensor {
            data: out,
            shape: shape,
            requires_grad: false,
            grad: none,
        }
    }
}
