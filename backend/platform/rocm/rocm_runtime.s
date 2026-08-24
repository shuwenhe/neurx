package neurx.platform.rocm.runtime

import (
    "neurx.platform.rocm" as rocm_mgr
)

type rocm_device_ptr = int64
type rocm_memory_ptr = int64
type hipblas_handle = int64
type miopen_handle = int64

func rocm_device_count() int {
    rocm_mgr.rocm_device_count()
}

func rocm_set_device(int device_id) int {
    rocm_mgr.rocm_set_device(device_id)
}

func rocm_malloc(int size) rocm_memory_ptr {
    0
}

func rocm_free(rocm_memory_ptr ptr) int {
    0
}

func rocm_memcpy_h2d(rocm_memory_ptr dst, int64 src_host_ptr, int size) int {
    0
}

func rocm_memcpy_d2h(int64 dst_host_ptr, rocm_memory_ptr src, int size) int {
    0
}

func rocm_memcpy_d2d(rocm_memory_ptr dst, rocm_memory_ptr src, int size) int {
    0
}

func rocm_memory_sync() int {
    0
}

func rocm_get_memory_info() [int64, int64] {
    [0, 0]
}

func hipblas_create() hipblas_handle {
    0
}

func hipblas_destroy(hipblas_handle handle) int {
    0
}

func hipblas_sgemm(hipblas_handle handle,
                   int m, int n, int k,
                   float alpha,
                   rocm_memory_ptr A, int lda,
                   rocm_memory_ptr B, int ldb,
                   float beta,
                   rocm_memory_ptr C, int ldc) int {
    0
}

func hipblas_dgemm(hipblas_handle handle,
                   int m, int n, int k,
                   float64 alpha,
                   rocm_memory_ptr A, int lda,
                   rocm_memory_ptr B, int ldb,
                   float64 beta,
                   rocm_memory_ptr C, int ldc) int {
    0
}

func hipblas_hgemm(hipblas_handle handle,
                   int m, int n, int k,
                   float16 alpha,
                   rocm_memory_ptr A, int lda,
                   rocm_memory_ptr B, int ldb,
                   float16 beta,
                   rocm_memory_ptr C, int ldc) int {
    0
}

func miopen_create() miopen_handle {
    0
}

func miopen_destroy(miopen_handle handle) int {
    0
}

func rocm_stream_create() int64 {
    0
}

func rocm_stream_destroy(int64 stream) int {
    0
}

func rocm_stream_synchronize(int64 stream) int {
    0
}

func rocm_event_create() int64 {
    0
}

func rocm_event_record(int64 event, int64 stream) int {
    0
}

func rocm_event_synchronize(int64 event) int {
    0
}

func rocm_event_destroy(int64 event) int {
    0
}

func rocm_event_elapsed_time(int64 start_event, int64 end_event) float {
    0.0
}
