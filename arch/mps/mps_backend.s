package neurx.mps
import "Foundation"
import "Metal"
import "MetalPerformanceShaders"

struct mps_device {
    id: int
    name: string
    max_memory: int
    shared_memory: bool
}

struct mps_tensor {
    data: []float
    shape: []int
    device: mps_device
    gpu_buffer: pointer
}

struct mps_context {
    devices: []mps_device
    current_device: int
    command_queue: pointer
}

struct mps_kernel {
    name: string
    shader: pointer
}

func mps_available() bool {
    let devices = mtl_copy_all_devices()
    devices.count > 0
}

func mps_get_devices() []mps_device {
    let metal_devices = mtl_copy_all_devices()
    []mps_device result = []mps_device{cap: metal_devices.count}
    for i in 0..<metal_devices.count {
        let device = metal_devices[i]
        mps_device mps_dev {
            id: i,
            string name(device.name),
            int max_memory(device.maximumTextureWidth),
            shared_memory: device.hasUnifiedMemory,
        }
        result.push(mps_dev)
    }
    result
}

func mps_create_context([]mps_device devices) mps_context {
    mps_context ctx {
        devices: devices,
        current_device: 0,
        command_queue: nil,
    }
    if len(devices) > 0 {
        ctx.command_queue = nil
    }
    ctx
}

func mps_select_device(mps_context ctx, int device_id) mps_context {
    if device_id >= 0 && device_id < len(ctx.devices) {
        ctx.current_device = device_id
    }
    ctx
}

func mps_allocate_tensor([]int shape, mps_device device) mps_tensor {
    int size = 1
    for i := 0; i < len(shape); i += 1 {
        size = size * shape[i]
    }
    mps_tensor tensor {
        data: []float{cap: size},
        shape: shape,
        device: device,
        gpu_buffer: nil,
    }
    tensor
}

func mps_copy_to_device(mps_tensor tensor, []float data) mps_tensor {
    int n = len(data)
    if n > len(tensor.data) {
        n = len(tensor.data)
    }
    for i := 0; i < n; i += 1 {
        tensor.data[i] = data[i]
    }
    tensor
}

func mps_copy_from_device(mps_tensor tensor) []float {
    copy_vector(tensor.data)
}

func mps_tensor_add(mps_tensor a, mps_tensor b) mps_tensor {
    if len(a.shape) != len(b.shape) {
        return a
    }
    int size = len(a.data)
    mps_tensor result = mps_allocate_tensor(a.shape, a.device)
    for i := 0; i < size; i += 1 {
        result.data[i] = a.data[i] + b.data[i]
    }
    result
}

func mps_tensor_mul(mps_tensor a, mps_tensor b) mps_tensor {
    if len(a.shape) != len(b.shape) {
        return a
    }
    int size = len(a.data)
    mps_tensor result = mps_allocate_tensor(a.shape, a.device)
    for i := 0; i < size; i += 1 {
        result.data[i] = a.data[i] * b.data[i]
    }
    result
}

func mps_tensor_matmul(mps_tensor a, mps_tensor b) mps_tensor {
    if len(a.shape) != 2 || len(b.shape) != 2 {
        return a
    }
    int m = a.shape[0]
    int k = a.shape[1]
    int n = b.shape[1]
    mps_tensor result = mps_allocate_tensor([m, n], a.device)
    for i := 0; i < m; i += 1 {
        for j := 0; j < n; j += 1 {
            float sum = 0.0
            for l := 0; l < k; l += 1 {
                sum = sum + a.data[i*k+l] * b.data[l*n+j]
            }
            result.data[i*n+j] = sum
        }
    }
    result
}

func mps_tensor_relu(mps_tensor input) mps_tensor {
    int size = len(input.data)
    mps_tensor result = mps_allocate_tensor(input.shape, input.device)
    for i := 0; i < size; i += 1 {
        if input.data[i] > 0.0 {
            result.data[i] = input.data[i]
        } else {
            result.data[i] = 0.0
        }
    }
    result
}

