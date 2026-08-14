int IRQ_HARDIRQ = 0
int IRQ_SOFTIRQ = 1
int IRQ_TASKLET = 2
struct irq_descriptor {
    int    irq_num
    string name
    int    priority
    bool   enabled
    int    triggered_count
    string handler
}

struct irq_state {
    []irq_descriptor descriptors
    []int            pending_hardirq
    []int            pending_softirq
    []int            pending_tasklet
    bool             irqs_disabled
}

func new_irq_state() irq_state {
    return irq_state{
        descriptors:     [],
        pending_hardirq: [],
        pending_softirq: [],
        pending_tasklet: [],
        irqs_disabled:   false,
    }
}

func request_irq(is irq_state, int irq_num, string name, int priority, string handler) irq_state {
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

func raise_irq(is irq_state, int irq_num) irq_state {
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

func drain_hardirq(is irq_state) (irq_state, []int) {
    []int fired = is.pending_hardirq
    is.pending_hardirq = []
    return (is, fired)
}
