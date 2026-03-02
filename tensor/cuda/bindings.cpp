#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <numpy/arrayobject.h>

#include <stdexcept>
#include <string>

extern "C" void cuda_add_float(const float* a, const float* b, float* out, size_t n);
extern "C" void cuda_add_double(const double* a, const double* b, double* out, size_t n);
extern "C" void cuda_mul_float(const float* a, const float* b, float* out, size_t n);
extern "C" void cuda_mul_double(const double* a, const double* b, double* out, size_t n);

static PyObject* _raise(PyObject* exc_type, const std::string& msg) {
    PyErr_SetString(exc_type, msg.c_str());
    return nullptr;
}

static PyObject* tensor_cuda_add(PyObject* /*self*/, PyObject* args) {
    PyArrayObject* a_obj = nullptr;
    PyArrayObject* b_obj = nullptr;
    if (!PyArg_ParseTuple(args, "O!O!", &PyArray_Type, &a_obj, &PyArray_Type, &b_obj)) {
        return _raise(PyExc_TypeError, "expected two numpy arrays");
    }

    if (PyArray_NDIM(a_obj) != PyArray_NDIM(b_obj)) {
        return _raise(PyExc_ValueError, "add: ndim mismatch");
    }
    for (int i = 0; i < PyArray_NDIM(a_obj); ++i) {
        if (PyArray_DIM(a_obj, i) != PyArray_DIM(b_obj, i)) {
            return _raise(PyExc_ValueError, "add: shape mismatch");
        }
    }

    int dtype = PyArray_TYPE(a_obj);
    if (dtype != PyArray_TYPE(b_obj)) {
        return _raise(PyExc_TypeError, "add: dtype mismatch");
    }

    npy_intp size = PyArray_SIZE(a_obj);
    if (dtype != NPY_FLOAT32 && dtype != NPY_FLOAT64) {
        return _raise(PyExc_TypeError, "add: only float32/float64 supported");
    }

    PyArrayObject* out_obj = (PyArrayObject*)PyArray_SimpleNew(PyArray_NDIM(a_obj), PyArray_DIMS(a_obj), dtype);
    if (!out_obj) {
        return _raise(PyExc_RuntimeError, "add: failed to allocate output");
    }

    if (dtype == NPY_FLOAT32) {
        cuda_add_float((float*)PyArray_DATA(a_obj), (float*)PyArray_DATA(b_obj), (float*)PyArray_DATA(out_obj), (size_t)size);
    } else {
        cuda_add_double((double*)PyArray_DATA(a_obj), (double*)PyArray_DATA(b_obj), (double*)PyArray_DATA(out_obj), (size_t)size);
    }

    return (PyObject*)out_obj;
}

static PyObject* tensor_cuda_mul(PyObject* /*self*/, PyObject* args) {
    PyArrayObject* a_obj = nullptr;
    PyArrayObject* b_obj = nullptr;
    if (!PyArg_ParseTuple(args, "O!O!", &PyArray_Type, &a_obj, &PyArray_Type, &b_obj)) {
        return _raise(PyExc_TypeError, "expected two numpy arrays");
    }

    if (PyArray_NDIM(a_obj) != PyArray_NDIM(b_obj)) {
        return _raise(PyExc_ValueError, "mul: ndim mismatch");
    }
    for (int i = 0; i < PyArray_NDIM(a_obj); ++i) {
        if (PyArray_DIM(a_obj, i) != PyArray_DIM(b_obj, i)) {
            return _raise(PyExc_ValueError, "mul: shape mismatch");
        }
    }

    int dtype = PyArray_TYPE(a_obj);
    if (dtype != PyArray_TYPE(b_obj)) {
        return _raise(PyExc_TypeError, "mul: dtype mismatch");
    }

    npy_intp size = PyArray_SIZE(a_obj);
    if (dtype != NPY_FLOAT32 && dtype != NPY_FLOAT64) {
        return _raise(PyExc_TypeError, "mul: only float32/float64 supported");
    }

    PyArrayObject* out_obj = (PyArrayObject*)PyArray_SimpleNew(PyArray_NDIM(a_obj), PyArray_DIMS(a_obj), dtype);
    if (!out_obj) {
        return _raise(PyExc_RuntimeError, "mul: failed to allocate output");
    }

    if (dtype == NPY_FLOAT32) {
        cuda_mul_float((float*)PyArray_DATA(a_obj), (float*)PyArray_DATA(b_obj), (float*)PyArray_DATA(out_obj), (size_t)size);
    } else {
        cuda_mul_double((double*)PyArray_DATA(a_obj), (double*)PyArray_DATA(b_obj), (double*)PyArray_DATA(out_obj), (size_t)size);
    }

    return (PyObject*)out_obj;
}

static PyMethodDef TensorCudaMethods[] = {
    {"add", tensor_cuda_add, METH_VARARGS, "CUDA elementwise add"},
    {"mul", tensor_cuda_mul, METH_VARARGS, "CUDA elementwise multiply"},
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
