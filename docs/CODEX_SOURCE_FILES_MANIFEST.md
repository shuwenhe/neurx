# Codex migrationEnglish textfileEnglish text

## completeEnglish textfileEnglish text

### 1. English textsystem (Approvals) English textfile

#### English textfile

```
codex-rs/protocol/src/approvals.rs
├─ English text: ~400
├─ English text:
│  ├─ ResolvedPermissionProfile
│  ├─ EscalationPermissions
│  ├─ ExecPolicyAmendment
│  ├─ NetworkApprovalProtocol (enum: Http, Https, Socks5Tcp, Socks5Udp)
│  ├─ NetworkApprovalContext
│  ├─ NetworkPolicyRuleAction (enum: Allow, Deny)
│  ├─ GuardianRiskLevel (enum: Low, Medium, High, Critical)
│  ├─ GuardianUserAuthorization (enum: Unknown, Low, Medium, High)
│  ├─ GuardianAssessmentOutcome (enum: Allow, Deny)
│  ├─ GuardianAssessmentStatus (enum: InProgress, Approved, Denied, TimedOut, Aborted)
│  ├─ GuardianAssessmentDecisionSource (enum: Agent)
│  ├─ GuardianCommandSource (enum: Shell, UnifiedExec)
│  ├─ GuardianAssessmentAction (enum: Command, Execve, ApplyPatch, NetworkAccess, McpToolCall, RequestPermissions)
│  ├─ NetworkPolicyAmendment
│  ├─ GuardianAssessmentEvent
│  ├─ ExecApprovalRequestEvent
│  ├─ ElicitationRequest
│  ├─ ElicitationRequestEvent
│  ├─ ElicitationAction (enum: Accept, Decline, Cancel)
│  └─ ApplyPatchApprovalRequestEvent
├─ English text:
│  ├─ crate::parse_command::ParsedCommand
│  ├─ crate::protocol::FileChange, ReviewDecision
│  ├─ crate::request_permissions::RequestPermissionProfile
│  ├─ codex_utils_absolute_path::AbsolutePathBuf
│  └─ serde, schemars, ts-rs
└─ English text: codex-rs/protocol/src/lib.rs (pub use)
```

```
codex-rs/protocol/src/protocol.rs
├─ English text: ~5000+
├─ English text:
│  ├─ AskForApproval (enum: UnlessTrusted, OnFailure, OnRequest, Granular, Never)
│  ├─ GranularApprovalConfig
│  ├─ NetworkAccess (enum: Restricted, Enabled)
│  ├─ SandboxPolicy (enum: DangerFullAccess, ReadOnly, ExternalSandbox, WorkspaceWrite)
│  └─ Other AgreementsEnglish text...
├─ English text:
│  ├─ crate::approvals::* (English text)
│  ├─ crate::config_types::ApprovalsReviewer
│  ├─ crate::permissions::* (English text)
│  └─ Other AgreementsEnglish text
└─ English text: English text
```

```
codex-rs/protocol/src/config_types.rs
├─ English text: ~800+
├─ English text:
│  ├─ SandboxMode (enum: ReadOnly, WorkspaceWrite, DangerFullAccess)
│  ├─ ProfileV2Name
│  ├─ ApprovalsReviewer (enum: User, AutoReview)
│  ├─ ShellEnvironmentPolicyInherit
│  └─ AutoCompactTokenLimitScope, Verbosity, ReasoningSummary, etc.
├─ English text:
│  ├─ crate::openai_models::ReasoningEffort
│  └─ English text serde
└─ English text: configurationEnglish text
```

#### English text

```
codex-rs/execpolicy/src/decision.rs
├─ English text: ~30
├─ English text:
│  └─ Decision (enum: Allow, Prompt, Forbidden)
├─ English text: serde
└─ English text: English text
```

