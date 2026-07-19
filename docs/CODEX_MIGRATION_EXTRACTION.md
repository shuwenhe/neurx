# Codex English textmigrationEnglish text

**English texttime**: 2026-06-02
**English text**: `/Users/feifei/agent/codex`
**English text**: neurx Agent framework

---

## directory

1. [English textsystem (Approvals)](#English textsystemapprovals)
2. [English textsystem (Sandbox)](#English textsystemsandbox)
3. [English textsupport (Threading)](#English textsupportthreading)
4. [English text](#English text)
5. [migrationEnglish text](#migrationEnglish text)

---

## English textsystem (Approvals)

### English textfile

| filepath | English text | English text |
|--------|------|------|
| `codex-rs/protocol/src/approvals.rs` | English textdataEnglish text | **English text** |
| `codex-rs/protocol/src/config_types.rs` | configurationEnglish text(ApprovalsReviewer) | **English text** |
| `codex-rs/protocol/src/protocol.rs` | English text(AskForApproval) | **English text** |
| `codex-rs/execpolicy/src/decision.rs` | English text | **English text** |
| `codex-rs/core/src/guardian/approval_request.rs` | Guardian English textrequestEnglish text | English text |
| `codex-rs/core/src/tools/network_approval.rs` | English texttool | English text |
| `codex-rs/protocol/src/mcp_approval_meta.rs` | MCP English textdata | English text |

### English text

#### 1. **English text** (`AskForApproval`)
```rust
pub enum AskForApproval {
    UnlessTrusted,              // English text"English textsafety"English text
    OnFailure,                  // failureEnglish textrequestEnglish text(English text)
    OnRequest,                  // modelEnglish textrequestEnglish text(default)
    Granular(GranularApprovalConfig),  // English text
    Never,                      // English textrequestEnglish text
}
```

#### 2. **English textconfiguration** (`GranularApprovalConfig`)
```rust
pub struct GranularApprovalConfig {
    pub sandbox_approval: bool,        // shell English text
    pub rules: bool,                   // execpolicy prompt English text
    pub skill_approval: bool,          // English text
    pub request_permissions: bool,     // English textrequesttool
    pub mcp_elicitations: bool,        // MCP prompt
}
```

#### 3. **English text** (`ApprovalsReviewer`)
```rust
pub enum ApprovalsReviewer {
    #[default]
    User,                       // English text
    #[serde(rename = "guardian_subagent", alias = "auto_review")]
    AutoReview,                 // Guardian English text
}
```

#### 4. **English textrequest** (`ExecApprovalRequestEvent`)
```rust
pub struct ExecApprovalRequestEvent {
    pub call_id: String,                          // English text ID
    pub approval_id: Option<String>,              // English text ID
    pub turn_id: String,                          // English text ID
    pub started_at_ms: i64,                       // starttime
    pub command: Vec<String>,                     // English text
    pub cwd: AbsolutePathBuf,                     // English textdirectory
    pub reason: Option<String>,                   // English text
    pub network_approval_context: Option<NetworkApprovalContext>,  // English text
    pub proposed_execpolicy_amendment: Option<ExecPolicyAmendment>, // English text
    pub proposed_network_policy_amendments: Option<Vec<NetworkPolicyAmendment>>, // English text
    pub additional_permissions: Option<AdditionalPermissionProfile>,  // English text
    pub available_decisions: Option<Vec<ReviewDecision>>,  // English text
    pub parsed_cmd: Vec<ParsedCommand>,           // English text
}
```

#### 5. **English text** (`NetworkApprovalProtocol`)
```rust
pub enum NetworkApprovalProtocol {
    Http,
    Https,
    Socks5Tcp,
    Socks5Udp,
}

pub struct NetworkApprovalContext {
    pub host: String,
    pub protocol: NetworkApprovalProtocol,
}
```

#### 6. **Guardian evaluationEnglish text** (`GuardianAssessmentEvent`)
```rust
pub struct GuardianAssessmentEvent {
    pub id: String,                              // English text
    pub target_item_id: Option<String>,          // English text ID
    pub turn_id: String,                         // English text ID
    pub started_at_ms: i64,                      // starttime
    pub completed_at_ms: Option<i64>,            // English texttime
    pub status: GuardianAssessmentStatus,        // evaluationstate
    pub risk_level: Option<GuardianRiskLevel>,   // English text
    pub user_authorization: Option<GuardianUserAuthorization>,  // English text
    pub rationale: Option<String>,               // evaluationEnglish text
    pub decision_source: Option<GuardianAssessmentDecisionSource>,  // English textSource
    pub action: GuardianAssessmentAction,        // English text
}

pub enum GuardianAssessmentStatus {
    InProgress,
    Approved,
    Denied,
    TimedOut,
    Aborted,
}

pub enum GuardianRiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

pub enum GuardianAssessmentAction {
    Command { source, command, cwd },
    Execve { source, program, argv, cwd },
    ApplyPatch { cwd, files },
    NetworkAccess { target, host, protocol, port },
    McpToolCall { server, tool_name, connector_id, connector_name, tool_title },
    RequestPermissions { reason, permissions },
}
```

#### 7. **English text** (`ExecPolicyAmendment`)
```rust
pub struct ExecPolicyAmendment {
    pub command: Vec<String>,  // English text
}
```

#### 8. **English text** (`Decision`)
```rust
pub enum Decision {
    Allow,      // English text, English textstepEnglish text
    Prompt,     // requestEnglish text
    Forbidden,  // English text
}
```

### English textsystemEnglish text

```
AskForApproval
├── GranularApprovalConfig
└── English text Protocol, Session, Config

ApprovalsReviewer
├── English text Session configuration
└── English text Guardian evaluation

ExecApprovalRequestEvent
├── ParsedCommand
├── NetworkApprovalContext
├── ExecPolicyAmendment
├── NetworkPolicyAmendment
└── AdditionalPermissionProfile

GuardianAssessmentEvent
├── GuardianAssessmentAction
├── GuardianAssessmentStatus
├── GuardianRiskLevel
├── GuardianUserAuthorization
└── NetworkApprovalProtocol

Decision
└── English text Policy, Rule English textuse
```

---

## English textsystem (Sandbox)

### English textfile

| filepath | English text | English text |
|--------|------|------|
| `codex-rs/protocol/src/permissions.rs` | English text | **English text** |
| `codex-rs/protocol/src/config_types.rs` | English textconfiguration | **English text** |
| `codex-rs/sandboxing/src/lib.rs` | English textmanagementEnglish text | **English text** |
| `codex-rs/sandboxing/src/manager.rs` | English textmanagementEnglish text | **English text** |
| `codex-rs/sandboxing/src/bwrap.rs` | Linux bwrap implementation | English text |
| `codex-rs/sandboxing/src/seatbelt.rs` | macOS Seatbelt implementation | English text |
| `codex-rs/sandboxing/src/landlock.rs` | Linux Landlock implementation | English text |
| `codex-rs/sandboxing/src/policy_transforms.rs` | English text | English text |

### English text

#### 1. **English text** (`SandboxPermissions`)
```rust
pub enum SandboxPermissions {
    #[default]
    UseDefault,                // useEnglish textconfigurationEnglish text
    RequireEscalated,          // requestEnglish textrun
    WithAdditionalPermissions, // English text
}

impl SandboxPermissions {
    pub fn requires_escalated_permissions(self) -> bool { /* */ }
    pub fn requests_sandbox_override(self) -> bool { /* */ }
    pub fn uses_additional_permissions(self) -> bool { /* */ }
}
```

#### 2. **filesystemEnglish text** (`FileSystemAccessMode`)
```rust
pub enum FileSystemAccessMode {
    Read,   // English text
    Write,  // English text
    Deny,   // English text
}

impl FileSystemAccessMode {
    pub fn can_read(self) -> bool { /* */ }
    pub fn can_write(self) -> bool { /* */ }
}
```

#### 3. **filesystemEnglish text** (`FileSystemSandboxEntry`)
```rust
pub struct FileSystemSandboxEntry {
    pub path: FileSystemPath,           // filepath
    pub access: FileSystemAccessMode,   // English text
}

pub enum FileSystemPath {
    Path { path: AbsolutePathBuf },
    SpecialPath { path: FileSystemSpecialPath },
}

pub enum FileSystemSpecialPath {
    Root,
    Minimal,
    ProjectRoots { subpath: Option<PathBuf> },
    Tmpdir,
    SlashTmp,
    Unknown { path: String, subpath: Option<PathBuf> },
}
```

#### 4. **filesystemEnglish text** (`FileSystemSandboxPolicy`)
```rust
pub struct FileSystemSandboxPolicy {
    pub kind: FileSystemSandboxKind,              // English text
    pub glob_scan_max_depth: Option<usize>,       // Glob English text
    pub entries: Vec<FileSystemSandboxEntry>,     // filesystemEnglish text
}

pub enum FileSystemSandboxKind {
    #[default]
    Restricted,         // English text
    Unrestricted,       // English text
    ExternalSandbox,    // English text
}

// English textdataName
pub const PROTECTED_METADATA_PATH_NAMES: &[&str] = &[
    ".git",
    ".agents",
    ".codex",
];
```

#### 5. **English text** (`NetworkSandboxPolicy`)
```rust
pub enum NetworkSandboxPolicy {
    #[default]
    Restricted,  // English text
    Enabled,     // English text
}

impl NetworkSandboxPolicy {
    pub fn is_enabled(self) -> bool { /* */ }
}
```

#### 6. **English text** (`SandboxMode`)
```rust
pub enum SandboxMode {
    #[serde(rename = "read-only")]
    #[default]
    ReadOnly,           // English text

    #[serde(rename = "workspace-write")]
    WorkspaceWrite,     // English text

    #[serde(rename = "danger-full-access")]
    DangerFullAccess,   // English text(English text)
}
```

#### 7. **English text** (`SandboxPolicy`)
```rust
pub enum SandboxPolicy {
    DangerFullAccess,
    ReadOnly { network_access: bool },
    ExternalSandbox { network_access: bool },
    WorkspaceWrite { network_access: bool },
}
```

#### 8. **English text** (`SandboxType`)
```rust
pub enum SandboxType {
    None,
    MacosSeatbelt,
    LinuxSeccomp,
    WindowsRestrictedToken,
}

impl SandboxType {
    pub fn as_metric_tag(self) -> &'static str { /* */ }
}
```

#### 9. **English textrequest** (`SandboxExecRequest`)
```rust
pub struct SandboxExecRequest {
    pub command: Vec<String>,
    pub cwd: AbsolutePathBuf,
    pub env: HashMap<String, String>,
    pub network: Option<NetworkProxy>,
    pub sandbox: SandboxType,
    pub windows_sandbox_level: WindowsSandboxLevel,
    pub windows_sandbox_private_desktop: bool,
    pub permission_profile: PermissionProfile,
    pub file_system_sandbox_policy: FileSystemSandboxPolicy,
    pub network_sandbox_policy: NetworkSandboxPolicy,
    pub arg0: Option<String>,
}
```

#### 10. **English textrequest** (`SandboxTransformRequest`)
```rust
pub struct SandboxTransformRequest<'a> {
    pub command: SandboxCommand,
    pub permissions: &'a PermissionProfile,
    pub sandbox: SandboxType,
    pub enforce_managed_network: bool,
    pub network: Option<&'a NetworkProxy>,
    pub sandbox_policy_cwd: &'a Path,
    pub codex_linux_sandbox_exe: Option<&'a Path>,
    pub use_legacy_landlock: bool,
    pub windows_sandbox_level: WindowsSandboxLevel,
    pub windows_sandbox_private_desktop: bool,
}
```

### English textsystemEnglish text

```
FileSystemAccessMode
├── FileSystemSandboxEntry
└── English text

FileSystemSandboxPolicy
├── FileSystemAccessMode
├── FileSystemSandboxEntry
├── English textdataName
└── English text

NetworkSandboxPolicy
├── English text
└── SandboxPolicy

SandboxMode / SandboxPolicy
├── configurationEnglish text
└── runEnglish text

SandboxType
├── SandboxManager
├── English textimplementation(bwrap, seatbelt, landlock)
└── English text

SandboxExecRequest
├── SandboxType
├── FileSystemSandboxPolicy
├── NetworkSandboxPolicy
└── PermissionProfile
```

---

## English textsupport (Threading)

### English textfile

| filepath | English text | English text |
|--------|------|------|
| `codex-rs/protocol/src/thread_id.rs` | English text ID English text | **English text** |
| `codex-rs/thread-store/src/types.rs` | English text | **English text** |
| `codex-rs/thread-store/src/store.rs` | English text | **English text** |
| `codex-rs/thread-store/src/live_thread.rs` | English text | **English text** |
| `codex-rs/analytics/src/facts.rs` | English textinitializeEnglish text | English text |
| `codex-rs/protocol/src/protocol.rs` | English text | English text |
| `codex-rs/ext/extension-api/src/contributors/thread_lifecycle.rs` | English text | English text |

### English text

#### 1. **English text ID** (`ThreadId`)
```rust
pub struct ThreadId {
    pub(crate) uuid: Uuid,  // UUID v7
}

impl ThreadId {
    pub fn new() -> Self { /* generateEnglish text ID */ }
    pub fn from_string(s: &str) -> Result<Self, uuid::Error> { /* */ }
}
```

#### 2. **English textinitializeEnglish text** (`ThreadInitializationMode`)
```rust
pub enum ThreadInitializationMode {
    Fresh,      // English text
    Resumed,    // recoverEnglish text
    Forked,     // English text
}
```

#### 3. **English textstart** (`SubAgentThreadStartedInput`)
```rust
pub struct SubAgentThreadStartedInput {
    pub thread_id: String,              // English text ID
    pub parent_thread_id: Option<String>, // English text ID
    pub initialization_mode: ThreadInitializationMode,  // initializeEnglish text
}
```

#### 4. **English textdata** (`ThreadPersistenceMetadata`)
```rust
pub struct ThreadPersistenceMetadata {
    pub cwd: Option<PathBuf>,           // English textdirectory
    pub model_provider: String,         // modelEnglish text
    pub memory_mode: MemoryMode,        // English text
}
```

#### 5. **English textparameter** (`CreateThreadParams`)
```rust
pub struct CreateThreadParams {
    pub thread_id: ThreadId,                      // English text ID
    pub forked_from_id: Option<ThreadId>,         // English text
    pub parent_thread_id: Option<ThreadId>,       // English text(English text)
    pub source: SessionSource,                    // English text
    pub thread_source: Option<ThreadSource>,      // English text
    pub base_instructions: BaseInstructions,      // English text
    pub dynamic_tools: Vec<DynamicToolSpec>,      // English texttool
    pub metadata: ThreadPersistenceMetadata,      // English textdata
}
```

#### 6. **recoverEnglish textparameter** (`ResumeThreadParams`)
```rust
pub struct ResumeThreadParams {
    pub thread_id: ThreadId,            // English text ID
    pub rollout_path: Option<PathBuf>,  // Rollout filepath
    pub history: Option<Vec<RolloutItem>>, // English text
    pub include_archived: bool,         // English textrecoverEnglish text
    pub metadata: ThreadPersistenceMetadata,  // English textdata
}
```

#### 7. **English textparameter** (`AppendThreadItemsParams`)
```rust
pub struct AppendThreadItemsParams {
    pub thread_id: ThreadId,            // English text ID
    pub items: Vec<RolloutItem>,        // English text
}
```

#### 8. **English text** (`LiveThread`)
```rust
pub struct LiveThread {
    thread_id: ThreadId,
    thread_store: Arc<dyn ThreadStore>,
    metadata_sync: Arc<Mutex<ThreadMetadataSync>>,
}

impl LiveThread {
    pub async fn create(
        thread_store: Arc<dyn ThreadStore>,
        params: CreateThreadParams,
    ) -> ThreadStoreResult<Self> { /* */ }

    pub async fn resume(/* ... */) -> ThreadStoreResult<Self> { /* */ }
    pub async fn append_items(/* ... */) -> ThreadStoreResult<()> { /* */ }
    pub async fn persist(&self) -> ThreadStoreResult<()> { /* */ }
    pub async fn flush(&self) -> ThreadStoreResult<()> { /* */ }
    pub async fn shutdown(&self) -> ThreadStoreResult<()> { /* */ }
}
```

#### 9. **English text** (`ThreadStore` trait)
```rust
#[async_trait]
pub trait ThreadStore: Any + Send + Sync {
    async fn create_thread(&self, params: CreateThreadParams) -> ThreadStoreResult<()>;
    async fn resume_thread(&self, params: ResumeThreadParams) -> ThreadStoreResult<()>;
    async fn append_items(&self, params: AppendThreadItemsParams) -> ThreadStoreResult<()>;
    async fn persist_thread(&self, thread_id: ThreadId) -> ThreadStoreResult<()>;
    async fn flush_thread(&self, thread_id: ThreadId) -> ThreadStoreResult<()>;
    async fn shutdown_thread(&self, thread_id: ThreadId) -> ThreadStoreResult<()>;
    async fn discard_thread(&self, thread_id: ThreadId) -> ThreadStoreResult<()>;
    async fn load_history(&self, params: LoadThreadHistoryParams)
        -> ThreadStoreResult<StoredThreadHistory>;
    async fn read_thread(&self, params: ReadThreadParams) -> ThreadStoreResult<StoredThread>;
    async fn list_threads(&self, params: ListThreadsParams) -> ThreadStoreResult<ThreadPage>;
    async fn search_threads(&self, params: SearchThreadsParams) -> ThreadStoreResult<ThreadSearchPage>;
    async fn archive_thread(&self, params: ArchiveThreadParams) -> ThreadStoreResult<()>;
    async fn unarchive_thread(&self, params: ArchiveThreadParams) -> ThreadStoreResult<StoredThread>;
}
```

#### 10. **English text** (`StoredThread`)
```rust
pub struct StoredThread {
    pub thread_id: ThreadId,
    pub source: SessionSource,
    pub thread_source: Option<ThreadSource>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub forked_from_id: Option<ThreadId>,
    pub parent_thread_id: Option<ThreadId>,
    pub metadata: ThreadPersistenceMetadata,
    pub archived_at: Option<DateTime<Utc>>,
    pub items: Vec<RolloutItem>,  // English text, English textloadparameter
}
```

#### 11. **English text**
```rust
pub struct ThreadStartInput<'a, C> { /* */ }
pub struct ThreadResumeInput<'a> { /* */ }
pub struct ThreadIdleInput<'a> { /* */ }
pub struct ThreadStopInput<'a> { /* */ }
```

### English textsystemEnglish text

```
ThreadId
├── UUID v7 generate
├── English text
└── English text

ThreadInitializationMode
├── English text
├── English textrecoverEnglish text
└── English text

CreateThreadParams
├── ThreadId
├── ThreadPersistenceMetadata
├── BaseInstructions
└── DynamicToolSpec

ResumeThreadParams
├── ThreadId
├── ThreadPersistenceMetadata
└── RolloutItem English text

AppendThreadItemsParams
├── ThreadId
└── RolloutItem

LiveThread
├── ThreadStore implementation
├── English textdataEnglish textstep
└── English textmanagement

ThreadStore trait
├── English textimplementation (LocalThreadStore)
├── English textimplementation (InMemoryThreadStore)
└── English textimplementation(English text)

StoredThread
├── ThreadPersistenceMetadata
├── RolloutItem
└── timeEnglish textmanagement
```

---

## English text

### English text

```
┌─────────────────────────────────────────────────────────────┐
│                      Protocol Layer                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │ Approvals Module │  │ Permissions Mod. │  │ Thread ID  │ │
│  └────────┬─────────┘  └────────┬─────────┘  └─────┬──────┘ │
│           │                     │                   │         │
│  ┌─────────▼──────────────────┐ │                   │         │
│  │ • AskForApproval           │ │                   │         │
│  │ • ApprovalsReviewer        │ │                   │         │
│  │ • ExecApprovalRequestEvent │ │                   │         │
│  │ • GuardianAssessmentEvent  │ │                   │         │
│  │ • NetworkApprovalProtocol  │ │                   │         │
│  └──────────────────────────┘ │                   │         │
│                                │                   │         │
│           ┌──────────────────┐ │                   │         │
│           │ • SandboxMode    │─┘                   │         │
│           │ • FileSystemAccMode                    │         │
│           │ • FileSystemSandboxPolicy              │         │
│           │ • NetworkSandboxPolicy                 │         │
│           │ • SandboxPermissions                   │         │
│           └──────────────────────────────────────┘         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ use
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                    Runtime/Storage Layer                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────────────┐   ┌──────────────────────┐   │
│  │ Thread Store Subsystem    │   │ Sandbox Manager      │   │
│  ├───────────────────────────┤   ├──────────────────────┤   │
│  │ • ThreadStore trait       │   │ • SandboxType enum   │   │
│  │ • LiveThread              │   │ • SandboxExecRequest │   │
│  │ • CreateThreadParams      │   │ • Platform impls:    │   │
│  │ • ResumeThreadParams      │   │   - bwrap            │   │
│  │ • StoredThread            │   │   - seatbelt         │   │
│  │ • ThreadInitializationMode│   │   - landlock         │   │
│  └───────────────────────────┘   └──────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ implementation
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                  Platform Implementation Layer               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Thread Store Implementations                           │ │
│  │  • LocalThreadStore (rollout files)                    │ │
│  │  • InMemoryThreadStore (testing)                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Sandbox Platform Implementations                       │ │
│  │  • Linux: bwrap + landlock                             │ │
│  │  • macOS: seatbelt                                     │ │
│  │  • Windows: restricted token                           │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### English textpipelineEnglish text

```
User Request
    │
    ▼
AskForApproval Policy
    │
    ├─► UnlessTrusted: English textsafetyEnglish text
    │       │
    │       ├─► safety(English text) ──► Allow
    │       └─► English text ──────────► requestEnglish text
    │
    ├─► OnFailure: English text, failureEnglish textrequestEnglish text(English text)
    │
    ├─► OnRequest: modelEnglish text
    │       │
    │       └─► RequiredEnglish text ──► ExecApprovalRequestEvent
    │
    ├─► Granular: English text
    │       │
    │       ├─► sandbox_approval
    │       ├─► rules
    │       ├─► skill_approval
    │       ├─► request_permissions
    │       └─► mcp_elicitations
    │
    └─► Never: English textrequest

English textrequest
    │
    ▼
ApprovalsReviewer
    │
    ├─► User: English text
    │       │
    │       └─► User Decision
    │
    └─► AutoReview: GuardianAssessmentEvent
            │
            ├─► English text/English text
            ├─► computeEnglish text
            ├─► English text
            └─► English text Allow/Deny

English text
    │
    ├─► ExecPolicyAmendment: English text execpolicy
    ├─► NetworkPolicyAmendment: English text
    └─► AdditionalPermissions: extensionEnglish text
```

### English textpipelineEnglish text

```
Request Execution
    │
    ▼
SandboxPolicy Selection
    │
    ├─► ReadOnly (default)
    │       ├─► FileSystemSandboxPolicy (English text)
    │       └─► NetworkSandboxPolicy (English text)
    │
    ├─► WorkspaceWrite
    │       ├─► English text
    │       └─► English textdata (.git, .agents, .codex)
    │
    ├─► ExternalSandbox
    │       └─► useEnglish text
    │
    └─► DangerFullAccess
            └─► English text(English text)

Platform Selection
    │
    ├─► Linux: SandboxType::LinuxSeccomp
    │       ├─► bwrap (bubblewrap)
    │       └─► landlock (LSM)
    │
    ├─► macOS: SandboxType::MacosSeatbelt
    │       └─► Seatbelt (SBPL language)
    │
    └─► Windows: SandboxType::WindowsRestrictedToken
            └─► Restricted Token

SandboxTransformRequest
    │
    ├─► English textfilesystemEnglish text
    ├─► English text
    ├─► English textparameter
    └─► English text

Enforcement
    │
    ├─► runEnglish text
    ├─► English textrequest(English text)
    └─► English text
```

### English text

```
Session Start
    │
    ▼
ThreadId Generation (UUID v7)
    │
    ├─► Fresh Thread
    │       │
    │       ▼
    │   CreateThreadParams
    │       │
    │       ├─► ThreadId
    │       ├─► source (SessionSource)
    │       ├─► metadata (cwd, model_provider, memory_mode)
    │       └─► base_instructions, dynamic_tools
    │
    │   LiveThread::create()
    │       │
    │       └─► ThreadStore::create_thread()
    │               │
    │               └─► Persistence (LocalThreadStore/InMemory)
    │
    ├─► Resumed Thread
    │       │
    │       ▼
    │   ResumeThreadParams
    │       │
    │       ├─► thread_id
    │       ├─► rollout_path (English text)
    │       └─► history (English text)
    │
    │   LiveThread::resume()
    │       │
    │       └─► ThreadStore::resume_thread()
    │               │
    │               └─► Load existing history
    │
    └─► Forked Thread
            │
            ▼
        CreateThreadParams
            │
            ├─► forked_from_id = parent_thread_id
            └─► source = Fork

        LiveThread::create()
            │
            └─► Copy parent state
                │
                └─► Create new thread in store

Active Session (Append Items)
    │
    ▼
AppendThreadItemsParams
    │
    ├─► thread_id
    └─► items (RolloutItem[])

LiveThread::append_items()
    │
    └─► ThreadStore::append_items()
            │
            └─► Write to persistence

Flush / Persist
    │
    ├─► LiveThread::flush() ──► English text
    ├─► LiveThread::persist() ─► English text
    └─► LiveThread::shutdown() ─► English text

Thread Closure
    │
    ├─► Archive: ThreadStore::archive_thread()
    ├─► Unarchive: ThreadStore::unarchive_thread()
    └─► Query: ThreadStore::read_thread(), list_threads(), search_threads()
```

---

## migrationEnglish text

### English text: **7.5/10** (English text)

### English text

#### English textsystem (Approvals): **8/10** ⚠️ English text

**mainEnglish text:**
- ✅ English text, dataEnglish text
- ❌ English text(English text → English text → Guardian evaluation → English text)
- ❌ English textSource(exec, network, MCP, permissions)
- ❌ Guardian English text(RequiredEnglish text AI English text)
- ❌ English textsystemEnglish text(execpolicy)

**English text:**
- Protocol: English text
- Config: AskForApproval, ApprovalsReviewer configuration
- ExecPolicy: Decision, Policy, Rule system
- Guardian: English textimplementation
- Network Proxy: English textmanagement

**migrationEnglish text:**
- English textmigration: 2-3 English text
- Guardian evaluationEnglish text: 4-5 English text
- English text: 3-4 English text
- testEnglish text: 2-3 English text
- **English text: 11-15 English text**

**English text:**
- English text Guardian English text
- English textsystemEnglish text
- English textmanagementEnglish text
- MCP English textsystemEnglish textmigration

---

#### English textsystem (Sandbox): **8.5/10** ⚠️ English text

**mainEnglish text:**
- ✅ English text, English textmodel
- ❌ English textimplementation(Linux/macOS/Windows)
- ❌ English textfilesystemEnglish text
- ❌ English text(bwrap, seatbelt, landlock)
- ❌ English textdatamanagement

**English text:**
- Protocol: FileSystemAccessMode, SandboxPolicy English text
- Permissions: English text
- Platform-specific: bwrap, seatbelt, landlock English text
- Network Proxy: English text
- Config: SandboxMode configuration

**migrationEnglish text:**
- English textmodelmigration: 2-3 English text
- English text: 5-7 English text(RequiredEnglish texttest)
- filesystemEnglish text: 3-4 English text
- English text: 2-3 English text
- testEnglish text: 3-4 English text
- **English text: 15-21 English text**

**English text:**
- English text(bwrap English text)
- Neurx English text
- filesystemEnglish textoptimize
- English textdataEnglish text

---

#### English textsupport (Threading): **7/10** English text

**mainEnglish text:**
- ✅ dataEnglish text
- ✅ English text
- ❌ English textstepEnglish text
- ❌ English textrecoverEnglish text
- ❌ English text(English text)

**English text:**
- Protocol: ThreadId, English text
- Storage: Rollout filesystem, English text
- Config: English textconfiguration
- Analytics: English textinitializeEnglish text

**migrationEnglish text:**
- ThreadId English text: 1-2 English text
- LocalThreadStore implementation: 3-4 English text
- English textstepEnglish text: 3-4 English text
- recoverEnglish text: 2-3 English text
- English textsupport(English text): 3-5 English text
- testEnglish text: 2-3 English text
- **English text: 14-21 English text**

**English text:**
- Neurx English text
- English textsteprunEnglish text(Tokio)
- English textstateEnglish text
- recoverEnglish text

---

### English text

**phase 1: English text (English text 1-2 English text)**
1. migration `ThreadId` English text
2. implementation `LocalThreadStore`(English textfile)
3. English textmanagementframework

**phase 2: English text (English text 3-4 English text)**
1. migrationEnglish textmodel(`FileSystemAccessMode`, `FileSystemSandboxPolicy`)
2. implementationEnglish text
3. English text Linux English textsupport(bwrap/landlock)
4. testEnglish textfilesystemEnglish text

**phase 3: English textsystem (English text 5-6 English text)**
1. migrationEnglish text(`AskForApproval`, `ApprovalsReviewer`)
2. implementationEnglish textrequestEnglish text
3. English text Guardian English text
4. testEnglish text

**phase 4: English textoptimize (English text 7-8 English text)**
1. English texttest
2. English textoptimize
3. English texttest(macOS, Windows)
4. English text

---

### English textevaluation

| English text | English text | English text | English text |
|------|------|------|--------|
| Guardian English text | English text | English text | English text, English text Guardian English text |
| English text | English text | English text | English textmigration, English texttest |
| English text | English text | English text | completeEnglish texttest, English texttestEnglish text |
| English text | English text | English text | English text, monitoring |
| English text | English text | English text | English text API English text, English text |

---

## English text (Neurx)

```
neurx/src/
├── agent/
│   ├── approvals/
│   │   ├── lib.rs
│   │   ├── models.rs          # English text protocol/src/approvals.rs
│   │   ├── policies.rs         # AskForApproval, GranularApprovalConfig
│   │   ├── reviewer.rs         # ApprovalsReviewer, Guardian English text
│   │   ├── request.rs          # ExecApprovalRequestEvent English text
│   │   ├── guardian.rs         # Guardian evaluationEnglish text
│   │   └── tests/
│   │
│   ├── sandbox/
│   │   ├── lib.rs
│   │   ├── models.rs           # English textmodel
│   │   ├── policy.rs           # FileSystemSandboxPolicy English text
│   │   ├── manager.rs          # SandboxManager
│   │   ├── platforms/
│   │   │   ├── linux.rs        # bwrap, landlock
│   │   │   ├── macos.rs        # seatbelt
│   │   │   └── windows.rs      # restricted token
│   │   └── tests/
│   │
│   ├── thread/
│   │   ├── lib.rs
│   │   ├── id.rs               # ThreadId
│   │   ├── store.rs            # ThreadStore trait
│   │   ├── persistence.rs      # LocalThreadStore
│   │   ├── lifecycle.rs        # English text, recover, English text, English text
│   │   ├── memory.rs           # InMemoryThreadStore
│   │   └── tests/
│   │
│   └── ...
```

---

## English text

- Codex English text: `/Users/feifei/agent/codex/codex-rs/`
- Protocol English text: `codex-rs/protocol/src/`
- Thread Store English text: `codex-rs/thread-store/src/`
- Sandboxing English text: `codex-rs/sandboxing/src/`
- ExecPolicy English text: `codex-rs/execpolicy/src/`
- Analytics English text: `codex-rs/analytics/src/`
