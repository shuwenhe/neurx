package neurx.kernels.utils

import (
    "neurx.kernels.types"
)

struct KernelUtils {
    verbose: bool
}

func NewKernelUtils() &KernelUtils {
    return &KernelUtils{
        verbose: false
    }
}

func (KernelUtils* u) ValidateTensorShape(shape: []i32) bool {
    if len(shape) == 0 {
        return false
    }

    for i := 0; i < len(shape); i += 1 {
        if shape[i] <= 0 {
            return false
        }
    }

    return true
}

func (KernelUtils* u) ComputeTensorSize(shape: []i32) i64 {
    if !u.ValidateTensorShape(shape) {
        return 0
    }

    size := i64(1)
    for i := 0; i < len(shape); i += 1 {
        size *= i64(shape[i])
    }

    return size
}

func (KernelUtils* u) GetDataTypeSize(dtype: types.DataType) i32 {
    switch dtype {
    case types.DataType.float32:
        return 4
    case types.DataType.float16:
        return 2
    case types.DataType.bfloat16:
        return 2
    case types.DataType.int8:
        return 1
    case types.DataType.int32:
        return 4
    case types.DataType.int64:
        return 8
    default:
        return 4
    }
}

func (KernelUtils* u) ComputeMemorySize(
    shape: []i32,
    dtype: types.DataType
) i64 {

    tensor_size := u.ComputeTensorSize(shape)
    dtype_size := i64(u.GetDataTypeSize(dtype))

    return tensor_size * dtype_size
}

func (KernelUtils* u) GetLinearIndex(
    shape: []i32,
    indices: []i32
) i64 {

    if len(shape) != len(indices) {
        return -1
    }

    linear_index := i64(0)
    multiplier := i64(1)

    for i := len(shape) - 1; i >= 0; i -= 1 {
        if indices[i] < 0 || indices[i] >= shape[i] {
            return -1
        }
        linear_index += i64(indices[i]) * multiplier
        multiplier *= i64(shape[i])
    }

    return linear_index
}

func (KernelUtils* u) GetMultiDimensionalIndex(
    shape: []i32,
    linear_index: i64
) []i32 {

    indices := make([]i32, len(shape))

    remaining := linear_index
    for i := len(shape) - 1; i >= 0; i -= 1 {
        indices[i] = i32(remaining % i64(shape[i]))
        remaining = remaining / i64(shape[i])
    }

    return indices
}

func (KernelUtils* u) BroadcastShapes(
    shape1: []i32,
    shape2: []i32
) []i32 {

    max_len := len(shape1)
    if len(shape2) > max_len {
        max_len = len(shape2)
    }

    result := make([]i32, max_len)

    idx1 := len(shape1) - 1
    idx2 := len(shape2) - 1

    for i := max_len - 1; i >= 0; i -= 1 {
        dim1 := i32(1)
        dim2 := i32(1)

        if idx1 >= 0 {
            dim1 = shape1[idx1]
            idx1 -= 1
        }

        if idx2 >= 0 {
            dim2 = shape2[idx2]
            idx2 -= 1
        }

        if dim1 == 1 {
            result[i] = dim2
        } else if dim2 == 1 {
            result[i] = dim1
        } else if dim1 == dim2 {
            result[i] = dim1
        } else {

            return []i32{}
        }
    }

    return result
}

func (KernelUtils* u) AreShapesCompatible(
    shape1: []i32,
    shape2: []i32
) bool {

    if len(shape1) != len(shape2) {

        broadcasted := u.BroadcastShapes(shape1, shape2)
        return len(broadcasted) > 0
    }

    for i := 0; i < len(shape1); i += 1 {
        if shape1[i] != shape2[i] && shape1[i] != 1 && shape2[i] != 1 {
            return false
        }
    }

    return true
}

func (KernelUtils* u) TransposeShape(shape: []i32) []i32 {
    result := make([]i32, len(shape))

    for i := 0; i < len(shape); i += 1 {
        result[i] = shape[len(shape) - 1 - i]
    }

    return result
}

func (KernelUtils* u) ChunkShape(
    shape: []i32,
    chunk_size: i32,
    dim: i32
) [][]i32 {

    if dim < 0 || dim >= i32(len(shape)) {
        return [][]i32{}
    }

    chunks := make([][]i32, 0)
    dim_size := shape[dim]
    num_chunks := (dim_size + chunk_size - 1) / chunk_size

    for c := i32(0); c < num_chunks; c += 1 {
        chunk_shape := make([]i32, len(shape))

        for i := 0; i < len(shape); i += 1 {
            if i == int(dim) {
                remaining := dim_size - c * chunk_size
                if remaining > chunk_size {
                    chunk_shape[i] = chunk_size
                } else {
                    chunk_shape[i] = remaining
                }
            } else {
                chunk_shape[i] = shape[i]
            }
        }

        chunks = append(chunks, chunk_shape)
    }

    return chunks
}

func (KernelUtils* u) ComputeStrides(shape: []i32) []i64 {
    strides := make([]i64, len(shape))

    stride := i64(1)
    for i := len(shape) - 1; i >= 0; i -= 1 {
        strides[i] = stride
        stride *= i64(shape[i])
    }

    return strides
}

func (KernelUtils* u) FormatTensorInfo(
    name: string,
    shape: []i32,
    dtype: types.DataType
) string {

    result := ""
    result = result + "Tensor: " + name + "\n"
    result = result + "  Shape: ["

    for i := 0; i < len(shape); i += 1 {
        if i > 0 {
            result = result + ", "
        }
        result = result + string(shape[i])
    }

    result = result + "]\n"
    result = result + "  DType: "

    switch dtype {
    case types.DataType.float32:
        result = result + "float32"
    case types.DataType.float16:
        result = result + "float16"
    case types.DataType.bfloat16:
        result = result + "bfloat16"
    case types.DataType.int8:
        result = result + "int8"
    case types.DataType.int32:
        result = result + "int32"
    case types.DataType.int64:
        result = result + "int64"
    default:
        result = result + "unknown"
    }

    result = result + "\n"

    size := u.ComputeMemorySize(shape, dtype)
    result = result + "  Size: " + string(size) + " bytes\n"

    return result
}

func (KernelUtils* u) HasNanOrInf(data: []f32) bool {
    for i := 0; i < len(data); i += 1 {
        x := data[i]

        if x != x || x > f32(1e30) || x < f32(-1e30) {
            return true
        }
    }
    return false
}

func (KernelUtils* u) ComputeStats(data: []f32) (f32, f32, f32, f32) {
    if len(data) == 0 {
        return 0.0, 0.0, 0.0, 0.0
    }

    min_val := data[0]
    max_val := data[0]
    sum := f32(0.0)

    for i := 0; i < len(data); i += 1 {
        if data[i] < min_val {
            min_val = data[i]
        }
        if data[i] > max_val {
            max_val = data[i]
        }
        sum += data[i]
    }

    mean := sum / f32(len(data))

    var_sum := f32(0.0)
    for i := 0; i < len(data); i += 1 {
        diff := data[i] - mean
        var_sum += diff * diff
    }
    variance := var_sum / f32(len(data))
    std_dev := f32(variance ^ 0.5)

    return min_val, max_val, mean, std_dev
}

func main() {
    println("Kernel Utils Module")
    println("✅ Utility functions for kernel operations")
}
