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
