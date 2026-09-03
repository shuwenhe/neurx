package neurx.kernel.process

use neurx.mm.vm.mm_struct
use neurx.mm.vm.vma

struct task_struct {
    int pid
    int ppid
    int tgid
    string name
    int state
    int priority
    int64 start_time
    mm_struct* mm
    int exit_code
    int signal_pending
    bool is_running
    int64 utime
    int64 stime
}

struct file_struct {
    int fd_array[1024]
    int fd_count
}

struct signal_struct {
    int sig_action[64]
    int64 sig_mask
    int sig_pending
}

func task_state_new() int { 0 }
func task_state_ready() int { 1 }
func task_state_running() int { 2 }
func task_state_blocked() int { 3 }
func task_state_stopped() int { 4 }
func task_state_zombie() int { 5 }
func task_state_dead() int { 6 }

struct process_table {
    task_struct processes[4096]
    int process_count
    int next_pid
    int parent_pids[4096]
}

func process_table_create() process_table {
    table := process_table {
        processes: [4096]task_struct{},
        process_count: 0,
        next_pid: 100,
        parent_pids: [4096]int{}
    }
    return table
}

func task_struct_create(int pid, int ppid, string name) task_struct {
    task := task_struct {
        pid: pid,
        ppid: ppid,
        tgid: pid,
        name: name,
        state: task_state_new(),
        priority: 20,
        start_time: 0,
        mm: nil,
        exit_code: 0,
        signal_pending: 0,
        is_running: false,
        utime: 0,
        stime: 0
    }
    return task
}

func file_struct_create() file_struct {
    fs := file_struct {
        fd_array: int[1024]{},
        fd_count: 0
    }
    return fs
}

func signal_struct_create() signal_struct {
    sig := signal_struct {
        sig_action: int[64]{},
        sig_mask: 0,
        sig_pending: 0
    }
    return sig
}

func do_fork(process_table* ptable, int flags, int clone_flags) (int, bool) {
    if ptable.process_count >= 4096 {
        return -1, false
    }
    
    new_pid := ptable.next_pid
    ptable.next_pid = ptable.next_pid + 1
    
    parent_idx := 0
    i := 0
    for i < ptable.process_count {
        if ptable.processes[i].pid == 1 {
            parent_idx = i
            break
        }
        i = i + 1
    }
    
    new_task := task_struct_create(new_pid, 1, "child")
    new_task.state = task_state_ready()
    new_task.mm = ptable.processes[parent_idx].mm
    
    idx := ptable.process_count
    ptable.processes[idx] = new_task
    ptable.parent_pids[new_pid] = 1
    ptable.process_count = ptable.process_count + 1
    
    return new_pid, true
}

func do_execve(process_table* ptable, int pid, string filename) bool {
    idx := 0
    found := false
    i := 0
    for i < ptable.process_count {
        if ptable.processes[i].pid == pid {
            idx = i
            found = true
            break
        }
        i = i + 1
    }
    
    if !found {
        return false
    }
    
    ptable.processes[idx].name = filename
    ptable.processes[idx].state = task_state_ready()
    ptable.processes[idx].exit_code = 0
    
    return true
}

func do_exit(process_table* ptable, int pid, int exit_code) bool {
    idx := 0
    found := false
    i := 0
    for i < ptable.process_count {
        if ptable.processes[i].pid == pid {
            idx = i
            found = true
            break
        }
        i = i + 1
    }
    
    if !found {
        return false
    }
    
    ptable.processes[idx].state = task_state_zombie()
    ptable.processes[idx].exit_code = exit_code
    
    return true
}

func do_wait(process_table* ptable, int parent_pid) (int, int, bool) {
    i := 0
    for i < ptable.process_count {
        if ptable.parent_pids[ptable.processes[i].pid] == parent_pid {
            if ptable.processes[i].state == task_state_zombie() {
                pid := ptable.processes[i].pid
                code := ptable.processes[i].exit_code
                ptable.processes[i].state = task_state_dead()
                return pid, code, true
            }
        }
        i = i + 1
    }
    
    return -1, 0, false
}

func print_process_table(process_table* ptable) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║           NeurX Process Table                              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("Total Processes: ")
    print(ptable.process_count as string)
    print("")
    print("Process List:")
    
    i := 0
    for i < ptable.process_count {
        print("  PID: ")
        print(ptable.processes[i].pid as string)
        print(" Name: ")
        print(ptable.processes[i].name)
        print(" State: ")
        print(ptable.processes[i].state as string)
        i = i + 1
    }
    print("")
}

func set_task_state(task_struct* task, int state) {
    task.state = state
}

func get_task_by_pid(process_table* ptable, int pid) task_struct* {
    i := 0
    for i < ptable.process_count {
        if ptable.processes[i].pid == pid {
            return *ptable.processes[i]
        }
        i = i + 1
    }
    return nil
}

func find_child_processes(process_table* ptable, int parent_pid) ([]int, int) {
    children := int[128]{}
    count := 0
    
    i := 0
    for i < ptable.process_count {
        if ptable.parent_pids[ptable.processes[i].pid] == parent_pid {
            children[count] = ptable.processes[i].pid
            count = count + 1
        }
        i = i + 1
    }
    
    return children, count
}
