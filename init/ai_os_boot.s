package neurx.os.core

use neurx.os.boot.boot_state_create
use neurx.os.boot.run_boot_sequence
use neurx.os.boot.boot_is_ready

func print_banner() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║       NeurX AI Operating System - Bootstrap Sequence       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
}

func main() {
    print_banner()

    state := run_boot_sequence(boot_state_create())

    if !boot_is_ready(state) {
        print("❌ AI OS boot failed at stage ")
        print(state.failed_stage)
        print(state.error)
        return
    }

    print("✓ Stage 1: early memory and page allocator")
    print("✓ Stage 2: task scheduler")
    print("✓ Stage 3: virtual file system")
    print("✓ Stage 4: network stack")
    print("✓ Stage 5: AI accelerator abstraction")
    print("✓ Stage 6: model runtime")
    print("✓ Stage 7: initial userspace services")
    print("")
    print("✅ NeurX AI OS reached READY state")
    print("Initialized stages: ")
    print(state.completed_stages)
}
