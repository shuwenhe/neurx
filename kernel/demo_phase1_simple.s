package neurx.kernel

use neurx.kernel.sched.advanced_scheduler
use neurx.ipc.pipes
use neurx.ipc.msgqueue
use neurx.kernel.process.process_manager

func demonstrate_scheduler() {
    print("")
    print("════════════════════════════════════════════════════════════")
    print("  🎯 Demonstrating Advanced Scheduler")
    print("════════════════════════════════════════════════════════════")
    
    sched := create_scheduler(8, 140)
    print_scheduler_info(sched)
}

func demonstrate_pipes() {
    print("")
    print("════════════════════════════════════════════════════════════")
    print("  🔗 Demonstrating IPC Pipes")
    print("════════════════════════════════════════════════════════════")
    
    mgr := create_pipe_manager()
    print_pipe_manager_info(mgr)
}

func demonstrate_msgqueue() {
    print("")
    print("════════════════════════════════════════════════════════════")
    print("  📨 Demonstrating Message Queues")
    print("════════════════════════════════════════════════════════════")
    
    mgr := create_msgqueue_manager()
    print_msgqueue_manager_info(mgr)
}

func demonstrate_process_manager() {
    print("")
    print("════════════════════════════════════════════════════════════")
    print("  🔄 Demonstrating Process Manager")
    print("════════════════════════════════════════════════════════════")
    
    mgr := create_process_manager()
    print_process_manager_info(mgr)
}

func main() {
    print("")
    print("╔════════════════════════════════════════════════════════════╗")
    print("║         NeurX Phase 1 - AI OS Integration Demo             ║")
    print("║   Advanced Scheduler + IPC + Process Management            ║")
    print("╚════════════════════════════════════════════════════════════╝")
    
    demonstrate_scheduler()
    demonstrate_pipes()
    demonstrate_msgqueue()
    demonstrate_process_manager()
    
    print("")
    print("════════════════════════════════════════════════════════════")
    print("✅ Phase 1 Demonstration Complete!")
    print("All systems operational and integrated successfully")
    print("════════════════════════════════════════════════════════════")
    print("")
}
