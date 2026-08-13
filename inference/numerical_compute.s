package neurx.inference.numerical_compute

func matmul([]float A, int a_r, int a_c, []float B, int b_c) []float {
    []float r
    int i = 0
    while i < a_r {
        int j = 0
        while j < b_c {
            float s = 0.0
            int k = 0
            while k < a_c {
                s = s + A[i * a_c + k] * B[k * b_c + j]
                k = k + 1
            }
            r[i * b_c + j] = s
            j = j + 1
        }
        i = i + 1
    }
    r
}

func dot([]float a, []float b, int n) float {
    float s = 0.0
    int i = 0
    while i < n {
        s = s + a[i] * b[i]
        i = i + 1
    }
    s
}

func add([]float a, []float b, int n) []float {
    []float r
    int i = 0
    while i < n {
        r[i] = a[i] + b[i]
        i = i + 1
    }
    r
}

func scale([]float v, float s, int n) []float {
    []float r
    int i = 0
    while i < n {
        r[i] = v[i] * s
        i = i + 1
    }
    r
}

func relu(float x) float {
    if x > 0.0 {
        return x
    }
    0.0
}

func gelu(float x) float {
    float t = 0.5 * (1.0 + tanh(0.797 * (x + 0.045 * x * x * x)))
    x * t
}

func sigmoid(float x) float {
    1.0 / (1.0 + exp_approx(0.0 - x))
}

func softmax([]float l, int n) []float {
    float m = l[0]
    int i = 1
    while i < n {
        if l[i] > m {
            m = l[i]
        }
        i = i + 1
    }
    
    []float e
    float s = 0.0
    i = 0
    while i < n {
        float v = exp_approx(l[i] - m)
        e[i] = v
        s = s + v
        i = i + 1
    }
    
    []float r
    i = 0
    while i < n {
        r[i] = e[i] / s
        i = i + 1
    }
    r
}

func sqrt_app(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float g = x * 0.5
    int j = 0
    while j < 5 {
        g = (g + x / g) * 0.5
        j = j + 1
    }
    g
}

func exp_approx(float x) float {
    float r = 1.0 + x + (x * x * 0.5) + (x * x * x * 0.166667)
    if r < 0.01 {
        return 0.01
    }
    r
}

func tanh(float x) float {
    float e = exp_approx(2.0 * x)
    (e - 1.0) / (e + 1.0)
}

func main() {
    print("Numerical compute library initialized.\n")
}
