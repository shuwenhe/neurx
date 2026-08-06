package neurx.inference.sampling
func min(int a, int b) int {
    if a < b { a } else { b }
}

func max(int a, int b) int {
    if a > b { a } else { b }
}

func copy_int_array([]int arr) []int {
    []int copy = []int{cap: len(arr)}
    for i in 0..len(arr) {
        copy[i] = arr[i]
    }
    copy
}

func apply_temperature([]float logits, float temp) []float {
    if temp <= 0.0 {
        return make_one_hot(argmax(logits), len(logits))
    }
    []float scaled = []float{cap: len(logits)}
    float inv_temp = 1.0 / temp
    for i in 0..len(logits) {
        scaled[i] = logits[i] * inv_temp
    }
    scaled
}

func make_one_hot(int idx, int size) []float {
    []float one_hot = []float{cap: size}
    for i in 0..size {
        one_hot[i] = 0.0
    }
    if idx >= 0 && idx < size {
        one_hot[idx] = 1.0
    }
    one_hot
}
