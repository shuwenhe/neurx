package neurx.kernel.locking

struct rw_lock {
    int read_count
    int write_locked
    int write_waiters
    int reader_acquisitions
    int writer_acquisitions
}

func create_rw_lock() rw_lock {
    rw_lock { read_count: 0, write_locked: 0, write_waiters: 0, reader_acquisitions: 0, writer_acquisitions: 0 }
}

func print_rw_lock_info(rw_lock r) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║            NeurX RW-Lock - Status Report                   ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 RW-Lock State:")
    print("   • Active Readers: ")
    print(r.read_count)
    if r.write_locked == 0 {
        print("   • Write Lock: 🟢 Unlocked")
    } else {
        print("   • Write Lock: 🔴 Locked")
    }
    print("   • Write Waiters: ")
    print(r.write_waiters)
    print("")
    print("📈 Statistics:")
    print("   • Reader Acquisitions: ")
    print(r.reader_acquisitions)
    print("   • Writer Acquisitions: ")
    print(r.writer_acquisitions)
    print("")
    print("✅ RW-Lock operational!")
    print("")
}
