package neurx.safety.safety

struct agent_safety_result {
    bool allowed
    string reason
    string category
    int severity
}

func new_agent_safety_result_allow() agent_safety_result {
    agent_safety_result {
        allowed: true,
        reason: "ok",
        category: "none",
        severity: 0,
    }
}

func new_agent_safety_result_block(string reason, string category, int severity) agent_safety_result {
    agent_safety_result {
        allowed: false,
        reason: reason,
        category: category,
        severity: severity,
    }
}

func agent_safety_text_contains(string text, string pattern) bool {
    string h = lower(trim(text))
    string n = lower(trim(pattern))
    int hl = len(h)
    int nl = len(n)
    if nl == 0 {
        return true
    }
    if hl < nl {
        return false
    }
    int i = 0
    while i <= hl - nl {
        int j = 0
        bool ok = true
        while j < nl {
            if h[i + j] != n[j] {
                ok = false
                break
            }
            j = j + 1
        }
        if ok {
            return true
        }
        i = i + 1
    }
    false
}

func agent_safety_check_injection(string input) agent_safety_result {
    if agent_safety_text_contains(input, "ignore previous instructions") || agent_safety_text_contains(input, "ignore all instructions") {
        return new_agent_safety_result_block("prompt_injection", "security", 3)
    }
    if agent_safety_text_contains(input, "disregard your") {
        return new_agent_safety_result_block("prompt_injection", "security", 3)
    }
    if agent_safety_text_contains(input, "system prompt") && agent_safety_text_contains(input, "override") {
        return new_agent_safety_result_block("system_prompt_override", "security", 3)
    }
    new_agent_safety_result_allow()
}

func agent_safety_check_destructive(string action, string input) agent_safety_result {
    if agent_safety_text_contains(input, "rm -rf") || agent_safety_text_contains(input, "drop table") || agent_safety_text_contains(input, "delete all") {
        return new_agent_safety_result_block("destructive_operation", "data_loss", 3)
    }
    if action == "delete" && agent_safety_text_contains(input, "force") {
        return new_agent_safety_result_block("forced_delete", "data_loss", 2)
    }
    new_agent_safety_result_allow()
}

func agent_safety_check_s(string cmd) agent_safety_result {
    string c = lower(trim(cmd))
    if agent_safety_text_contains(c, "| bash") || agent_safety_text_contains(c, "|bash") {
        return new_agent_safety_result_block("remote_code_exec", "rce", 3)
    }
    if agent_safety_text_contains(c, "| sh") || agent_safety_text_contains(c, "|sh") {
        return new_agent_safety_result_block("remote_code_exec", "rce", 3)
    }
    if agent_safety_text_contains(c, "| python") || agent_safety_text_contains(c, "|python") {
        return new_agent_safety_result_block("remote_code_exec", "rce", 3)
    }
    if agent_safety_text_contains(c, "dd ") && agent_safety_text_contains(c, "of=/dev/") {
        return new_agent_safety_result_block("disk_destroy", "data_loss", 3)
    }
    if agent_safety_text_contains(c, "> /dev/sd") || agent_safety_text_contains(c, "> /dev/nvme") || agent_safety_text_contains(c, "> /dev/hd") {
        return new_agent_safety_result_block("disk_overwrite", "data_loss", 3)
    }
    if agent_safety_text_contains(c, "mkfs.") || agent_safety_text_contains(c, "mkfs ") {
        return new_agent_safety_result_block("disk_format", "data_loss", 3)
    }
    if agent_safety_text_contains(c, "shred /dev/") || agent_safety_text_contains(c, "fdisk /dev/") || agent_safety_text_contains(c, "parted /dev/") {
        return new_agent_safety_result_block("disk_destroy", "data_loss", 3)
    }
    if agent_safety_text_contains(c, "rm ") && agent_safety_text_contains(c, "-rf") {
        if agent_safety_text_contains(c, " / ") || agent_safety_text_contains(c, " /\n") {
            return new_agent_safety_result_block("delete_root", "data_loss", 3)
        }
        if agent_safety_text_contains(c, "rm -rf /") || agent_safety_text_contains(c, "rm -rf ~/") {
            return new_agent_safety_result_block("delete_root", "data_loss", 3)
        }
        if agent_safety_text_contains(c, "rm -rf $home") || agent_safety_text_contains(c, "rm -rf ${home}") {
            return new_agent_safety_result_block("delete_home", "data_loss", 3)
        }
    }
    if agent_safety_text_contains(c, "--no-preserve-root") {
        return new_agent_safety_result_block("delete_root_no_preserve", "data_loss", 3)
    }
    if agent_safety_text_contains(c, ":(){:|:&};:") || agent_safety_text_contains(c, ":(){ :|:& };:") {
        return new_agent_safety_result_block("fork_bomb", "dos", 3)
    }
    if agent_safety_text_contains(c, "chmod") && agent_safety_text_contains(c, "777") {
        if agent_safety_text_contains(c, " / ") || agent_safety_text_contains(c, " /\n") || agent_safety_text_contains(c, "chmod 777 /") || agent_safety_text_contains(c, "chmod -r 777") {
            return new_agent_safety_result_block("chmod_world_write_root", "security", 2)
        }
    }
    if agent_safety_text_contains(c, "/.ssh/authorized_keys") && (agent_safety_text_contains(c, ">") || agent_safety_text_contains(c, "tee ")) {
        return new_agent_safety_result_block("ssh_key_write", "security", 3)
    }
    if agent_safety_text_contains(c, "/.ssh/id_") && (agent_safety_text_contains(c, ">") || agent_safety_text_contains(c, "tee ")) {
        return new_agent_safety_result_block("ssh_key_write", "security", 3)
    }
    new_agent_safety_result_allow()
}

func agent_safety_check_shell(string cmd) agent_safety_result {
    agent_safety_check_s(cmd)
}

func agent_safety_check(string action, string input, string goal) agent_safety_result {
    agent_safety_result inject_result = agent_safety_check_injection(input)
    if !inject_result.allowed {
        return inject_result
    }
    agent_safety_result destroy_result = agent_safety_check_destructive(action, input)
    if !destroy_result.allowed {
        return destroy_result
    }
    if action == "s" || action == "bash" {
        agent_safety_result shell_result = agent_safety_check_s(input)
        if !shell_result.allowed {
            return shell_result
        }
    }
    new_agent_safety_result_allow()
}

func agent_safety_summary(agent_safety_result result) string {
    "allowed=" + string(result.allowed) + " reason=" + result.reason + " category=" + result.category + " severity=" + string(result.severity)
}
