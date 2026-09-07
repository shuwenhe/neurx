package neurx.kernel.syscall

func SYS_read() int { 0 }

func SYS_write() int { 1 }

func SYS_open() int { 2 }

func SYS_close() int { 3 }

func SYS_stat() int { 4 }

func SYS_fstat() int { 5 }

func SYS_lstat() int { 6 }

func SYS_poll() int { 7 }

func SYS_lseek() int { 8 }

func SYS_mmap() int { 9 }

func SYS_mprotect() int { 10 }

func SYS_munmap() int { 11 }

func SYS_brk() int { 12 }

func SYS_rt_sigaction() int { 13 }

func SYS_rt_sigprocmask() int { 14 }

func SYS_rt_sigpending() int { 15 }

func SYS_rt_sigtimedwait() int { 16 }

func SYS_rt_sigqueueinfo() int { 17 }

func SYS_rt_sigsuspend() int { 18 }

func SYS_pread64() int { 19 }

func SYS_pwrite64() int { 20 }

func SYS_readv() int { 21 }

func SYS_writev() int { 22 }

func SYS_access() int { 23 }

func SYS_pipe() int { 24 }

func SYS_select() int { 25 }

func SYS_sched_yield() int { 24 }

func SYS_mremap() int { 25 }

func SYS_msync() int { 26 }

func SYS_mincore() int { 27 }

func SYS_madvise() int { 28 }

func SYS_shmget() int { 29 }

func SYS_shmat() int { 30 }

func SYS_shmctl() int { 31 }

func SYS_dup() int { 32 }

func SYS_dup2() int { 33 }

func SYS_pause() int { 34 }

func SYS_nanosleep() int { 35 }

func SYS_getitimer() int { 36 }

func SYS_alarm() int { 37 }

func SYS_setitimer() int { 38 }

func SYS_getpid() int { 39 }

func SYS_sendto() int { 44 }

func SYS_recvfrom() int { 45 }

func SYS_sendto() int { 44 }

func SYS_socket() int { 41 }

func SYS_connect() int { 42 }

func SYS_accept() int { 43 }

func SYS_sendto() int { 44 }

func SYS_recvfrom() int { 45 }

func SYS_sendmsg() int { 46 }

func SYS_recvmsg() int { 47 }

func SYS_shutdown() int { 48 }

func SYS_bind() int { 49 }

func SYS_listen() int { 50 }

func SYS_getsockname() int { 51 }

func SYS_getpeername() int { 52 }

func SYS_socketpair() int { 53 }

func SYS_setsockopt() int { 54 }

func SYS_getsockopt() int { 55 }

func SYS_clone() int { 56 }

func SYS_fork() int { 57 }

func SYS_vfork() int { 58 }

func SYS_execve() int { 59 }

func SYS_exit() int { 60 }

func SYS_wait4() int { 61 }

func SYS_kill() int { 62 }

func SYS_uname() int { 63 }

func SYS_fcntl() int { 72 }

func SYS_flock() int { 73 }

func SYS_fsync() int { 74 }

func SYS_fdatasync() int { 75 }

func SYS_truncate() int { 76 }

func SYS_ftruncate() int { 77 }

func SYS_getdents() int { 78 }

func SYS_getcwd() int { 79 }

func SYS_chdir() int { 80 }

func SYS_fchdir() int { 81 }

func SYS_rename() int { 82 }

func SYS_mkdir() int { 83 }

func SYS_rmdir() int { 84 }

func SYS_creat() int { 85 }

func SYS_link() int { 86 }

func SYS_unlink() int { 87 }

func SYS_symlink() int { 88 }

func SYS_readlink() int { 89 }

func SYS_chmod() int { 90 }

func SYS_fchmod() int { 91 }

func SYS_chown() int { 92 }

func SYS_fchown() int { 93 }

func SYS_lchown() int { 94 }

func SYS_umask() int { 95 }

func SYS_gettimeofday() int { 96 }

func SYS_getrlimit() int { 97 }

