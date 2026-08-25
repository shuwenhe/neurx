package neurx.kernel.locking

struct mutex {
    int state
    int owner_pid
    int contention_count
}

func create_mutex() mutex {
    mutex { state: 0, owner_pid: 0, contention_count: 0 }
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
