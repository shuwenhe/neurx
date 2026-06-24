package neurx.stats

struct tensor {
    []float data
    []int shape
    bool requires_grad
    option[tensor] grad
}

func clone(tensor a) tensor {
    tensor {
        data: a.data,
        shape: a.shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func shape1(int n) []int {
    []int shape = []int{cap: 1}
    shape[0] = n
    shape
}

func sorted_pair([]float values, bool descending) tensor {
    int n = len(values)
    []float out = copy_float(values)
    int i = 0
    while i < n {
        int best = i
        int j = i + 1
        while j < n {
            if descending {
                if out[j] > out[best] {
                    best = j
                }
            } else {
                if out[j] < out[best] {
                    best = j
                }
            }
            j = j + 1
        }
        if best != i {
            float tmp = out[i]
            out[i] = out[best]
            out[best] = tmp
        }
        i = i + 1
    }
    []int shape = shape1(n)
    tensor {
        data: out,
        shape: shape,
        requires_grad: false,
        grad: none,
    }
}

func sort(tensor a, int dim) tensor {
    sorted_pair(a.data, false)
}

func argsort(tensor a, int dim) tensor {
    int n = len(a.data)
    []float values = copy_float(a.data)
    []float idx = []float{cap: n}
    int i = 0
    while i < n {
        idx[i] = i
        i = i + 1
    }
    i = 0
    while i < n {
        int best = i
        int j = i + 1
        while j < n {
            if values[j] < values[best] {
                best = j
            }
            j = j + 1
        }
        if best != i {
            float tv = values[i]
            values[i] = values[best]
            values[best] = tv
            float ti = idx[i]
            idx[i] = idx[best]
            idx[best] = ti
        }
        i = i + 1
    }
    tensor {
        data: idx,
        shape: shape1(n),
        requires_grad: false,
        grad: none,
    }
}

func topk(tensor a, int k) tensor {
    tensor sorted = sorted_pair(a.data, true)
    int n = len(sorted.data)
    int count = k
    if count > n {
        count = n
    }
    []float out = []float{cap: count}
    int i = 0
    while i < count {
        out[i] = sorted.data[i]
        i = i + 1
    }
    []int shape = shape1(count)
    tensor {
        data: out,
        shape: shape,
        requires_grad: false,
        grad: none,
    }
}

func unique(tensor a) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    int count = 0
    int i = 0
    while i < n {
        bool seen = false
        int j = 0
        while j < count {
            if out[j] == a.data[i] {
                seen = true
            }
            j = j + 1
        }
        if !seen {
            out[count] = a.data[i]
            count = count + 1
        }
        i = i + 1
    }
    []float trimmed = []float{cap: count}
    i = 0
    while i < count {
        trimmed[i] = out[i]
        i = i + 1
    }
    tensor {
        data: trimmed,
        shape: shape1(count),
        requires_grad: false,
        grad: none,
    }
}

func median(tensor a) tensor {
    tensor sorted = sort(a, 0)
    int n = len(sorted.data)
    float value = 0.0
    if n > 0 {
        int half = n / 2
        if half * 2 == n {
            value = 0.5 * (sorted.data[half - 1] + sorted.data[half])
        } else {
            value = sorted.data[half]
        }
    }
    []float out = []float{cap: 1}
    out[0] = value
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func mode(tensor a) tensor {
    int n = len(a.data)
    float best_value = 0.0
    int best_count = 0
    int i = 0
    while i < n {
        int count = 0
        int j = 0
        while j < n {
            if a.data[j] == a.data[i] {
                count = count + 1
            }
            j = j + 1
        }
        if count > best_count {
            best_count = count
            best_value = a.data[i]
        }
        i = i + 1
    }
    []float out = []float{cap: 1}
    out[0] = best_value
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func quantile(tensor a, float q) tensor {
    tensor sorted = sort(a, 0)
    int n = len(sorted.data)
    float value = 0.0
    if n > 0 {
        int index = q * (n - 1)
        if index < 0 {
            index = 0
        }
        if index >= n {
            index = n - 1
        }
        value = sorted.data[index]
    }
    []float out = []float{cap: 1}
    out[0] = value
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func cumsum(tensor a, int dim) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    float acc = 0.0
    int i = 0
    while i < n {
        acc = acc + a.data[i]
        out[i] = acc
        i = i + 1
    }
    tensor {
        data: out,
        shape: copy_int(a.shape),
        requires_grad: false,
        grad: none,
    }
}

func cumprod(tensor a, int dim) tensor {
    int n = len(a.data)
    []float out = []float{cap: n}
    float acc = 1.0
    int i = 0
    while i < n {
        acc = acc * a.data[i]
        out[i] = acc
        i = i + 1
    }
    tensor {
        data: out,
        shape: copy_int(a.shape),
        requires_grad: false,
        grad: none,
    }
}

func prod(tensor a, int dim) tensor {
    int n = len(a.data)
    float acc = 1.0
    int i = 0
    while i < n {
        acc = acc * a.data[i]
        i = i + 1
    }
    []float out = []float{cap: 1}
    out[0] = acc
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}
