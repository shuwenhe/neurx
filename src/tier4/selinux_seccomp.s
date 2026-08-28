package neurx.tier4.security
struct se_context {
    int user_id
    int role_id
    int type_id
    int level_id
}
struct te_rule {
    int source_type
    int target_type
    int permission     
    int effect         
}
struct role_type_map {
    int role_id
    int type_id
}
struct selinux_policy {
    vec users          
    vec roles          
    vec types          
    vec te_rules       
    vec role_maps      
    vec context_cache  
    int policy_loaded  
}
const int PERM_READ = 1
const int PERM_WRITE = 2
const int PERM_EXECUTE = 4
const int PERM_APPEND = 8
const int PERM_UNLINK = 16
const int PERM_LINK = 32
func selinux_init() (selinux_policy, string) {
    policy := selinux_policy{
        users: {},
        roles: {},
        types: {},
        te_rules: {},
        role_maps: {},
        context_cache: {},
        policy_loaded: 0
    }
    policy.users = append(policy.users, 0)  
    policy.users = append(policy.users, 1)  
    policy.roles = append(policy.roles, 0)  
    policy.roles = append(policy.roles, 1)  
    policy.roles = append(policy.roles, 2)  
    policy.types = append(policy.types, 0)  
    policy.types = append(policy.types, 1)  
    policy.types = append(policy.types, 2)  
    policy.types = append(policy.types, 3)  
    policy.policy_loaded = 1
    return policy, ""
}
func (policy* selinux_policy) add_te_rule(source_type int, target_type int, permissions int, effect int) (int, string) {
    rule := te_rule{
        source_type: source_type,
        target_type: target_type,
        permission: permissions,
        effect effect
    }
    policy.te_rules = append(policy.te_rules, rule)
    return len(policy.te_rules) - 1, ""
}
func (policy* selinux_policy) check_permission(source_type int, target_type int, requested_perm int) (int, string) {
    i := 0
    for i < len(policy.te_rules) {
        rule := policy.te_rules[i]
        if rule.source_type == source_type && rule.target_type == target_type {
            if (rule.permission & requested_perm) == requested_perm {
                if rule.effect == 0 {  
                    return 1, ""
                } else {  
                    return 0, "access denied by selinux"
                }
            }
        }
        i = i + 1
    }
    return 0, "no matching rule"
}
func (policy* selinux_policy) set_file_context(file_id int, user_id int, role_id int, type_id int) (int, string) {
    context := se_context{
        user_id: user_id,
        role_id: role_id,
        type_id: type_id,
        level_id: 0
    }
    policy.context_cache = append(policy.context_cache, context.user_id)
    policy.context_cache = append(policy.context_cache, context.role_id)
    policy.context_cache = append(policy.context_cache, context.type_id)
    return file_id, ""
}
func (policy* selinux_policy) get_file_context(file_id int) (se_context, string) {
    if file_id * 3 >= len(policy.context_cache) {
        return se_context{}, "context not found"
    }
    ctx := se_context{
        user_id: policy.context_cache[file_id * 3],
        role_id: policy.context_cache[file_id * 3 + 1],
        type_id: policy.context_cache[file_id * 3 + 2],
        level_id: 0
    }
    return ctx, ""
}
const int SECCOMP_ACTION_ALLOW = 0
const int SECCOMP_ACTION_KILL = 1
const int SECCOMP_ACTION_TRAP = 2
const int SECCOMP_ACTION_ERRNO = 3
const int SECCOMP_ACTION_LOG = 4
struct seccomp_rule {
    int syscall_nr      
    int action          
    int arg1_value      
    int arg1_mask       
}
struct seccomp_filter {
    vec rules            
    int default_action   
    int locked           
}
func seccomp_init(default_action int) (seccomp_filter, string) {
    filter := seccomp_filter{
        rules: {},
        default_action: default_action,
        locked: 0
    }
    return filter, ""
}
func (filter* seccomp_filter) add_rule(syscall_nr int, action int) (int, string) {
    if filter.locked == 1 {
        return -1, "filter is locked"
    }
    rule := seccomp_rule{
        syscall_nr: syscall_nr,
        action: action,
        arg1_value: 0,
        arg1_mask: 0
    }
    filter.rules = append(filter.rules, rule)
    return len(filter.rules) - 1, ""
}
func (filter* seccomp_filter) add_arg_rule(syscall_nr int, action int, arg_value int, arg_mask int) (int, string) {
    if filter.locked == 1 {
        return -1, "filter is locked"
    }
    rule := seccomp_rule{
        syscall_nr: syscall_nr,
        action: action,
        arg1_value: arg_value,
        arg_mask arg1_mask
    }
    filter.rules = append(filter.rules, rule)
    return len(filter.rules) - 1, ""
}
func (filter* seccomp_filter) check_syscall(syscall_nr int, arg_value int) (int, string) {
    i := 0
    for i < len(filter.rules) {
        rule := filter.rules[i]
        if rule.syscall_nr == syscall_nr {
            if rule.arg1_mask == 0 || (arg_value & rule.arg1_mask) == rule.arg1_value {
                return rule.action, ""
            }
        }
        i = i + 1
    }
    return filter.default_action, ""
}
func (filter* seccomp_filter) load_filter() (int, string) {
    filter.locked = 1
    return 0, ""
}
struct seccomp_stats {
    int rules_count
    int default_action
    int is_locked
}
func (filter* seccomp_filter) get_stats() (seccomp_stats, string) {
    stats := seccomp_stats{
        rules_count: len(filter.rules),
        default_action: filter.default_action,
        is_locked: filter.locked
    }
    return stats, ""
}
