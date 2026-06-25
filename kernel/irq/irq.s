// kernel/irq/irq.s
// AI OS event/interrupt subsystem — analogue of Linux kernel/irq/
//
// Linux maps:
//   irq/handle.c     → handle_irq_event(): dispatch to handler
//   irq/manage.c     → request_irq() / free_irq()
//   irq/irqdesc.c    → IRQ descriptor table
//
// NeurX maps:
//   "IRQ"     = an asynchronous event that interrupts normal agent execution
//   Sources:  tool timeout, user interrupt, safety alert, OOM, model error,
//             sensor update (robot/auto), low-battery (mobile)
//
// IRQ priority levels (mirrors Linux IRQF_ flags concept):
//   IRQ_HARDIRQ   → must preempt immediately (safety alert, OOM)
//   IRQ_SOFTIRQ   → handle after current step completes
//   IRQ_TASKLET   → deferred, low priority

int IRQ_HARDIRQ = 0
int IRQ_SOFTIRQ = 1
int IRQ_TASKLET = 2

struct irq_descriptor {
    int    irq_num
    string name
    int    priority        // IRQ_HARDIRQ | IRQ_SOFTIRQ | IRQ_TASKLET
    bool   enabled
    int    triggered_count
    string handler         // name of S function to call
}

struct irq_state {
    []irq_descriptor descriptors
    []int            pending_hardirq
    []int            pending_softirq
    []int            pending_tasklet
    bool             irqs_disabled  // cli() equivalent
}

func new_irq_state() -> irq_state {
    return irq_state{
        descriptors:     [],
        pending_hardirq: [],
        pending_softirq: [],
        pending_tasklet: [],
        irqs_disabled:   false,
    }
}

// request_irq: register an interrupt handler
func request_irq(is irq_state, irq_num int, name string, priority int, handler string) -> irq_state {
    irq_descriptor d = irq_descriptor{
        irq_num:         irq_num,
        name:            name,
        priority:        priority,
        enabled:         true,
        triggered_count: 0,
        handler:         handler,
    }
    is.descriptors = append(is.descriptors, d)
    return is
}

// raise_irq: signal an interrupt (hardware equivalent: write to IRQ controller)
func raise_irq(is irq_state, irq_num int) -> irq_state {
    int i = 0
    while i < len(is.descriptors) {
        if is.descriptors[i].irq_num == irq_num && is.descriptors[i].enabled {
            is.descriptors[i].triggered_count = is.descriptors[i].triggered_count + 1
            int p = is.descriptors[i].priority
            if p == IRQ_HARDIRQ {
                is.pending_hardirq = append(is.pending_hardirq, irq_num)
            } else if p == IRQ_SOFTIRQ {
                is.pending_softirq = append(is.pending_softirq, irq_num)
            } else {
                is.pending_tasklet = append(is.pending_tasklet, irq_num)
            }
        }
        i = i + 1
    }
    return is
}

// drain_hardirq: process all pending hard IRQs (called before each agent step)
func drain_hardirq(is irq_state) -> (irq_state, []int) {
    []int fired = is.pending_hardirq
    is.pending_hardirq = []
    return (is, fired)
}
