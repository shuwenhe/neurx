package neurx.runtime.tensor_builder

// Construction IDs are explicit shared mutable state, not S array aliases.
// Successful finish consumes the ID; ordinary published arrays remain values.
extern "intrinsic" func __native_builder_new(int count, int kind) int
extern "intrinsic" func __native_builder_set_float(int id, int index, float value) int
extern "intrinsic" func __native_builder_set_int(int id, int index, int value) int
extern "intrinsic" func __native_builder_set_string(int id, int index, string value) int
extern "intrinsic" func __native_builder_fill_float(int id, float value) int
extern "intrinsic" func __native_builder_copy_float(int id, int offset, float[] source) int
extern "intrinsic" func __native_builder_seal(int id, int kind) int
extern "intrinsic" func __native_builder_take_float(int id) float[]
extern "intrinsic" func __native_builder_take_int(int id) int[]
extern "intrinsic" func __native_builder_take_string(int id) string[]
extern "intrinsic" func __native_builder_release(int id) int
extern "intrinsic" func __native_builder_open(int id) bool
extern "intrinsic" func __native_builder_stats(int metric) int
extern "intrinsic" func __native_builder_stats_reset() int
extern "intrinsic" func __native_tensor_read(string path, int offset, int count, int dtype) int
extern "intrinsic" func __native_float_slice(float[] source, int offset, int count) float[]
extern "intrinsic" func __native_float_patch(float[] target, int offset, float[] source) float[]
extern "intrinsic" func __native_bytes_string(int[] bytes) string

struct float_construction_result {
    bool ok
    float[] values
    int error
}
struct int_construction_result {
    bool ok
    int[] values
    int error
}
struct string_construction_result {
    bool ok
    string[] values
    int error
}

func new_float_builder(int count) int { __native_builder_new(count, 0) }
func new_int_builder(int count) int { __native_builder_new(count, 1) }
func new_string_builder(int count) int { __native_builder_new(count, 2) }
func builder_set_float(int id, int index, float value) int { __native_builder_set_float(id, index, value) }
func builder_set_int(int id, int index, int value) int { __native_builder_set_int(id, index, value) }
func builder_set_string(int id, int index, string value) int { __native_builder_set_string(id, index, value) }
func builder_fill_float(int id, float value) int { __native_builder_fill_float(id, value) }
func builder_copy_float(int id, int offset, float[] source) int { __native_builder_copy_float(id, offset, source) }
func release_builder(int id) int { __native_builder_release(id) }
func builder_is_open(int id) bool { __native_builder_open(id) }
func construction_stat(int metric) int { __native_builder_stats(metric) }
func reset_construction_stats() int { __native_builder_stats_reset() }

func finish_float_builder(int id) float_construction_result {
    int status = __native_builder_seal(id, 0)
    if status != 0 { return float_construction_result { ok: false, values: [], error: status } }
    float[] values = __native_builder_take_float(id)
    float_construction_result { ok: true, values: values, error: 0 }
}
func finish_int_builder(int id) int_construction_result {
    int status = __native_builder_seal(id, 1)
    if status != 0 { return int_construction_result { ok: false, values: [], error: status } }
    int[] values = __native_builder_take_int(id)
    int_construction_result { ok: true, values: values, error: 0 }
}
func finish_string_builder(int id) string_construction_result {
    int status = __native_builder_seal(id, 2)
    if status != 0 { return string_construction_result { ok: false, values: [], error: status } }
    string[] values = __native_builder_take_string(id)
    string_construction_result { ok: true, values: values, error: 0 }
}
func read_float_tensor_range(string path, int offset, int count, int dtype) float_construction_result {
    int id = __native_tensor_read(path, offset, count, dtype)
    if id <= 0 { return float_construction_result { ok: false, values: [], error: id } }
    finish_float_builder(id)
}
func slice_float_array(float[] source, int offset, int count) float_construction_result {
    if offset < 0 || count < 0 || offset > len(source) || count > len(source) - offset {
        return float_construction_result { ok: false, values: [], error: -34 }
    }
    float_construction_result { ok: true, values: __native_float_slice(source, offset, count), error: 0 }
}
func patch_float_array(float[] target, int offset, float[] source) float_construction_result {
    if offset < 0 || offset > len(target) || len(source) > len(target) - offset {
        return float_construction_result { ok: false, values: [], error: -34 }
    }
    float_construction_result { ok: true, values: __native_float_patch(target, offset, source), error: 0 }
}
func byte_array_string(int[] bytes) string { __native_bytes_string(bytes) }
