package neurx.lib.tensor

// Tensor (matrix/vector) operations library for S language
// Provides basic linear algebra operations needed for neural network training

// Vector: 1D array of floats
struct Vector {
    []float data
    int size
}

// Matrix: 2D array of floats
struct Matrix {
    []float data
    int rows
    int cols
}

// Tensor: 3D array of floats (for higher dimensional tensors)
struct Tensor {
    []float data
    int dim1
    int dim2
    int dim3
}

// Creates a vector of given size
func create_vector(int size) Vector {
    Vector v
    v.size = size
    // Initialize with zeros
    []float data
    int i = 0
    while i < size {
        data[i] = 0.0
        i = i + 1
    }
    v.data = data
    v
}

// Creates a vector with specific values
func vector_from_array([]float values) Vector {
    Vector v
    v.size = len(values)
    v.data = values
    v
}

// Creates a matrix of given dimensions
func create_matrix(int rows, int cols) Matrix {
    Matrix m
    m.rows = rows
    m.cols = cols
    
    []float data
    int i = 0
    while i < rows * cols {
        data[i] = 0.0
        i = i + 1
    }
    m.data = data
    m
}

// Creates an identity matrix
func identity_matrix(int size) Matrix {
    Matrix m = create_matrix(size, size)
    
    int i = 0
    while i < size {
        int j = 0
        while j < size {
            if i == j {
                m.data[i * size + j] = 1.0
            } else {
                m.data[i * size + j] = 0.0
            }
            j = j + 1
        }
        i = i + 1
    }
    
    m
}

// Creates a random matrix with values in [0, 1)
func random_matrix(int rows, int cols, int seed) Matrix {
    Matrix m = create_matrix(rows, cols)
    
    int state = seed
    int i = 0
    while i < rows * cols {
        // Linear congruential generator
        state = (state * 1103515245 + 12345) - ((state * 1103515245 + 12345) / 2147483648) * 2147483648
        if state < 0 {
            state = 0 - state
        }
        
        float rand_value = ((state / 65536) - ((state / 65536) / 32768) * 32768) as float
        rand_value = rand_value / 32768.0
        m.data[i] = rand_value
        
        i = i + 1
    }
    
    m
}

// Gets element from matrix
func matrix_get(Matrix m, int row, int col) float {
    if row < 0 || row >= m.rows || col < 0 || col >= m.cols {
        return 0.0
    }
    m.data[row * m.cols + col]
}

// Sets element in matrix
func matrix_set(Matrix m, int row, int col, float value) Matrix {
    if row >= 0 && row < m.rows && col >= 0 && col < m.cols {
        m.data[row * m.cols + col] = value
    }
    m
}

// Gets element from vector
func vector_get(Vector v, int idx) float {
    if idx < 0 || idx >= v.size {
        return 0.0
    }
    v.data[idx]
}

// Sets element in vector
func vector_set(Vector v, int idx, float value) Vector {
    if idx >= 0 && idx < v.size {
        v.data[idx] = value
    }
    v
}

// Dot product of two vectors
func dot_product(Vector a, Vector b) float {
    if a.size != b.size {
        return 0.0
    }
    
    float result = 0.0
    int i = 0
    while i < a.size {
        result = result + a.data[i] * b.data[i]
        i = i + 1
    }
    result
}

// Vector addition: a + b
func vector_add(Vector a, Vector b) Vector {
    if a.size != b.size {
        return a
    }
    
    Vector result = create_vector(a.size)
    int i = 0
    while i < a.size {
        result.data[i] = a.data[i] + b.data[i]
        i = i + 1
    }
    result
}

// Vector subtraction: a - b
func vector_subtract(Vector a, Vector b) Vector {
    if a.size != b.size {
        return a
    }
    
    Vector result = create_vector(a.size)
    int i = 0
    while i < a.size {
        result.data[i] = a.data[i] - b.data[i]
        i = i + 1
    }
    result
}

// Scalar multiplication of vector
func vector_scale(Vector v, float scalar) Vector {
    Vector result = create_vector(v.size)
    int i = 0
    while i < v.size {
        result.data[i] = v.data[i] * scalar
        i = i + 1
    }
    result
}

