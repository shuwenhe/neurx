package neurx.inference.sampling

// ============================================================================
// Normalization & Sorting Utilities
// ========================================================================

// ========================================================================
// NORMALIZE array to sum to 1.0
// ========================================================================

func normalize([]float arr) []float {
    float sum = 0.0
    for v in arr { sum = sum + v }
    
    if sum < 1e-10 {
        // Edge case: return uniform distribution
        []float uniform = []float{cap: len(arr)}
        for i in 0..len(arr) {
            uniform[i] = 1.0 / float(len(arr))
        }
        return uniform
    }
    
    []float normalized = []float{cap: len(arr)}
    for i in 0..len(arr) {
        normalized[i] = arr[i] / sum
    }
    
    normalized
}

// ========================================================================
// ARGSORT DESCENDING
// Returns indices that would sort the array in descending order
// Uses simple selection sort (sufficient for vocab sizes up to ~100K)
// ========================================================================

func argsort_descending([]float arr) []int {
    int n = len(arr)
    if n == 0 { return [] }
    
    // Create index array
    []int indices = []int{cap: n}
    for i in 0..n {
        indices[i] = i
    }
    
    // Selection sort (descending by value)
    for i in 0..n - 1 {
        int max_idx = i
        for j in i+1 .. n {
            if arr[indices[j]] > arr[indices[max_idx]] {
                max_idx = j
            }
        }
        
        if max_idx != i {
            int temp = indices[i]
            indices[i] = indices[max_idx]
            indices[max_idx] = temp
        }
    }
    
    indices
}
