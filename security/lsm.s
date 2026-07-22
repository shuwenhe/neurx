

int CAP_TOOL_EXEC    = 1
int CAP_FILE_READ    = 2
int CAP_FILE_WRITE   = 4
int CAP_NET_OUTBOUND = 8
int CAP_SPAWN_AGENT  = 16
int CAP_GPU_ALLOC    = 32
int CAP_ADMIN        = 255

int LSM_ALLOW = 0
int LSM_DENY  = 1
int LSM_AUDIT = 2

struct security_context {
    int    agent_pid
    string agent_name
    string agent_label
    int    capabilities
    []string allowed_tools
    []string allowed_paths
    bool   network_allowed
}

struct lsm_state {
    []security_context contexts
    bool               enforcing
    []string           audit_log
}

func new_lsm_state(enforcing bool) lsm_state {
    return lsm_state{
        contexts:  [],
        enforcing: enforcing,
        audit_log: [],
    }
}

func get_allowed_tool(security_context ctx, int index) string {
    ctx.allowed_tools[index]
}

func lsm_register(ls lsm_state, ctx security_context) lsm_state {
    ls.contexts = append(ls.contexts, ctx)
    return ls
}

func lsm_find_context(ls lsm_state, agent_pid int) (security_context, bool) {
    int i = 0
    while i < len(ls.contexts) {
        if ls.contexts[i].agent_pid == agent_pid {
            return (ls.contexts[i], true)
        }
        i = i + 1
    }
    return (security_context{}, false)
}

func lsm_check_tool_call(ls lsm_state, agent_pid int, tool_name string) (lsm_state, int) {
    security_context ctx = security_context{}
    bool found = false
    (ctx, found) = lsm_find_context(ls, agent_pid)
    if !found {
        ls.audit_log = append(ls.audit_log, "DENY tool=" + tool_name + " pid=" + string(agent_pid) + " (no context)")
        if ls.enforcing { return (ls, LSM_DENY) }
        return (ls, LSM_ALLOW)
    }

    if (ctx.capabilities & CAP_TOOL_EXEC) == 0 {
        ls.audit_log = append(ls.audit_log, "DENY tool=" + tool_name + " label=" + ctx.agent_label)
        if ls.enforcing { return (ls, LSM_DENY) }
    }

    if len(ctx.allowed_tools) > 0 {
        bool ok = false
        int j = 0
        while j < len(ctx.allowed_tools) {
            if get_allowed_tool(ctx, j) == tool_name {
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

func lsm_check_spawn(ls lsm_state, agent_pid int, child_goal string) (lsm_state, int) {
    security_context ctx = security_context{}
    bool found = false
    (ctx, found) = lsm_find_context(ls, agent_pid)
    if !found || (ctx.capabilities & CAP_SPAWN_AGENT) == 0 {
        ls.audit_log = append(ls.audit_log, "DENY spawn goal=" + child_goal + " pid=" + string(agent_pid))
        if ls.enforcing { return (ls, LSM_DENY) }
    }
    return (ls, LSM_ALLOW)
}

func lsm_check_network(ls lsm_state, agent_pid int, url string) (lsm_state, int) {
    security_context ctx = security_context{}
    bool found = false
    (ctx, found) = lsm_find_context(ls, agent_pid)
    if !found || !ctx.network_allowed {
        ls.audit_log = append(ls.audit_log, "DENY net url=" + url + " pid=" + string(agent_pid))
        if ls.enforcing { return (ls, LSM_DENY) }
    }
    return (ls, LSM_ALLOW)
}