```
codex-rs/execpolicy/src/policy.rs
├─ English text: ~200+
├─ English text:
│  ├─ MatchOptions
│  ├─ Policy
│  └─ English text
├─ English text:
│  ├─ crate::decision::Decision
│  ├─ crate::rule::*
│  └─ multimap::MultiMap
└─ English text: English text
```

#### Guardian English text

```
codex-rs/core/src/guardian/approval_request.rs
├─ English text: Guardian English textrequestEnglish text
├─ English text:
│  ├─ codex_protocol::approvals::*
│  └─ codex_protocol::config_types::ApprovalsReviewer
└─ English text: RequiredEnglish text Guardian English text
```

```
codex-rs/core/src/tools/network_approval.rs
├─ English text: English texttoolimplementation
├─ English text:
│  ├─ codex_protocol::approvals::NetworkApprovalProtocol
│  └─ English textimplementation
└─ English text: English textmanagementEnglish text
```

#### MCP English text

```
codex-rs/protocol/src/mcp_approval_meta.rs
├─ English text: MCP English textdata
├─ English text:
│  ├─ codex_protocol::mcp::RequestId
│  └─ English text MCP English text
└─ English text: MCP elicitation systemEnglish text
```

### 2. English textsystem (Sandbox) English textfile

#### English textmodel

```
codex-rs/protocol/src/permissions.rs
├─ English text: ~1000+
├─ English text:
│  ├─ FileSystemAccessMode (enum: Read, Write, Deny)
│  ├─ FileSystemSpecialPath (enum: Root, Minimal, ProjectRoots, Tmpdir, SlashTmp, Unknown)
│  ├─ FileSystemSandboxEntry
│  ├─ FileSystemSandboxKind (enum: Restricted, Unrestricted, ExternalSandbox)
│  ├─ FileSystemSandboxPolicy
│  ├─ ReadDenyMatcher
│  ├─ WritableRoot
│  ├─ FileSystemPath
│  ├─ NetworkSandboxPolicy (enum: Restricted, Enabled)
│  ├─ PROTECTED_METADATA_PATH_NAMES (English text)
│  └─ is_protected_metadata_name, forbidden_agent_metadata_write, etc.
├─ English text:
│  ├─ crate::protocol::{NetworkAccess, SandboxPolicy, WritableRoot}
│  ├─ codex_utils_absolute_path::*
│  ├─ globset::*
│  └─ serde
└─ English text: English textmodelEnglish text
```

```
codex-rs/protocol/src/models.rs
├─ English text: ~200+
├─ English text:
│  ├─ SandboxPermissions (enum: UseDefault, RequireEscalated, WithAdditionalPermissions)
│  ├─ FileSystemPermissions
│  └─ English textmodelEnglish text
├─ English text:
│  ├─ crate::permissions::*
│  ├─ codex_utils_absolute_path::*
│  └─ serde
└─ English text: English textdataEnglish text
```

#### English textmanagement

```
codex-rs/sandboxing/src/lib.rs
├─ English text: ~50
├─ English text:
│  ├─ SandboxManager
│  ├─ SandboxCommand, SandboxExecRequest
│  ├─ SandboxTransformRequest, SandboxTransformError
│  ├─ SandboxType, SandboxablePreference
│  ├─ English textfunction
│  └─ errorEnglish text
├─ English text:
│  ├─ crate::manager::*
│  ├─ crate::landlock::*
│  ├─ crate::seatbelt::*
│  └─ crate::bwrap::*
└─ English text: English text
```

```
codex-rs/sandboxing/src/manager.rs
├─ English text: ~400+
├─ English text:
│  ├─ SandboxType (enum: None, MacosSeatbelt, LinuxSeccomp, WindowsRestrictedToken)
│  ├─ SandboxablePreference (enum: Auto, Require, Forbid)
│  ├─ SandboxCommand
│  ├─ SandboxExecRequest
│  ├─ SandboxTransformRequest
│  ├─ SandboxTransformError
│  └─ English textfunction
├─ English text:
│  ├─ crate::policy_transforms::*
│  ├─ codex_protocol::{models::*, permissions::*, protocol::*, config_types::*}
│  ├─ codex_network_proxy::NetworkProxy
│  └─ English texttoolEnglish text
└─ English text: English textmanagement
```