func mps_tensor_softmax(mps_tensor input) mps_tensor {
    int size = len(input.data)
    mps_tensor result = mps_allocate_tensor(input.shape, input.device)
    float max_val = input.data[0]
    for i := 1; i < size; i += 1 {
        if input.data[i] > max_val {
            max_val = input.data[i]
        }
    }
    float sum_exp = 0.0
    for i := 0; i < size; i += 1 {
        float e = exp(input.data[i] - max_val)
        result.data[i] = e
        sum_exp = sum_exp + e
    }
    for i := 0; i < size; i += 1 {
        result.data[i] = result.data[i] / sum_exp
    }
    result
}

func mps_tensor_sum(mps_tensor input) float {
    float sum = 0.0
    for i := 0; i < len(input.data); i += 1 {
        sum = sum + input.data[i]
    }
    sum
}

func mps_tensor_mean(mps_tensor input) float {
    if len(input.data) == 0 {
        return 0.0
    }
    mps_tensor_sum(input) / float(len(input.data))
}

func mps_tensor_scale(mps_tensor input, float scale) mps_tensor {
    int size = len(input.data)
    mps_tensor result = mps_allocate_tensor(input.shape, input.device)
    for i := 0; i < size; i += 1 {
        result.data[i] = input.data[i] * scale
    }
    result
}

func mps_tensor_sub(mps_tensor a, mps_tensor b) mps_tensor {
    if len(a.shape) != len(b.shape) {
        return a
    }
    int size = len(a.data)
    mps_tensor result = mps_allocate_tensor(a.shape, a.device)
    for i := 0; i < size; i += 1 {
        result.data[i] = a.data[i] - b.data[i]
    }
    result
}

func mps_tensor_div(mps_tensor a, mps_tensor b) mps_tensor {
    if len(a.shape) != len(b.shape) {
        return a
    }
    int size = len(a.data)
    mps_tensor result = mps_allocate_tensor(a.shape, a.device)
    for i := 0; i < size; i += 1 {
        if b.data[i] != 0.0 {
            result.data[i] = a.data[i] / b.data[i]
        } else {
            result.data[i] = 0.0
        }
    }
    result
}

func mps_tensor_transpose(mps_tensor input, int dim0, int dim1) mps_tensor {
    if len(input.shape) < 2 {
        return input
    }
    []int new_shape = copy_int(input.shape)
    new_shape[dim0] = input.shape[dim1]
    new_shape[dim1] = input.shape[dim0]
    mps_tensor result = mps_allocate_tensor(new_shape, input.device)
    if len(input.shape) == 2 {
        int rows = input.shape[0]
        int cols = input.shape[1]
        for i := 0; i < rows; i += 1 {
            for j := 0; j < cols; j += 1 {
                result.data[j*rows+i] = input.data[i*cols+j]
            }
        }
    }
    result
}

func mps_tensor_reshape(mps_tensor input, []int new_shape) mps_tensor {
    int old_size = 1
    for i := 0; i < len(input.shape); i += 1 {
        old_size = old_size * input.shape[i]
    }
    int new_size = 1
    for i := 0; i < len(new_shape); i += 1 {
        new_size = new_size * new_shape[i]
    }
    if old_size != new_size {
        return input
    }
    mps_tensor result {
        data: copy_vector(input.data),
        shape: new_shape,
        device: input.device,
        gpu_buffer: input.gpu_buffer,
    }
    result
}

func mps_free_tensor(mps_tensor tensor) {
}

func mps_sync() {
}

func mps_get_device_info(mps_device device) string {
    "Device " + string(device.id) + ": " + device.name + " (Max Mem: " + string(device.max_memory) + ")"
}

func copy_vector([]float src) []float {
    int n = len(src)
    []float out = []float{cap: n}
    for i := 0; i < n; i += 1 {
        out[i] = src[i]
    }
    out
}

func copy_int([]int src) []int {
    int n = len(src)
    []int out = []int{cap: n}
    for i := 0; i < n; i += 1 {
        out[i] = src[i]
    }
    out
}

func exp(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}
