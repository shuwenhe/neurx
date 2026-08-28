package main
use neurx.serving.cache.physical_paged_kv.{physical_kv_state, physical_kv_allocation, new_physical_kv_state, physical_kv_bind_block, physical_kv_allocate, physical_kv_share_prefix, physical_kv_release}
func fail(string message) int { println("physical-kv FAIL " + message); 1 }
func main() {
    physical_kv_state state = new_physical_kv_state(4, 4)
    int i = 0
    for i < 4 {
        state = physical_kv_bind_block(state, i, int64(4096 + i * 1024))
        i = i + 1
    }
    physical_kv_allocation allocated = physical_kv_allocate(state, "req-a", 0, 6)
    if !allocated.ok || len(allocated.block_table) != 2 { return fail("allocation") }
    state = allocated.state
    physical_kv_allocation shared = physical_kv_share_prefix(state, "req-a", "req-b", 4)
    if !shared.ok || state.reference_counts[allocated.block_table[0]] != 1 { return fail("share") }
    state = shared.state
    if state.reference_counts[allocated.block_table[0]] != 2 { return fail("reference-count") }
    state = physical_kv_release(state, "req-a")
    if state.reference_counts[allocated.block_table[0]] != 1 { return fail("shared-release") }
    state = physical_kv_release(state, "req-b")
    if state.reference_counts[allocated.block_table[0]] != 0 { return fail("final-release") }
    println("physical-kv PASS allocations=" + string(state.allocations) + " shared_blocks=" + string(state.shared_blocks))
    0
}
