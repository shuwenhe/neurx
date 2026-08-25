package neurx.kernel.locking

struct lock {
    int lock_type
    int owner_id
    int wait_queue_size
    int is_locked
}

func create_lock(int lock_type) lock {
    lock { lock_type: lock_type, owner_id: -1, wait_queue_size: 0, is_locked: 0 }
}

func try_acquire_lock(lock* lock) bool {
    if !lock.is_locked {
        lock.is_locked = true
        lock.owner_id = 0
        true
    } else {
        false
    }
}
