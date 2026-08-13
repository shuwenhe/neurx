package neurx.inference.numerical_compute
func sqrt_app(float x) float {
    if x <= 0.0 {
        return 1.0
    }
    float g = x * 0.5
    int j = 0
    while j < 3 {
        g = (g + x / g) * 0.5
        j = j + 1
    }
    g
}
func exp_approx(float x) float {
    float r = 1.0 + x + (x * x * 0.5) + (x * x * x * 0.166)
    r
}
func tanh(float x) float {
    float e = exp_approx(2.0 * x)
    (e - 1.0) / (e + 1.0)
}
func sigmoid(float x) float {
    1.0 / (1.0 + exp_approx(0.0 - x))
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
func main() {
    print("NeurX Numerical Compute Library\n")
}
