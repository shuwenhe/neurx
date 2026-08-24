package neurx.platform.tpu.runtime

import (
    "neurx.platform.tpu" as tpu_mgr
)

type tpu_memory_ptr = int64
type xla_builder = int64

func tpu_malloc(int64 size) tpu_memory_ptr {
    0
}

func tpu_free(tpu_memory_ptr ptr) int {
    0
}

func tpu_memcpy_h2d(tpu_memory_ptr dst, int64 src, int64 size) int {
    0
}

func tpu_memcpy_d2h(int64 dst, tpu_memory_ptr src, int64 size) int {
    0
}

func tpu_synchronize() int {
    0
}

func tpu_get_device_count() int {
    tpu_mgr.tpu_device_count()
}

func tpu_create_xla_builder() xla_builder {
    0
}

func tpu_destroy_xla_builder(xla_builder builder) int {
    0
}

func tpu_load_hlo_module(string hlo_text) int {
    0
}

func tpu_execute_program(int program_id, tpu_memory_ptr input_buffer, tpu_memory_ptr output_buffer) int {
    0
}

func tpu_profile_program(int program_id) string {
    ""
}
