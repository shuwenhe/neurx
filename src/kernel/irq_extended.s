package kernel.irq
use std.strings.int_to_string
struct irq_desc {
    int irq_num
    string name
    string[] handler_names
    int cpu_affinity
    int count
    int depth
    int flags
}

struct irq_action {
    int irq_num
    int flags
    int cpu_affinity
    string handler_name
}

struct irq_chip {
    int irq_num
    int mask
    int unmask
    int ack
    int eoi
}
irq_desc g_irq_descriptors[]
irq_chip g_irq_chips[]
int g_nr_irqs
func init_irq_system(int nr_irqs) int {
    g_nr_irqs = nr_irqs
    g_irq_descriptors = new irq_desc[nr_irqs]
    g_irq_chips = new irq_chip[nr_irqs]
    var i = 0
    for i < nr_irqs {
        g_irq_descriptors[i] = irq_desc {
            irq_num: i,
            name: "irq_" + int_to_string(i),
            handler_names: new string[16],
            cpu_affinity: 0,
            count: 0,
            depth: 1,
            flags: 0,
        }
        g_irq_chips[i] = irq_chip {
            irq_num: i,
            mask: 0,
            unmask: 0,
            ack: 0,
            eoi: 0,
        }
        i = i + 1
    }
    0
}

func request_irq(int irq_num, int flags, string handler_name) (int, string) {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1, "Invalid IRQ number"
    }
    var desc = g_irq_descriptors[irq_num]
    desc.flags = flags
    desc.count = desc.count + 1
    0, ""
}

func request_threaded_irq(int irq_num, int flags, string primary_handler, string thread_handler) (int, string) {
    var res, msg := request_irq(irq_num, flags, primary_handler)
    if msg != "" {
        return res, msg
    }
    0, ""
}

func free_irq(int irq_num) int {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1
    }
    var desc = g_irq_descriptors[irq_num]
    if desc.count > 0 {
        desc.count = desc.count - 1
    }
    0
}

func enable_irq(int irq_num) int {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1
    }
    var desc = g_irq_descriptors[irq_num]
    if desc.depth > 0 {
        desc.depth = desc.depth - 1
    }
    0
}

func disable_irq(int irq_num) int {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1
    }
    var desc = g_irq_descriptors[irq_num]
    desc.depth = desc.depth + 1
    0
}

func irq_set_affinity(int irq_num, int cpumask) (int, string) {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1, "Invalid IRQ"
    }
    var desc = g_irq_descriptors[irq_num]
    desc.cpu_affinity = cpumask
    0, ""
}

func irq_get_affinity(int irq_num) (int, string) {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1, "Invalid IRQ"
    }
    var desc = g_irq_descriptors[irq_num]
    desc.cpu_affinity, ""
}

func irq_balance_load() int {
    var i = 0
    var total_count = 0
    var avg_load = 0
    for i < g_nr_irqs {
        total_count = total_count + g_irq_descriptors[i].count
        i = i + 1
    }
    if g_nr_irqs > 0 {
        avg_load = total_count / g_nr_irqs
    }
    i = 0
    for i < g_nr_irqs {
        var desc = g_irq_descriptors[i]
        if desc.count > avg_load && desc.cpu_affinity == 0 {
            desc.cpu_affinity = i % 16
        }
        i = i + 1
    }
    0
}

func handle_irq(int irq_num) int {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1
    }
    var desc = g_irq_descriptors[irq_num]
    if desc.depth > 0 {
        return -2
    }
    desc.count = desc.count + 1
    0
}

func ack_irq(int irq_num) int {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1
    }
    0
}

func eoi_irq(int irq_num) int {
    if irq_num < 0 || irq_num >= g_nr_irqs {
        return -1
    }
    0
}

func irq_stats() (int, int, int) {
    var total = g_nr_irqs
    var active = 0
    var disabled = 0
    var i = 0
    for i < g_nr_irqs {
        if g_irq_descriptors[i].depth == 0 {
            active = active + 1
        } else {
            disabled = disabled + 1
        }
        i = i + 1
    }
    total, active, disabled
}
