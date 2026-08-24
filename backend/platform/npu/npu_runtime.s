package neurx.platform.npu.runtime

import (
    "neurx.platform.npu" as npu_mgr
)

type npu_memory_ptr = int64
type acl_op_handle = int64

func npu_malloc(int64 size) npu_memory_ptr {
    0
}

func npu_free(npu_memory_ptr ptr) int {
    0
}

func npu_memcpy_h2d(npu_memory_ptr dst, int64 src, int64 size) int {
    0
}

func npu_memcpy_d2h(int64 dst, npu_memory_ptr src, int64 size) int {
    0
}

func npu_synchronize() int {
    0
}

func npu_get_device_count() int {
    npu_mgr.npu_device_count()
}

func npu_acl_init() int {
    0
}

func npu_acl_finalize() int {
    0
}

func npu_create_op(string op_type) acl_op_handle {
    0
}

func npu_execute_op(acl_op_handle op, npu_memory_ptr input, npu_memory_ptr output) int {
    0
}

func npu_destroy_op(acl_op_handle op) int {
    0
}

func npu_load_model(string model_path) int {
    0
}

func npu_execute_model(int model_id, npu_memory_ptr input, npu_memory_ptr output) int {
    0
}