#### English textimplementation

```
codex-rs/sandboxing/src/bwrap.rs
├─ English text: ~400+
├─ English textfunction:
│  ├─ system_bwrap_warning()
│  ├─ find_system_bwrap_in_path()
│  ├─ system_bwrap_has_user_namespace_access()
│  └─ English text bwrap English textfunction
├─ English text:
│  ├─ SYSTEM_BWRAP_PROGRAM
│  ├─ MISSING_BWRAP_WARNING
│  ├─ USER_NAMESPACE_WARNING
│  ├─ WSL1_BWRAP_WARNING
│  └─ English text
├─ English text:
│  ├─ std::process::Command
│  ├─ std::thread
│  └─ libc English text
└─ English text: Linux bubblewrap English textimplementation
```

```
codex-rs/sandboxing/src/seatbelt.rs
├─ English text: macOS Seatbelt English textimplementation
├─ English text: seatbelt-rs English text
└─ English text: use SBPL (Seatbelt Profile Language) file
```

```
codex-rs/sandboxing/src/landlock.rs
├─ English text: Linux Landlock LSM implementation
├─ English text: landlock crate
└─ English text: English text bwrap English text
```

```
codex-rs/sandboxing/src/policy_transforms.rs
├─ English text: ~300+
├─ English textfunction:
│  ├─ effective_permission_profile()
│  ├─ should_require_platform_sandbox()
│  └─ English text
├─ English text:
│  ├─ codex_protocol::permissions::*
│  ├─ codex_protocol::models::*
│  └─ crate::manager::*
└─ English text: English text
```

### 3. English textsupport (Threading) English textfile

#### English text

```
codex-rs/protocol/src/thread_id.rs
├─ English text: ~120
├─ English text:
│  └─ ThreadId { uuid: Uuid }
├─ mainEnglish text:
│  ├─ new()
│  ├─ from_string(s: &str)
│  ├─ Display, Serialize, Deserialize
│  └─ JsonSchema implementation
├─ English text:
│  ├─ uuid::Uuid (UUID v7)
│  ├─ serde
│  └─ schemars
└─ English text: English text
```

#### English text

```
codex-rs/thread-store/src/types.rs
├─ English text: ~500+
├─ English text:
│  ├─ ThreadPersistenceMetadata
│  ├─ CreateThreadParams
│  ├─ ResumeThreadParams
│  ├─ AppendThreadItemsParams
│  ├─ LoadThreadHistoryParams
│  ├─ ReadThreadParams
│  ├─ ReadThreadByRolloutPathParams
│  ├─ ListThreadsParams
│  ├─ SearchThreadsParams
│  ├─ ThreadPage
│  ├─ StoredThreadSearchResult, ThreadSearchPage
│  ├─ StoredTurnItemsView, StoredTurnStatus, StoredTurnError
│  ├─ ListTurnsParams, StoredTurn
│  ├─ ListItemsParams, ItemPage
│  ├─ UpdateThreadMetadataParams
│  ├─ ArchiveThreadParams
│  ├─ StoredThread
│  ├─ ThreadMetadataPatch
│  ├─ SortDirection
│  └─ English textparameterEnglish text
├─ English text:
│  ├─ codex_protocol::ThreadId
│  ├─ codex_protocol::protocol::{AskForApproval, GitInfo, RolloutItem, SessionSource, ThreadMemoryMode, ThreadSource, TokenUsage}
│  ├─ codex_protocol::models::{BaseInstructions, PermissionProfile}
│  ├─ codex_protocol::openai_models::ReasoningEffort
│  ├─ codex_protocol::dynamic_tools::DynamicToolSpec
│  ├─ chrono::DateTime<Utc>
│  └─ serde
└─ English text: English textparameterEnglish textdataEnglish text
```

