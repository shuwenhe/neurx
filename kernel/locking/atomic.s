package neurx.kernel.locking

struct atomic_int {
    int value              // Atomic integer value
    int increment_count    // Total increments
    int decrement_count    // Total decrements
    int compare_swap_count // Total CAS operations
}

func create_atomic(int initial_value) atomic_int {
    atomic_int {
        value: initial_value,
        increment_count: 0,
        decrement_count: 0,
        compare_swap_count: 0
    }
}

func atomic_increment(mut a: &atomic_int) atomic_int {
    atom_local := a.*
    atom_local.value = atom_local.value + 1
    atom_local.increment_count = atom_local.increment_count + 1
    
    a.* = atom_local
    atom_local
}

func atomic_decrement(mut a: &atomic_int) atomic_int {
    atom_local := a.*
    atom_local.value = atom_local.value - 1
    atom_local.decrement_count = atom_local.decrement_count + 1
    
    a.* = atom_local
    atom_local
}

func atomic_add(mut a: &atomic_int, int delta) atomic_int {
    atom_local := a.*
    atom_local.value = atom_local.value + delta
    atom_local.increment_count = atom_local.increment_count + 1
    
    a.* = atom_local
    atom_local
}

func atomic_sub(mut a: &atomic_int, int delta) atomic_int {
    atom_local := a.*
    atom_local.value = atom_local.value - delta
    atom_local.decrement_count = atom_local.decrement_count + 1
    
    a.* = atom_local
    atom_local
}

func atomic_compare_and_swap(mut a: &atomic_int, int expected, int new_value) (atomic_int, bool) {
    atom_local := a.*
    success := false
    
    if atom_local.value == expected {
        atom_local.value = new_value
        success = true
        atom_local.compare_swap_count = atom_local.compare_swap_count + 1
    }
    
    a.* = atom_local
    (atom_local, success)
}

func atomic_get(atomic_int a) int {
    a.value
}

func atomic_set(mut a: &atomic_int, int new_value) atomic_int {
    atom_local := a.*
    atom_local.value = new_value
    
    a.* = atom_local
    atom_local
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
