package neurx.kernel.locking

struct spinlock {
    int locked
    int spin_count
    int lock_acquisitions
    int owner_cpu
}

func create_spinlock() spinlock {
    spinlock { locked: 0, spin_count: 0, lock_acquisitions: 0, owner_cpu: -1 }
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
