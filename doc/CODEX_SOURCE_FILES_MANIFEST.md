# Codex 迁移源文件清单和依赖关系

## 完整源文件清单

### 1. 审批系统 (Approvals) 相关文件

#### 核心定义文件

```
codex-rs/protocol/src/approvals.rs
├─ 行数: ~400
├─ 关键类型:
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
├─ 依赖:
│  ├─ crate::parse_command::ParsedCommand
│  ├─ crate::protocol::FileChange, ReviewDecision
│  ├─ crate::request_permissions::RequestPermissionProfile
│  ├─ codex_utils_absolute_path::AbsolutePathBuf
│  └─ serde, schemars, ts-rs
└─ 导出到: codex-rs/protocol/src/lib.rs (pub use)
```

```
codex-rs/protocol/src/protocol.rs
├─ 行数: ~5000+
├─ 关键类型:
│  ├─ AskForApproval (enum: UnlessTrusted, OnFailure, OnRequest, Granular, Never)
│  ├─ GranularApprovalConfig
│  ├─ NetworkAccess (enum: Restricted, Enabled)
│  ├─ SandboxPolicy (enum: DangerFullAccess, ReadOnly, ExternalSandbox, WorkspaceWrite)
│  └─ 其他协议定义...
├─ 依赖:
│  ├─ crate::approvals::* (重新导出)
│  ├─ crate::config_types::ApprovalsReviewer
│  ├─ crate::permissions::* (重新导出)
│  └─ 其他协议类型
└─ 用途: 协议层类型定义和导出
```

```
codex-rs/protocol/src/config_types.rs
├─ 行数: ~800+
├─ 关键类型:
│  ├─ SandboxMode (enum: ReadOnly, WorkspaceWrite, DangerFullAccess)
│  ├─ ProfileV2Name
│  ├─ ApprovalsReviewer (enum: User, AutoReview)
│  ├─ ShellEnvironmentPolicyInherit
│  └─ AutoCompactTokenLimitScope, Verbosity, ReasoningSummary, etc.
├─ 依赖:
│  ├─ crate::openai_models::ReasoningEffort
│  └─ 标准库和 serde
└─ 用途: 配置和枚举定义
```

#### 执行策略相关

```
codex-rs/execpolicy/src/decision.rs
├─ 行数: ~30
├─ 关键类型:
│  └─ Decision (enum: Allow, Prompt, Forbidden)
├─ 依赖: serde
└─ 用途: 执行策略决策
```

```
codex-rs/execpolicy/src/policy.rs
├─ 行数: ~200+
├─ 关键类型:
│  ├─ MatchOptions
│  ├─ Policy
│  └─ 规则相关类型
├─ 依赖:
│  ├─ crate::decision::Decision
│  ├─ crate::rule::*
│  └─ multimap::MultiMap
└─ 用途: 执行策略匹配
```

#### Guardian 和审批处理

```
codex-rs/core/src/guardian/approval_request.rs
├─ 用途: Guardian 审批请求处理
├─ 依赖:
│  ├─ codex_protocol::approvals::*
│  └─ codex_protocol::config_types::ApprovalsReviewer
└─ 注: 需要了解 Guardian 子代理架构
```

```
codex-rs/core/src/tools/network_approval.rs
├─ 用途: 网络审批工具实现
├─ 依赖:
│  ├─ codex_protocol::approvals::NetworkApprovalProtocol
│  └─ 网络代理实现
└─ 注: 与网络策略管理紧密耦合
```

#### MCP 审批

```
codex-rs/protocol/src/mcp_approval_meta.rs
├─ 用途: MCP 审批元数据
├─ 依赖:
│  ├─ codex_protocol::mcp::RequestId
│  └─ 其他 MCP 类型
└─ 注: MCP elicitation 系统集成
```

### 2. 沙箱系统 (Sandbox) 相关文件

#### 核心权限模型

