package neurx.serving.security.request_governance

// API keys are represented only by fixed-size SHA-256 hexadecimal
// fingerprints. Raw secrets must be hashed by the TLS/native transport before
// entering this module and must never be logged.

struct governance_state {
    []string tenant_ids
    []string key_fingerprints
    []string roles
    []int requests_per_minute
    []int tokens_per_minute
    []int window_start_ms
    []int window_requests
    []int window_tokens
    []bool enabled
    int authorized
    int denied
    int quota_rejected
}

func new_governance_state() governance_state {
    governance_state {
        tenant_ids: [], key_fingerprints: [], roles: [],
        requests_per_minute: [], tokens_per_minute: [],
        window_start_ms: [], window_requests: [], window_tokens: [], enabled: [],
        authorized: 0, denied: 0, quota_rejected: 0,
    }
}

func governance_constant_time_fingerprint_equal(string left, string right) bool {
    if len(left) != 64 || len(right) != 64 { return false }
    int difference = 0
    int i = 0
    while i < 64 {
        difference = difference | (left[i] ^ right[i])
        i = i + 1
    }
    difference == 0
}

func governance_role_allows(string role, string permission) bool {
    if role == "admin" { return true }
    if role == "inference" && (permission == "generate" || permission == "models:read" || permission == "metrics:read") { return true }
    if role == "observer" && (permission == "models:read" || permission == "metrics:read") { return true }
    false
}

func governance_register_tenant(governance_state state, string tenant_id, string key_fingerprint, string role, int requests_per_minute, int tokens_per_minute, int now_ms) governance_state {
    if tenant_id == "" || len(key_fingerprint) != 64 { return state }
    if requests_per_minute <= 0 { requests_per_minute = 1 }
    if tokens_per_minute <= 0 { tokens_per_minute = 1 }
    state.tenant_ids = append(state.tenant_ids, tenant_id)
    state.key_fingerprints = append(state.key_fingerprints, key_fingerprint)
    state.roles = append(state.roles, role)
    state.requests_per_minute = append(state.requests_per_minute, requests_per_minute)
    state.tokens_per_minute = append(state.tokens_per_minute, tokens_per_minute)
    state.window_start_ms = append(state.window_start_ms, now_ms)
    state.window_requests = append(state.window_requests, 0)
    state.window_tokens = append(state.window_tokens, 0)
    state.enabled = append(state.enabled, true)
    state
}

struct governance_decision {
    governance_state state
    bool allowed
    string tenant_id
    int http_status
    string reason
    int retry_after_ms
}

func governance_deny(governance_state state, int status, string reason, bool quota, int retry_after_ms) governance_decision {
    state.denied = state.denied + 1
    if quota { state.quota_rejected = state.quota_rejected + 1 }
    governance_decision { state: state, allowed: false, tenant_id: "", http_status: status, reason: reason, retry_after_ms: retry_after_ms }
}

func governance_authorize(governance_state state, string key_fingerprint, string permission, int requested_tokens, int now_ms) governance_decision {
    int index = -1
    int i = 0
    while i < len(state.key_fingerprints) {
        if state.enabled[i] && governance_constant_time_fingerprint_equal(state.key_fingerprints[i], key_fingerprint) { index = i }
        i = i + 1
    }
    if index < 0 { return governance_deny(state, 401, "invalid_api_key", false, 0) }
    if !governance_role_allows(state.roles[index], permission) { return governance_deny(state, 403, "permission_denied", false, 0) }
    if requested_tokens < 0 { requested_tokens = 0 }
    int elapsed = now_ms - state.window_start_ms[index]
    if elapsed >= 60000 || elapsed < 0 {
        state.window_start_ms[index] = now_ms
        state.window_requests[index] = 0
        state.window_tokens[index] = 0
        elapsed = 0
    }
    if state.window_requests[index] + 1 > state.requests_per_minute[index] || state.window_tokens[index] + requested_tokens > state.tokens_per_minute[index] {
        int retry_after = 60000 - elapsed
        if retry_after < 0 { retry_after = 0 }
        governance_decision denied = governance_deny(state, 429, "quota_exceeded", true, retry_after)
        denied.tenant_id = state.tenant_ids[index]
        return denied
    }
    state.window_requests[index] = state.window_requests[index] + 1
    state.window_tokens[index] = state.window_tokens[index] + requested_tokens
    state.authorized = state.authorized + 1
    governance_decision { state: state, allowed: true, tenant_id: state.tenant_ids[index], http_status: 200, reason: "allowed", retry_after_ms: 0 }
}

func governance_disable_tenant(governance_state state, string tenant_id) governance_state {
    int i = 0
    while i < len(state.tenant_ids) {
        if state.tenant_ids[i] == tenant_id { state.enabled[i] = false }
        i = i + 1
    }
    state
}
