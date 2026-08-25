package neurx.kernel.locking

struct spinlock {
    int locked              // 0 = unlocked, 1 = locked
    int spin_count          // Total spins performed
    int lock_acquisitions   // Number of times locked
    int owner_cpu           // CPU holding the lock
}

func create_spinlock() spinlock {
    spinlock {
        locked: 0,
        spin_count: 0,
        lock_acquisitions: 0,
        owner_cpu: -1
    }
}

func spinlock_lock(mut s: &spinlock, int cpu_id) spinlock {
    spin_local := s.*
    max_spins := 10000
    spins := 0
    
    while spin_local.locked == 1 && spins < max_spins {
        spin_local.spin_count = spin_local.spin_count + 1
        spins = spins + 1
    }
    
    spin_local.locked = 1
    spin_local.owner_cpu = cpu_id
    spin_local.lock_acquisitions = spin_local.lock_acquisitions + 1
    
    s.* = spin_local
    spin_local
}

func spinlock_unlock(mut s: &spinlock) spinlock {
    spin_local := s.*
    spin_local.locked = 0
    spin_local.owner_cpu = -1
    
    s.* = spin_local
    spin_local
}

func spinlock_trylock(mut s: &spinlock, int cpu_id) (spinlock, bool) {
    spin_local := s.*
    success := false
    
    if spin_local.locked == 0 {
        spin_local.locked = 1
        spin_local.owner_cpu = cpu_id
        spin_local.lock_acquisitions = spin_local.lock_acquisitions + 1
        success = true
    }
    
    s.* = spin_local
    (spin_local, success)
}

func is_spinlock_held(spinlock s) bool {
    s.locked == 1
}

func get_spinlock_owner(spinlock s) int {
    s.owner_cpu
}

func print_spinlock_info(spinlock s) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║              NeurX Spinlock - Status Report                ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Spinlock State:")
    if s.locked == 0 {
        print("   • Status: 🟢 Unlocked")
    } else {
        print("   • Status: 🔴 Locked")
    }
    print("   • Owner CPU: ")
    print(s.owner_cpu)
    print("")
    print("📈 Statistics:")
    print("   • Total Spins: ")
    print(s.spin_count)
    print("   • Lock Acquisitions: ")
    print(s.lock_acquisitions)
    print("")
    print("✅ Spinlock operational!")
    print("")
}
