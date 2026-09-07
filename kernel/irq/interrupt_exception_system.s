package neurx.kernel.irq

struct interrupt_type {
    int value
}

func interrupt_type_hardware() interrupt_type { interrupt_type { value: 0 } }

func interrupt_type_software() interrupt_type { interrupt_type { value: 1 } }

func interrupt_type_exception() interrupt_type { interrupt_type { value: 2 } }

func interrupt_type_trap() interrupt_type { interrupt_type { value: 3 } }

func interrupt_type_fault() interrupt_type { interrupt_type { value: 4 } }

struct irq_state {
    int value
}

func irq_state_masked() irq_state { irq_state { value: 0 } }

func irq_state_unmasked() irq_state { irq_state { value: 1 } }

func irq_state_disabled() irq_state { irq_state { value: 2 } }

struct irq_handler {
    int irq_number
    string handler_name
    interrupt_type int_type
    int priority
    int total_handled
    int total_errors
}

struct irq_descriptor {
    int irq_num
    interrupt_type int_type
    irq_handler[] handlers
    int status
    int depth
    int disable_count
    int enable_count
}

struct interrupt_controller {
    irq_descriptor[] descriptors
    int total_interrupts
    int total_handlers
    int spurious_count
    int interrupt_rate_per_sec
}

struct exception_frame {
    int error_code
    int rip
    int rsp
    int rflags
    int cr2
    string exception_name
}

struct exception_handler {
    int exception_num
    string handler_name
    int total_handled
    int total_errors
}

struct exception_manager {
    exception_handler[] handlers
    int total_exceptions
    int critical_count
    int panic_count
}

func interrupt_controller_create() interrupt_controller {
    ctrl := interrupt_controller {
        descriptors: irq_descriptor[](),
        total_interrupts: 0,
        total_handlers: 0,
        spurious_count: 0,
        interrupt_rate_per_sec: 0
    }
    return ctrl
}

func (interrupt_controller* ctrl) register_handler(int irq_num, string name, interrupt_type int_type, int priority) (int, string) {
    if irq_num < 0 || irq_num > 255 {
        return ((), "Invalid IRQ number")
    }
    
    handler := irq_handler {
        irq_number: irq_num,
        handler_name: name,
        int_type: int_type,
        priority: priority,
        total_handled: 0,
        total_errors: 0
    }
    
    desc := irq_descriptor {
        irq_num: irq_num,
        int_type: int_type,
        handlers: irq_handler[](),
        status: 0,
        depth: 0,
        disable_count: 0,
        enable_count: 0
    }
    
    desc.handlers = append(desc.handlers, handler)
    ctrl.descriptors = append(ctrl.descriptors, desc)
    ctrl.total_handlers = ctrl.total_handlers + 1
    
    return irq_num, ""
}

func (interrupt_controller* ctrl) handle_interrupt(int irq_num) (int, string) {
    if irq_num < 0 || irq_num > 255 {
        ctrl.spurious_count = ctrl.spurious_count + 1
        return ((), "Spurious interrupt")
    }
    
    ctrl.total_interrupts = ctrl.total_interrupts + 1
    return irq_num, ""
}

func (interrupt_controller* ctrl) mask_irq(int irq_num) (bool, string) {
    if irq_num < 0 || irq_num > 255 {
        return ((), "Invalid IRQ")
    }
    return true, ""
}

func (interrupt_controller* ctrl) unmask_irq(int irq_num) (bool, string) {
    if irq_num < 0 || irq_num > 255 {
        return ((), "Invalid IRQ")
    }
    return true, ""
}

func exception_manager_create() exception_manager {
    mgr := exception_manager {
        handlers: exception_handler[](),
        total_exceptions: 0,
        critical_count: 0,
        panic_count: 0
    }
    return mgr
}

func (exception_manager* mgr) register_exception_handler(int exc_num, string name) (int, string) {
    if exc_num < 0 || exc_num > 31 {
        return ((), "Invalid exception number")
    }
    
    handler := exception_handler {
        exception_num: exc_num,
        handler_name: name,
        total_handled: 0,
        total_errors: 0
    }
    
    mgr.handlers = append(mgr.handlers, handler)
    return exc_num, ""
}

func (exception_manager* mgr) handle_exception(int exc_num, exception_frame frame) (bool, string) {
    mgr.total_exceptions = mgr.total_exceptions + 1
    
    if exc_num == 0 {
        return true, ""
    }
    
    if exc_num >= 8 && exc_num <= 14 {
        mgr.critical_count = mgr.critical_count + 1
    }
    
    if exc_num == 31 {
        mgr.panic_count = mgr.panic_count + 1
        return ((), "PANIC: Double fault detected")
    }
    
    return true, ""
}

func (exception_manager* mgr) exception_stats() string {
    total := mgr.total_exceptions
    critical := mgr.critical_count
    panics := mgr.panic_count
    
    return "Exceptions: " + total as string + ", Critical: " + critical as string + ", Panics: " + panics as string
}
