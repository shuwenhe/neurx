#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <numpy/arrayobject.h>
#include <cuda_runtime.h>

#include <stdexcept>
#include <string>
#include <vector>

extern "C" void cuda_add_device_float(const float* a, const float* b, float* out, size_t n);
extern "C" void cuda_mul_device_float(const float* a, const float* b, float* out, size_t n);
extern "C" void cuda_add_bias_device_float(const float* a, const float* b, float* out, int m, int n);
extern "C" void cuda_add_bias_3d_device_float(const float* a, const float* b, float* out, int bsz, int t, int c);
extern "C" void cuda_matmul_device_float(const float* a, const float* b, float* out, int m, int k, int n);
extern "C" void cuda_layernorm_device_float(const float* a, const float* gamma, const float* beta, float* out, int m, int n, float eps);
extern "C" void cuda_softmax_device_float(const float* a, float* out, int m, int n);
extern "C" void cuda_reduce_sum_device_float(const float* a, float* out, size_t n);
extern "C" void cuda_reduce_mean_device_float(const float* a, float* out, size_t n);
extern "C" void cuda_reduce_max_device_float(const float* a, float* out, size_t n);
extern "C" void cuda_reduce_min_device_float(const float* a, float* out, size_t n);
extern "C" void cuda_reduce_sum_lastdim_device_float(const float* a, float* out, int m, int n);
extern "C" void cuda_reduce_mean_lastdim_device_float(const float* a, float* out, int m, int n);
extern "C" void cuda_reduce_max_lastdim_device_float(const float* a, float* out, int m, int n);
extern "C" void cuda_reduce_min_lastdim_device_float(const float* a, float* out, int m, int n);
extern "C" void cuda_argmax_lastdim_device_int(const float* a, int* out, int m, int n);
extern "C" void cuda_argmin_lastdim_device_int(const float* a, int* out, int m, int n);
extern "C" void cuda_transpose_2d_device_float(const float* a, float* out, int m, int n);
extern "C" void cuda_permute_3d_0_2_1_device_float(const float* a, float* out, int b, int t, int c);
extern "C" void cuda_permute_3d_1_2_0_device_float(const float* a, float* out, int b, int t, int c);

struct DeviceArray {
    void* ptr;
    size_t size;
};

static PyObject* _raise(PyObject* exc_type, const std::string& msg) {
    PyErr_SetString(exc_type, msg.c_str());
    return nullptr;
}

static void _cuda_check(cudaError_t err, const char* msg) {
    if (err != cudaSuccess) {
        std::string out = std::string(msg) + ": " + cudaGetErrorString(err);
        throw std::runtime_error(out);
    }
}

static DeviceArray* _get_device_array(PyObject* capsule) {
    return static_cast<DeviceArray*>(PyCapsule_GetPointer(capsule, "tensor.cuda.DeviceArray"));
}

static void _capsule_destructor(PyObject* capsule) {
    auto* arr = _get_device_array(capsule);
    if (!arr) {
        return;
    }
    cudaFree(arr->ptr);
    delete arr;
}

