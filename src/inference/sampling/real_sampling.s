package neurx.inference.real_sampling
struct sampling_params {
    float temperature
    int top_k
    float top_p
    int seed
    bool greedy
}

struct rng_state {
    int state
}

func new_sampling_params(float temperature, int top_k, float top_p, int seed) sampling_params {
    float t = temperature
    if t <= 0.0 {
        t = 1.0
    }
    int k = top_k
    if k < 0 {
        k = 0
    }
    float p = top_p
    if p <= 0.0 {
        p = 1.0
    }
    if p > 1.0 {
        p = 1.0
    }
    sampling_params{
        temperature: t,
        top_k: k,
        top_p: p,
        seed: seed,
        greedy: t == 1.0 && k <= 0 && p >= 1.0,
    }
}

func new_rng(int seed) rng_state {
    int s = seed
    if s == 0 {
        s = 123456789
    }
    rng_state{state: s}
}

func next_uint(rng_state rng) (int, rng_state) {
    int x = rng.state
    x = x ^ (x * 2048)
    x = x ^ (x / 16384)
    x = x ^ (x * 8192)
    if x < 0 {
        x = 0 - x
    }
    if x == 0 {
        x = 1
    }
    (x, rng_state{state: x})
}

func next_float(rng_state rng) (float, rng_state) {
    (int u, rng_state r) = next_uint(rng)
    float f = float(u % 1000000) / 1000000.0
    (f, r)
}

func math_exp(float x) float {
    if x > 88.0 {
        return 6.5623733e37
    }
    if x < -88.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    for i < 24 {
        term = term * x / float(i)
        result = result + term
        if term < 0.0 {
            term = 0.0 - term
        }
        if term < 1.0e-12 {
            break
        }
        i = i + 1
    }
    result
}

func apply_temperature([]float logits, float temp, int vocab_size) []float {
    []float out = make([]float, vocab_size)
    float inv = 1.0 / temp
    int i = 0
    for i < vocab_size {
        out[i] = logits[i] * inv
        i = i + 1
    }
    out
}

func softmax([]float logits, int size) []float {
    []float probs = make([]float, size)
    if size == 0 {
        return probs
    }
    float max_val = logits[0]
    int i = 1
    for i < size {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }
    float sum = 0.0
    i = 0
    for i < size {
        probs[i] = math_exp(logits[i] - max_val)
        sum = sum + probs[i]
        i = i + 1
    }
    if sum <= 0.0 {
        return probs
    }
    i = 0
    for i < size {
        probs[i] = probs[i] / sum
        i = i + 1
    }
    probs
}

func argmax([]float arr, int size) int {
    if size == 0 {
        return 0
    }
    int best = 0
    float best_val = arr[0]
    int i = 1
    for i < size {
        if arr[i] > best_val {
            best_val = arr[i]
            best = i
        }
        i = i + 1
    }
    best
}

struct index_score {
    int idx
    float score
}

func argsort_desc([]float arr, int size) []index_score {
    []index_score items = []index_score{}
    int i = 0
    for i < size {
        items = append(items, index_score{idx: i, score: arr[i]})
        i = i + 1
    }
    int n = len(items)
    int outer = 0
    for outer < n {
        int inner = 0
        for inner < n - 1 - outer {
            if items[inner].score < items[inner + 1].score {
                index_score tmp = items[inner]
                items[inner] = items[inner + 1]
                items[inner + 1] = tmp
            }
            inner = inner + 1
        }
        outer = outer + 1
    }
    items
}

func top_k_filter([]float logits, int vocab_size, int k) []float {
    if k <= 0 || k >= vocab_size {
        return logits
    }
    []index_score sorted = argsort_desc(logits, vocab_size)
    []float filtered = make([]float, vocab_size)
    int i = 0
    for i < vocab_size {
        filtered[i] = -1.0e30
        i = i + 1
    }
    i = 0
    for i < k && i < len(sorted) {
        filtered[sorted[i].idx] = logits[sorted[i].idx]
        i = i + 1
    }
    filtered
}

func top_p_filter([]float logits, int vocab_size, float p) []float {
    if p >= 1.0 {
        return logits
    }
    []index_score sorted = argsort_desc(logits, vocab_size)
    []float probs = softmax(logits, vocab_size)
    float cum = 0.0
    []bool keep = make([]bool, vocab_size)
    int i = 0
    for i < len(sorted) {
        cum = cum + probs[sorted[i].idx]
        keep[sorted[i].idx] = true
        if cum >= p {
            break
        }
        i = i + 1
    }
    []float filtered = make([]float, vocab_size)
    i = 0
    for i < vocab_size {
        if keep[i] {
            filtered[i] = logits[i]
        } else {
            filtered[i] = -1.0e30
        }
        i = i + 1
    }
    filtered
}

func sample_from_probs([]float probs, int size, rng_state rng) (int, rng_state) {
    (float r, rng_state r2) = next_float(rng)
    float cum = 0.0
    int i = 0
    for i < size {
        cum = cum + probs[i]
        if r < cum {
            return i, r2
        }
        i = i + 1
    }
    (size - 1, r2)
}

func sample([]float logits, int vocab_size, sampling_params params, rng_state rng) (int, rng_state) {
    if params.greedy || params.temperature == 0.0 {
        return (argmax(logits, vocab_size), rng)
    }
    []float scaled = apply_temperature(logits, params.temperature, vocab_size)
    if params.top_k > 0 && params.top_k < vocab_size {
        scaled = top_k_filter(scaled, vocab_size, params.top_k)
    }
    if params.top_p < 1.0 {
        scaled = top_p_filter(scaled, vocab_size, params.top_p)
    }
    []float probs = softmax(scaled, vocab_size)
    (int tok, rng_state r) = sample_from_probs(probs, vocab_size, rng)
    (tok, r)
}

func greedy_sample([]float logits, int vocab_size) int {
    argmax(logits, vocab_size)
}
