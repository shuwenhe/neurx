package main
use neurx.serving.security.request_governance.{governance_state, governance_decision, new_governance_state, governance_register_tenant, governance_authorize, governance_disable_tenant}
use neurx.serving.lifecycle.request_lifecycle.{lifecycle_state, new_lifecycle_state, lifecycle_register, lifecycle_fail_attempt, lifecycle_tick, lifecycle_cancel, lifecycle_complete, lifecycle_begin_shutdown, lifecycle_shutdown_complete}

func fail(string message) int { println("governance-lifecycle FAIL " + message); 1 }

func main() {
    string fingerprint = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    governance_state governance = new_governance_state()
    governance = governance_register_tenant(governance, "tenant-a", fingerprint, "inference", 2, 10, 0)
    governance_decision decision = governance_authorize(governance, fingerprint, "generate", 4, 1)
    if !decision.allowed || decision.tenant_id != "tenant-a" { return fail("authorization") }
    governance = decision.state
    decision = governance_authorize(governance, fingerprint, "admin:write", 1, 2)
    if decision.http_status != 403 { return fail("rbac") }
    governance = decision.state
    decision = governance_authorize(governance, fingerprint, "generate", 7, 3)
    if decision.http_status != 429 || decision.retry_after_ms <= 0 { return fail("quota") }
    governance = governance_disable_tenant(decision.state, "tenant-a")
    decision = governance_authorize(governance, fingerprint, "generate", 1, 4)
    if decision.http_status != 401 { return fail("disable") }
    lifecycle_state lifecycle = new_lifecycle_state()
    lifecycle = lifecycle_register(lifecycle, "req-1", 0, 1000, 2)
    lifecycle = lifecycle_fail_attempt(lifecycle, "req-1", 100, true)
    lifecycle = lifecycle_tick(lifecycle, 200)
    if lifecycle.statuses[0] != "running" || lifecycle.attempts[0] != 2 { return fail("retry") }
    lifecycle = lifecycle_complete(lifecycle, "req-1")
    lifecycle = lifecycle_register(lifecycle, "req-2", 0, 10, 0)
    lifecycle = lifecycle_tick(lifecycle, 11)
    if lifecycle.timed_out != 1 { return fail("timeout") }
    lifecycle = lifecycle_register(lifecycle, "req-3", 20, 100, 0)
    lifecycle = lifecycle_cancel(lifecycle, "req-3")
    lifecycle = lifecycle_begin_shutdown(lifecycle)
    if !lifecycle_shutdown_complete(lifecycle) { return fail("graceful-shutdown") }
    println("governance-lifecycle PASS authorized=1 rbac=true quota=true retry=true timeout=true cancel=true shutdown=true")
    0
}