#### English text

```
codex-rs/thread-store/src/store.rs
├─ English text: ~150+
├─ English text:
│  └─ ThreadStore (async trait)
├─ mainEnglish text:
│  ├─ create_thread()
│  ├─ resume_thread()
│  ├─ append_items()
│  ├─ persist_thread()
│  ├─ flush_thread()
│  ├─ shutdown_thread()
│  ├─ discard_thread()
│  ├─ load_history()
│  ├─ read_thread()
│  ├─ read_thread_by_rollout_path()
│  ├─ list_threads()
│  ├─ search_threads()
│  ├─ list_turns()
│  ├─ list_items()
│  ├─ update_thread_metadata()
│  ├─ archive_thread()
│  └─ unarchive_thread()
├─ English text:
│  ├─ async_trait
│  ├─ std::any::Any
│  └─ crate English textparameterEnglish text
└─ English text: English text
```

#### English text

```
codex-rs/thread-store/src/live_thread.rs
├─ English text: ~200+
├─ English text:
│  ├─ LiveThread
│  └─ LiveThreadInitGuard
├─ mainEnglish text:
│  ├─ LiveThread::create()
│  ├─ LiveThread::resume()
│  ├─ LiveThread::fork()
│  ├─ LiveThread::append_items()
│  ├─ LiveThread::persist()
│  ├─ LiveThread::flush()
│  ├─ LiveThread::shutdown()
│  ├─ LiveThread::discard()
│  └─ English text
├─ English text:
│  ├─ Arc<dyn ThreadStore>
│  ├─ Tokio::sync::Mutex
│  ├─ ThreadMetadataSync
│  └─ English text
└─ English text: English textmanagement
```

#### English textimplementation

```
codex-rs/thread-store/src/local/mod.rs
├─ English text: ~500+
├─ English text:
│  ├─ LocalThreadStore
│  └─ LocalThreadStoreConfig
├─ English text: English textfile/Rollout English textimplementation
├─ English text:
│  ├─ codex_rollout::persisted_rollout_items
│  ├─ tokio::fs
│  └─ English text
└─ English text: defaultimplementation, use rollout file
```

```
codex-rs/thread-store/src/in_memory.rs
├─ English text: ~300+
├─ English text:
│  ├─ InMemoryThreadStore
│  └─ InMemoryThreadStoreCalls
├─ English text: English text(English texttest)
├─ English text: English textdataEnglish text
└─ English text: testEnglish textquickEnglish textuse
```

#### English text

```
codex-rs/analytics/src/facts.rs
├─ English text: ~400+
├─ English text:
│  ├─ ThreadInitializationMode (enum: Fresh, Resumed, Forked)
│  ├─ SubAgentThreadStartedInput
│  └─ English text
├─ English text: English textinitializeEnglish text
├─ English text:
│  ├─ codex_protocol::approvals::*, models::*, etc.
│  └─ serde
└─ English text: English text
```

```
codex-rs/ext/extension-api/src/contributors/thread_lifecycle.rs
├─ English text: ~100+
├─ English text:
│  ├─ ThreadStartInput
│  ├─ ThreadResumeInput
│  ├─ ThreadIdleInput
│  └─ ThreadStopInput
├─ English text: English textextensionEnglish text
├─ English text: extension API
└─ English text: English text
```

---

## English text

### English textsystemEnglish text

```
                           approvals.rs  protocol.rs  config_types.rs  execpolicy/  guardian/
approvals.rs                   -           ←           ←              ←           ←
protocol.rs                    →           -           ←              ←           ←
config_types.rs                →           →           -              -           -
execpolicy/decision.rs         -           ←           -              -           -
execpolicy/policy.rs           -           ←           ←              -           -
guardian/approval_request.rs   →           →           →              -           -

explanation:
  → English text(depends on)
  ← English text(is depended by)
  - English text
```