```
codex-rs/protocol/src/permissions.rs
├─ 行数: ~1000+
├─ 关键类型:
│  ├─ FileSystemAccessMode (enum: Read, Write, Deny)
│  ├─ FileSystemSpecialPath (enum: Root, Minimal, ProjectRoots, Tmpdir, SlashTmp, Unknown)
│  ├─ FileSystemSandboxEntry
│  ├─ FileSystemSandboxKind (enum: Restricted, Unrestricted, ExternalSandbox)
│  ├─ FileSystemSandboxPolicy
│  ├─ ReadDenyMatcher
│  ├─ WritableRoot
│  ├─ FileSystemPath
│  ├─ NetworkSandboxPolicy (enum: Restricted, Enabled)
│  ├─ PROTECTED_METADATA_PATH_NAMES (常量)
│  └─ is_protected_metadata_name, forbidden_agent_metadata_write, etc.
├─ 依赖:
│  ├─ crate::protocol::{NetworkAccess, SandboxPolicy, WritableRoot}
│  ├─ codex_utils_absolute_path::*
│  ├─ globset::*
│  └─ serde
└─ 用途: 权限模型和检查
```

```
codex-rs/protocol/src/models.rs
├─ 行数: ~200+
├─ 关键类型:
│  ├─ SandboxPermissions (enum: UseDefault, RequireEscalated, WithAdditionalPermissions)
│  ├─ FileSystemPermissions
│  └─ 其他模型类型
├─ 依赖:
│  ├─ crate::permissions::*
│  ├─ codex_utils_absolute_path::*
│  └─ serde
└─ 用途: 权限数据结构
```

#### 沙箱管理

```
codex-rs/sandboxing/src/lib.rs
├─ 行数: ~50
├─ 导出:
│  ├─ SandboxManager
│  ├─ SandboxCommand, SandboxExecRequest
│  ├─ SandboxTransformRequest, SandboxTransformError
│  ├─ SandboxType, SandboxablePreference
│  ├─ 平台特定函数
│  └─ 错误转换
├─ 依赖:
│  ├─ crate::manager::*
│  ├─ crate::landlock::*
│  ├─ crate::seatbelt::*
│  └─ crate::bwrap::*
└─ 用途: 沙箱模块导出和协调
```

```
codex-rs/sandboxing/src/manager.rs
├─ 行数: ~400+
├─ 关键类型:
│  ├─ SandboxType (enum: None, MacosSeatbelt, LinuxSeccomp, WindowsRestrictedToken)
│  ├─ SandboxablePreference (enum: Auto, Require, Forbid)
│  ├─ SandboxCommand
│  ├─ SandboxExecRequest
│  ├─ SandboxTransformRequest
│  ├─ SandboxTransformError
│  └─ 转换函数
├─ 依赖:
│  ├─ crate::policy_transforms::*
│  ├─ codex_protocol::{models::*, permissions::*, protocol::*, config_types::*}
│  ├─ codex_network_proxy::NetworkProxy
│  └─ 其他工具库
└─ 用途: 沙箱执行管理
```

#### 平台特定实现

```
codex-rs/sandboxing/src/bwrap.rs
├─ 行数: ~400+
├─ 关键函数:
│  ├─ system_bwrap_warning()
│  ├─ find_system_bwrap_in_path()
│  ├─ system_bwrap_has_user_namespace_access()
│  └─ 其他 bwrap 特定函数
├─ 常量:
│  ├─ SYSTEM_BWRAP_PROGRAM
│  ├─ MISSING_BWRAP_WARNING
│  ├─ USER_NAMESPACE_WARNING
│  ├─ WSL1_BWRAP_WARNING
│  └─ 其他
├─ 依赖:
│  ├─ std::process::Command
│  ├─ std::thread
│  └─ libc 调用
└─ 用途: Linux bubblewrap 沙箱实现
```

```
codex-rs/sandboxing/src/seatbelt.rs
├─ 用途: macOS Seatbelt 沙箱实现
├─ 依赖: seatbelt-rs 库
└─ 注: 使用 SBPL (Seatbelt Profile Language) 文件
```

```
codex-rs/sandboxing/src/landlock.rs
├─ 用途: Linux Landlock LSM 实现
├─ 依赖: landlock crate
└─ 注: 作为 bwrap 的替代方案
```

