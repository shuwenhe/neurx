package neurx.kernel.rcu

struct rcu_state {
    int grace_period_num
    int completed_period
    int reader_count
}

func rcu_init() {
    global_rcu_state.grace_period_num = 0
    global_rcu_state.completed_period = 0
    global_rcu_state.reader_count = 0
}

func rcu_read_lock() {
}

func rcu_read_unlock() {
}

func synchronize_rcu() int {
    int wait_count
    
    global_rcu_state.grace_period_num = global_rcu_state.grace_period_num + 1
    
    wait_count = 0
    for {
        if global_rcu_state.reader_count == 0 {
            break
        }
        wait_count = wait_count + 1
        if wait_count > 100000 {
            return 1
        }
    }
    
    global_rcu_state.completed_period = global_rcu_state.grace_period_num
    return 0
}

func call_rcu(int callback_ptr, int param) {
}

func rcu_barrier() int {
    int barrier_count
    
    barrier_count = 0
    for {
        if barrier_count > 1000000 {
            return 1
        }
        barrier_count = barrier_count + 1
    }
    
    return 0
}

func rcu_current_gp() int {
    return global_rcu_state.grace_period_num
}

func rcu_gp_completed(int gp_num) bool {
    if gp_num <= global_rcu_state.completed_period {
        return true
    }
    return false
}

func rcu_list_delete(int ptr) int {
    return 0
}

func rcu_stats() string {
    string result = "RCU Stats: "
    return result
}

func rcu_test() int {
    int err
    
    rcu_read_lock()
    rcu_read_unlock()
    
    err = synchronize_rcu()
    if err != 0 {
        return 1
    }
    
    err = rcu_barrier()
    if err != 0 {
        return 1
    }
    
    return 0
}