func SYS_getrusage() int { 98 }

func SYS_sysinfo() int { 99 }

func SYS_times() int { 100 }

func SYS_ptrace() int { 101 }

func SYS_getuid() int { 102 }

func SYS_syslog() int { 103 }

func SYS_getgid() int { 104 }

func SYS_setuid() int { 105 }

func SYS_setgid() int { 106 }

func SYS_geteuid() int { 107 }

func SYS_getegid() int { 108 }

func SYS_setpgid() int { 109 }

func SYS_getppid() int { 110 }

func SYS_getpgrp() int { 111 }

func SYS_setsid() int { 112 }

func SYS_setreuid() int { 113 }

func SYS_setregid() int { 114 }

func SYS_getgroups() int { 115 }

func SYS_setgroups() int { 116 }

func SYS_setresuid() int { 117 }

func SYS_getresuid() int { 118 }

func SYS_setresgid() int { 119 }

func SYS_getresgid() int { 120 }

func SYS_getpgid() int { 121 }

func SYS_setfsuid() int { 122 }

func SYS_setfsgid() int { 123 }

func SYS_getsid() int { 124 }

func SYS_capget() int { 125 }

func SYS_capset() int { 126 }

func SYS_rt_sigpending() int { 127 }

func SYS_rt_sigtimedwait() int { 128 }

func SYS_rt_sigqueueinfo() int { 129 }

func SYS_rt_sigsuspend() int { 130 }

func SYS_sigaltstack() int { 131 }

func SYS_utime() int { 132 }

func SYS_mknod() int { 133 }

func SYS_uselib() int { 134 }

func SYS_personality() int { 135 }

func SYS_ustat() int { 136 }

func SYS_statfs() int { 137 }

func SYS_fstatfs() int { 138 }

func SYS_sysfs() int { 139 }

func SYS_getpriority() int { 140 }

func SYS_setpriority() int { 141 }

func SYS_sched_setparam() int { 142 }

func SYS_sched_getparam() int { 143 }

func SYS_sched_setscheduler() int { 144 }

func SYS_sched_getscheduler() int { 145 }

func SYS_sched_get_priority_max() int { 146 }

func SYS_sched_get_priority_min() int { 147 }

func SYS_sched_rr_get_interval() int { 148 }

func SYS_mlock() int { 149 }

func SYS_munlock() int { 150 }

func SYS_mlockall() int { 151 }

func SYS_munlockall() int { 152 }

func SYS_vhangup() int { 153 }

func SYS_modify_ldt() int { 154 }

func SYS__sysctl() int { 156 }

func SYS_arch_prctl() int { 158 }

func SYS_adjtimex() int { 159 }

func SYS_setrlimit() int { 160 }

func SYS_chroot() int { 161 }

func SYS_sync() int { 162 }

func SYS_acct() int { 163 }

func SYS_settimeofday() int { 164 }

func SYS_mount() int { 165 }

func SYS_umount2() int { 166 }

func SYS_swapon() int { 167 }

func SYS_swapoff() int { 168 }

func SYS_reboot() int { 169 }

func SYS_sethostname() int { 170 }

func SYS_setdomainname() int { 171 }

func SYS_ioctl() int { 16 }

func SYS_ioperm() int { 172 }

func SYS_iopl() int { 173 }

func SYS_create_module() int { 174 }

func SYS_init_module() int { 175 }

func SYS_delete_module() int { 176 }

func SYS_get_kernel_syms() int { 177 }

func SYS_query_module() int { 178 }

func SYS_quotactl() int { 179 }

func SYS_nfsservctl() int { 180 }

func SYS_getpmsg() int { 181 }

func SYS_putpmsg() int { 182 }

func SYS_afs_syscall() int { 183 }

func SYS_tuxcall() int { 184 }

func SYS_security() int { 185 }

func SYS_gettid() int { 186 }

func SYS_readahead() int { 187 }

func SYS_setxattr() int { 188 }

func SYS_lsetxattr() int { 189 }