### English textsystemEnglish text

```
                         permissions.rs  config_types.rs  protocol.rs  manager.rs  bwrap/seatbelt
permissions.rs                -              ←              ←           ←           -
config_types.rs               →              -              ←           ←           -
protocol.rs                   →              →              -           ←           -
manager.rs                    →              →              →           -           →
bwrap.rs/seatbelt.rs          -              -              -           →           -
landlock.rs                   -              -              -           →           -
policy_transforms.rs          →              -              →           -           -
```

### English textsystemEnglish text

```
                      thread_id.rs  types.rs  store.rs  live_thread.rs  local/  in_memory.rs
thread_id.rs               -          ←         ←         ←              ←        ←
types.rs                   →          -         ←         ←              ←        ←
store.rs                   →          →         -         ←              ←        ←
live_thread.rs             →          →         →         -              →        →
local/                     →          →         →         →              -        -
in_memory.rs               →          →         →         →              -        -
analytics/facts.rs         →          -         -         -              -        -
```

---

## English text

### English text ↔ English text

```
English text → English text:
  ├─ ExecApprovalRequestEvent English text AdditionalPermissionProfile
  └─ AdditionalPermissionProfile → English text

English text → English text:
  ├─ SandboxDenied → ReviewTrigger::SandboxDenial
  └─ English text → requestEnglish text
```

### English text ↔ English text

```
English text → English text:
  └─ ExecApprovalRequestEvent.turn_id → StoredTurn.turn_id

English text → English text:
  ├─ CreateThreadParams → AskForApproval English text
  └─ ResumeThreadParams → recoverEnglish textstate
```

### English text ↔ English text

```
English text → English text:
  └─ SandboxPolicy saveEnglish text ThreadPersistenceMetadata

English text → English text:
  └─ English textrecoverEnglish text
```

### English text

```
English textsystem ← Guardian English text
  ├─ GuardianAssessmentEvent English text Guardian generate
  └─ Guardian RequiredEnglish text ApprovalsReviewer configuration

English textsystem ← NetworkProxy
  ├─ SandboxExecRequest.network: Option<NetworkProxy>
  └─ English text

English textsystem ← Rollout system
  ├─ StoredThread English text RolloutItem
  └─ LocalThreadStore use codex_rollout crate
```

---

## fileEnglish text

### English textstatistics

| English text | file | English text | English text |
|------|------|------|-------|
| **English text** | approvals.rs | ~400 | English text |
| | protocol.rs (English text) | ~500 | English text |
| | config_types.rs (English text) | ~200 | English text |
| | execpolicy/decision.rs | ~30 | English text |
| | execpolicy/policy.rs | ~200 | English text |
| | guardian/approval_request.rs | ~300 | English text |
| **English text** | | ~1630 | |
| | | | |
| **English text** | permissions.rs | ~1000 | English text |
| | config_types.rs (English text) | ~100 | English text |
| | protocol.rs (English text) | ~300 | English text |
| | manager.rs | ~400 | English text |
| | bwrap.rs | ~400 | English text |
| | seatbelt.rs | ~200 | English text |
| | landlock.rs | ~300 | English text |
| | policy_transforms.rs | ~300 | English text |
| **English text** | | ~3400 | |
| | | | |
| **English text** | thread_id.rs | ~120 | English text |
| | types.rs | ~500 | English text |
| | store.rs | ~150 | English text |
| | live_thread.rs | ~200 | English text |
| | local/mod.rs | ~500 | English text |
| | in_memory.rs | ~300 | English text |
| | analytics/facts.rs (English text) | ~100 | English text |
| **English text** | | ~1870 | |
| | | | |
| **English text** | | ~6900 | |

---

## English text

### English textimplementationEnglish text Traits

