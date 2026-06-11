// security/lsm.s
// AI OS Linux Security Module — analogue of Linux security/security.c
//
// Linux maps:
//   security/security.c   → LSM hook dispatch (SELinux / AppArmor / etc.)
//   security/commoncap.c  → POSIX capabilities
//   security/seccomp.c    → syscall filtering
//   security/keys/        → key/credential management
//
// NeurX maps:
//   Every agent action passes through security hooks before execution.
//   Policy is expressed as capability sets per agent identity.
//   Hooks:
//     lsm_check_tool_call()   → can this agent call this tool?
//     lsm_check_mem_alloc()   → can this agent alloc N bytes on this device?
//     lsm_check_file_access() → can this agent read/write this VFS path?
//     lsm_check_spawn()       → can this agent spawn a sub-agent?
//     lsm_check_network()     → can this agent make an outbound request?

// Capability bits (analogous to Linux CAP_* constants)
int CAP_TOOL_EXEC    = 1    // may call registered tools
int CAP_FILE_READ    = 2    // may read from VFS
int CAP_FILE_WRITE   = 4    // may write to VFS
int CAP_NET_OUTBOUND = 8    // may make outbound network calls
int CAP_SPAWN_AGENT  = 16   // may spawn sub-agents
int CAP_GPU_ALLOC    = 32   // may allocate GPU memory
int CAP_ADMIN        = 255  // all capabilities

// Verdict codes
int LSM_ALLOW = 0
int LSM_DENY  = 1
int LSM_AUDIT = 2   // allow but log

struct security_context {
    int    agent_pid
    string agent_name
    string agent_label      // e.g. "trusted" | "sandboxed" | "guest"
    int    capabilities     // bitmask of CAP_*
    []string allowed_tools  // explicit allowlist, empty = use caps only
    []string allowed_paths  // VFS path prefixes agent may access
    bool   network_allowed
}

struct lsm_state {
    []security_context contexts
    bool               enforcing      // false = permissive (log only)
    []string           audit_log
}

func new_lsm_state(enforcing bool) -> lsm_state {
    return lsm_state{
        contexts:  [],
        enforcing: enforcing,
        audit_log: [],
    }
}

// register_context: assign a security context to an agent (like setcon / task_setcon)
func lsm_register(ls lsm_state, ctx security_context) -> lsm_state {
    ls.contexts = append(ls.contexts, ctx)
    return ls
}

func lsm_find_context(ls lsm_state, agent_pid int) -> (security_context, bool) {
    int i = 0
    while i < len(ls.contexts) {
        if ls.contexts[i].agent_pid == agent_pid {
            return (ls.contexts[i], true)
        }
        i = i + 1
    }
    return (security_context{}, false)
}

// lsm_check_tool_call: hook before any tool execution
func lsm_check_tool_call(ls lsm_state, agent_pid int, tool_name string) -> (lsm_state, int) {
    security_context ctx = security_context{}
    bool found = false
    (ctx, found) = lsm_find_context(ls, agent_pid)
    if !found {
        ls.audit_log = append(ls.audit_log, "DENY tool=" + tool_name + " pid=" + string(agent_pid) + " (no context)")
        if ls.enforcing { return (ls, LSM_DENY) }
        return (ls, LSM_ALLOW)
    }
    // check CAP_TOOL_EXEC
    if (ctx.capabilities & CAP_TOOL_EXEC) == 0 {
        ls.audit_log = append(ls.audit_log, "DENY tool=" + tool_name + " label=" + ctx.agent_label)
        if ls.enforcing { return (ls, LSM_DENY) }
    }
    // check allowlist if set
    if len(ctx.allowed_tools) > 0 {
        bool ok = false
        int j = 0
        while j < len(ctx.allowed_tools) {
            if ctx.allowed_tools[j] == tool_name {
                ok = true
            }
            j = j + 1
        }
        if !ok {
            ls.audit_log = append(ls.audit_log, "DENY tool=" + tool_name + " not_in_allowlist")
            if ls.enforcing { return (ls, LSM_DENY) }
        }
    }
    return (ls, LSM_ALLOW)
}

// lsm_check_spawn: hook before spawning sub-agent
func lsm_check_spawn(ls lsm_state, agent_pid int, child_goal string) -> (lsm_state, int) {
    security_context ctx = security_context{}
    bool found = false
    (ctx, found) = lsm_find_context(ls, agent_pid)
    if !found || (ctx.capabilities & CAP_SPAWN_AGENT) == 0 {
        ls.audit_log = append(ls.audit_log, "DENY spawn goal=" + child_goal + " pid=" + string(agent_pid))
        if ls.enforcing { return (ls, LSM_DENY) }
    }
    return (ls, LSM_ALLOW)
}

// lsm_check_network: hook before outbound calls
func lsm_check_network(ls lsm_state, agent_pid int, url string) -> (lsm_state, int) {
    security_context ctx = security_context{}
    bool found = false
    (ctx, found) = lsm_find_context(ls, agent_pid)
    if !found || !ctx.network_allowed {
        ls.audit_log = append(ls.audit_log, "DENY net url=" + url + " pid=" + string(agent_pid))
        if ls.enforcing { return (ls, LSM_DENY) }
    }
    return (ls, LSM_ALLOW)
}
