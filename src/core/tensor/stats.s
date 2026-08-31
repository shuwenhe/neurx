package neurx.stats
struct tensor {
    float[] data
    int[] shape
    bool requires_grad
    option[tensor] grad
}

func clone(tensor a) tensor {
    tensor {
        data: a.data,
        shape: a.shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func copy_float(float[] data) []float {
    int n = len(data)
    float[] out = make([]float, n)
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_int(int[] data) []int {
    int n = len(data)
    int[] out = make([]int, n)
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func shape1(int n) []int {
    int[] shape = make([]int, 1)
    shape[0] = n
    shape
}

func normalize_dim(int dim, int ndim) int {
    int axis = dim
    if axis < 0 {
        axis = axis + ndim
    }
    axis
}

func shape_prod(int[] shape) int {
    int n = 1
    int i = 0
    for i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    n
}

func unravel_index(int flat_index, int[] shape) []int {
    int ndim = len(shape)
    int[] coords = make([]int, ndim)
    int i = 0
    for i < ndim {
        coords[i] = 0
        i = i + 1
    }
    int remaining = flat_index
    i = ndim - 1
    for i >= 0 {
        int size = shape[i]
        int coord = 0
        if size > 0 {
            coord = remaining - (remaining / size) * size
            remaining = remaining / size
        }
        coords[i] = coord
        i = i - 1
    }
    coords
}

func ravel_index(int[] coords, int[] shape) int {
    int ndim = len(shape)
    int flat = 0
    int stride = 1
    int i = ndim - 1
    for i >= 0 {
        flat = flat + coords[i] * stride
        stride = stride * shape[i]
        i = i - 1
    }
    flat
}

func reduce_output_shape(int[] shape, int dim) []int {
    int ndim = len(shape)
    int axis = normalize_dim(dim, ndim)
    if ndim <= 1 {
        return shape1(1)
    }
    int[] out = make([]int, ndim - 1)
    int i = 0
    int j = 0
    for i < ndim {
        if i != axis {
            out[j] = shape[i]
            j = j + 1
        }
        i = i + 1
    }
    out
}

func sorted_pair(float[] values, bool descending) tensor {
    int n = len(values)
    float[] out = copy_float(values)
    int i = 0
    for i < n {
        int best = i
        int j = i + 1
        for j < n {
            if descending {
                if out[j] > out[best] {
                    best = j
                }
            } else {
                if out[j] < out[best] {
                    best = j
                }
            }
            j = j + 1
        }
        if best != i {
            float tmp = out[i]
            out[i] = out[best]
            out[best] = tmp
        }
        i = i + 1
    }
    int[] shape = shape1(n)
    tensor {
        data: out,
        shape: shape,
        requires_grad: false,
        grad: none,
    }
}

func replace_dim_shape(int[] shape, int dim, int size) []int {
    int[] out = copy_int(shape)
    int ndim = len(shape)
    int axis = normalize_dim(dim, ndim)
    if axis >= 0 && axis < ndim {
        out[axis] = size
    }
    out
}

func sort_slice_values(float[] values, bool descending) []float {
    int n = len(values)
    int i = 0
    for i < n {
        int best = i
        int j = i + 1
        for j < n {
            if descending {
                if values[j] > values[best] {
                    best = j
                }
            } else {
                if values[j] < values[best] {
                    best = j
                }
            }
            j = j + 1
        }
        if best != i {
            float tmp = values[i]
            values[i] = values[best]
            values[best] = tmp
        }
        i = i + 1
    }
    values
}

func sort_slice_values_and_indices(float[] values, float[] indices, bool descending) {
    int n = len(values)
    int i = 0
    for i < n {
        int best = i
        int j = i + 1
        for j < n {
            if descending {
                if values[j] > values[best] {
                    best = j
                }
            } else {
                if values[j] < values[best] {
                    best = j
                }
            }
            j = j + 1
        }
        if best != i {
            float tmpv = values[i]
            values[i] = values[best]
            values[best] = tmpv
            float tmpi = indices[i]
            indices[i] = indices[best]
            indices[best] = tmpi
        }
        i = i + 1
    }
}

func slice_sorted_value(tensor a, int[] coords, int axis, int rank, bool descending) float {
    int axis_len = a.shape[axis]
    float[] values = make([]float, axis_len)
    int i = 0
    for i < axis_len {
        int[] src_coords = copy_int(coords)
        src_coords[axis] = i
        values[i] = a.data[ravel_index(src_coords, a.shape)]
        i = i + 1
    }
    values = sort_slice_values(values, descending)
    values[rank]
}

func slice_sorted_index(tensor a, int[] coords, int axis, int rank, bool descending) float {
    int axis_len = a.shape[axis]
    float[] values = make([]float, axis_len)
    float[] indices = make([]float, axis_len)
    int i = 0
    for i < axis_len {
        int[] src_coords = copy_int(coords)
        src_coords[axis] = i
        values[i] = a.data[ravel_index(src_coords, a.shape)]
        indices[i] = i
        i = i + 1
    }
    sort_slice_values_and_indices(values, indices, descending)
    indices[rank]
}

func slice_values(tensor a, int[] coords, int axis) []float {
    int axis_len = a.shape[axis]
    float[] values = make([]float, axis_len)
    int i = 0
    for i < axis_len {
        int[] src_coords = copy_int(coords)
        src_coords[axis] = i
        values[i] = a.data[ravel_index(src_coords, a.shape)]
        i = i + 1
    }
    values
}

func sort(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    if ndim <= 1 {
        return sorted_pair(a.data, false)
    }
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return sorted_pair(a.data, false)
    }
    int total = shape_prod(a.shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, a.shape)
        out[flat] = slice_sorted_value(a, coords, axis, coords[axis], false)
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: copy_int(a.shape),
        requires_grad: false,
        grad: none,
    }
}

func argsort(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    if ndim <= 1 {
        int n = len(a.data)
        float[] values = copy_float(a.data)
        float[] idx = make([]float, n)
        int i = 0
        for i < n {
            idx[i] = i
            i = i + 1
        }
        sort_slice_values_and_indices(values, idx, false)
        return tensor {
            data: idx,
            shape: shape1(n),
            requires_grad: false,
            grad: none,
        }
    }
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        int n = len(a.data)
        float[] values = copy_float(a.data)
        float[] idx = make([]float, n)
        int i = 0
        for i < n {
            idx[i] = i
            i = i + 1
        }
        sort_slice_values_and_indices(values, idx, false)
        return tensor {
            data: idx,
            shape: shape1(n),
            requires_grad: false,
            grad: none,
        }
    }
    int total = shape_prod(a.shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, a.shape)
        out[flat] = slice_sorted_index(a, coords, axis, coords[axis], false)
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: copy_int(a.shape),
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func topk(tensor a, int k) tensor {
    tensor sorted = sorted_pair(a.data, true)
    int n = len(sorted.data)
    int count = k
    if count > n {
        count = n
    }
    float[] out = make([]float, count)
    int i = 0
    for i < count {
        out[i] = sorted.data[i]
        i = i + 1
    }
    int[] shape = shape1(count)
    tensor {
        data: out,
        shape: shape,
        requires_grad: false,
        grad: none,
    }
}

func topk_dim(tensor a, int k, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return topk(a, k)
    }
    int axis_len = a.shape[axis]
    int count = k
    if count > axis_len {
        count = axis_len
    }
    int[] out_shape = replace_dim_shape(a.shape, dim, count)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        out[flat] = slice_sorted_value(a, coords, axis, coords[axis], true)
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func cumsum_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return clone(a)
    }
    int total = shape_prod(a.shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, a.shape)
        int inner = coords[axis]
        float acc = 0.0
        int i = 0
        for i <= inner {
            coords[axis] = i
            acc = acc + a.data[ravel_index(coords, a.shape)]
            i = i + 1
        }
        out[flat] = acc
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: copy_int(a.shape),
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func cumprod_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return clone(a)
    }
    int total = shape_prod(a.shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, a.shape)
        int inner = coords[axis]
        float acc = 1.0
        int i = 0
        for i <= inner {
            coords[axis] = i
            acc = acc * a.data[ravel_index(coords, a.shape)]
            i = i + 1
        }
        out[flat] = acc
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: copy_int(a.shape),
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func prod_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return clone(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float acc = 1.0
        int red = 0
        for red < a.shape[axis] {
            src_coords[axis] = red
            acc = acc * a.data[ravel_index(src_coords, a.shape)]
            red = red + 1
        }
        out[flat] = acc
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: a.requires_grad,
        grad: none,
    }
}

