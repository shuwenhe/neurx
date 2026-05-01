package neurx.creation

struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func _numel([]int shape) int {
    int n = 1
    for i in 0..len(shape) {
        n = n * shape[i]
    }
    n
}

func _make([]int shape, float value, bool requires_grad) tensor {
    int n = _numel(shape)
    []float data = []float{cap: n}
    for i in 0..n {
        data[i] = value
    }
    tensor {
        data: data,
        shape: shape,
        requires_grad: requires_grad,
        grad: none,
    }
}

func zeros([]int shape) tensor {
    _make(shape, 0.0, false)
}

func ones([]int shape) tensor {
    _make(shape, 1.0, false)
}

func full([]int shape, float value) tensor {
    _make(shape, value, false)
}

func zeros_like(tensor like) tensor {
    _make(like.shape, 0.0, like.requires_grad)
}

func ones_like(tensor like) tensor {
    _make(like.shape, 1.0, like.requires_grad)
}

func full_like(tensor like, float value) tensor {
    _make(like.shape, value, like.requires_grad)
}

func eye(int n, int m) tensor {
    []int shape = []int{cap: 2}
    shape[0] = n
    shape[1] = m
    tensor out = _make(shape, 0.0, false)
    int diag = n
    if m < diag {
        diag = m
    }
    int i = 0
    while i < diag {
        out.data[i * m + i] = 1.0
        i = i + 1
    }
    out
}

func arange(int start, int end, int step) tensor {
    if step == 0 {
        return _make([0], 0.0, false)
    }
    int count = 0
    int value = start
    if step > 0 {
        while value < end {
            count = count + 1
            value = value + step
        }
    } else {
        while value > end {
            count = count + 1
            value = value + step
        }
    }
    []int shape = []int{cap: 1}
    shape[0] = count
    tensor out = _make(shape, 0.0, false)
    value = start
    int i = 0
    if step > 0 {
        while value < end {
            out.data[i] = value
            value = value + step
            i = i + 1
        }
    } else {
        while value > end {
            out.data[i] = value
            value = value + step
            i = i + 1
        }
    }
    out
}

func linspace(float start, float end, int steps) tensor {
    []int shape = []int{cap: 1}
    shape[0] = steps
    tensor out = _make(shape, 0.0, false)
    if steps <= 0 {
        return out
    }
    if steps == 1 {
        out.data[0] = start
        return out
    }
    float step_size = (end - start) / (steps - 1)
    int i = 0
    while i < steps {
        out.data[i] = start + step_size * i
        i = i + 1
    }
    out
}

func logspace(float start, float end, int steps, float base) tensor {
    linspace(start, end, steps)
}

func rand([]int shape) tensor {
    _make(shape, 0.0, false)
}

func randn([]int shape) tensor {
    _make(shape, 0.0, false)
}

func randint(int low, int high, []int shape) tensor {
    _make(shape, 0.0, false)
}

func randperm(int n) tensor {
    []int shape = []int{cap: 1}
    shape[0] = n
    tensor out = _make(shape, 0.0, false)
    int i = 0
    while i < n {
        out.data[i] = i
        i = i + 1
    }
    out
}

func normal(float mean, float std, []int shape) tensor {
    _make(shape, 0.0, false)
}

func uniform(float low, float high, []int shape) tensor {
    _make(shape, 0.0, false)
}

func empty([]int shape) tensor {
    _make(shape, 0.0, false)
}

func empty_like(tensor like) tensor {
    _make(like.shape, 0.0, like.requires_grad)
}
