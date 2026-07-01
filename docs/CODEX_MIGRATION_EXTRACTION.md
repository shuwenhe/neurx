# Codex 功能迁移提取报告

**更新时间**: 2026-06-02  
**源仓库**: `/Users/feifei/agent/codex`  
**目标**: neurx Agent 框架

---

## 目录

1. [审批系统 (Approvals)](#审批系统approvals)
2. [沙箱系统 (Sandbox)](#沙箱系统sandbox)
3. [线程支持 (Threading)](#线程支持threading)
4. [依赖关系图](#依赖关系图)
5. [迁移复杂性评分](#迁移复杂性评分)

---

## 审批系统 (Approvals)

### 关键源文件

| 文件路径 | 用途 | 优先级 |
|--------|------|------|
| `codex-rs/protocol/src/approvals.rs` | 审批数据结构定义 | **必需** |
| `codex-rs/protocol/src/config_types.rs` | 配置类型（ApprovalsReviewer） | **必需** |
| `codex-rs/protocol/src/protocol.rs` | 协议定义（AskForApproval） | **必需** |
| `codex-rs/execpolicy/src/decision.rs` | 执行策略决策 | **必需** |
| `codex-rs/core/src/guardian/approval_request.rs` | Guardian 审批请求处理 | 重要 |
| `codex-rs/core/src/tools/network_approval.rs` | 网络审批工具 | 重要 |
| `codex-rs/protocol/src/mcp_approval_meta.rs` | MCP 审批元数据 | 重要 |

### 关键类型定义

#### 1. **审批策略枚举** (`AskForApproval`)
```rust
pub enum AskForApproval {
    UnlessTrusted,              // 仅自动批准"已知安全"命令
    OnFailure,                  // 失败时才请求批准（已弃用）
    OnRequest,                  // 模型决定是否请求批准（默认）
    Granular(GranularApprovalConfig),  // 细粒度控制
    Never,                      // 从不请求批准
}
```

#### 2. **细粒度审批配置** (`GranularApprovalConfig`)
```rust
pub struct GranularApprovalConfig {
    pub sandbox_approval: bool,        // shell 命令审批
    pub rules: bool,                   // execpolicy prompt 规则
    pub skill_approval: bool,          // 技能脚本执行
    pub request_permissions: bool,     // 权限请求工具
    pub mcp_elicitations: bool,        // MCP 提示
}
```

#### 3. **审批审评者枚举** (`ApprovalsReviewer`)
```rust
pub enum ApprovalsReviewer {
    #[default]
    User,                       // 用户审批
    #[serde(rename = "guardian_subagent", alias = "auto_review")]
    AutoReview,                 // Guardian 子代理审批
}
```

#### 4. **执行审批请求** (`ExecApprovalRequestEvent`)
```rust
pub struct ExecApprovalRequestEvent {
    pub call_id: String,                          // 命令执行项 ID
    pub approval_id: Option<String>,              // 审批回调 ID
    pub turn_id: String,                          // 转向 ID
    pub started_at_ms: i64,                       // 开始时间
    pub command: Vec<String>,                     // 执行命令
    pub cwd: AbsolutePathBuf,                     // 工作目录
    pub reason: Option<String>,                   // 审批原因
    pub network_approval_context: Option<NetworkApprovalContext>,  // 网络上下文
    pub proposed_execpolicy_amendment: Option<ExecPolicyAmendment>, // 建议执行策略修改
    pub proposed_network_policy_amendments: Option<Vec<NetworkPolicyAmendment>>, // 网络策略修改
    pub additional_permissions: Option<AdditionalPermissionProfile>,  // 额外权限
    pub available_decisions: Option<Vec<ReviewDecision>>,  // 可用决策
    pub parsed_cmd: Vec<ParsedCommand>,           // 解析后的命令
}
```

#### 5. **网络审批协议** (`NetworkApprovalProtocol`)
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

#### 6. **Guardian 评估事件** (`GuardianAssessmentEvent`)
```rust
pub struct GuardianAssessmentEvent {
    pub id: String,                              // 稳定标识符
    pub target_item_id: Option<String>,          // 目标项 ID
    pub turn_id: String,                         // 转向 ID
    pub started_at_ms: i64,                      // 开始时间
    pub completed_at_ms: Option<i64>,            // 完成时间
    pub status: GuardianAssessmentStatus,        // 评估状态
    pub risk_level: Option<GuardianRiskLevel>,   // 风险等级
    pub user_authorization: Option<GuardianUserAuthorization>,  // 用户授权
    pub rationale: Option<String>,               // 评估理由
    pub decision_source: Option<GuardianAssessmentDecisionSource>,  // 决策来源
    pub action: GuardianAssessmentAction,        // 审批动作
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

#### 7. **执行策略修改** (`ExecPolicyAmendment`)
```rust
pub struct ExecPolicyAmendment {
    pub command: Vec<String>,  // 命令前缀
}
```

#### 8. **执行策略决策** (`Decision`)
```rust
pub enum Decision {
    Allow,      // 允许执行，无需进一步批准
    Prompt,     // 请求显式用户批准
    Forbidden,  // 直接阻止
}
```

### 审批系统依赖关系

```
AskForApproval
├── GranularApprovalConfig
└── 用于 Protocol, Session, Config

ApprovalsReviewer
├── 用于 Session 配置
└── 用于 Guardian 评估

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
└── 在 Policy, Rule 中使用
```

---

## 沙箱系统 (Sandbox)

### 关键源文件

| 文件路径 | 用途 | 优先级 |
|--------|------|------|
| `codex-rs/protocol/src/permissions.rs` | 权限和沙箱定义 | **必需** |
| `codex-rs/protocol/src/config_types.rs` | 沙箱模式配置 | **必需** |
| `codex-rs/sandboxing/src/lib.rs` | 沙箱管理接口 | **必需** |
| `codex-rs/sandboxing/src/manager.rs` | 沙箱执行管理器 | **必需** |
| `codex-rs/sandboxing/src/bwrap.rs` | Linux bwrap 实现 | 重要 |
| `codex-rs/sandboxing/src/seatbelt.rs` | macOS Seatbelt 实现 | 重要 |
| `codex-rs/sandboxing/src/landlock.rs` | Linux Landlock 实现 | 重要 |
| `codex-rs/sandboxing/src/policy_transforms.rs` | 策略转换 | 重要 |

### 关键类型定义

#### 1. **沙箱权限模式** (`SandboxPermissions`)
```rust
pub enum SandboxPermissions {
    #[default]
    UseDefault,                // 使用转向配置的沙箱策略
    RequireEscalated,          // 请求在沙箱外运行
    WithAdditionalPermissions, // 在沙箱内扩宽权限
}

impl SandboxPermissions {
    pub fn requires_escalated_permissions(self) -> bool { /* */ }
    pub fn requests_sandbox_override(self) -> bool { /* */ }
    pub fn uses_additional_permissions(self) -> bool { /* */ }
}
```

#### 2. **文件系统访问模式** (`FileSystemAccessMode`)
```rust
pub enum FileSystemAccessMode {
    Read,   // 只读
    Write,  // 读写
    Deny,   // 拒绝访问
}

impl FileSystemAccessMode {
    pub fn can_read(self) -> bool { /* */ }
    pub fn can_write(self) -> bool { /* */ }
}
```

#### 3. **文件系统沙箱项** (`FileSystemSandboxEntry`)
```rust
pub struct FileSystemSandboxEntry {
    pub path: FileSystemPath,           // 文件路径
    pub access: FileSystemAccessMode,   // 访问模式
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

#### 4. **文件系统沙箱策略** (`FileSystemSandboxPolicy`)
```rust
pub struct FileSystemSandboxPolicy {
    pub kind: FileSystemSandboxKind,              // 沙箱类型
    pub glob_scan_max_depth: Option<usize>,       // Glob 扫描最大深度
    pub entries: Vec<FileSystemSandboxEntry>,     // 文件系统项
}

pub enum FileSystemSandboxKind {
    #[default]
    Restricted,         // 受限沙箱
    Unrestricted,       // 无限制
    ExternalSandbox,    // 外部沙箱
}

// 保护的元数据名称
pub const PROTECTED_METADATA_PATH_NAMES: &[&str] = &[
    ".git",
    ".agents", 
    ".codex",
];
```

#### 5. **网络沙箱策略** (`NetworkSandboxPolicy`)
```rust
pub enum NetworkSandboxPolicy {
    #[default]
    Restricted,  // 网络受限
    Enabled,     // 网络启用
}

impl NetworkSandboxPolicy {
    pub fn is_enabled(self) -> bool { /* */ }
}
```

#### 6. **沙箱模式** (`SandboxMode`)
```rust
pub enum SandboxMode {
    #[serde(rename = "read-only")]
    #[default]
    ReadOnly,           // 只读模式

    #[serde(rename = "workspace-write")]
    WorkspaceWrite,     // 工作区写入模式

    #[serde(rename = "danger-full-access")]
    DangerFullAccess,   // 完全访问（危险）
}
```

#### 7. **沙箱策略** (`SandboxPolicy`)
```rust
pub enum SandboxPolicy {
    DangerFullAccess,
    ReadOnly { network_access: bool },
    ExternalSandbox { network_access: bool },
    WorkspaceWrite { network_access: bool },
}
```

#### 8. **沙箱类型** (`SandboxType`)
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

#### 9. **沙箱执行请求** (`SandboxExecRequest`)
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

#### 10. **沙箱变换请求** (`SandboxTransformRequest`)
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

### 沙箱系统依赖关系

```
FileSystemAccessMode
├── FileSystemSandboxEntry
└── 用于权限检查

FileSystemSandboxPolicy
├── FileSystemAccessMode
├── FileSystemSandboxEntry
├── 保护元数据名称
└── 权限验证

NetworkSandboxPolicy
├── 网络访问控制
└── SandboxPolicy

SandboxMode / SandboxPolicy
├── 配置解析
└── 运行时决策

SandboxType
├── SandboxManager
├── 平台特定实现（bwrap, seatbelt, landlock）
└── 平台检测

SandboxExecRequest
├── SandboxType
├── FileSystemSandboxPolicy
├── NetworkSandboxPolicy
└── PermissionProfile
```

---

## 线程支持 (Threading)

### 关键源文件

| 文件路径 | 用途 | 优先级 |
|--------|------|------|
| `codex-rs/protocol/src/thread_id.rs` | 线程 ID 定义 | **必需** |
| `codex-rs/thread-store/src/types.rs` | 线程存储类型 | **必需** |
| `codex-rs/thread-store/src/store.rs` | 线程存储接口 | **必需** |
| `codex-rs/thread-store/src/live_thread.rs` | 活跃线程处理 | **必需** |
| `codex-rs/analytics/src/facts.rs` | 线程初始化模式 | 重要 |
| `codex-rs/protocol/src/protocol.rs` | 线程相关协议 | 重要 |
| `codex-rs/ext/extension-api/src/contributors/thread_lifecycle.rs` | 线程生命周期钩子 | 重要 |

### 关键类型定义

#### 1. **线程 ID** (`ThreadId`)
```rust
pub struct ThreadId {
    pub(crate) uuid: Uuid,  // UUID v7
}

impl ThreadId {
    pub fn new() -> Self { /* 生成新 ID */ }
    pub fn from_string(s: &str) -> Result<Self, uuid::Error> { /* */ }
}
```

#### 2. **线程初始化模式** (`ThreadInitializationMode`)
```rust
pub enum ThreadInitializationMode {
    Fresh,      // 新创建线程
    Resumed,    // 恢复已有线程
    Forked,     // 从现有线程分叉
}
```

#### 3. **子代理线程启动** (`SubAgentThreadStartedInput`)
```rust
pub struct SubAgentThreadStartedInput {
    pub thread_id: String,              // 新线程 ID
    pub parent_thread_id: Option<String>, // 父线程 ID
    pub initialization_mode: ThreadInitializationMode,  // 初始化模式
}
```

#### 4. **线程持久化元数据** (`ThreadPersistenceMetadata`)
```rust
pub struct ThreadPersistenceMetadata {
    pub cwd: Option<PathBuf>,           // 工作目录
    pub model_provider: String,         // 模型提供商
    pub memory_mode: MemoryMode,        // 内存模式
}
```

#### 5. **创建线程参数** (`CreateThreadParams`)
```rust
pub struct CreateThreadParams {
    pub thread_id: ThreadId,                      // 线程 ID
    pub forked_from_id: Option<ThreadId>,         // 分叉源
    pub parent_thread_id: Option<ThreadId>,       // 父线程（子代理）
    pub source: SessionSource,                    // 源分类
    pub thread_source: Option<ThreadSource>,      // 分析源
    pub base_instructions: BaseInstructions,      // 基础指令
    pub dynamic_tools: Vec<DynamicToolSpec>,      // 动态工具
    pub metadata: ThreadPersistenceMetadata,      // 元数据
}
```

#### 6. **恢复线程参数** (`ResumeThreadParams`)
```rust
pub struct ResumeThreadParams {
    pub thread_id: ThreadId,            // 线程 ID
    pub rollout_path: Option<PathBuf>,  // Rollout 文件路径
    pub history: Option<Vec<RolloutItem>>, // 已知历史
    pub include_archived: bool,         // 允许恢复已归档线程
    pub metadata: ThreadPersistenceMetadata,  // 元数据
}
```

#### 7. **追加线程项参数** (`AppendThreadItemsParams`)
```rust
pub struct AppendThreadItemsParams {
    pub thread_id: ThreadId,            // 线程 ID
    pub items: Vec<RolloutItem>,        // 要追加的项
}
```

#### 8. **活跃线程** (`LiveThread`)
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

#### 9. **线程存储接口** (`ThreadStore` trait)
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

#### 10. **已存储线程** (`StoredThread`)
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
    pub items: Vec<RolloutItem>,  // 可选，取决于加载参数
}
```

#### 11. **线程生命周期钩子**
```rust
pub struct ThreadStartInput<'a, C> { /* */ }
pub struct ThreadResumeInput<'a> { /* */ }
pub struct ThreadIdleInput<'a> { /* */ }
pub struct ThreadStopInput<'a> { /* */ }
```

### 线程系统依赖关系

```
ThreadId
├── UUID v7 生成
├── 字符串序列化
└── 用于所有线程操作

ThreadInitializationMode
├── 用于分析
├── 用于恢复决策
└── 用于分叉逻辑

CreateThreadParams
├── ThreadId
├── ThreadPersistenceMetadata
├── BaseInstructions
└── DynamicToolSpec

ResumeThreadParams
├── ThreadId
├── ThreadPersistenceMetadata
└── RolloutItem 历史

AppendThreadItemsParams
├── ThreadId
└── RolloutItem

LiveThread
├── ThreadStore 实现
├── 元数据同步
└── 生命周期管理

ThreadStore trait
├── 本地实现 (LocalThreadStore)
├── 内存实现 (InMemoryThreadStore)
└── 远程实现（可选）

StoredThread
├── ThreadPersistenceMetadata
├── RolloutItem
└── 时间戳管理
```

---

## 依赖关系图

### 全局依赖关系

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
                          │ 使用
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
                          │ 实现
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

### 审批流程图

```
User Request
    │
    ▼
AskForApproval Policy
    │
    ├─► UnlessTrusted: 检查已知安全命令
    │       │
    │       ├─► 安全(只读) ──► Allow
    │       └─► 其他 ──────────► 请求批准
    │
    ├─► OnFailure: 先执行，失败后请求批准(已弃用)
    │
    ├─► OnRequest: 模型决定
    │       │
    │       └─► 需要批准 ──► ExecApprovalRequestEvent
    │
    ├─► Granular: 按类别细粒度控制
    │       │
    │       ├─► sandbox_approval
    │       ├─► rules
    │       ├─► skill_approval
    │       ├─► request_permissions
    │       └─► mcp_elicitations
    │
    └─► Never: 拒绝所有请求

批准请求
    │
    ▼
ApprovalsReviewer
    │
    ├─► User: 显示给用户
    │       │
    │       └─► User Decision
    │
    └─► AutoReview: GuardianAssessmentEvent
            │
            ├─► 分析行动/上下文
            ├─► 计算风险等级
            ├─► 检查用户授权
            └─► 返回 Allow/Deny

决策应用
    │
    ├─► ExecPolicyAmendment: 更新 execpolicy
    ├─► NetworkPolicyAmendment: 更新网络策略
    └─► AdditionalPermissions: 扩展权限
```

### 沙箱应用流程图

```
Request Execution
    │
    ▼
SandboxPolicy Selection
    │
    ├─► ReadOnly (默认)
    │       ├─► FileSystemSandboxPolicy (受限读取)
    │       └─► NetworkSandboxPolicy (受限网络)
    │
    ├─► WorkspaceWrite
    │       ├─► 写入工作区
    │       └─► 保护元数据 (.git, .agents, .codex)
    │
    ├─► ExternalSandbox
    │       └─► 使用外部沙箱
    │
    └─► DangerFullAccess
            └─► 完全访问(危险)

Platform Selection
    │
    ├─► Linux: SandboxType::LinuxSeccomp
    │       ├─► bwrap (bubblewrap)
    │       └─► landlock (LSM)
    │
    ├─► macOS: SandboxType::MacosSeatbelt
    │       └─► Seatbelt (SBPL 语言)
    │
    └─► Windows: SandboxType::WindowsRestrictedToken
            └─► Restricted Token

SandboxTransformRequest
    │
    ├─► 应用文件系统权限
    ├─► 应用网络限制
    ├─► 注入平台特定参数
    └─► 执行受限命令

Enforcement
    │
    ├─► 运行时拒绝访问
    ├─► 审批请求(如果启用)
    └─► 执行决策应用
```

### 线程生命周期图

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
    │       ├─► rollout_path (可选)
    │       └─► history (可选)
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
    ├─► LiveThread::flush() ──► 立即持久化
    ├─► LiveThread::persist() ─► 标记为持久化
    └─► LiveThread::shutdown() ─► 关闭写入器

Thread Closure
    │
    ├─► Archive: ThreadStore::archive_thread()
    ├─► Unarchive: ThreadStore::unarchive_thread()
    └─► Query: ThreadStore::read_thread(), list_threads(), search_threads()
```

---

## 迁移复杂性评分

### 总体评分: **7.5/10** (高复杂度)

### 各模块详细评分

#### 审批系统 (Approvals): **8/10** ⚠️ 高

**主要复杂性因素:**
- ✅ 相对独立的模块，数据结构清晰
- ❌ 多层决策逻辑（策略 → 审批 → Guardian 评估 → 决策）
- ❌ 多种审批来源（exec, network, MCP, permissions）
- ❌ Guardian 子代理集成（需要理解 AI 驱动的审批）
- ❌ 与执行策略系统紧密耦合（execpolicy）

**依赖关系:**
- Protocol: 类型定义
- Config: AskForApproval, ApprovalsReviewer 配置
- ExecPolicy: Decision, Policy, Rule 系统
- Guardian: 子代理审批实现
- Network Proxy: 网络策略管理

**迁移工作量估计:**
- 类型定义迁移: 2-3 天
- Guardian 评估逻辑: 4-5 天
- 决策应用逻辑: 3-4 天
- 测试和集成: 2-3 天
- **总计: 11-15 天**

**关键问题需解决:**
- 如何集成 Guardian 子代理决策逻辑
- 执行策略系统的兼容性
- 网络审批与代理网络管理的集成
- MCP 审批系统的迁移

---

#### 沙箱系统 (Sandbox): **8.5/10** ⚠️ 高

**主要复杂性因素:**
- ✅ 模块化设计，明确的权限模型
- ❌ 平台特定实现（Linux/macOS/Windows）
- ❌ 复杂的文件系统权限匹配逻辑
- ❌ 多种沙箱后端（bwrap, seatbelt, landlock）
- ❌ 受保护元数据管理

**依赖关系:**
- Protocol: FileSystemAccessMode, SandboxPolicy 定义
- Permissions: 权限验证逻辑
- Platform-specific: bwrap, seatbelt, landlock 库
- Network Proxy: 网络策略应用
- Config: SandboxMode 配置

**迁移工作量估计:**
- 权限模型迁移: 2-3 天
- 跨平台沙箱适配: 5-7 天（需要每个平台测试）
- 文件系统匹配逻辑: 3-4 天
- 网络策略集成: 2-3 天
- 测试和验证: 3-4 天
- **总计: 15-21 天**

**关键问题需解决:**
- 如何集成现有沙箱后端（bwrap 等）
- Neurx 中的平台检测和选择机制
- 文件系统权限匹配算法的优化
- 受保护元数据的强制执行

---

#### 线程支持 (Threading): **7/10** 中高

**主要复杂性因素:**
- ✅ 数据结构相对简洁
- ✅ 存储接口定义清晰
- ❌ 异步持久化机制
- ❌ 线程恢复和分叉逻辑
- ❌ 分布式一致性考虑（远程存储）

**依赖关系:**
- Protocol: ThreadId, 协议定义
- Storage: Rollout 文件系统、远程存储
- Config: 内存模式配置
- Analytics: 线程初始化事件

**迁移工作量估计:**
- ThreadId 和基础类型: 1-2 天
- LocalThreadStore 实现: 3-4 天
- 异步持久化逻辑: 3-4 天
- 恢复和分叉机制: 2-3 天
- 远程存储支持（可选）: 3-5 天
- 测试和集成: 2-3 天
- **总计: 14-21 天**

**关键问题需解决:**
- Neurx 中的存储后端选择
- 异步运行时集成（Tokio）
- 分叉时的状态复制策略
- 恢复时的一致性保证

---

### 优先级建议

**阶段 1: 基础设施 (第 1-2 周)**
1. 迁移 `ThreadId` 和线程基础类型
2. 实现 `LocalThreadStore`（基于内存或文件）
3. 建立线程生命周期管理框架

**阶段 2: 权限和沙箱 (第 3-4 周)**
1. 迁移权限模型（`FileSystemAccessMode`, `FileSystemSandboxPolicy`）
2. 实现跨平台沙箱检测和选择
3. 移植 Linux 沙箱支持（bwrap/landlock）
4. 测试和验证文件系统权限

**阶段 3: 审批系统 (第 5-6 周)**
1. 迁移审批基础类型（`AskForApproval`, `ApprovalsReviewer`）
2. 实现审批请求事件处理
3. 集成 Guardian 子代理决策
4. 测试审批工作流

**阶段 4: 集成和优化 (第 7-8 周)**
1. 端到端集成测试
2. 性能优化
3. 平台特定测试（macOS, Windows）
4. 文档和知识转移

---

### 风险评估

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|--------|
| Guardian 子代理集成 | 中 | 高 | 早期设计审查，与 Guardian 团队合作 |
| 平台特定沙箱 | 中 | 中 | 逐个平台迁移，充分测试 |
| 持久化一致性 | 中 | 中 | 完整的单元测试，集成测试覆盖 |
| 性能回归 | 低 | 中 | 建立性能基准，监控 |
| 向后兼容性 | 低 | 高 | 保持 API 契约，版本控制 |

---

## 建议的代码组织结构 (Neurx)

```
neurx/src/
├── agent/
│   ├── approvals/
│   │   ├── lib.rs
│   │   ├── models.rs          # 从 protocol/src/approvals.rs
│   │   ├── policies.rs         # AskForApproval, GranularApprovalConfig
│   │   ├── reviewer.rs         # ApprovalsReviewer, Guardian 集成
│   │   ├── request.rs          # ExecApprovalRequestEvent 等
│   │   ├── guardian.rs         # Guardian 评估事件和动作
│   │   └── tests/
│   │
│   ├── sandbox/
│   │   ├── lib.rs
│   │   ├── models.rs           # 权限模型
│   │   ├── policy.rs           # FileSystemSandboxPolicy 等
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
│   │   ├── lifecycle.rs        # 创建、恢复、分叉、关闭
│   │   ├── memory.rs           # InMemoryThreadStore
│   │   └── tests/
│   │
│   └── ...
```

---

## 参考文献

- Codex 源代码: `/Users/feifei/agent/codex/codex-rs/`
- Protocol 模块: `codex-rs/protocol/src/`
- Thread Store 模块: `codex-rs/thread-store/src/`
- Sandboxing 模块: `codex-rs/sandboxing/src/`
- ExecPolicy 模块: `codex-rs/execpolicy/src/`
- Analytics 模块: `codex-rs/analytics/src/`