static PyObject* tensor_cuda_to_device(PyObject* /*self*/, PyObject* args) {
    PyArrayObject* a_obj = nullptr;
    if (!PyArg_ParseTuple(args, "O!", &PyArray_Type, &a_obj)) {
        return _raise(PyExc_TypeError, "expected numpy array");
    }

    if (PyArray_TYPE(a_obj) != NPY_FLOAT32 && PyArray_TYPE(a_obj) != NPY_INT32) {
        return _raise(PyExc_TypeError, "to_device: only float32/int32 supported");
    }
    if (!PyArray_ISCONTIGUOUS(a_obj)) {
        return _raise(PyExc_TypeError, "to_device: array must be contiguous");
    }

    npy_intp size = PyArray_SIZE(a_obj);
    size_t bytes = (size_t)size * (PyArray_TYPE(a_obj) == NPY_INT32 ? sizeof(int) : sizeof(float));
    void* d_ptr = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_ptr, bytes), "cudaMalloc");
        _cuda_check(cudaMemcpy(d_ptr, PyArray_DATA(a_obj), bytes, cudaMemcpyHostToDevice), "cudaMemcpy H2D");
    } catch (const std::exception& e) {
        if (d_ptr) {
            cudaFree(d_ptr);
        }
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* arr = new DeviceArray{d_ptr, (size_t)size};
    return PyCapsule_New(arr, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_to_host(PyObject* /*self*/, PyObject* args) {
    PyObject* capsule = nullptr;
    PyObject* shape_obj = nullptr;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "OO!s", &capsule, &PyTuple_Type, &shape_obj, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, shape, dtype)");
    }

    if (std::string(dtype_str) != "float32" && std::string(dtype_str) != "int32") {
        return _raise(PyExc_TypeError, "to_host: only float32/int32 supported");
    }

    auto* arr = _get_device_array(capsule);
    if (!arr) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }

    int ndim = (int)PyTuple_Size(shape_obj);
    npy_intp dims[8];
    if (ndim > 8) {
        return _raise(PyExc_ValueError, "to_host: ndim too large");
    }
    npy_intp size = 1;
    for (int i = 0; i < ndim; ++i) {
        PyObject* item = PyTuple_GetItem(shape_obj, i);
        dims[i] = (npy_intp)PyLong_AsLongLong(item);
        size *= dims[i];
    }
    if ((size_t)size != arr->size) {
        return _raise(PyExc_ValueError, "to_host: size mismatch");
    }

    int out_type = std::string(dtype_str) == "int32" ? NPY_INT32 : NPY_FLOAT32;
    PyArrayObject* out = (PyArrayObject*)PyArray_SimpleNew(ndim, dims, out_type);
    if (!out) {
        return _raise(PyExc_RuntimeError, "to_host: failed to allocate");
    }
    size_t bytes = (size_t)size * (std::string(dtype_str) == "int32" ? sizeof(int) : sizeof(float));
    try {
        _cuda_check(cudaMemcpy(PyArray_DATA(out), arr->ptr, bytes, cudaMemcpyDeviceToHost), "cudaMemcpy D2H");
    } catch (const std::exception& e) {
        Py_DECREF(out);
        return _raise(PyExc_RuntimeError, e.what());
    }
    return (PyObject*)out;
}