// Matrix addition: A + B
func matrix_add(Matrix a, Matrix b) Matrix {
    if a.rows != b.rows || a.cols != b.cols {
        return a
    }
    
    Matrix result = create_matrix(a.rows, a.cols)
    int i = 0
    while i < a.rows * a.cols {
        result.data[i] = a.data[i] + b.data[i]
        i = i + 1
    }
    result
}

// Matrix subtraction: A - B
func matrix_subtract(Matrix a, Matrix b) Matrix {
    if a.rows != b.rows || a.cols != b.cols {
        return a
    }
    
    Matrix result = create_matrix(a.rows, a.cols)
    int i = 0
    while i < a.rows * a.cols {
        result.data[i] = a.data[i] - b.data[i]
        i = i + 1
    }
    result
}

// Scalar multiplication of matrix
func matrix_scale(Matrix m, float scalar) Matrix {
    Matrix result = create_matrix(m.rows, m.cols)
    int i = 0
    while i < m.rows * m.cols {
        result.data[i] = m.data[i] * scalar
        i = i + 1
    }
    result
}

// Matrix multiplication: A @ B (m x n @ n x p = m x p)
func matrix_multiply(Matrix a, Matrix b) Matrix {
    if a.cols != b.rows {
        // Dimension mismatch, return zero matrix
        return create_matrix(a.rows, b.cols)
    }
    
    Matrix result = create_matrix(a.rows, b.cols)
    
    int i = 0
    while i < a.rows {
        int j = 0
        while j < b.cols {
            float sum = 0.0
            int k = 0
            while k < a.cols {
                sum = sum + a.data[i * a.cols + k] * b.data[k * b.cols + j]
                k = k + 1
            }
            result.data[i * b.cols + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    
    result
}

// Matrix-vector multiplication: A @ v (m x n @ n = m)
func matrix_vector_multiply(Matrix a, Vector v) Vector {
    if a.cols != v.size {
        return create_vector(a.rows)
    }
    
    Vector result = create_vector(a.rows)
    
    int i = 0
    while i < a.rows {
        float sum = 0.0
        int j = 0
        while j < a.cols {
            sum = sum + a.data[i * a.cols + j] * v.data[j]
            j = j + 1
        }
        result.data[i] = sum
        i = i + 1
    }
    
    result
}

// Transpose matrix
func matrix_transpose(Matrix m) Matrix {
    Matrix result = create_matrix(m.cols, m.rows)
    
    int i = 0
    while i < m.rows {
        int j = 0
        while j < m.cols {
            result.data[j * m.rows + i] = m.data[i * m.cols + j]
            j = j + 1
        }
        i = i + 1
    }
    
    result
}

// ReLU activation: max(0, x)
func relu(float x) float {
    if x > 0.0 {
        return x
    }
    0.0
}

// ReLU on vector
func vector_relu(Vector v) Vector {
    Vector result = create_vector(v.size)
    int i = 0
    while i < v.size {
        result.data[i] = relu(v.data[i])
        i = i + 1
    }
    result
}

// Tanh activation
func tanh_activation(float x) float {
    float exp_2x = 1.0
    float x2 = x * 2.0
    
    // Approximation of e^(2x)
    int i = 0
    float term = 1.0
    while i < 10 {
        term = term * x2 / ((i + 1) as float)
        exp_2x = exp_2x + term
        i = i + 1
    }
    
    // (e^(2x) - 1) / (e^(2x) + 1)
    float numerator = exp_2x - 1.0
    float denominator = exp_2x + 1.0
    
    if denominator == 0.0 {
        return 0.0
    }
    
    numerator / denominator
}

// Sigmoid activation
func sigmoid(float x) float {
    // 1 / (1 + e^(-x))
    // Approximated for numerical stability
    if x > 0.0 {
        float exp_neg_x = 1.0
        int i = 0
        float term = 1.0
        while i < 10 {
            term = term * (0.0 - x) / ((i + 1) as float)
            exp_neg_x = exp_neg_x + term
            i = i + 1
        }
        return 1.0 / (1.0 + exp_neg_x)
    } else {
        float exp_x = 1.0
        int i = 0
        float term = 1.0
        while i < 10 {
            term = term * x / ((i + 1) as float)
            exp_x = exp_x + term
            i = i + 1
        }
        return exp_x / (1.0 + exp_x)
    }
}

// Softmax on vector (numerical stability version)
func vector_softmax(Vector v) Vector {
    // Find max value
    float max_val = v.data[0]
    int i = 1
    while i < v.size {
        if v.data[i] > max_val {
            max_val = v.data[i]
        }
        i = i + 1
    }
    
    // Compute exp(x_i - max_val) and sum
    []float exp_vals
    float sum = 0.0
    i = 0
    while i < v.size {
        float exp_val = 1.0
        float diff = v.data[i] - max_val
        
        // Approximate e^diff
        int j = 0
        float term = 1.0
        while j < 10 {
            term = term * diff / ((j + 1) as float)
            exp_val = exp_val + term
            j = j + 1
        }
        
        if exp_val < 0.0 {
            exp_val = 0.0
        }
        
        exp_vals[i] = exp_val
        sum = sum + exp_val
        i = i + 1
    }
    
    // Normalize
    Vector result = create_vector(v.size)
    i = 0
    while i < v.size {
        if sum > 0.0 {
            result.data[i] = exp_vals[i] / sum
        } else {
            result.data[i] = 0.0
        }
        i = i + 1
    }
    
    result
}

// L2 norm of vector
func vector_norm(Vector v) float {
    float sum = 0.0
    int i = 0
    while i < v.size {
        sum = sum + v.data[i] * v.data[i]
        i = i + 1
    }
    
    // Approximate sqrt
    if sum == 0.0 {
        return 0.0
    }
    
    float x = sum
    float result = x
    int i_iter = 0
    while i_iter < 10 {
        result = (result + x / result) * 0.5
        i_iter = i_iter + 1
    }
    result
}

// Normalize vector to unit length
func vector_normalize(Vector v) Vector {
    float norm = vector_norm(v)
    
    if norm == 0.0 {
        return v
    }
    
    return vector_scale(v, 1.0 / norm)
}

// Outer product: a ⊗ b (m x n = m vector ⊗ n vector)
func outer_product(Vector a, Vector b) Matrix {
    Matrix result = create_matrix(a.size, b.size)
    
    int i = 0
    while i < a.size {
        int j = 0
        while j < b.size {
            result.data[i * b.size + j] = a.data[i] * b.data[j]
            j = j + 1
        }
        i = i + 1
    }
    
    result
}

// Element-wise multiplication (Hadamard product)
func matrix_hadamard(Matrix a, Matrix b) Matrix {
    if a.rows != b.rows || a.cols != b.cols {
        return a
    }
    
    Matrix result = create_matrix(a.rows, a.cols)
    int i = 0
    while i < a.rows * a.cols {
        result.data[i] = a.data[i] * b.data[i]
        i = i + 1
    }
    result
}

// Frobenius norm of matrix
func matrix_frobenius_norm(Matrix m) float {
    float sum = 0.0
    int i = 0
    while i < m.rows * m.cols {
        sum = sum + m.data[i] * m.data[i]
        i = i + 1
    }
    
    // Approximate sqrt
    if sum == 0.0 {
        return 0.0
    }
    
    float x = sum
    float result = x
    int i_iter = 0
    while i_iter < 10 {
        result = (result + x / result) * 0.5
        i_iter = i_iter + 1
    }
    result
}

// Matrix row mean
func matrix_row_mean(Matrix m) Vector {
    Vector result = create_vector(m.rows)
    
    int i = 0
    while i < m.rows {
        float sum = 0.0
        int j = 0
        while j < m.cols {
            sum = sum + m.data[i * m.cols + j]
            j = j + 1
        }
        
        result.data[i] = sum / (m.cols as float)
        i = i + 1
    }
    
    result
}
