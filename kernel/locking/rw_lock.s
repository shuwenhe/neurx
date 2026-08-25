package neurx.kernel.locking

struct rw_lock {
    int read_count         // Number of active readers
    int write_locked       // 0 = not locked, 1 = write locked
    int write_waiters      // Processes waiting for write
    int reader_acquisitions
    int writer_acquisitions
}

func create_rw_lock() rw_lock {
    rw_lock {
        read_count: 0,
        write_locked: 0,
        write_waiters: 0,
        reader_acquisitions: 0,
        writer_acquisitions: 0
    }
}

func rw_lock_read_lock(mut r: &rw_lock) rw_lock {
    rw_local := r.*
    
    if rw_local.write_locked == 0 {
        rw_local.read_count = rw_local.read_count + 1
        rw_local.reader_acquisitions = rw_local.reader_acquisitions + 1
    } else {
        rw_local.write_waiters = rw_local.write_waiters + 1
    }
    
    r.* = rw_local
    rw_local
}

func rw_lock_read_unlock(mut r: &rw_lock) rw_lock {
    rw_local := r.*
    
    if rw_local.read_count > 0 {
        rw_local.read_count = rw_local.read_count - 1
    }
    
    r.* = rw_local
    rw_local
}

func rw_lock_write_lock(mut r: &rw_lock) rw_lock {
    rw_local := r.*
    
    if rw_local.write_locked == 0 && rw_local.read_count == 0 {
        rw_local.write_locked = 1
        rw_local.writer_acquisitions = rw_local.writer_acquisitions + 1
    } else {
        rw_local.write_waiters = rw_local.write_waiters + 1
    }
    
    r.* = rw_local
    rw_local
}

func rw_lock_write_unlock(mut r: &rw_lock) rw_lock {
    rw_local := r.*
    
    rw_local.write_locked = 0
    if rw_local.write_waiters > 0 {
        rw_local.write_waiters = rw_local.write_waiters - 1
    }
    
    r.* = rw_local
    rw_local
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
