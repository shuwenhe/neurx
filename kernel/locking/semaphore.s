package neurx.kernel.locking

struct semaphore {
    int count              // Current semaphore count
    int initial_count      // Initial count
    int acquired_count     // Number of times acquired
    int released_count     // Number of times released
    int wait_queue_depth   // Number of waiters
}

func create_semaphore(int initial_value) semaphore {
    semaphore {
        count: initial_value,
        initial_count: initial_value,
        acquired_count: 0,
        released_count: 0,
        wait_queue_depth: 0
    }
}

func semaphore_acquire(mut s: &semaphore) semaphore {
    sem_local := s.*
    
    if sem_local.count > 0 {
        sem_local.count = sem_local.count - 1
        sem_local.acquired_count = sem_local.acquired_count + 1
    } else {
        sem_local.wait_queue_depth = sem_local.wait_queue_depth + 1
    }
    
    s.* = sem_local
    sem_local
}

func semaphore_release(mut s: &semaphore) semaphore {
    sem_local := s.*
    
    sem_local.count = sem_local.count + 1
    sem_local.released_count = sem_local.released_count + 1
    
    if sem_local.wait_queue_depth > 0 {
        sem_local.wait_queue_depth = sem_local.wait_queue_depth - 1
    }
    
    s.* = sem_local
    sem_local
}

func semaphore_try_acquire(mut s: &semaphore) (semaphore, bool) {
    sem_local := s.*
    success := false
    
    if sem_local.count > 0 {
        sem_local.count = sem_local.count - 1
        sem_local.acquired_count = sem_local.acquired_count + 1
        success = true
    }
    
    s.* = sem_local
    (sem_local, success)
}

func get_semaphore_count(semaphore s) int {
    s.count
}

func get_semaphore_waiters(semaphore s) int {
    s.wait_queue_depth
}

func print_semaphore_info(semaphore s) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║            NeurX Semaphore - Status Report                 ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Semaphore Configuration:")
    print("   • Initial Count: ")
    print(s.initial_count)
    print("   • Current Count: ")
    print(s.count)
    print("")
    print("📈 Statistics:")
    print("   • Total Acquired: ")
    print(s.acquired_count)
    print("   • Total Released: ")
    print(s.released_count)
    print("   • Waiters in Queue: ")
    print(s.wait_queue_depth)
    print("")
    print("✅ Semaphore operational!")
    print("")
}
