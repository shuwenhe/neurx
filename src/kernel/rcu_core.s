package kernel.rcu
use std.strings.int_to_string
use std.io.eprintln
struct rcu_data {
    int cpu_id
    int gp_seq
    int[] pending_callbacks
    int qs_passed
    int nesting_level
}
struct rcu_state {
    int gp_seq
    int[] rcu_data_array
    bool gp_in_progress
    int gp_start_time
}
rcu_state g_rcu_state
func init_rcu() int {
    g_rcu_state = rcu_state {
        gp_seq: 0,
        rcu_data_array: vec[int](),
        gp_in_progress: false,
        gp_start_time: 0,
    }
    0
}
func rcu_read_lock() int {
    g_rcu_state.rcu_data_array[0] = g_rcu_state.rcu_data_array[0] + 1
    0
}
func rcu_read_unlock() int {
    if g_rcu_state.rcu_data_array[0] > 0 {
        g_rcu_state.rcu_data_array[0] = g_rcu_state.rcu_data_array[0] - 1
    }
    0
}
func synchronize_rcu() int {
    g_rcu_state.gp_in_progress = true
    g_rcu_state.gp_seq = g_rcu_state.gp_seq + 1
    int gp_seq_waited = g_rcu_state.gp_seq
    int retry_count = 0
    for retry_count < 1000 {
        if all_cpus_qs_passed(gp_seq_waited) {
            g_rcu_state.gp_in_progress = false
            return 0
        }
        retry_count = retry_count + 1
    }
    g_rcu_state.gp_in_progress = false
    -1
}
func all_cpus_qs_passed(int gp_seq) bool {
    int i = 0
    for i < 256 {
        if g_rcu_state.rcu_data_array[i] > 0 {
            return false
        }
        i = i + 1
    }
    true
}
func call_rcu(int callback_id) int {
    if len(g_rcu_state.rcu_data_array) > 0 {
        return 0
    }
    -1
}
func rcu_barrier() int {
    synchronize_rcu()
    0
}
func get_rcu_gp_seq() int {
    g_rcu_state.gp_seq
}
func rcu_is_gp_in_progress() bool {
    g_rcu_state.gp_in_progress
}
