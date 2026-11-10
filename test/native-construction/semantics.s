package main
import ("neurx.runtime.tensor_builder")
extern "intrinsic" func __int_to_string(int value) string
struct array_record { float[] values }
func changed_argument(float[] input) float[] { input[0] = 17.0; input }
func make_string_construction() int {
    int id = new_string_builder(64)
    if id <= 0 { return id }
    int i = 0
    for i < 64 {
        if builder_set_string(id, i, "value-" + __int_to_string(i)) != 0 { return -1 }
        i = i + 1
    }
    id
}
func collector_pressure() int {
    int i = 0
    for i < 64 {
        int id = new_float_builder(1000000)
        if id <= 0 { return 1 }
        if builder_set_float(id, 999999, i * 1.0) != 0 { return 2 }
        if release_builder(id) != 0 { return 3 }
        i = i + 1
    }
    0
}
func finalized_pressure() int {
    int i = 0
    for i < 32 {
        int id = new_float_builder(1000000)
        if id <= 0 || builder_fill_float(id, i * 1.0) != 0 { return 1 }
        float_construction_result output = finish_float_builder(id)
        if !output.ok || output.values[999999] != i * 1.0 || builder_is_open(id) { return 2 }
        i = i + 1
    }
    0
}
func main() int {
    int id = new_float_builder(3)
    int alias = id
    if id <= 0 || builder_set_float(id, 0, -2.5) != 0 || builder_set_float(alias, 1, 1.25) != 0 { return 1 }
    int_construction_result wrong = finish_int_builder(id)
    if wrong.ok || wrong.error != -22 || !builder_is_open(id) { return 2 }
    if builder_set_float(id, -1, 9.0) != -34 || builder_set_float(id, 3, 9.0) != -34 { return 3 }
    float_construction_result finished = finish_float_builder(id)
    if !finished.ok || len(finished.values) != 3 || finished.values[0] != -2.5 || finished.values[1] != 1.25 || finished.values[2] != 0.0 { return 4 }
    if builder_is_open(alias) || builder_set_float(alias, 0, 90.0) != -9 { return 5 }
    if finish_float_builder(alias).ok || release_builder(alias) != -9 { return 6 }
    float[] old = finished.values
    float[] updated = old
    updated[0] = 99.0
    if old[0] != -2.5 || updated[0] != 99.0 { return 7 }
    float[] changed = changed_argument(old)
    if changed[0] != 17.0 || old[0] != -2.5 { return 8 }
    array_record first = array_record { values: old }
    array_record second = first
    second.values[1] = 11.0
    if first.values[1] != 1.25 || second.values[1] != 11.0 { return 9 }
    float_construction_result sliced = slice_float_array(old, 0, 2)
    if !sliced.ok || sliced.values[0] != -2.5 { return 10 }
    sliced.values[0] = 12.0
    if old[0] != -2.5 { return 11 }
    float_construction_result patched = patch_float_array(old, 1, float[]{7.0})
    if !patched.ok || patched.values[1] != 7.0 || old[1] != 1.25 { return 12 }
    if slice_float_array(old, 3, 1).ok || patch_float_array(old, 3, float[]{1.0}).ok { return 13 }
    int empty = new_float_builder(0)
    float_construction_result empty_result = finish_float_builder(empty)
    if !empty_result.ok || len(empty_result.values) != 0 || finish_float_builder(empty).ok { return 14 }
    if new_float_builder(-1) != -22 || builder_set_float(123456789, 0, 1.0) != -9 { return 15 }
    int string_id = make_string_construction()
    if string_id <= 0 || collector_pressure() != 0 { return 16 }
    string_construction_result text = finish_string_builder(string_id)
    if !text.ok || len(text.values) != 64 || text.values[0] != "value-0" || text.values[63] != "value-63" { return 17 }
    if finalized_pressure() != 0 || old[0] != -2.5 || text.values[63] != "value-63" { return 18 }
    if construction_stat(5) != 0 { return 19 }
    0
}
