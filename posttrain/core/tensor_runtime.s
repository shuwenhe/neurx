package neurx.posttrain.core.tensor_runtime

use std.io.println

struct tensor_s {
    []float data
    []int shape
    []int strides
    int rank
    int total_elements
    string dtype
    string device
}

struct tensor_metadata_s {
    []int shape
    []int strides
    int rank
    int total_elements
    string dtype
    string device
    int offset
}

func new_tensor_s([]float data_ptr, []int shape_list) tensor_s {
    int total = 1
    int i = 0
    while i < len(shape_list) {
        total = total * shape_list[i]
        i = i + 1
    }
    
    []int strides = compute_strides_s(shape_list)
    
    tensor_s {
        data: data_ptr,
        shape: shape_list,
        strides: strides,
        rank: len(shape_list),
        total_elements: total,
        dtype: "float32",
        device: "cpu",
    }
}

func compute_strides_s([]int shape_list) []int {
    []int strides
    
    if len(shape_list) == 0 {
        return strides
    }
    
    int stride = 1
    int i = len(shape_list) - 1
    while i >= 0 {
        strides = append(strides, stride)
        stride = stride * shape_list[i]
        i = i - 1
    }
    
    reverse_int_array_s(strides)
}

func reverse_int_array_s([]int arr) []int {
    []int reversed
    int i = len(arr) - 1
    while i >= 0 {
        reversed = append(reversed, arr[i])
        i = i - 1
    }
    reversed
}

func tensor_get_flat_index_s(tensor_s t, []int indices) int {
    int index = 0
    int i = 0
    while i < len(indices) {
        if i < len(t.strides) {
            index = index + indices[i] * t.strides[i]
        }
        i = i + 1
    }
    index
}

func tensor_reshape_s(tensor_s t, []int new_shape) tensor_s {
    int new_total = 1
    int i = 0
    while i < len(new_shape) {
        new_total = new_total * new_shape[i]
        i = i + 1
    }
    
    if new_total != t.total_elements {
        println("[ERROR] reshape: total elements mismatch")
        return t
    }
    
    []int new_strides = compute_strides_s(new_shape)
    
    tensor_s {
        data: t.data,
        shape: new_shape,
        strides: new_strides,
        rank: len(new_shape),
        total_elements: new_total,
        dtype: t.dtype,
        device: t.device,
    }
}

func tensor_transpose_2d_s(tensor_s t) tensor_s {
    if t.rank != 2 {
        println("[ERROR] transpose: only 2D tensors supported")
        return t
    }
    
    []int new_shape = make([]int, 0)
    new_shape = append(new_shape, t.shape[1])
    new_shape = append(new_shape, t.shape[0])
    
    tensor_s {
        data: t.data,
        shape: new_shape,
        strides: make([]int, 2),
        rank: 2,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func tensor_slice_s(tensor_s t, int start, int end) tensor_s {
    if start < 0 || end > len(t.data) || start > end {
        println("[ERROR] slice: invalid indices")
        return t
    }
    
    []float sliced_data = make([]float, 0)
    int i = start
    while i < end {
        sliced_data = append(sliced_data, t.data[i])
        i = i + 1
    }
    
    []int slice_shape = make([]int, 0)
    slice_shape = append(slice_shape, end - start)
    
    tensor_s {
        data: sliced_data,
        shape: slice_shape,
        strides: make([]int, 1),
        rank: 1,
        total_elements: end - start,
        dtype: t.dtype,
        device: t.device,
    }
}

func tensor_cat_s(tensor_s t1, tensor_s t2, int dim) tensor_s {
    if t1.dtype != t2.dtype {
        println("[ERROR] cat: dtype mismatch")
        return t1
    }
    
    []float combined = make([]float, 0)
    
    int i = 0
    while i < len(t1.data) {
        combined = append(combined, t1.data[i])
        i = i + 1
    }
    
    i = 0
    while i < len(t2.data) {
        combined = append(combined, t2.data[i])
        i = i + 1
    }
    
    []int new_shape = make([]int, 0)
    int j = 0
    while j < len(t1.shape) {
        if j == dim {
            new_shape = append(new_shape, t1.shape[j] + t2.shape[j])
        } else {
            new_shape = append(new_shape, t1.shape[j])
        }
        j = j + 1
    }
    
    tensor_s {
        data: combined,
        shape: new_shape,
        strides: compute_strides_s(new_shape),
        rank: t1.rank,
        total_elements: len(combined),
        dtype: t1.dtype,
        device: t1.device,
    }
}

func tensor_to_string_s(tensor_s t) string {
    string result = "Tensor("
    
    int i = 0
    while i < len(t.shape) {
        result = result + int_to_str(t.shape[i])
        if i < len(t.shape) - 1 {
            result = result + ", "
        }
        i = i + 1
    }
    
    result = result + ", dtype=" + t.dtype + ", device=" + t.device + ")"
    result
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    string result = ""
    bool neg = false
    if n < 0 { neg = true; n = 0 - n }
    while n > 0 {
        int d = n - (n / 10) * 10
        if d == 0 { result = "0" + result }
        else if d == 1 { result = "1" + result }
        else if d == 2 { result = "2" + result }
        else if d == 3 { result = "3" + result }
        else if d == 4 { result = "4" + result }
        else if d == 5 { result = "5" + result }
        else if d == 6 { result = "6" + result }
        else if d == 7 { result = "7" + result }
        else if d == 8 { result = "8" + result }
        else if d == 9 { result = "9" + result }
        n = n / 10
    }
    if neg { result = "-" + result }
    result
}
