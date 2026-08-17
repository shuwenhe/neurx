package neurx.lib.tensor

struct vector {
    []float data
    int size
}

struct matrix {
    []float data
    int rows
    int cols
}

struct tensor_2 {
    []float data
    int dim1
    int dim2
    int dim3
}

func create_vector(int size) vector {
    vector v
    v.size = size
    []float data
    int i = 0
    while i < size {
        data[i] = 0.0
        i = i + 1
    }
    v.data = data
    v
}

func vector_from_array([]float values) vector {
    vector v
    v.size = len(values)
    v.data = values
    v
}

func create_matrix(int rows, int cols) matrix {
    matrix m
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

func identity_matrix(int size) matrix {
    matrix m = create_matrix(size, size)
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

func random_matrix(int rows, int cols, int seed) matrix {
    matrix m = create_matrix(rows, cols)
    int state = seed
    int i = 0
    while i < rows * cols {
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

func matrix_get(matrix m, int row, int col) float {
    if row < 0 || row >= m.rows || col < 0 || col >= m.cols {
        return 0.0
    }
    m.data[row * m.cols + col]
}

func matrix_set(matrix m, int row, int col, float value) matrix {
    if row >= 0 && row < m.rows && col >= 0 && col < m.cols {
        m.data[row * m.cols + col] = value
    }
    m
}

func vector_get(vector v, int idx) float {
    if idx < 0 || idx >= v.size {
        return 0.0
    }
    v.data[idx]
}

func vector_set(vector v, int idx, float value) vector {
    if idx >= 0 && idx < v.size {
        v.data[idx] = value
    }
    v
}

func dot_product(vector a, vector b) float {
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

func vector_add(vector a, vector b) vector {
    if a.size != b.size {
        return a
    }
    vector result = create_vector(a.size)
    int i = 0
    while i < a.size {
        result.data[i] = a.data[i] + b.data[i]
        i = i + 1
    }
    result
}

func vector_subtract(vector a, vector b) vector {
    if a.size != b.size {
        return a
    }
    vector result = create_vector(a.size)
    int i = 0
    while i < a.size {
        result.data[i] = a.data[i] - b.data[i]
        i = i + 1
    }
    result
}

func vector_scale(vector v, float scalar) vector {
    vector result = create_vector(v.size)
    int i = 0
    while i < v.size {
        result.data[i] = v.data[i] * scalar
        i = i + 1
    }
    result
}

func matrix_add(matrix a, matrix b) matrix {
    if a.rows != b.rows || a.cols != b.cols {
        return a
    }
    matrix result = create_matrix(a.rows, a.cols)
    int i = 0
    while i < a.rows * a.cols {
        result.data[i] = a.data[i] + b.data[i]
        i = i + 1
    }
    result
}

func matrix_subtract(matrix a, matrix b) matrix {
    if a.rows != b.rows || a.cols != b.cols {
        return a
    }
    matrix result = create_matrix(a.rows, a.cols)
    int i = 0
    while i < a.rows * a.cols {
        result.data[i] = a.data[i] - b.data[i]
        i = i + 1
    }
    result
}

func matrix_scale(matrix m, float scalar) matrix {
    matrix result = create_matrix(m.rows, m.cols)
    int i = 0
    while i < m.rows * m.cols {
        result.data[i] = m.data[i] * scalar
        i = i + 1
    }
    result
}

func matrix_multiply(matrix a, matrix b) matrix {
    if a.cols != b.rows {
        return create_matrix(a.rows, b.cols)
    }
    matrix result = create_matrix(a.rows, b.cols)
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

func matrix_vector_multiply(matrix a, vector v) vector {
    if a.cols != v.size {
        return create_vector(a.rows)
    }
    vector result = create_vector(a.rows)
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

func matrix_transpose(matrix m) matrix {
    matrix result = create_matrix(m.cols, m.rows)
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

func relu(float x) float {
    if x > 0.0 {
        return x
    }
    0.0
}

func vector_relu(vector v) vector {
    vector result = create_vector(v.size)
    int i = 0
    while i < v.size {
        result.data[i] = relu(v.data[i])
        i = i + 1
    }
    result
}

func tanh_activation(float x) float {
    float exp_2x = 1.0
    float x2 = x * 2.0
    int i = 0
    float term = 1.0
    while i < 10 {
        term = term * x2 / ((i + 1) as float)
        exp_2x = exp_2x + term
        i = i + 1
    }
    float numerator = exp_2x - 1.0
    float denominator = exp_2x + 1.0
    if denominator == 0.0 {
        return 0.0
    }
    numerator / denominator
}

func sigmoid(float x) float {
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

func vector_softmax(vector v) vector {
    float max_val = v.data[0]
    int i = 1
    while i < v.size {
        if v.data[i] > max_val {
            max_val = v.data[i]
        }
        i = i + 1
    }
    []float exp_vals
    float sum = 0.0
    i = 0
    while i < v.size {
        float exp_val = 1.0
        float diff = v.data[i] - max_val
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
    vector result = create_vector(v.size)
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

func vector_norm(vector v) float {
    float sum = 0.0
    int i = 0
    while i < v.size {
        sum = sum + v.data[i] * v.data[i]
        i = i + 1
    }
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

func vector_normalize(vector v) vector {
    float norm = vector_norm(v)
    if norm == 0.0 {
        return v
    }
    return vector_scale(v, 1.0 / norm)
}

func outer_product(vector a, vector b) matrix {
    matrix result = create_matrix(a.size, b.size)
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

func matrix_hadamard(matrix a, matrix b) matrix {
    if a.rows != b.rows || a.cols != b.cols {
        return a
    }
    matrix result = create_matrix(a.rows, a.cols)
    int i = 0
    while i < a.rows * a.cols {
        result.data[i] = a.data[i] * b.data[i]
        i = i + 1
    }
    result
}

func matrix_frobenius_norm(matrix m) float {
    float sum = 0.0
    int i = 0
    while i < m.rows * m.cols {
        sum = sum + m.data[i] * m.data[i]
        i = i + 1
    }
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

func matrix_row_mean(matrix m) vector {
    vector result = create_vector(m.rows)
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
