package neurx.kernel.signal

struct signal_manager {
    signal_context contexts[4096]
    int32 signal_pending[4096]
    int64 active_signals
}

var global_signal_manager signal_manager

func signal_manager_init() bool {
    int32 i = 0
    for i < 4096 {
        global_signal_manager.contexts[i].blocked_mask = 0
        global_signal_manager.contexts[i].pending_mask = 0
        global_signal_manager.contexts[i].delivery_count = 0
        
        int32 j = 0
        for j < 64 {
            global_signal_manager.contexts[i].pending_signals.signals[j] = 0
            j = j + 1
        }
        global_signal_manager.contexts[i].pending_signals.head = 0
        global_signal_manager.contexts[i].pending_signals.tail = 0
        global_signal_manager.contexts[i].pending_signals.count = 0
        
        j = 0
        for j < 64 {
            global_signal_manager.contexts[i].actions[j].sa_handler = 0
            global_signal_manager.contexts[i].actions[j].sa_flags = 0
            global_signal_manager.contexts[i].actions[j].sa_mask = 0
            j = j + 1
        }
        
        global_signal_manager.signal_pending[i] = 0
        i = i + 1
    }
    global_signal_manager.active_signals = 0
    return true
}

func do_sigaction(pid int32, sig int32, new_action sigaction*, old_action sigaction*) int {
    if !SIG_VALID(sig) {
        return -22
    } else if pid < 0 || pid >= 4096 {
        return -3
    } else {
        signal_context* ctx = *global_signal_manager.contexts[pid]
        
        if old_action != 0 {
            old_action->sa_handler = ctx->actions[sig].sa_handler
            old_action->sa_flags = ctx->actions[sig].sa_flags
            old_action->sa_mask = ctx->actions[sig].sa_mask
        }
        
        if new_action != 0 {
            ctx->actions[sig].sa_handler = new_action->sa_handler
            ctx->actions[sig].sa_flags = new_action->sa_flags
            ctx->actions[sig].sa_mask = new_action->sa_mask
        }
        
        return 0
    }
}

func do_sigprocmask(pid int32, how int32, set int64*, oldset int64*) int {
    if pid < 0 || pid >= 4096 {
        return -3
    } else {
        signal_context* ctx = *global_signal_manager.contexts[pid]
        
        if oldset != 0 {
            oldset* = ctx->blocked_mask
        }
        
        if set != 0 {
            if how == SIG_BLOCK {
                ctx->blocked_mask = ctx->blocked_mask | set*
            } else if how == SIG_UNBLOCK {
                ctx->blocked_mask = ctx->blocked_mask & ~(set*)
            } else if how == SIG_SETMASK {
                ctx->blocked_mask = set*
            } else {
                return -22
            }
        }
        
        return 0
    }
}

func do_kill(sender_pid int32, target_pid int32, sig int32) int {
    if !SIG_VALID(sig) {
        return -22
    } else if target_pid < 0 || target_pid >= 4096 {
        return -3
    } else if sender_pid < 0 || sender_pid >= 4096 {
        return -3
    } else {
        signal_queue* queue = *global_signal_manager.contexts[target_pid].pending_signals
        
        if queue->count >= 64 {
            return -11
        } else {
            int32 idx = queue->tail
            queue->signals[idx] = sig
            queue->tail = (queue->tail + 1) % 64
            queue->count = queue->count + 1
            
            global_signal_manager.signal_pending[target_pid] = 1
            global_signal_manager.active_signals = global_signal_manager.active_signals + 1
            
            return 0
        }
    }
}

func signal_queue_enqueue(queue signal_queue*, sig int32) bool {
    if queue->count >= 64 {
        return false
    } else {
        queue->signals[queue->tail] = sig
        queue->tail = (queue->tail + 1) % 64
        queue->count = queue->count + 1
        return true
    }
}

func signal_queue_dequeue(queue signal_queue*) int32 {
    if queue->count == 0 {
        return -1
    } else {
        int32 sig = queue->signals[queue->head]
        queue->head = (queue->head + 1) % 64
        queue->count = queue->count - 1
        return sig
    }
}

func signal_queue_empty(queue signal_queue*) bool {
    return queue->count == 0
}

func signal_is_blocked(ctx signal_context*, sig int32) bool {
    return (ctx->blocked_mask & (1 << (sig - 1))) != 0
}

func signal_can_deliver(ctx signal_context*, sig int32) bool {
    return SIG_VALID(sig) && !signal_is_blocked(ctx, sig)
}

func signal_set_handler(ctx signal_context*, sig int32, handler func ptr) {
    if SIG_VALID(sig) {
        ctx->actions[sig].sa_handler = handler
    }
}

func signal_get_handler(ctx signal_context*, sig int32) func ptr {
    if SIG_VALID(sig) {
        return ctx->actions[sig].sa_handler
    } else {
        return 0
    }
}

func signal_set_mask(ctx signal_context*, mask int64) {
    ctx->blocked_mask = mask
}

func signal_get_mask(ctx signal_context*) int64 {
    return ctx->blocked_mask
}

func signal_check_pending(pid int32) int32 {
    if pid < 0 || pid >= 4096 {
        return -1
    } else {
        signal_queue* queue = *global_signal_manager.contexts[pid].pending_signals
        if signal_queue_empty(queue) {
            return -1
        } else {
            int32 sig = signal_queue_dequeue(queue)
            if signal_queue_empty(queue) {
                global_signal_manager.signal_pending[pid] = 0
            }
            return sig
        }
    }
}

func signal_deliver_all(pid int32) int32 {
    if pid < 0 || pid >= 4096 {
        return 0
    } else {
        signal_context* ctx = *global_signal_manager.contexts[pid]
        int32 delivered = 0
        int32 sig = signal_check_pending(pid)
        
        for sig > 0 {
            if signal_can_deliver(ctx, sig) {
                func ptr handler = signal_get_handler(ctx, sig)
                if handler != 0 && handler != SIG_IGN {
                    delivered = delivered + 1
                }
            }
            sig = signal_check_pending(pid)
        }
        
        return delivered
    }
}