1. **ThreadStore** (async_trait)
   ```rust
   pub trait ThreadStore: Any + Send + Sync {
       async fn create_thread(&self, params: CreateThreadParams) -> ThreadStoreResult<()>;
       // English text 15+ English text
   }
   ```

2. **English text/English text**
   - Serde (JSON)
   - TypeScript English textgenerate (ts-rs)

3. **errorEnglish text**
   - ThreadStoreError
   - SandboxTransformError
   - CodexErr

### English text

- `#[serde(rename_all = "snake_case")]`
- `#[ts(...)]` - TypeScript generate
- `#[async_trait]` - English textstepEnglish text
- `pub use` - English text

---

## testEnglish text

### English textsystem

```
codex-rs/
├─ protocol/src/approvals.rs
│  └─ English texttest (~100 English text)
├─ analytics/src/analytics_client_tests.rs
│  └─ English texttest
└─ core/tests/suite/approvals.rs
   └─ English texttest
```

### English textsystem

```
codex-rs/
├─ sandboxing/src/
│  ├─ bwrap_tests.rs
│  ├─ seatbelt_tests.rs
│  ├─ landlock_tests.rs
│  ├─ manager_tests.rs
│  └─ policy_transforms_tests.rs
├─ exec/tests/suite/approval_policy.rs
└─ core/tests/ (English text)
```

### English textsystem

```
codex-rs/
└─ thread-store/src/
   └─ mainEnglish textuseEnglish texttest
      ├─ English texttest
      └─ English texttest
```

---

## configurationEnglish text

### English textsystemEnglish text

```rust
// English text, mainEnglish textconfigurationparameter
```

### English textsystemEnglish text

```rust
// codex-rs/protocol/src/permissions.rs
pub const PROTECTED_METADATA_PATH_NAMES: &[&str] = &[
    ".git",
    ".agents",
    ".codex",
];

// codex-rs/sandboxing/src/bwrap.rs
const SYSTEM_BWRAP_PROGRAM: &str = "bwrap";
const WSL1_BWRAP_WARNING: &str = "...";
const SYSTEM_BWRAP_PROBE_TIMEOUT: Duration = Duration::from_millis(500);
// English text...
```

### English textsystemEnglish text

```rust
// English text, mainEnglish text config
```

---

## English text

### English textsystem

1. Guardian English text
2. MCP elicitation systemEnglish textRequiredEnglish text
3. English text

### English textsystem

1. WSL1 English textsupport bwrap(Required WSL2)
2. English textdataEnglish text
3. Landlock Required Linux 5.13+ English text
4. Windows English textRequiredEnglish text

### English textsystem

1. English textimplementationEnglish textcomplete
2. English textRequiredEnglish text
3. English text

---

## recommendedEnglish text

1. **English text** (Day 1-2)
   - `protocol/src/thread_id.rs`
   - `protocol/src/config_types.rs`
   - `protocol/src/permissions.rs` (English text)

2. **English text** (Day 3-4)
   - `protocol/src/permissions.rs` (complete)
   - `sandboxing/src/manager.rs`
   - `sandboxing/src/policy_transforms.rs`

3. **English textpipeline** (Day 5-6)
   - `protocol/src/approvals.rs`
   - `protocol/src/protocol.rs` (AskForApproval English text)
   - `execpolicy/src/decision.rs` English text `policy.rs`

4. **English textsystem** (Day 7-8)
   - `thread-store/src/types.rs`
   - `thread-store/src/store.rs`
   - `thread-store/src/live_thread.rs`
   - `thread-store/src/local/mod.rs`

5. **English text** (Day 9-10)
   - `core/src/guardian/approval_request.rs`
   - `core/src/tools/network_approval.rs`
   - testEnglish text

6. **English text** (English text)
   - `sandboxing/src/bwrap.rs` (Linux)
   - `sandboxing/src/seatbelt.rs` (macOS)
   - `sandboxing/src/landlock.rs` (Linux English text)

