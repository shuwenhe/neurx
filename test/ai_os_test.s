package neurx.test.ai_os_test

use neurx.kernel.syscall.syscall_context_create
use neurx.kernel.syscall.trap_frame_create
use neurx.kernel.syscall.get_syscall_name
use neurx.kernel.syscall.SYS_read
use neurx.kernel.syscall.SYS_write
use neurx.kernel.syscall.SYS_fork
use neurx.kernel.syscall.SYS_getpid
use neurx.kernel.syscall.SYS_exit
use neurx.kernel.syscall.syscall_entry_handler
use neurx.kernel.process.process_table_create
use neurx.kernel.process.task_struct_create
use neurx.kernel.process.do_fork
use neurx.kernel.process.do_execve
use neurx.kernel.process.do_exit
use neurx.kernel.process.do_wait
use neurx.mm.vm.mm_struct_create
use neurx.mm.vm.tlb_create
use neurx.mm.vm.tlb_lookup
use neurx.mm.vm.tlb_insert
use neurx.init.os_init_complete

struct test_result {
    string test_name
    bool passed
    string error_msg
}

func test_syscall_context() test_result {
    frame := trap_frame_create()
    ctx := syscall_context_create(SYS_read(), *frame)
    
    result := test_result {
        test_name: "System Call Context Creation",
        passed: ctx.syscall_number == SYS_read(),
        error_msg: ""
    }
    return result
}

func test_syscall_names() test_result {
    name1 := get_syscall_name(SYS_read())
    name2 := get_syscall_name(SYS_write())
    name3 := get_syscall_name(SYS_fork())
    
    passed := (name1 == "read") && (name2 == "write") && (name3 == "fork")
    
    result := test_result {
        test_name: "System Call Name Mapping",
        passed: passed,
        error_msg: ""
    }
    return result
}

func test_process_table() test_result {
    ptable := process_table_create()
    
    passed := ptable.process_count == 0 && ptable.next_pid == 100
    
    result := test_result {
        test_name: "Process Table Creation",
        passed: passed,
        error_msg: ""
    }
    return result
}

func test_fork_syscall() test_result {
    ptable := process_table_create()
    
    init_task := task_struct_create(1, 0, "init")
    mm := mm_struct_create(1)
    init_task.mm = *mm
    ptable.processes[0] = init_task
    ptable.process_count = 1
    
    new_pid, success := do_fork(*ptable, 0, 0)
    
    passed := success && new_pid == 100 && ptable.process_count == 2
    
    result := test_result {
        test_name: "Fork System Call",
        passed: passed,
        error_msg: ""
    }
    return result
}

func test_execve_syscall() test_result {
    ptable := process_table_create()
    
    task := task_struct_create(100, 1, "parent")
    ptable.processes[0] = task
    ptable.process_count = 1
    
    success := do_execve(*ptable, 100, "/bin/bash")
    
    passed := success && ptable.processes[0].name == "/bin/bash"
    
    result := test_result {
        test_name: "Execve System Call",
        passed: passed,
        error_msg: ""
    }
    return result
}

func test_exit_syscall() test_result {
    ptable := process_table_create()
    
    task := task_struct_create(100, 1, "process")
    ptable.processes[0] = task
    ptable.process_count = 1
    ptable.parent_pids[100] = 1
    
    success := do_exit(*ptable, 100, 42)
    
    passed := success && ptable.processes[0].exit_code == 42
    
    result := test_result {
        test_name: "Exit System Call",
        passed: passed,
        error_msg: ""
    }
    return result
}

func test_wait_syscall() test_result {
    ptable := process_table_create()
    
    parent := task_struct_create(1, 0, "parent")
    child := task_struct_create(100, 1, "child")
    
    ptable.processes[0] = parent
    ptable.processes[1] = child
    ptable.process_count = 2
    ptable.parent_pids[100] = 1
    
    ptable.processes[1].state = 5
    ptable.processes[1].exit_code = 0
    
    pid, code, success := do_wait(*ptable, 1)
    
    passed := success && pid == 100 && code == 0
    
    result := test_result {
        test_name: "Wait System Call",
        passed: passed,
        error_msg: ""
    }
    return result
}

func test_virtual_memory() test_result {
    mm := mm_struct_create(1)
    
    passed := mm.pid == 1 && mm.vma_count == 0 && mm.total_pages == 0
    
    result := test_result {
        test_name: "Virtual Memory Structure",
        passed: passed,
        error_msg: ""
    }
    return result
}

func test_tlb_operations() test_result {
    tlb := tlb_create()
    
    tlb_insert(*tlb, 0x1000, 0x4000)
    tlb_insert(*tlb, 0x2000, 0x5000)
    
    addr1 := tlb_lookup(*tlb, 0x1000)
    addr2 := tlb_lookup(*tlb, 0x2000)
    addr3 := tlb_lookup(*tlb, 0x3000)
    
    passed := (addr1 == 0x4000) && (addr2 == 0x5000) && (addr3 == -1)
    
    result := test_result {
        test_name: "TLB Lookup/Insert",
        passed: passed,
        error_msg: ""
    }
    return result
}

func run_all_tests() {
    print("")
    print("╔════════════════════════════════════════════════════════════╗")
    print("║          NeurX AI OS - Unit Test Suite                    ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    tests := [10]test_result{}
    
    tests[0] = test_syscall_context()
    tests[1] = test_syscall_names()
    tests[2] = test_process_table()
    tests[3] = test_fork_syscall()
    tests[4] = test_execve_syscall()
    tests[5] = test_exit_syscall()
    tests[6] = test_wait_syscall()
    tests[7] = test_virtual_memory()
    tests[8] = test_tlb_operations()
    
    passed_count := 0
    total_count := 9
    
    i := 0
    for i < total_count {
        status := "❌ FAIL"
        if tests[i].passed {
            status = "✅ PASS"
            passed_count = passed_count + 1
        }
        
        print(status)
        print(" - ")
        print(tests[i].test_name)
        
        if tests[i].error_msg != "" {
            print(" (")
            print(tests[i].error_msg)
            print(")")
        }
        print("")
        
        i = i + 1
    }
    
    print("")
    print("Test Summary:")
    print("  Passed: ")
    print(passed_count as string)
    print("/")
    print(total_count as string)
    print("")
    
    percentage := (passed_count * 100) / total_count
    print("  Success Rate: ")
    print(percentage as string)
    print("%")
    print("")
}

func main() {
    os_init_complete()
    print("")
    run_all_tests()
    print("")
    print("✨ Test execution completed!")
}
