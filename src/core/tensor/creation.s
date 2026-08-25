package neurx.creation

struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func numel([]int shape) int {
    int n = 1
    for i in 0..len(shape) {
        n = n * shape[i]
    }
    n
}

func make([]int shape, float value, bool requires_grad) tensor {
    int n = numel(shape)
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

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func fill_ramp(tensor out, float low, float high) tensor {
    int n = len(out.data)
    if n <= 0 {
        return out
    }
    if n == 1 {
        out.data[0] = low
        return out
    }
    float span = high - low
    int i = 0
    for i < n {
        out.data[i] = low + span * (i / (n - 1))
        i = i + 1
    }
    out
}

func zeros([]int shape) tensor {
    make(shape, 0.0, false)
}

func ones([]int shape) tensor {
    make(shape, 1.0, false)
}

func full([]int shape, float value) tensor {
    make(shape, value, false)
}

func zeros_like(tensor like) tensor {
    make(like.shape, 0.0, like.requires_grad)
}

func ones_like(tensor like) tensor {
    make(like.shape, 1.0, like.requires_grad)
}

func full_like(tensor like, float value) tensor {
    make(like.shape, value, like.requires_grad)
}

func eye(int n, int m) tensor {
    []int shape = []int{cap: 2}
    shape[0] = n
    shape[1] = m
    tensor out = make(shape, 0.0, false)
    int diag = n
    if m < diag {
        diag = m
    }
    int i = 0
    for i < diag {
        out.data[i * m + i] = 1.0
        i = i + 1
    }
    out
}

func arange(int start, int end, int step) tensor {
    if step == 0 {
        return make([0], 0.0, false)
    }
    int count = 0
    int value = start
    if step > 0 {
        for value < end {
            count = count + 1
            value = value + step
        }
    } else {
        for value > end {
            count = count + 1
            value = value + step
        }
    }
    []int shape = []int{cap: 1}
    shape[0] = count
    tensor out = make(shape, 0.0, false)
    value = start
    int i = 0
    if step > 0 {
        for value < end {
            out.data[i] = value
            value = value + step
            i = i + 1
        }
    } else {
        for value > end {
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
    tensor out = make(shape, 0.0, false)
    if steps <= 0 {
        return out
    }
    if steps == 1 {
        out.data[0] = start
        return out
    }
    float step_size = (end - start) / (steps - 1)
    int i = 0
    for i < steps {
        out.data[i] = start + step_size * i
        i = i + 1
    }
    out
}

func logspace(float start, float end, int steps, float base) tensor {
    linspace(start, end, steps)
}

func rand([]int shape) tensor {
    tensor out = make(shape, 0.0, false)
    int n = len(out.data)
    int i = 0
    for i < n {
        out.data[i] = (i + 1) / (n + 1)
        i = i + 1
    }
    out
}

func randn([]int shape) tensor {
    tensor out = make(shape, 0.0, false)
    int n = len(out.data)
    int i = 0
    for i < n {
        int j = 0
        for j < i {
            j = j + 2
        }
        if j == i {
            out.data[i] = (i + 1) / (n + 1)
        } else {
            out.data[i] = -((i + 1) / (n + 1))
        }
        i = i + 1
    }
    out
}

func randint(int low, int high, []int shape) tensor {
    tensor out = make(shape, 0.0, false)
    int n = len(out.data)
    int span = high - low
    if span <= 0 {
        return out
    }
    int i = 0
    for i < n {
        int value = low + i
        for value >= high {
            value = value - span
        }
        out.data[i] = value
        i = i + 1
    }
    out
}

func randperm(int n) tensor {
    []int shape = []int{cap: 1}
    shape[0] = n
    tensor out = make(shape, 0.0, false)
    int i = 0
    for i < n {
        out.data[i] = i
        i = i + 1
    }
    out
}

func normal(float mean, float std, []int shape) tensor {
    tensor out = make(shape, 0.0, false)
    int n = len(out.data)
    if n <= 0 {
        return out
    }
    int i = 0
    for i < n {
        float centered = (i / (n - 1)) * 2.0 - 1.0
        if n == 1 {
            centered = 0.0
        }
        out.data[i] = mean + std * centered
        i = i + 1
    }
    out
}

func uniform(float low, float high, []int shape) tensor {
    tensor out = make(shape, 0.0, false)
    fill_ramp(out, low, high)
}

func empty([]int shape) tensor {
    make(shape, 0.0, false)
}

func empty_like(tensor like) tensor {
    make(like.shape, 0.0, like.requires_grad)
}