```
codex-rs/sandboxing/src/policy_transforms.rs
├─ 行数: ~300+
├─ 关键函数:
│  ├─ effective_permission_profile()
│  ├─ should_require_platform_sandbox()
│  └─ 其他策略转换
├─ 依赖:
│  ├─ codex_protocol::permissions::*
│  ├─ codex_protocol::models::*
│  └─ crate::manager::*
└─ 用途: 权限策略转换和平台检测
```

### 3. 线程支持 (Threading) 相关文件

#### 核心线程定义

```
codex-rs/protocol/src/thread_id.rs
├─ 行数: ~120
├─ 关键类型:
│  └─ ThreadId { uuid: Uuid }
├─ 主要方法:
│  ├─ new()
│  ├─ from_string(s: &str)
│  ├─ Display, Serialize, Deserialize
│  └─ JsonSchema 实现
├─ 依赖:
│  ├─ uuid::Uuid (UUID v7)
│  ├─ serde
│  └─ schemars
└─ 用途: 线程标识符
```

#### 线程存储类型

```
codex-rs/thread-store/src/types.rs
├─ 行数: ~500+
├─ 关键类型:
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
│  └─ 其他参数和返回类型
├─ 依赖:
│  ├─ codex_protocol::ThreadId
│  ├─ codex_protocol::protocol::{AskForApproval, GitInfo, RolloutItem, SessionSource, ThreadMemoryMode, ThreadSource, TokenUsage}
│  ├─ codex_protocol::models::{BaseInstructions, PermissionProfile}
│  ├─ codex_protocol::openai_models::ReasoningEffort
│  ├─ codex_protocol::dynamic_tools::DynamicToolSpec
│  ├─ chrono::DateTime<Utc>
│  └─ serde
└─ 用途: 线程存储参数和数据结构
```

#### 线程存储接口

```
codex-rs/thread-store/src/store.rs
├─ 行数: ~150+
├─ 关键类型:
│  └─ ThreadStore (async trait)
├─ 主要方法:
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
├─ 依赖:
│  ├─ async_trait
│  ├─ std::any::Any
│  └─ crate 中的所有参数类型
└─ 用途: 存储后端接口定义
```

#### 活跃线程

```
codex-rs/thread-store/src/live_thread.rs
├─ 行数: ~200+
├─ 关键类型:
│  ├─ LiveThread
│  └─ LiveThreadInitGuard
├─ 主要方法:
│  ├─ LiveThread::create()
│  ├─ LiveThread::resume()
│  ├─ LiveThread::fork()
│  ├─ LiveThread::append_items()
│  ├─ LiveThread::persist()
│  ├─ LiveThread::flush()
│  ├─ LiveThread::shutdown()
│  ├─ LiveThread::discard()
│  └─ 其他方法
├─ 依赖:
│  ├─ Arc<dyn ThreadStore>
│  ├─ Tokio::sync::Mutex
│  ├─ ThreadMetadataSync
│  └─ 其他线程类型
└─ 用途: 活跃线程生命周期管理
```

#### 本地实现

```
codex-rs/thread-store/src/local/mod.rs
├─ 行数: ~500+
├─ 关键类型:
│  ├─ LocalThreadStore
│  └─ LocalThreadStoreConfig
├─ 用途: 基于文件/Rollout 的本地存储实现
├─ 依赖:
│  ├─ codex_rollout::persisted_rollout_items
│  ├─ tokio::fs
│  └─ 其他存储库
└─ 注: 默认实现，使用 rollout 文件
```

```
codex-rs/thread-store/src/in_memory.rs
├─ 行数: ~300+
├─ 关键类型:
│  ├─ InMemoryThreadStore
│  └─ InMemoryThreadStoreCalls
├─ 用途: 内存中的线程存储（用于测试）
├─ 依赖: 基本的内存数据结构
└─ 注: 测试和快速迭代使用
```

#### 分析和生命周期