func SYS_fsetxattr() int { 190 }

func SYS_getxattr() int { 191 }

func SYS_lgetxattr() int { 192 }

func SYS_fgetxattr() int { 193 }

func SYS_listxattr() int { 194 }

func SYS_llistxattr() int { 195 }

func SYS_flistxattr() int { 196 }

func SYS_removexattr() int { 197 }

func SYS_lremovexattr() int { 198 }

func SYS_fremovexattr() int { 199 }

func SYS_tkill() int { 200 }

func SYS_time() int { 201 }

func SYS_futex() int { 202 }

func SYS_sched_setaffinity() int { 203 }

func SYS_sched_getaffinity() int { 204 }

func SYS_set_thread_area() int { 205 }

func SYS_io_setup() int { 206 }

func SYS_io_destroy() int { 207 }

func SYS_io_getevents() int { 208 }

func SYS_io_submit() int { 209 }

func SYS_io_cancel() int { 210 }

func SYS_get_thread_area() int { 211 }

func SYS_lookup_dcookie() int { 212 }

func SYS_epoll_create() int { 213 }

func SYS_epoll_ctl_old() int { 214 }

func SYS_epoll_wait_old() int { 215 }

func SYS_remap_file_pages() int { 216 }

func SYS_getdents64() int { 217 }

func SYS_set_tid_address() int { 218 }

func SYS_restart_syscall() int { 219 }

func SYS_semtimedop() int { 220 }

func SYS_fadvise64() int { 221 }

func SYS_timer_create() int { 222 }

func SYS_timer_settime() int { 223 }

func SYS_timer_gettime() int { 224 }

func SYS_timer_getoverrun() int { 225 }

func SYS_timer_delete() int { 226 }

func SYS_clock_settime() int { 227 }

func SYS_clock_gettime() int { 228 }

func SYS_clock_getres() int { 229 }

func SYS_clock_nanosleep() int { 230 }

func SYS_exit_group() int { 231 }

func SYS_epoll_wait() int { 232 }

func SYS_epoll_ctl() int { 233 }

func SYS_tgkill() int { 234 }

func SYS_utimes() int { 235 }

func SYS_vserver() int { 236 }

func SYS_mbind() int { 237 }

func SYS_set_mempolicy() int { 238 }

func SYS_get_mempolicy() int { 239 }

func SYS_mq_open() int { 240 }

func SYS_mq_unlink() int { 241 }

func SYS_mq_timedsend() int { 242 }

func SYS_mq_timedreceive() int { 243 }

func SYS_mq_notify() int { 244 }

func SYS_mq_getsetattr() int { 245 }

func SYS_kexec_load() int { 246 }

func SYS_waitid() int { 247 }

func SYS_add_key() int { 248 }

func SYS_request_key() int { 249 }

func SYS_keyctl() int { 250 }

func SYS_ioprio_set() int { 251 }

func SYS_ioprio_get() int { 252 }

func SYS_inotify_init() int { 253 }

func SYS_inotify_add_watch() int { 254 }

func SYS_inotify_rm_watch() int { 255 }

func get_syscall_name(int number) string {
    if number == SYS_read() { return "read" }
    if number == SYS_write() { return "write" }
    if number == SYS_open() { return "open" }
    if number == SYS_close() { return "close" }
    if number == SYS_fork() { return "fork" }
    if number == SYS_execve() { return "execve" }
    if number == SYS_exit() { return "exit" }
    if number == SYS_wait4() { return "wait4" }
    if number == SYS_mmap() { return "mmap" }
    if number == SYS_munmap() { return "munmap" }
    if number == SYS_socket() { return "socket" }
    if number == SYS_connect() { return "connect" }
    if number == SYS_getpid() { return "getpid" }
    if number == SYS_gettid() { return "gettid" }
    if number == SYS_kill() { return "kill" }
    if number == SYS_rt_sigaction() { return "rt_sigaction" }
    if number == SYS_rt_sigprocmask() { return "rt_sigprocmask" }
    return "unknown"
}
