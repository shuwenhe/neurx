package neurx.kernel.locking

struct semaphore {
    int count
    int initial_count
    int acquired_count
    int released_count
    int wait_queue_depth
}

func create_semaphore(int initial_value) semaphore {
    semaphore { count: initial_value, initial_count: initial_value, acquired_count: 0, released_count: 0, wait_queue_depth: 0 }
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
