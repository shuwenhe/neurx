package neurx.platform.xpu.runtime

import (
    "neurx.platform.xpu" as xpu_mgr
)

type xpu_memory_ptr = int64
type oneapi_queue = int64
type level_zero_device = int64

func xpu_malloc(int64 size) xpu_memory_ptr {
    0
}

func xpu_free(xpu_memory_ptr ptr) int {
    0
}

func xpu_memcpy_h2d(xpu_memory_ptr dst, int64 src, int64 size) int {
    0
}

func xpu_memcpy_d2h(int64 dst, xpu_memory_ptr src, int64 size) int {
    0
}

func xpu_memcpy_d2d(xpu_memory_ptr dst, xpu_memory_ptr src, int64 size) int {
    0
}

func xpu_synchronize() int {
    0
}

func xpu_get_device_count() int {
    xpu_mgr.xpu_device_count()
}

func xpu_create_queue() oneapi_queue {
    0
}

func xpu_destroy_queue(oneapi_queue queue) int {
    0
}

func xpu_submit_kernel(oneapi_queue queue, string kernel_name, int grid_size, int block_size, xpu_memory_ptr args) int {
    0
}

func xpu_wait_kernel(oneapi_queue queue) int {
    0
}

func xpu_get_level_zero_device() level_zero_device {
    0
}

func xpu_enable_oneapi_mode() int {
    0
}
