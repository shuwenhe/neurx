package neurx.kernel.locking

enum lock_type {
    mutex,
    rwlock,
    spinlock,
    semaphore
}

struct lock {
    lock_type lock_type
    int owner_id
    int wait_queue_size
    bool is_locked
}

struct rwlock {
    int reader_count
    int writer_waiting
    bool writer_active
}

func create_lock(lock_type: lock_type) lock {
    lock {
        lock_type: lock_type,
        owner_id: -1,
        wait_queue_size: 0,
        is_locked: false
    }
}

func acquire_lock(lock: lock*) result[int, string] {
    if lock*.is_locked {
        lock*.wait_queue_size = lock*.wait_queue_size + 1
        result::err("Lock not acquired")
    } else {
        lock*.is_locked = true
        lock*.owner_id = 0
        result::ok(0)
    }
}

func release_lock(lock: lock*) result[int, string] {
    lock*.is_locked = false
    lock*.owner_id = -1
    if lock*.wait_queue_size > 0 {
        lock*.wait_queue_size = lock*.wait_queue_size - 1
    }
    result::ok(0)
}

func try_acquire_lock(lock: lock*) bool {
    if !lock*.is_locked {
        lock*.is_locked = true
        lock*.owner_id = 0
        true
    } else {
        false
    }
}
