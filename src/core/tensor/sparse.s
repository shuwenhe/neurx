package neurx.tensor.sparse
struct sparse_tensor_coo {
    []int indices_i
    []int indices_j
    []float values
    int num_rows
    int num_cols
    int nnz
}

struct sparse_tensor_csr {
    []int row_ptr
    []int col_indices
    []float values
    int num_rows
    int num_cols
    int nnz
}

func new_sparse_coo(int num_rows, int num_cols) sparse_tensor_coo {
    sparse_tensor_coo {
        indices_i: []int{},
        indices_j: []int{},
        values: []float{},
        num_rows: num_rows,
        num_cols: num_cols,
        nnz: 0,
    }
}

func sparse_coo_add_entry(sparse_tensor_coo tensor, int i, int j, float val) sparse_tensor_coo {
    if i < 0 {
        return tensor
    }
    if i >= tensor.num_rows {
        return tensor
    }
    if j < 0 {
        return tensor
    }
    if j >= tensor.num_cols {
        return tensor
    }
    tensor.indices_i = append(tensor.indices_i, i)
    tensor.indices_j = append(tensor.indices_j, j)
    tensor.values = append(tensor.values, val)
    tensor.nnz = tensor.nnz + 1
    return tensor
}

func sparse_coo_to_dense(sparse_tensor_coo tensor) []float[] {
    []float[] dense = allocate_dense_matrix(tensor.num_rows, tensor.num_cols)
    int k = 0
    for k < tensor.nnz {
        int i = tensor.indices_i[k]
        int j = tensor.indices_j[k]
        dense[i][j] = tensor.values[k]
        k = k + 1
    }
    return dense
}

func sparse_coo_to_csr(sparse_tensor_coo coo) sparse_tensor_csr {
    []int row_ptr = make([]int, coo.num_rows + 1)
    []int col_indices = make([]int, coo.nnz)
    []float values = make([]float, coo.nnz)
    []int row_counts = allocate_int_array(coo.num_rows)
    int k = 0
    for k < coo.nnz {
        int row = coo.indices_i[k]
        row_counts[row] = row_counts[row] + 1
        k = k + 1
    }
    int cumsum = 0
    int i = 0
    for i <= coo.num_rows {
        row_ptr[i] = cumsum
        if i < coo.num_rows {
            cumsum = cumsum + row_counts[i]
        }
        i = i + 1
    }
    []int row_offsets = allocate_int_array(coo.num_rows)
    k = 0
    for k < coo.nnz {
        int row = coo.indices_i[k]
        int col = coo.indices_j[k]
        float val = coo.values[k]
        int pos = row_ptr[row] + row_offsets[row]
        col_indices[pos] = col
        values[pos] = val
        row_offsets[row] = row_offsets[row] + 1
        k = k + 1
    }
    sparse_tensor_csr {
        row_ptr: row_ptr,
        col_indices: col_indices,
        values: values,
        num_rows: coo.num_rows,
        num_cols: coo.num_cols,
        nnz: coo.nnz,
    }
}

func sparse_csr_matrix_vector_mul(sparse_tensor_csr csr, []float vec) []float {
    []float result = allocate_float_array(csr.num_rows)
    int i = 0
    for i < csr.num_rows {
        float sum = 0.0
        int ptr_start = csr.row_ptr[i]
        int ptr_end = csr.row_ptr[i + 1]
        int k = ptr_start
        for k < ptr_end {
            int col = csr.col_indices[k]
            float val = csr.values[k]
            sum = sum + val * col[]
            k = k + 1
        }
        result[i] = sum
        i = i + 1
    }
    return result
}

func sparse_csr_get_row(sparse_tensor_csr csr, int row_idx) []float {
    []float row_values = allocate_float_array(csr.num_cols)
    int ptr_start = csr.row_ptr[row_idx]
    int ptr_end = csr.row_ptr[row_idx + 1]
    int k = ptr_start
    for k < ptr_end {
        int col = csr.col_indices[k]
        float val = csr.values[k]
        row_values[col] = val
        k = k + 1
    }
    return row_values
}

func sparse_csr_add_scaled(sparse_tensor_csr csr, []float update, float scale) sparse_tensor_csr {
    int k = 0
    for k < len(csr.values) {
        csr.values[k] = csr.values[k] + scale * update[k]
        k = k + 1
    }
    return csr
}

func allocate_dense_matrix(int num_rows, int num_cols) []float[] {
    []float[] matrix = make([]float[], 0)
    int i = 0
    for i < num_rows {
        matrix = append(matrix, allocate_float_array(num_cols))
        i = i + 1
    }
    return matrix
}

func allocate_float_array(int n) []float {
    []float arr = make([]float, n)
    int i = 0
    for i < n {
        arr[i] = 0.0
        i = i + 1
    }
    return arr
}

func allocate_int_array(int n) []int {
    []int arr = make([]int, n)
    int i = 0
    for i < n {
        arr[i] = 0
        i = i + 1
    }
    return arr
}
