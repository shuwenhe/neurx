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
    vec[irq_handler] handlers
    int status
    int depth
    int disable_count
    int enable_count
}

struct interrupt_controller {
    vec[irq_descriptor] descriptors
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
    vec[exception_handler] handlers
    int total_exceptions
    int critical_count
    int panic_count
}

func interrupt_controller_create() interrupt_controller {
    ctrl := interrupt_controller {
        descriptors: vec[irq_descriptor](),
        total_interrupts: 0,
        total_handlers: 0,
        spurious_count: 0,
        interrupt_rate_per_sec: 0
    }
    return ctrl
}

func (ctrl: &mut interrupt_controller) register_handler(int irq_num, string name, interrupt_type int_type, int priority) result[int, string] {
    if irq_num < 0 || irq_num > 255 {
        return result::err("Invalid IRQ number")
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
        handlers: vec[irq_handler](),
        status: 0,
        depth: 0,
        disable_count: 0,
        enable_count: 0
    }
    
    desc.handlers.push(handler)
    ctrl.descriptors.push(desc)
    ctrl.total_handlers = ctrl.total_handlers + 1
    
    return result::ok(irq_num)
}

func (ctrl: &mut interrupt_controller) handle_interrupt(int irq_num) result[int, string] {
    if irq_num < 0 || irq_num > 255 {
        ctrl.spurious_count = ctrl.spurious_count + 1
        return result::err("Spurious interrupt")
    }
    
    ctrl.total_interrupts = ctrl.total_interrupts + 1
    return result::ok(irq_num)
}

func (ctrl: &mut interrupt_controller) mask_irq(int irq_num) result[bool, string] {
    if irq_num < 0 || irq_num > 255 {
        return result::err("Invalid IRQ")
    }
    return result::ok(true)
}

func (ctrl: &mut interrupt_controller) unmask_irq(int irq_num) result[bool, string] {
    if irq_num < 0 || irq_num > 255 {
        return result::err("Invalid IRQ")
    }
    return result::ok(true)
}

func exception_manager_create() exception_manager {
    mgr := exception_manager {
        handlers: vec[exception_handler](),
        total_exceptions: 0,
        critical_count: 0,
        panic_count: 0
    }
    return mgr
}

func (mgr: &mut exception_manager) register_exception_handler(int exc_num, string name) result[int, string] {
    if exc_num < 0 || exc_num > 31 {
        return result::err("Invalid exception number")
    }
    
    handler := exception_handler {
        exception_num: exc_num,
        handler_name: name,
        total_handled: 0,
        total_errors: 0
    }
    
    mgr.handlers.push(handler)
    return result::ok(exc_num)
}

func (mgr: &mut exception_manager) handle_exception(int exc_num, exception_frame frame) result[bool, string] {
    mgr.total_exceptions = mgr.total_exceptions + 1
    
    if exc_num == 0 {
        return result::ok(true)
    }
    
    if exc_num >= 8 && exc_num <= 14 {
        mgr.critical_count = mgr.critical_count + 1
    }
    
    if exc_num == 31 {
        mgr.panic_count = mgr.panic_count + 1
        return result::err("PANIC: Double fault detected")
    }
    
    return result::ok(true)
}

func (mgr: &mut exception_manager) exception_stats() string {
    total := mgr.total_exceptions
    critical := mgr.critical_count
    panics := mgr.panic_count
    
    return "Exceptions: " + total as string + ", Critical: " + critical as string + ", Panics: " + panics as string
}
