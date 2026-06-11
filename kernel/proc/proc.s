// kernel/proc/proc.s
// AI agent/process lifecycle — analogue of Linux kernel/fork.c + kernel/exit.c
//
// Linux maps:
//   kernel/fork.c    → copy_process(), do_fork()
//   kernel/exit.c    → do_exit(), wait_for_completion
//   kernel/pid.c     → PID allocation
//
// NeurX maps:
//   "process" = an agent instance with its own goal, memory, tool registry
//   "thread"  = a sub-step within an agent (parallel tool calls, sub-agents)
//   Lifecycle: CREATED → RUNNING → WAITING → ZOMBIE → REAPED

int PROC_CREATED = 0
int PROC_RUNNING = 1
int PROC_WAITING = 2   // blocked on tool call / sub-agent
int PROC_ZOMBIE  = 3   // finished, result not yet collected
int PROC_REAPED  = 4   // result collected, resources freed

struct proc_descriptor {
    int    pid
    int    ppid            // parent pid, -1 for root agents
    string name
    string goal
    int    state           // PROC_*
    int    sched_class     // from kernel/sched
    int    exit_code       // 0 = success
    string exit_reason
    int    created_at_ms
    int    exited_at_ms
    int    mem_region_id   // assigned memory region
}

struct proc_table {
    []proc_descriptor procs
    int               next_pid
}

func new_proc_table() -> proc_table {
    return proc_table{procs: [], next_pid: 1}
}

// spawn: create a new agent process (do_fork equivalent)
func proc_spawn(pt proc_table, ppid int, name string, goal string, sched_class int) -> (proc_table, int) {
    int pid = pt.next_pid
    proc_descriptor p = proc_descriptor{
        pid:          pid,
        ppid:         ppid,
        name:         name,
        goal:         goal,
        state:        PROC_CREATED,
        sched_class:  sched_class,
        exit_code:    0,
        exit_reason:  "",
        created_at_ms: 0,
        exited_at_ms:  0,
        mem_region_id: -1,
    }
    pt.procs = append(pt.procs, p)
    pt.next_pid = pt.next_pid + 1
    return (pt, pid)
}

// exit: mark agent as zombie (do_exit equivalent)
func proc_exit(pt proc_table, pid int, exit_code int, reason string) -> proc_table {
    int i = 0
    while i < len(pt.procs) {
        if pt.procs[i].pid == pid {
            pt.procs[i].state       = PROC_ZOMBIE
            pt.procs[i].exit_code   = exit_code
            pt.procs[i].exit_reason = reason
        }
        i = i + 1
    }
    return pt
}

// wait: collect zombie child (waitpid equivalent)
func proc_wait(pt proc_table, ppid int) -> (proc_table, proc_descriptor, bool) {
    int i = 0
    while i < len(pt.procs) {
        if pt.procs[i].ppid == ppid && pt.procs[i].state == PROC_ZOMBIE {
            proc_descriptor result = pt.procs[i]
            pt.procs[i].state = PROC_REAPED
            return (pt, result, true)
        }
        i = i + 1
    }
    return (pt, proc_descriptor{}, false)
}
