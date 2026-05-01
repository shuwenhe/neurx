package neurx.tensor_creation

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
        data.push(value)
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
    shape.push(n)
    shape.push(m)
    _make(shape, 0.0, false)
}

func arange(int start, int end, int step) tensor {
    []int shape = []int{cap: 1}
    shape.push(1)
    _make(shape, 0.0, false)
}

func linspace(float start, float end, int steps) tensor {
    []int shape = []int{cap: 1}
    shape.push(steps)
    _make(shape, 0.0, false)
}

func logspace(float start, float end, int steps, float base) tensor {
    []int shape = []int{cap: 1}
    shape.push(steps)
    _make(shape, 0.0, false)
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
    shape.push(n)
    _make(shape, 0.0, false)
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