```
codex-rs/analytics/src/facts.rs
├─ 行数: ~400+
├─ 关键类型:
│  ├─ ThreadInitializationMode (enum: Fresh, Resumed, Forked)
│  ├─ SubAgentThreadStartedInput
│  └─ 其他分析事实
├─ 用途: 线程初始化和分析事件
├─ 依赖:
│  ├─ codex_protocol::approvals::*, models::*, etc.
│  └─ serde
└─ 注: 分析层集成
```

```
codex-rs/ext/extension-api/src/contributors/thread_lifecycle.rs
├─ 行数: ~100+
├─ 关键类型:
│  ├─ ThreadStartInput
│  ├─ ThreadResumeInput
│  ├─ ThreadIdleInput
│  └─ ThreadStopInput
├─ 用途: 线程生命周期扩展钩子
├─ 依赖: 扩展 API
└─ 注: 可选的第三方集成点
```

---

## 详细依赖关系矩阵

### 审批系统依赖矩阵

```
                           approvals.rs  protocol.rs  config_types.rs  execpolicy/  guardian/
approvals.rs                   -           ←           ←              ←           ←
protocol.rs                    →           -           ←              ←           ←
config_types.rs                →           →           -              -           -
execpolicy/decision.rs         -           ←           -              -           -
execpolicy/policy.rs           -           ←           ←              -           -
guardian/approval_request.rs   →           →           →              -           -

说明:
  → 被引用（depends on）
  ← 引用（is depended by）
  - 无直接依赖
```

### 沙箱系统依赖矩阵

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

### 线程系统依赖矩阵

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

## 跨模块依赖关系

### 审批 ↔ 沙箱

```
审批 → 沙箱:
  ├─ ExecApprovalRequestEvent 包含 AdditionalPermissionProfile
  └─ AdditionalPermissionProfile → 沙箱权限

沙箱 → 审批:
  ├─ SandboxDenied → ReviewTrigger::SandboxDenial
  └─ 权限溢出 → 请求批准
```

### 审批 ↔ 线程

```
审批 → 线程:
  └─ ExecApprovalRequestEvent.turn_id → StoredTurn.turn_id

线程 → 审批:
  ├─ CreateThreadParams → AskForApproval 策略
  └─ ResumeThreadParams → 恢复时的批准状态
```

### 沙箱 ↔ 线程

```
沙箱 → 线程:
  └─ SandboxPolicy 保存在 ThreadPersistenceMetadata

线程 → 沙箱:
  └─ 线程恢复时应用持久化的沙箱策略
```

### 外部依赖

```
审批系统 ← Guardian 子代理
  ├─ GuardianAssessmentEvent 由 Guardian 生成
  └─ Guardian 需要访问 ApprovalsReviewer 配置

沙箱系统 ← NetworkProxy
  ├─ SandboxExecRequest.network: Option<NetworkProxy>
  └─ 网络代理负责网络策略应用

线程系统 ← Rollout 系统
  ├─ StoredThread 持久化为 RolloutItem
  └─ LocalThreadStore 使用 codex_rollout crate
```

---

## 文件大小和复杂度指标

### 代码行数统计

| 模块 | 文件 | 行数 | 复杂度 |
|------|------|------|-------|
| **审批** | approvals.rs | ~400 | 中 |
| | protocol.rs (部分) | ~500 | 高 |
| | config_types.rs (部分) | ~200 | 低 |
| | execpolicy/decision.rs | ~30 | 低 |
| | execpolicy/policy.rs | ~200 | 中 |
| | guardian/approval_request.rs | ~300 | 中 |
| **小计** | | ~1630 | |
| | | | |
| **沙箱** | permissions.rs | ~1000 | 高 |
| | config_types.rs (部分) | ~100 | 低 |
| | protocol.rs (部分) | ~300 | 中 |
| | manager.rs | ~400 | 中 |
| | bwrap.rs | ~400 | 高 |
| | seatbelt.rs | ~200 | 中 |
| | landlock.rs | ~300 | 高 |
| | policy_transforms.rs | ~300 | 高 |
| **小计** | | ~3400 | |
| | | | |
| **线程** | thread_id.rs | ~120 | 低 |
| | types.rs | ~500 | 中 |
| | store.rs | ~150 | 低 |
| | live_thread.rs | ~200 | 中 |
| | local/mod.rs | ~500 | 中 |
| | in_memory.rs | ~300 | 低 |
| | analytics/facts.rs (部分) | ~100 | 低 |
| **小计** | | ~1870 | |
| | | | |
| **总计** | | ~6900 | |

