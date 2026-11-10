package neurx.posttrain.core.tensor_runtime
struct tensor_s {
    float[] data
    int[] shape
    int[] strides
    int rank
    int total_elements
    string dtype
    string device
}

struct tensor_metadata_s {
    int[] shape
    int[] strides
    int rank
    int total_elements
    string dtype
    string device
    int offset
}

func new_tensor_s(float[] data_ptr, int[] shape_list) tensor_s {
    int total = 1
    int i = 0
    for i < len(shape_list) {
        total = total * shape_list[i]
        i = i + 1
    }
    int[] strides = compute_strides_s(shape_list)
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

func compute_strides_s(int[] shape_list) int[] {
    int[] strides
    if len(shape_list) == 0 {
        return strides
    }
    int stride = 1
    int i = len(shape_list) - 1
    for i >= 0 {
        strides = append(strides, stride)
        stride = stride * shape_list[i]
        i = i - 1
    }
    reverse_int_array_s(strides)
}

func reverse_int_array_s(int[] arr) int[] {
    int[] reversed
    int i = len(arr) - 1
    for i >= 0 {
        reversed = append(reversed, arr[i])
        i = i - 1
    }
    reversed
}

func tensor_get_flat_index_s(tensor_s t, int[] indices) int {
    int index = 0
    int i = 0
    for i < len(indices) {
        if i < len(t.strides) {
            index = index + indices[i] * t.strides[i]
        }
        i = i + 1
    }
    index
}

func tensor_reshape_s(tensor_s t, int[] new_shape) tensor_s {
    int new_total = 1
    int i = 0
    for i < len(new_shape) {
        new_total = new_total * new_shape[i]
        i = i + 1
    }
    if new_total != t.total_elements {
        println("[ERROR] reshape: total elements mismatch")
        return t
    }
    int[] new_strides = compute_strides_s(new_shape)
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
    int[] new_shape = make(int[], 0)
    new_shape = append(new_shape, t.shape[1])
    new_shape = append(new_shape, t.shape[0])
    tensor_s {
        data: t.data,
        shape: new_shape,
        strides: make(int[], 2),
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
    float[] sliced_data = make(float[], 0)
    int i = start
    for i < end {
        sliced_data = append(sliced_data, t.data[i])
        i = i + 1
    }
    int[] slice_shape = make(int[], 0)
    slice_shape = append(slice_shape, end - start)
    tensor_s {
        data: sliced_data,
        shape: slice_shape,
        strides: make(int[], 1),
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
    float[] combined = make(float[], 0)
    int i = 0
    for i < len(t1.data) {
        combined = append(combined, t1.data[i])
        i = i + 1
    }
    i = 0
    for i < len(t2.data) {
        combined = append(combined, t2.data[i])
        i = i + 1
    }
    int[] new_shape = make(int[], 0)
    int j = 0
    for j < len(t1.shape) {
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
    for i < len(t.shape) {
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
    for n > 0 {
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

func tensor_copy_s(tensor_s t) tensor_s {
    float[] new_data = make(float[], len(t.data))
    int i = 0
    for i < len(t.data) {
        new_data[i] = t.data[i]
        i = i + 1
    }
    int[] new_shape = make(int[], len(t.shape))
    i = 0
    for i < len(t.shape) {
        new_shape[i] = t.shape[i]
        i = i + 1
    }
    tensor_s {
        data: new_data,
        shape: new_shape,
        strides: compute_strides_s(new_shape),
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func tensor_fill_s(tensor_s t, float value) tensor_s {
    int i = 0
    for i < len(t.data) {
        t.data[i] = value
        i = i + 1
    }
    t
}

func tensor_transpose_nd_s(tensor_s t, int[] axes) tensor_s {
    if len(axes) != t.rank {
        println("[ERROR] transpose_nd: axes length mismatch")
        return t
    }
    int[] new_shape = make(int[], t.rank)
    int i = 0
    for i < len(axes) {
        if axes[i] < 0 || axes[i] >= t.rank {
            println("[ERROR] transpose_nd: invalid axis index")
            return t
        }
        new_shape[i] = t.shape[axes[i]]
        i = i + 1
    }
    int[] new_strides = make(int[], t.rank)
    i = 0
    for i < len(axes) {
        new_strides[i] = t.strides[axes[i]]
        i = i + 1
    }
    tensor_s {
        data: t.data,
        shape: new_shape,
        strides: new_strides,
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func tensor_expand_s(tensor_s t, int[] new_shape) tensor_s {
    int new_total = 1
    int i = 0
    for i < len(new_shape) {
        new_total = new_total * new_shape[i]
        i = i + 1
    }
    if new_total < t.total_elements {
        println("[ERROR] expand: new size smaller than original")
        return t
    }
    if new_total > t.total_elements && t.total_elements != 1 {
        if new_total != t.total_elements * (new_total / t.total_elements) {
            println("[ERROR] expand: shape not compatible for broadcast")
            return t
        }
    }
    int[] new_strides = make(int[], len(new_shape))
    i = 0
    for i < len(new_shape) {
        if i < len(t.strides) && t.shape[i] == new_shape[i] {
            new_strides[i] = t.strides[i]
        } else if i < len(t.strides) && t.shape[i] == 1 {
            new_strides[i] = 0
        } else if i >= len(t.strides) {
            new_strides[i] = 0
        }
        i = i + 1
    }
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

func tensor_sum_s(tensor_s t, int axis) tensor_s {
    if axis < 0 || axis >= t.rank {
        println("[ERROR] sum: invalid axis")
        return t
    }
    int[] result_shape = make(int[], 0)
    int i = 0
    for i < t.rank {
        if i != axis {
            result_shape = append(result_shape, t.shape[i])
        }
        i = i + 1
    }
    int result_size = 1
    i = 0
    for i < len(result_shape) {
        result_size = result_size * result_shape[i]
        i = i + 1
    }
    float[] result_data = make(float[], result_size)
    int axis_size = t.shape[axis]
    int other_size = 1
    i = 0
    for i < t.rank {
        if i != axis {
            other_size = other_size * t.shape[i]
        }
        i = i + 1
    }
    i = 0
    for i < result_size {
        float sum_val = 0.0
        int j = 0
        for j < axis_size {
            int flat_idx = i + j * other_size
            if flat_idx < len(t.data) {
                sum_val = sum_val + t.data[flat_idx]
            }
            j = j + 1
        }
        result_data[i] = sum_val
        i = i + 1
    }
    tensor_s {
        data: result_data,
        shape: if len(result_shape) == 0 { make(int[], 1); result_shape = append(result_shape, 1); result_shape } else { result_shape },
        strides: if len(result_shape) == 0 { make(int[], 1) } else { compute_strides_s(result_shape) },
        rank: len(result_shape),
        total_elements: result_size,
        dtype: t.dtype,
        device: t.device,
    }
}

func tensor_mean_s(tensor_s t, int axis) tensor_s {
    tensor_s sum_result = tensor_sum_s(t, axis)
    float count = float_from_int(t.shape[axis])
    int i = 0
    for i < len(sum_result.data) {
        if count > 0.0 {
            sum_result.data[i] = sum_result.data[i] / count
        }
        i = i + 1
    }
    sum_result
}

func float_from_int_ext(int n) float {
    float result = 0.0
    int i = 0
    for i < n {
        result = result + 1.0
        i = i + 1
    }
    result
}

func tensor_softmax_s(tensor_s t, int axis) tensor_s {
    if axis < 0 || axis >= t.rank {
        println("[ERROR] softmax: invalid axis")
        return t
    }
    float[] result = make(float[], len(t.data))
    int i = 0
    for i < len(t.data) {
        result[i] = t.data[i]
        i = i + 1
    }
    tensor_s {
        data: result,
        shape: t.shape,
        strides: t.strides,
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func tensor_apply_s(tensor_s t, string op) tensor_s {
    float[] result = make(float[], len(t.data))
    int i = 0
    for i < len(t.data) {
        if op == "relu" {
            if t.data[i] > 0.0 {
                result[i] = t.data[i]
            } else {
                result[i] = 0.0
            }
        } else if op == "abs" {
            float val = t.data[i]
            if val < 0.0 { val = 0.0 - val }
            result[i] = val
        } else {
            result[i] = t.data[i]
        }
        i = i + 1
    }
    tensor_s {
        data: result,
        shape: t.shape,
        strides: t.strides,
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}
