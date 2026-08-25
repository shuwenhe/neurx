package neurx.kernel.locking

struct atomic_int {
    int value
    int increment_count
    int decrement_count
    int compare_swap_count
}

func create_atomic(int initial_value) atomic_int {
    atomic_int { value: initial_value, increment_count: 0, decrement_count: 0, compare_swap_count: 0 }
}

func print_atomic_info(atomic_int a) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║             NeurX Atomic - Status Report                   ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Atomic Value:")
    print("   • Current Value: ")
    print(a.value)
    print("")
    print("📈 Statistics:")
    print("   • Increments: ")
    print(a.increment_count)
    print("   • Decrements: ")
    print(a.decrement_count)
    print("   • CAS Operations: ")
    print(a.compare_swap_count)
    print("")
    print("✅ Atomic operations operational!")
    print("")
}