---

## 关键接口和特性

### 必须实现的 Traits

1. **ThreadStore** (async_trait)
   ```rust
   pub trait ThreadStore: Any + Send + Sync {
       async fn create_thread(&self, params: CreateThreadParams) -> ThreadStoreResult<()>;
       // 其他 15+ 个方法
   }
   ```

2. **序列化/反序列化**
   - Serde (JSON)
   - TypeScript 定义生成 (ts-rs)

3. **错误处理**
   - ThreadStoreError
   - SandboxTransformError
   - CodexErr

### 关键宏和属性

- `#[serde(rename_all = "snake_case")]`
- `#[ts(...)]` - TypeScript 生成
- `#[async_trait]` - 异步特性
- `pub use` - 模块导出

---

## 测试覆盖情况

### 审批系统

```
codex-rs/
├─ protocol/src/approvals.rs
│  └─ 内联测试 (~100 行)
├─ analytics/src/analytics_client_tests.rs
│  └─ 审批相关测试
└─ core/tests/suite/approvals.rs
   └─ 集成测试
```

### 沙箱系统

```
codex-rs/
├─ sandboxing/src/
│  ├─ bwrap_tests.rs
│  ├─ seatbelt_tests.rs
│  ├─ landlock_tests.rs
│  ├─ manager_tests.rs
│  └─ policy_transforms_tests.rs
├─ exec/tests/suite/approval_policy.rs
└─ core/tests/ (沙箱集成)
```

### 线程系统

```
codex-rs/
└─ thread-store/src/
   └─ 主要使用集成测试
      ├─ 本地存储测试
      └─ 内存存储测试
```

---

## 配置和常量

### 审批系统常量

```rust
// 无全局常量，主要通过配置参数
```

### 沙箱系统常量

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
// 等等...
```

### 线程系统常量

```rust
// 无重要全局常量，主要通过 config
```

---

## 已知问题和限制

### 审批系统

1. Guardian 子代理集成仍在开发中
2. MCP elicitation 系统可能需要额外工作
3. 跨会话审批历史追踪有限

### 沙箱系统

1. WSL1 不支持 bwrap（需要 WSL2）
2. 受保护元数据强制执行可能存在边界情况
3. Landlock 需要 Linux 5.13+ 内核
4. Windows 沙箱需要特殊权限

### 线程系统

1. 分布式线程存储实现不完整
2. 线程分叉后的一致性保证需要明确
3. 远程存储后端的网络分区处理未定义

---

## 推荐阅读顺序

1. **入门** (Day 1-2)
   - `protocol/src/thread_id.rs`
   - `protocol/src/config_types.rs`
   - `protocol/src/permissions.rs` (概览)

2. **深入权限** (Day 3-4)
   - `protocol/src/permissions.rs` (完整)
   - `sandboxing/src/manager.rs`
   - `sandboxing/src/policy_transforms.rs`

3. **审批流程** (Day 5-6)
   - `protocol/src/approvals.rs`
   - `protocol/src/protocol.rs` (AskForApproval 部分)
   - `execpolicy/src/decision.rs` 和 `policy.rs`

4. **线程系统** (Day 7-8)
   - `thread-store/src/types.rs`
   - `thread-store/src/store.rs`
   - `thread-store/src/live_thread.rs`
   - `thread-store/src/local/mod.rs`

5. **集成** (Day 9-10)
   - `core/src/guardian/approval_request.rs`
   - `core/src/tools/network_approval.rs`
   - 测试套件

6. **平台特定** (按需)
   - `sandboxing/src/bwrap.rs` (Linux)
   - `sandboxing/src/seatbelt.rs` (macOS)
   - `sandboxing/src/landlock.rs` (Linux 替代)