func unique(tensor a) tensor {
    int n = len(a.data)
    float[] out = make([]float, n)
    int count = 0
    int i = 0
    for i < n {
        bool seen = false
        int j = 0
        for j < count {
            if out[j] == a.data[i] {
                seen = true
            }
            j = j + 1
        }
        if !seen {
            out[count] = a.data[i]
            count = count + 1
        }
        i = i + 1
    }
    float[] trimmed = make([]float, count)
    i = 0
    for i < count {
        trimmed[i] = out[i]
        i = i + 1
    }
    tensor {
        data: trimmed,
        shape: shape1(count),
        requires_grad: false,
        grad: none,
    }
}

func unique_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return unique(a)
    }
    int[] out_shape = copy_int(a.shape)
    int axis_len = a.shape[axis]
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        out[flat] = 0.0
        flat = flat + 1
    }
    flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int i = 0
        int j = 0
        int[] src_coords = make([]int, ndim)
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float[] values = slice_values(a, src_coords, axis)
        float[] uniques = make([]float, axis_len)
        int unique_count = 0
        int v = 0
        for v < len(values) {
            bool seen = false
            int u = 0
            for u < unique_count {
                if uniques[u] == values[v] {
                    seen = true
                }
                u = u + 1
            }
            if !seen {
                uniques[unique_count] = values[v]
                unique_count = unique_count + 1
            }
            v = v + 1
        }
        int pos = 0
        for pos < unique_count {
            src_coords[axis] = pos
            out[ravel_index(src_coords, out_shape)] = uniques[pos]
            pos = pos + 1
        }
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func median(tensor a) tensor {
    tensor sorted = sorted_pair(a.data, false)
    int n = len(sorted.data)
    float value = 0.0
    if n > 0 {
        int half = n / 2
        if half * 2 == n {
            value = 0.5 * (sorted.data[half - 1] + sorted.data[half])
        } else {
            value = sorted.data[half]
        }
    }
    float[] out = make([]float, 1)
    out[0] = value
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func median_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return median(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float[] values = slice_values(a, src_coords, axis)
        values = sort_slice_values(values, false)
        int n = len(values)
        float value = 0.0
        if n > 0 {
            int half = n / 2
            if half * 2 == n {
                value = 0.5 * (values[half - 1] + values[half])
            } else {
                value = values[half]
            }
        }
        out[flat] = value
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func mode(tensor a) tensor {
    int n = len(a.data)
    float best_value = 0.0
    int best_count = 0
    int i = 0
    for i < n {
        int count = 0
        int j = 0
        for j < n {
            if a.data[j] == a.data[i] {
                count = count + 1
            }
            j = j + 1
        }
        if count > best_count {
            best_count = count
            best_value = a.data[i]
        }
        i = i + 1
    }
    float[] out = make([]float, 1)
    out[0] = best_value
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func mode_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return mode(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float[] values = slice_values(a, src_coords, axis)
        float best_value = 0.0
        int best_count = 0
        int i2 = 0
        for i2 < len(values) {
            int count = 0
            int j2 = 0
            for j2 < len(values) {
                if values[j2] == values[i2] {
                    count = count + 1
                }
                j2 = j2 + 1
            }
            if count > best_count {
                best_count = count
                best_value = values[i2]
            }
            i2 = i2 + 1
        }
        out[flat] = best_value
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func quantile(tensor a, float q) tensor {
    tensor sorted = sorted_pair(a.data, false)
    int n = len(sorted.data)
    float value = 0.0
    if n > 0 {
        int index = q * (n - 1)
        if index < 0 {
            index = 0
        }
        if index >= n {
            index = n - 1
        }
        value = sorted.data[index]
    }
    float[] out = make([]float, 1)
    out[0] = value
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func quantile_dim(tensor a, float q, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return quantile(a, q)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float[] values = slice_values(a, src_coords, axis)
        values = sort_slice_values(values, false)
        int n = len(values)
        float value = 0.0
        if n > 0 {
            int index = q * (n - 1)
            if index < 0 {
                index = 0
            }
            if index >= n {
                index = n - 1
            }
            value = values[index]
        }
        out[flat] = value
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func sum(tensor a) tensor {
    float acc = 0.0
    int i = 0
    for i < len(a.data) {
        acc = acc + a.data[i]
        i = i + 1
    }
    float[] out = make([]float, 1)
    out[0] = acc
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func mean(tensor a) tensor {
    int n = len(a.data)
    float acc = 0.0
    int i = 0
    for i < n {
        acc = acc + a.data[i]
        i = i + 1
    }
    if n > 0 {
        acc = acc / n
    }
    float[] out = make([]float, 1)
    out[0] = acc
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func max(tensor a) tensor {
    int n = len(a.data)
    float best = 0.0
    if n > 0 {
        best = a.data[0]
    }
    int i = 1
    for i < n {
        if a.data[i] > best {
            best = a.data[i]
        }
        i = i + 1
    }
    float[] out = make([]float, 1)
    out[0] = best
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func min(tensor a) tensor {
    int n = len(a.data)
    float best = 0.0
    if n > 0 {
        best = a.data[0]
    }
    int i = 1
    for i < n {
        if a.data[i] < best {
            best = a.data[i]
        }
        i = i + 1
    }
    float[] out = make([]float, 1)
    out[0] = best
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func argmax(tensor a) tensor {
    int n = len(a.data)
    int best_idx = 0
    float best = 0.0
    if n > 0 {
        best = a.data[0]
    }
    int i = 1
    for i < n {
        if a.data[i] > best {
            best = a.data[i]
            best_idx = i
        }
        i = i + 1
    }
    float[] out = make([]float, 1)
    out[0] = best_idx
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func argmin(tensor a) tensor {
    int n = len(a.data)
    int best_idx = 0
    float best = 0.0
    if n > 0 {
        best = a.data[0]
    }
    int i = 1
    for i < n {
        if a.data[i] < best {
            best = a.data[i]
            best_idx = i
        }
        i = i + 1
    }
    float[] out = make([]float, 1)
    out[0] = best_idx
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}

func sum_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return sum(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float acc = 0.0
        int red = 0
        for red < a.shape[axis] {
            src_coords[axis] = red
            acc = acc + a.data[ravel_index(src_coords, a.shape)]
            red = red + 1
        }
        out[flat] = acc
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func mean_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return mean(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        float acc = 0.0
        int red = 0
        for red < a.shape[axis] {
            src_coords[axis] = red
            acc = acc + a.data[ravel_index(src_coords, a.shape)]
            red = red + 1
        }
        if a.shape[axis] > 0 {
            acc = acc / a.shape[axis]
        }
        out[flat] = acc
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func max_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return max(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        src_coords[axis] = 0
        float best = a.data[ravel_index(src_coords, a.shape)]
        int red = 1
        for red < a.shape[axis] {
            src_coords[axis] = red
            float value = a.data[ravel_index(src_coords, a.shape)]
            if value > best {
                best = value
            }
            red = red + 1
        }
        out[flat] = best
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func min_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return min(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        src_coords[axis] = 0
        float best = a.data[ravel_index(src_coords, a.shape)]
        int red = 1
        for red < a.shape[axis] {
            src_coords[axis] = red
            float value = a.data[ravel_index(src_coords, a.shape)]
            if value < best {
                best = value
            }
            red = red + 1
        }
        out[flat] = best
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func argmax_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return argmax(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        src_coords[axis] = 0
        float best = a.data[ravel_index(src_coords, a.shape)]
        float best_idx = 0.0
        int red = 1
        for red < a.shape[axis] {
            src_coords[axis] = red
            float value = a.data[ravel_index(src_coords, a.shape)]
            if value > best {
                best = value
                best_idx = red * 1.0
            }
            red = red + 1
        }
        out[flat] = best_idx
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func argmin_dim(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if axis < 0 || axis >= ndim {
        return argmin(a)
    }
    int[] out_shape = reduce_output_shape(a.shape, dim)
    int total = shape_prod(out_shape)
    float[] out = make([]float, total)
    int flat = 0
    for flat < total {
        int[] coords = unravel_index(flat, out_shape)
        int[] src_coords = make([]int, ndim)
        int i = 0
        int j = 0
        for i < ndim {
            src_coords[i] = 0
            if i != axis {
                src_coords[i] = coords[j]
                j = j + 1
            }
            i = i + 1
        }
        src_coords[axis] = 0
        float best = a.data[ravel_index(src_coords, a.shape)]
        float best_idx = 0.0
        int red = 1
        for red < a.shape[axis] {
            src_coords[axis] = red
            float value = a.data[ravel_index(src_coords, a.shape)]
            if value < best {
                best = value
                best_idx = red * 1.0
            }
            red = red + 1
        }
        out[flat] = best_idx
        flat = flat + 1
    }
    tensor {
        data: out,
        shape: out_shape,
        requires_grad: false,
        grad: none,
    }
}

func cumsum(tensor a, int dim) tensor {
    return cumsum_dim(a, dim)
}

func cumprod(tensor a, int dim) tensor {
    return cumprod_dim(a, dim)
}

func prod(tensor a, int dim) tensor {
    int ndim = len(a.shape)
    int axis = normalize_dim(dim, ndim)
    if ndim > 1 && axis >= 0 && axis < ndim {
        return prod_dim(a, dim)
    }
    int n = len(a.data)
    float acc = 1.0
    int i = 0
    for i < n {
        acc = acc * a.data[i]
        i = i + 1
    }
    float[] out = make([]float, 1)
    out[0] = acc
    tensor {
        data: out,
        shape: shape1(1),
        requires_grad: false,
        grad: none,
    }
}
