package neurx.platform.musa.runtime

import (
    "neurx.platform.musa" as musa_mgr
)

type musa_memory_ptr = int64
type musa_stream = int64
type mudnn_handle = int64
type mublas_handle = int64

func musa_malloc(int64 size) musa_memory_ptr {
    0
}

func musa_free(musa_memory_ptr ptr) int {
    0
}

func musa_memcpy_h2d(musa_memory_ptr dst, int64 src, int64 size) int {
    0
}

func musa_memcpy_d2h(int64 dst, musa_memory_ptr src, int64 size) int {
    0
}

func musa_memcpy_d2d(musa_memory_ptr dst, musa_memory_ptr src, int64 size) int {
    0
}

func musa_synchronize() int {
    0
}

func musa_get_device_count() int {
    musa_mgr.musa_device_count()
}

func musa_create_stream() musa_stream {
    0
}

func musa_destroy_stream(musa_stream stream) int {
    0
}

func musa_stream_synchronize(musa_stream stream) int {
    0
}

func mudnn_create() mudnn_handle {
    0
}

func mudnn_destroy(mudnn_handle handle) int {
    0
}

func mublas_create() mublas_handle {
    0
}

func mublas_destroy(mublas_handle handle) int {
    0
}

func mublas_sgemm(mublas_handle handle, int m, int n, int k,
                  float alpha, musa_memory_ptr A, musa_memory_ptr B,
                  float beta, musa_memory_ptr C) int {
    0
}

func musa_launch_kernel(string kernel_name, int grid_size, int block_size,
                       musa_stream stream, []musa_memory_ptr args) int {
    0
}
