package neurx.kernel.signal

const SIGKILL = 9
const SIGSTOP = 19
const SIGTERM = 15
const SIGINT = 2
const SIGSEGV = 11
const SIGFPE = 8
const SIGABRT = 6
const SIGALRM = 14
const SIGCHLD = 17
const SIGCONT = 18
const SIGPIPE = 13
const SIGUSR1 = 10
const SIGUSR2 = 12
const SIGHUP = 1
const SIGQUIT = 3
const SIGILL = 4
const SIGTRAP = 5
const SIGBUS = 7
const SIGPROF = 27
const SIGSYS = 31
const SIGURG = 23
const SIGVTALRM = 26
const SIGXCPU = 24
const SIGXFSZ = 25
const SIGPOLL = 29
const SIGPWR = 30

const SIG_DFL = 0
const SIG_IGN = 1
const SIG_ERR = -1

const SA_NOCLDSTOP = 1
const SA_NOCLDWAIT = 2
const SA_SIGINFO = 4
const SA_RESTART = 0x10000000
const SA_NODEFER = 0x40000000
const SA_RESETHAND = 0x80000000

const SIG_BLOCK = 0
const SIG_UNBLOCK = 1
const SIG_SETMASK = 2

struct sigaction {
    func ptr sa_handler
    int64 sa_flags
    int64 sa_mask
    func ptr sa_sigaction
}

struct siginfo {
    int32 si_signo
    int32 si_errno
    int32 si_code
    int32 si_trapno
    int64 si_pid
    int64 si_uid
    int32 si_status
    int64 si_utime
    int64 si_stime
    int64 si_value
    int64 si_int
    int64 si_ptr
    int64 si_overrun
    int32 si_timerid
    int64 si_addr
    int64 si_band
    int64 si_fd
    int64 si_call_addr
    int32 si_syscall
    int32 si_arch
}

struct signal_frame {
    func ptr handler
    int32 sig
    siginfo info
    int64 mask_old
    int64 sp
    int64 ip
}

struct signal_queue {
    int32 signals[64]
    int32 head
    int32 tail
    int32 count
}

struct signal_context {
    sigaction actions[64]
    signal_queue pending_signals
    int64 blocked_mask
    int64 pending_mask
    int64 delivery_count
}

func SIG_VALID(sig int) bool {
    return sig >= 1 && sig <= 64
}

func SIG_BLOCKABLE(sig int) bool {
    return sig != SIGKILL && sig != SIGSTOP
}

func SA_ONSTACK(flags int64) bool {
    return flags & 0x08000000 != 0
}

func SA_RESTART_FLAG(flags int64) bool {
    return flags & SA_RESTART != 0
}

func SA_SIGINFO_FLAG(flags int64) bool {
    return flags & SA_SIGINFO != 0
}
