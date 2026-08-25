package neurx.kernel.signal

func syscall_rt_sigaction(sig int32, act sigaction*, oldact sigaction*, sigset_size int64) int {
    if sigset_size != 8 {
        return -22
    } else if !SIG_VALID(sig) {
        return -22
    } else {
        sigaction new_action
        sigaction old_action
        
        if act != 0 {
            new_action.sa_handler = act->sa_handler
            new_action.sa_flags = act->sa_flags
            new_action.sa_mask = act->sa_mask
        }
        
        int result = do_sigaction(0, sig, &new_action, &old_action)
        
        if result == 0 && oldact != 0 {
            oldact->sa_handler = old_action.sa_handler
            oldact->sa_flags = old_action.sa_flags
            oldact->sa_mask = old_action.sa_mask
        }
        
        return result
    }
}

func syscall_rt_sigprocmask(how int32, set int64*, oldset int64*) int {
    if how != SIG_BLOCK && how != SIG_UNBLOCK && how != SIG_SETMASK {
        return -22
    } else {
        int64 new_set = 0
        if set != 0 {
            new_set = set*
        }
        
        int64 old_set = 0
        int result = do_sigprocmask(0, how, &new_set, &old_set)
        
        if result == 0 && oldset != 0 {
            oldset* = old_set
        }
        
        return result
    }
}

func syscall_kill(pid int32, sig int32) int {
    if !SIG_VALID(sig) && sig != 0 {
        return -22
    } else if pid == 0 {
        return -22
    } else {
        return do_kill(0, pid, sig)
    }
}

func syscall_tgkill(tgid int32, tid int32, sig int32) int {
    if !SIG_VALID(sig) && sig != 0 {
        return -22
    } else if tgid <= 0 || tid <= 0 {
        return -22
    } else {
        return do_kill(tgid, tid, sig)
    }
}

func syscall_tkill(tid int32, sig int32) int {
    if !SIG_VALID(sig) && sig != 0 {
        return -22
    } else if tid <= 0 {
        return -22
    } else {
        return do_kill(tid, tid, sig)
    }
}

func syscall_signal(sig int32, handler func ptr) func ptr {
    if !SIG_VALID(sig) {
        return 0
    } else {
        sigaction new_action
        sigaction old_action
        
        new_action.sa_handler = handler
        new_action.sa_flags = SA_RESETHAND | SA_RESTART
        new_action.sa_mask = 0
        
        int result = do_sigaction(0, sig, &new_action, &old_action)
        
        if result == 0 {
            return old_action.sa_handler
        } else {
            return 0
        }
    }
}

func syscall_pause() int {
    return -4
}

func syscall_sigsuspend(mask int64*) int {
    if mask == 0 {
        return -14
    } else {
        return -4
    }
}

func syscall_sigpending(set int64*) int {
    if set == 0 {
        return -14
    } else {
        signal_context* ctx = &global_signal_manager.contexts[0]
        set* = ctx->pending_mask
        return 0
    }
}

func syscall_sigaltstack(ss int64*, oss int64*) int {
    if ss == 0 && oss == 0 {
        return -14
    } else {
        return 0
    }
}

func syscall_rt_sigpending(set int64*, sigset_size int64) int {
    if set == 0 {
        return -14
    } else if sigset_size != 8 {
        return -22
    } else {
        signal_context* ctx = &global_signal_manager.contexts[0]
        set* = ctx->pending_mask
        return 0
    }
}

func syscall_rt_sigwait(uthese int64*, info siginfo*, timeout int64) int {
    if uthese == 0 || info == 0 {
        return -14
    } else {
        return -4
    }
}

func syscall_rt_sigtimedwait(uthese int64*, info siginfo*, timeout int64, sigset_size int64) int {
    if uthese == 0 || info == 0 {
        return -14
    } else if sigset_size != 8 {
        return -22
    } else {
        return -110
    }
}

func syscall_signalfd(ufd int32, user_mask int64*, sizemask int64) int {
    if sizemask != 8 {
        return -22
    } else {
        return -9
    }
}

func syscall_signalfd4(ufd int32, user_mask int64*, sizemask int64, flags int32) int {
    if sizemask != 8 {
        return -22
    } else {
        return -9
    }
}
