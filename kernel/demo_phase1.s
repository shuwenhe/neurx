package neurx.kernel.demo

use neurx.kernel.sched.advanced_scheduler
use neurx.ipc.pipes
use neurx.ipc.msgqueue
use neurx.kernel.process.process_manager

func demonstrate_scheduler() {
    print("")
    print("═══════════════════════════════════════════════════════════")
    print("Phase 1: Advanced Scheduler Demonstration")
    print("═══════════════════════════════════════════════════════════")
    print("")
    
    sched := create_scheduler(8, 140)
    
    print("✓ Scheduler created with 8 CPUs and 140 priority levels (Linux-compatible)")
    print("")
    
    t1 := create_task(1, "gpu_inference_task", 50, 1, false)
    t2 := create_task(2, "training_task", 100, 2, false)
    t3 := create_task(3, "realtime_control", 10, 4, true)
    t4 := create_task(4, "background_service", 139, 8, false)
    
    enqueue_task(&sched, t1)
    enqueue_task(&sched, t2)
    enqueue_task(&sched, t3)
    enqueue_task(&sched, t4)
    
    print("✓ 4 tasks enqueued:")
    print("  - GPU inference (priority 50)")
    print("  - Training (priority 100)")
    print("  - Real-time control (priority 10, RT)")
    print("  - Background service (priority 139)")
    print("")
    
    selected_task, _ := schedule(&sched)
    print("✓ Scheduler selected task: ")
    print(selected_task.name)
    print(" (PID: ")
    print(selected_task.task_id as string)
    print(", Priority: ")
    print(selected_task.priority as string)
    print(")")
    print("")
    
    print_scheduler_info(&sched)
}

func demonstrate_pipes() {
    print("")
    print("═══════════════════════════════════════════════════════════")
    print("Phase 1: IPC Pipes Demonstration")
    print("═══════════════════════════════════════════════════════════")
    print("")
    
    pipe_mgr := create_pipe_manager()
    
    pipe_id, _ := create_pipe(&pipe_mgr, 1024)
    print("✓ Pipe created (ID: ")
    print(pipe_id as string)
    print(", buffer: 1024 bytes)")
    print("")
    
    print("✓ Writing 5 integers to pipe...")
    int i = 0
    while i < 5 {
        write_pipe(&pipe_mgr, pipe_id, 100 + i)
        i = i + 1
    }
    print("")
    
    print("✓ Reading from pipe:")
    int j = 0
    while j < 5 {
        val, _ := read_pipe(&pipe_mgr, pipe_id)
        print("  Data: ")
        print(val as string)
        j = j + 1
    }
    print("")
    
    close_pipe_end(&pipe_mgr, pipe_id, true)
    close_pipe_end(&pipe_mgr, pipe_id, false)
    
    print_pipe_manager_info(&pipe_mgr)
}

func demonstrate_msgqueue() {
    print("")
    print("═══════════════════════════════════════════════════════════")
    print("Phase 1: IPC Message Queues Demonstration")
    print("═══════════════════════════════════════════════════════════")
    print("")
    
    mgr := create_msgqueue_manager()
    
    queue_id, _ := create_message_queue(&mgr, 100)
    print("✓ Message queue created (ID: ")
    print(queue_id as string)
    print(", max: 100 messages)")
    print("")
    
    print("✓ Sending 5 messages...")
    int i = 0
    while i < 5 {
        send_message(&mgr, queue_id, 1000 + i, 1, 10 + i)
        i = i + 1
    }
    print("")
    
    print("✓ Receiving messages:")
    int j = 0
    while j < 5 {
        msg, _ := receive_message(&mgr, queue_id, 2000)
        print("  Message ID: ")
        print(msg.msg_id as string)
        print(", From PID: ")
        print(msg.sender_pid as string)
        print(", Type: ")
        print(msg.msg_type as string)
        j = j + 1
    }
    print("")
    
    print_msgqueue_manager_info(&mgr)
}

func demonstrate_process_manager() {
    print("")
    print("═══════════════════════════════════════════════════════════")
    print("Phase 1: Process Manager Demonstration")
    print("═══════════════════════════════════════════════════════════")
    print("")
    
    pm := create_process_manager()
    
    create_process(&pm, 0, "init", 100, false)
    create_process(&pm, 1, "inference_server", 50, false)
    create_process(&pm, 1, "training_worker", 80, false)
    create_process(&pm, 1, "realtime_controller", 10, true)
    
    print("✓ 4 processes created under init")
    print("")
    
    pgid, _ := create_process_group(&pm, 1, 2)
    join_process_group(&pm, pgid, 3)
    join_process_group(&pm, pgid, 4)
    
    print("✓ Process group created with multiple processes")
    print("")
    
    sid, _ := create_session(&pm, 2)
    print("✓ Session created (ID: ")
    print(sid as string)
    print(")")
    print("")
    
    children, _ := get_child_processes(&pm, 1)
    print("✓ Found ")
    print(children.len() as string)
    print(" child processes of init")
    print("")
    
    print_process_manager_info(&pm)
}

func main() {
    print("")
    print("╔════════════════════════════════════════════════════════════╗")
    print("║    NeurX AI Operating System - Phase 1 Implementation      ║")
    print("║       Advanced Scheduler + IPC + Process Management        ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    demonstrate_scheduler()
    demonstrate_pipes()
    demonstrate_msgqueue()
    demonstrate_process_manager()
    
    print("")
    print("╔════════════════════════════════════════════════════════════╗")
    print("║         ✅ Phase 1 Demonstration Complete!                ║")
    print("║                                                            ║")
    print("║  Implemented:                                              ║")
    print("║  ✓ Advanced Multi-level Scheduler (140 priority levels)   ║")
    print("║  ✓ IPC Pipes (inter-process communication)                ║")
    print("║  ✓ Message Queues (async messaging)                       ║")
    print("║  ✓ Process Management (hierarchy, groups, sessions)       ║")
    print("║                                                            ║")
    print("║  Ready for Phase 2: Storage & I/O Optimization             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
}
