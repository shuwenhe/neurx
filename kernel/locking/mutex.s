package neurx.kernel.locking

enum mutex_state {
    unlocked,
    locked
}

struct mutex {
    int state              // 0 = unlocked, 1 = locked
    int owner_pid          // PID of owning process
    int contention_count   // Number of waiters
}

func create_mutex() mutex {
    mutex {
        state: 0,
        owner_pid: 0,
        contention_count: 0
    }
}

func mutex_lock(mut m: &mutex, int pid) mutex {
    mut_local := m.*
    
    if mut_local.state == 0 {
        mut_local.state = 1
        mut_local.owner_pid = pid
    } else {
        mut_local.contention_count = mut_local.contention_count + 1
    }
    
    m.* = mut_local
    mut_local
}

func mutex_unlock(mut m: &mutex) mutex {
    mut_local := m.*
    
    if mut_local.owner_pid != 0 {
        mut_local.state = 0
        mut_local.owner_pid = 0
        
        if mut_local.contention_count > 0 {
            mut_local.contention_count = mut_local.contention_count - 1
        }
    }
    
    m.* = mut_local
    mut_local
}

func mutex_trylock(mut m: &mutex, int pid) (mutex, bool) {
    mut_local := m.*
    success := false
    
    if mut_local.state == 0 {
        mut_local.state = 1
        mut_local.owner_pid = pid
        success = true
    }
    
    m.* = mut_local
    (mut_local, success)
}

func is_mutex_locked(mutex m) bool {
    m.state == 1
}

func get_mutex_owner(mutex m) int {
    m.owner_pid
}

func get_mutex_contention(mutex m) int {
    m.contention_count
}

func print_mutex_info(mutex m) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║               NeurX Mutex - Status Report                  ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Mutex State:")
    if m.state == 0 {
        print("   • Status: 🟢 Unlocked")
    } else {
        print("   • Status: 🔴 Locked")
    }
    print("   • Owner PID: ")
    print(m.owner_pid)
    print("   • Contention Count: ")
    print(m.contention_count)
    print("")
    print("✅ Mutex operational!")
    print("")
}
