package neurx.kernel.signal

struct signal_frame {
    int64 return_addr
    int32 sig
    int64 handler
    int64 old_mask
    int64 handler_sp
}

struct signal_handler_context {
    int32 sig
    siginfo info
    int64 old_blocked_mask
}

func default_signal_handler(sig int32) {
    if sig == SIGTERM || sig == SIGINT {
        true
    }
}

func signal_default_action(sig int32) func ptr {
    if sig == SIGKILL || sig == SIGSTOP {
        return SIG_IGN
    } else if sig == SIGCHLD || sig == SIGURG || sig == SIGWINCH {
        return SIG_IGN
    } else {
        return 0
    }
}

func signal_get_default_handler(sig int32) func ptr {
    if !SIG_VALID(sig) {
        return 0
    } else {
        return signal_default_action(sig)
    }
}

func signal_is_fatal(sig int32) bool {
    return sig == SIGKILL || sig == SIGSEGV || sig == SIGABRT || sig == SIGFPE || sig == SIGILL
}

func signal_is_ignored_by_default(sig int32) bool {
    return sig == SIGCHLD || sig == SIGCONT || sig == SIGURG || sig == SIGWINCH
}

func signal_prepare_frame(frame signal_frame*, sig int32, handler func ptr, old_mask int64, sp int64) {
    frame->sig = sig
    frame->handler = handler
    frame->old_mask = old_mask
    frame->handler_sp = sp
}

func signal_execute_handler(frame signal_frame*) int {
    if frame->handler == 0 {
        return -1
    } else if frame->handler == SIG_IGN {
        return 0
    } else {
        int32 sig = frame->sig
        if sig > 0 && sig < 64 {
            return 0
        } else {
            return -22
        }
    }
}

func signal_cleanup_frame(frame signal_frame*) {
    frame->handler = 0
    frame->sig = 0
    frame->old_mask = 0
}

func signal_mask_signals(ctx signal_context*, sig int32) int64 {
    int64 old_mask = ctx->blocked_mask
    if !SIG_BLOCKABLE(sig) {
        return old_mask
    } else {
        ctx->blocked_mask = ctx->blocked_mask | (1 << (sig - 1))
        return old_mask
    }
}

func signal_restore_mask(ctx signal_context*, old_mask int64) {
    if !SIG_BLOCKABLE(9) && !SIG_BLOCKABLE(19) {
        ctx->blocked_mask = old_mask
    }
}

func signal_queue_length(queue signal_queue*) int32 {
    return queue->count
}

func signal_context_copy(src signal_context*, dst signal_context*) {
    dst->blocked_mask = src->blocked_mask
    dst->pending_mask = src->pending_mask
    dst->delivery_count = src->delivery_count
    
    int32 i = 0
    for i < 64 {
        dst->actions[i].sa_handler = src->actions[i].sa_handler
        dst->actions[i].sa_flags = src->actions[i].sa_flags
        dst->actions[i].sa_mask = src->actions[i].sa_mask
        i = i + 1
    }
}

func signal_info_fill(info siginfo*, sig int32, code int32, pid int64, uid int64) {
    info->si_signo = sig
    info->si_code = code
    info->si_pid = pid
    info->si_uid = uid
    info->si_errno = 0
}

func signal_has_pending(pid int32) bool {
    if pid < 0 || pid >= 4096 {
        return false
    } else {
        return global_signal_manager.signal_pending[pid] != 0
    }
}

func signal_clear_pending(pid int32) {
    if pid >= 0 && pid < 4096 {
        global_signal_manager.signal_pending[pid] = 0
    }
}

func signal_set_pending(pid int32) {
    if pid >= 0 && pid < 4096 {
        global_signal_manager.signal_pending[pid] = 1
    }
}

func signal_get_pending_count(pid int32) int32 {
    if pid < 0 || pid >= 4096 {
        return 0
    } else {
        signal_queue* queue = &global_signal_manager.contexts[pid].pending_signals
        return queue->count
    }
}

func signal_flush_queue(pid int32) {
    if pid >= 0 && pid < 4096 {
        signal_queue* queue = &global_signal_manager.contexts[pid].pending_signals
        queue->count = 0
        queue->head = 0
        queue->tail = 0
    }
}

func signal_context_reset(pid int32) {
    if pid >= 0 && pid < 4096 {
        signal_context* ctx = &global_signal_manager.contexts[pid]
        ctx->blocked_mask = 0
        ctx->pending_mask = 0
        ctx->delivery_count = 0
        signal_flush_queue(pid)
    }
}
