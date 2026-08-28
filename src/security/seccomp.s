package neurx.security
const SECCOMP_ACTION_ALLOW = 0
const SECCOMP_ACTION_DENY = 1
const SECCOMP_ACTION_KILL = 2
const SECCOMP_ACTION_LOG = 3
const SECCOMP_MODE_DISABLED = 0
const SECCOMP_MODE_STRICT = 1
const SECCOMP_MODE_FILTER = 2
struct seccomp_rule {
    int rule_id
    int syscall_nr
    int action  
    string syscall_name
    int condition_count
}
struct seccomp_condition {
    int arg_index  
    int comparator  
    int value
}
struct seccomp_filter {
    int filter_id
    string filter_name
    vec rules
    vec conditions
    int total_rules
}
struct seccomp_manager {
    int mode  
    seccomp_filter current_filter
    vec filters
    int filter_counter
    int denied_syscalls
    int allowed_syscalls
    int killed_processes
    int logged_violations
}
func create_seccomp_rule(syscall_nr int, syscall_name string, action int) (seccomp_rule, string) {
    rule := seccomp_rule{
        rule_id: 0,
        syscall_nr: syscall_nr,
        action: action,
        syscall_name: syscall_name,
        condition_count: 0
    }
    return rule, ""
}
func (filter* seccomp_filter) add_rule(rule seccomp_rule) (int, string) {
    rule.rule_id = filter.total_rules
    filter.rules = append(filter.rules, rule)
    filter.total_rules = filter.total_rules + 1
    return rule.rule_id, ""
}
func (filter* seccomp_filter) add_condition(arg_index int, comparator int, value int) (int, string) {
    condition := seccomp_condition{
        arg_index: arg_index,
        comparator: comparator,
        value value
    }
    filter.conditions = append(filter.conditions, condition)
    return len(filter.conditions) - 1, ""
}
func (mgr* seccomp_manager) check_syscall(syscall_nr int, arg0 int, arg1 int, arg2 int) (int, string) {
    if mgr.mode == SECCOMP_MODE_DISABLED {
        mgr.allowed_syscalls = mgr.allowed_syscalls + 1
        return SECCOMP_ACTION_ALLOW, ""
    }
    i := 0
    for i < len(mgr.current_filter.rules) {
        rule := mgr.current_filter.rules[i]
        if rule.syscall_nr == syscall_nr {
            if rule.action == SECCOMP_ACTION_ALLOW {
                mgr.allowed_syscalls = mgr.allowed_syscalls + 1
                return SECCOMP_ACTION_ALLOW, ""
            } else if rule.action == SECCOMP_ACTION_DENY {
                mgr.denied_syscalls = mgr.denied_syscalls + 1
                return SECCOMP_ACTION_DENY, "syscall denied"
            } else if rule.action == SECCOMP_ACTION_KILL {
                mgr.killed_processes = mgr.killed_processes + 1
                return SECCOMP_ACTION_KILL, "process killed"
            } else if rule.action == SECCOMP_ACTION_LOG {
                mgr.logged_violations = mgr.logged_violations + 1
                return SECCOMP_ACTION_LOG, "syscall logged"
            }
        }
        i = i + 1
    }
    mgr.denied_syscalls = mgr.denied_syscalls + 1
    return SECCOMP_ACTION_DENY, "syscall not in whitelist"
}
func create_seccomp_filter(name string) (seccomp_filter, string) {
    filter := seccomp_filter{
        filter_id: 0,
        filter_name: name,
        rules: {},
        conditions: {},
        total_rules: 0
    }
    return filter, ""
}
func create_seccomp_manager() (seccomp_manager, string) {
    filter, _ := create_seccomp_filter("default")
    mgr := seccomp_manager{
        mode: SECCOMP_MODE_DISABLED,
        current_filter: filter,
        filters: {},
        filter_counter: 0,
        denied_syscalls: 0,
        allowed_syscalls: 0,
        killed_processes: 0,
        logged_violations: 0
    }
    return mgr, ""
}
func (mgr* seccomp_manager) set_mode(mode int) (int, string) {
    mgr.mode = mode
    return mode, ""
}
func (mgr* seccomp_manager) enable_whitelist() (int, string) {
    mgr.mode = SECCOMP_MODE_FILTER
    return 0, ""
}
func (mgr* seccomp_manager) enable_blacklist() (int, string) {
    mgr.mode = SECCOMP_MODE_FILTER
    return 0, ""
}
func (mgr* seccomp_manager) load_filter(filter seccomp_filter) (int, string) {
    filter.filter_id = mgr.filter_counter
    mgr.filters = append(mgr.filters, filter)
    mgr.current_filter = filter
    mgr.filter_counter = mgr.filter_counter + 1
    return filter.filter_id, ""
}
func (mgr* seccomp_manager) get_stats() (seccomp_manager, string) {
    return mgr, ""
}