static PyObject* tensor_cuda_add_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    PyObject* b_capsule = nullptr;
    Py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "OOns", &a_capsule, &b_capsule, &size, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "add_device: only float32 supported");
    }

    auto* a = _get_device_array(a_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !b) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)size != a->size || (size_t)size != b->size) {
        return _raise(PyExc_ValueError, "add_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)size * sizeof(float)), "cudaMalloc");
        cuda_add_device_float((const float*)a->ptr, (const float*)b->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cudaGetLastError(), "cuda_add_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)size};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_mul_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    PyObject* b_capsule = nullptr;
    Py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "OOns", &a_capsule, &b_capsule, &size, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "mul_device: only float32 supported");
    }

    auto* a = _get_device_array(a_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !b) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)size != a->size || (size_t)size != b->size) {
        return _raise(PyExc_ValueError, "mul_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)size * sizeof(float)), "cudaMalloc");
        cuda_mul_device_float((const float*)a->ptr, (const float*)b->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cudaGetLastError(), "cuda_mul_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)size};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_add_bias_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    PyObject* b_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "OOiis", &a_capsule, &b_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "add_bias_device: only float32 supported");
    }

    auto* a = _get_device_array(a_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !b) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size || (size_t)n != b->size) {
        return _raise(PyExc_ValueError, "add_bias_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_add_bias_device_float((const float*)a->ptr, (const float*)b->ptr, (float*)d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_add_bias_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m * (size_t)n};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_add_bias_3d_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    PyObject* b_capsule = nullptr;
    int bsz = 0, t = 0, c = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "OOiiis", &a_capsule, &b_capsule, &bsz, &t, &c, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, capsule, b, t, c, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "add_bias_3d_device: only float32 supported");
    }

    auto* a = _get_device_array(a_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !b) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)bsz * (size_t)t * (size_t)c != a->size || (size_t)c != b->size) {
        return _raise(PyExc_ValueError, "add_bias_3d_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)bsz * (size_t)t * (size_t)c * sizeof(float)), "cudaMalloc");
        cuda_add_bias_3d_device_float((const float*)a->ptr, (const float*)b->ptr, (float*)d_out, bsz, t, c);
        _cuda_check(cudaGetLastError(), "cuda_add_bias_3d_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)bsz * (size_t)t * (size_t)c};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_matmul_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    PyObject* b_capsule = nullptr;
    int m = 0, k = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "OOiiis", &a_capsule, &b_capsule, &m, &k, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, capsule, m, k, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "matmul_device: only float32 supported");
    }

    auto* a = _get_device_array(a_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !b) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)k != a->size || (size_t)k * (size_t)n != b->size) {
        return _raise(PyExc_ValueError, "matmul_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_matmul_device_float((const float*)a->ptr, (const float*)b->ptr, (float*)d_out, m, k, n);
        _cuda_check(cudaGetLastError(), "cuda_matmul_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m * (size_t)n};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_layernorm_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    PyObject* g_capsule = nullptr;
    PyObject* b_capsule = nullptr;
    int m = 0, n = 0;
    float eps = 1e-5f;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "OOOiifs", &a_capsule, &g_capsule, &b_capsule, &m, &n, &eps, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, gamma, beta, m, n, eps, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "layernorm_device: only float32 supported");
    }

    auto* a = _get_device_array(a_capsule);
    auto* g = _get_device_array(g_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !g || !b) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size || (size_t)n != g->size || (size_t)n != b->size) {
        return _raise(PyExc_ValueError, "layernorm_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_layernorm_device_float((const float*)a->ptr, (const float*)g->ptr, (const float*)b->ptr, (float*)d_out, m, n, eps);
        _cuda_check(cudaGetLastError(), "cuda_layernorm_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m * (size_t)n};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_softmax_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "softmax_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "softmax_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_softmax_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_softmax_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m * (size_t)n};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_sum_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    Py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_sum_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(PyExc_ValueError, "reduce_sum_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_sum_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cudaGetLastError(), "cuda_reduce_sum_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, 1};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_mean_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    Py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_mean_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(PyExc_ValueError, "reduce_mean_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_mean_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cudaGetLastError(), "cuda_reduce_mean_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, 1};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_max_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    Py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_max_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(PyExc_ValueError, "reduce_max_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_max_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cudaGetLastError(), "cuda_reduce_max_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, 1};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_min_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    Py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_min_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(PyExc_ValueError, "reduce_min_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_min_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cudaGetLastError(), "cuda_reduce_min_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, 1};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_sum_lastdim_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_sum_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "reduce_sum_lastdim_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_sum_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_reduce_sum_lastdim_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_mean_lastdim_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_mean_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "reduce_mean_lastdim_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_mean_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_reduce_mean_lastdim_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_max_lastdim_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_max_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "reduce_max_lastdim_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_max_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_reduce_max_lastdim_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_reduce_min_lastdim_device(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "reduce_min_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "reduce_min_lastdim_device: size mismatch");
    }

    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_min_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_reduce_min_lastdim_device");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_argmax_lastdim(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "argmax_lastdim: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "argmax_lastdim: size mismatch");
    }

    int* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * sizeof(int)), "cudaMalloc");
        cuda_argmax_lastdim_device_int((const float*)a->ptr, d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_argmax_lastdim");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_argmin_lastdim(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "argmin_lastdim: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "argmin_lastdim: size mismatch");
    }

    int* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * sizeof(int)), "cudaMalloc");
        cuda_argmin_lastdim_device_int((const float*)a->ptr, d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_argmin_lastdim");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }

    auto* out = new DeviceArray{d_out, (size_t)m};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_transpose_2d(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "transpose_2d: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(PyExc_ValueError, "transpose_2d: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_transpose_2d_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cudaGetLastError(), "cuda_transpose_2d");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }
    auto* out = new DeviceArray{d_out, (size_t)m * (size_t)n};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_permute_3d_0_2_1(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int b = 0, t = 0, c = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiiis", &a_capsule, &b, &t, &c, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, b, t, c, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "permute_3d_0_2_1: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)b * (size_t)t * (size_t)c != a->size) {
        return _raise(PyExc_ValueError, "permute_3d_0_2_1: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)b * (size_t)t * (size_t)c * sizeof(float)), "cudaMalloc");
        cuda_permute_3d_0_2_1_device_float((const float*)a->ptr, (float*)d_out, b, t, c);
        _cuda_check(cudaGetLastError(), "cuda_permute_3d_0_2_1");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }
    auto* out = new DeviceArray{d_out, (size_t)b * (size_t)t * (size_t)c};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyObject* tensor_cuda_permute_3d_1_2_0(PyObject* /*self*/, PyObject* args) {
    PyObject* a_capsule = nullptr;
    int b = 0, t = 0, c = 0;
    const char* dtype_str = nullptr;
    if (!PyArg_ParseTuple(args, "Oiiis", &a_capsule, &b, &t, &c, &dtype_str)) {
        return _raise(PyExc_TypeError, "expected (capsule, b, t, c, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(PyExc_TypeError, "permute_3d_1_2_0: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(PyExc_RuntimeError, "invalid device array capsule");
    }
    if ((size_t)b * (size_t)t * (size_t)c != a->size) {
        return _raise(PyExc_ValueError, "permute_3d_1_2_0: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cudaMalloc(&d_out, (size_t)b * (size_t)t * (size_t)c * sizeof(float)), "cudaMalloc");
        cuda_permute_3d_1_2_0_device_float((const float*)a->ptr, (float*)d_out, b, t, c);
        _cuda_check(cudaGetLastError(), "cuda_permute_3d_1_2_0");
        _cuda_check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cudaFree(d_out);
        return _raise(PyExc_RuntimeError, e.what());
    }
    auto* out = new DeviceArray{d_out, (size_t)b * (size_t)t * (size_t)c};
    return PyCapsule_New(out, "tensor.cuda.DeviceArray", _capsule_destructor);
}

static PyMethodDef TensorCudaMethods[] = {
    {"to_device", tensor_cuda_to_device, METH_VARARGS, "Copy numpy array to device"},
    {"to_host", tensor_cuda_to_host, METH_VARARGS, "Copy device array to numpy"},
    {"add_device", tensor_cuda_add_device, METH_VARARGS, "CUDA elementwise add (device)"},
    {"mul_device", tensor_cuda_mul_device, METH_VARARGS, "CUDA elementwise multiply (device)"},
    {"add_bias_device", tensor_cuda_add_bias_device, METH_VARARGS, "CUDA add bias (device)"},
    {"add_bias_3d_device", tensor_cuda_add_bias_3d_device, METH_VARARGS, "CUDA add bias 3d (device)"},
    {"matmul_device", tensor_cuda_matmul_device, METH_VARARGS, "CUDA matmul (device)"},
    {"layernorm_device", tensor_cuda_layernorm_device, METH_VARARGS, "CUDA layernorm (device)"},
    {"softmax_device", tensor_cuda_softmax_device, METH_VARARGS, "CUDA softmax (device)"},
    {"reduce_sum_device", tensor_cuda_reduce_sum_device, METH_VARARGS, "CUDA reduce sum (device)"},
    {"reduce_mean_device", tensor_cuda_reduce_mean_device, METH_VARARGS, "CUDA reduce mean (device)"},
    {"reduce_max_device", tensor_cuda_reduce_max_device, METH_VARARGS, "CUDA reduce max (device)"},
    {"reduce_min_device", tensor_cuda_reduce_min_device, METH_VARARGS, "CUDA reduce min (device)"},
    {"reduce_sum_lastdim_device", tensor_cuda_reduce_sum_lastdim_device, METH_VARARGS, "CUDA reduce sum last dim (device)"},
    {"reduce_mean_lastdim_device", tensor_cuda_reduce_mean_lastdim_device, METH_VARARGS, "CUDA reduce mean last dim (device)"},
    {"reduce_max_lastdim_device", tensor_cuda_reduce_max_lastdim_device, METH_VARARGS, "CUDA reduce max last dim (device)"},
    {"reduce_min_lastdim_device", tensor_cuda_reduce_min_lastdim_device, METH_VARARGS, "CUDA reduce min last dim (device)"},
    {"argmax_lastdim", tensor_cuda_argmax_lastdim, METH_VARARGS, "CUDA argmax last dim (host indices)"},
    {"argmin_lastdim", tensor_cuda_argmin_lastdim, METH_VARARGS, "CUDA argmin last dim (host indices)"},
    {"transpose_2d", tensor_cuda_transpose_2d, METH_VARARGS, "CUDA transpose 2d"},
    {"permute_3d_0_2_1", tensor_cuda_permute_3d_0_2_1, METH_VARARGS, "CUDA permute 3d (0,2,1)"},
    {"permute_3d_1_2_0", tensor_cuda_permute_3d_1_2_0, METH_VARARGS, "CUDA permute 3d (1,2,0)"},
    {nullptr, nullptr, 0, nullptr}
};

static struct PyModuleDef tensor_cuda_module = {
    PyModuleDef_HEAD_INIT,
    "_tensor_cuda",
    "Tensor CUDA ops",
    -1,
    TensorCudaMethods,
};

PyMODINIT_FUNC PyInit__tensor_cuda(void) {
    import_array();
    return PyModule_Create(&tensor_cuda_module);
}
