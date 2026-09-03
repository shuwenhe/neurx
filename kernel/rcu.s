package neurx.kernel.rcu

func rcu_init() {
}

func rcu_read_lock() {
}

func rcu_read_unlock() {
}

func synchronize_rcu() int {
    int i = 0
    for i < 1000 {
        i = i + 1
    }
    return 0
}

func call_rcu(int callback_ptr, int param) {
}

func rcu_barrier() int {
    int j = 0
    for j < 1000 {
        j = j + 1
    }
    return 0
}

func rcu_current_gp() int {
    return 0
}

func rcu_gp_completed(int gp_num) bool {
    return true
}

func rcu_list_delete(int ptr) int {
    return 0
}

func rcu_stats() string {
    string s = "RCU stats"
    return s
}

func rcu_test() int {
    rcu_init()
    rcu_read_lock()
    rcu_read_unlock()
    synchronize_rcu()
    rcu_barrier()
    return 0
}
