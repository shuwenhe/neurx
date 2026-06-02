# Codex 迁移快速参考卡

## 🎯 核心指标

| 指标 | 数值 |
|------|------|
| 总体迁移复杂性 | **7.5/10** (高) |
| 预计工作量 | **8-10 周** |
| 关键文件数 | **25+** |
| 代码行数 | **~6900** |
| 子模块数 | **3** (审批、沙箱、线程) |

---

## 📋 三大核心模块速览

### 1️⃣ 审批系统 (8/10)

**关键文件**: 6 个
```
✓ protocol/src/approvals.rs          (400 行，核心定义)
✓ protocol/src/protocol.rs           (AskForApproval enum)
✓ protocol/src/config_types.rs       (ApprovalsReviewer enum)
✓ execpolicy/src/decision.rs         (Allow/Prompt/Forbidden)
✓ core/src/guardian/...              (Guardian 集成)
✓ core/src/tools/network_approval.rs (网络审批)
```

**关键枚举**:
- `AskForApproval`: UnlessTrusted | OnFailure | OnRequest | Granular | Never
- `ApprovalsReviewer`: User | AutoReview
- `NetworkApprovalProtocol`: Http | Https | Socks5Tcp | Socks5Udp
- `GuardianAssessmentStatus`: InProgress | Approved | Denied | TimedOut | Aborted

**关键结构**:
- `ExecApprovalRequestEvent` - 执行审批请求
- `GuardianAssessmentEvent` - Guardian 评估事件
- `NetworkApprovalContext` - 网络上下文
- `GranularApprovalConfig` - 细粒度配置

**工作量**: 11-15 天

---

### 2️⃣ 沙箱系统 (8.5/10)

**关键文件**: 8 个
```
✓ protocol/src/permissions.rs        (1000 行，核心定义)
✓ protocol/src/config_types.rs       (SandboxMode enum)
✓ protocol/src/protocol.rs           (SandboxPolicy enum)
✓ sandboxing/src/manager.rs          (管理器)
✓ sandboxing/src/bwrap.rs            (Linux bubblewrap)
✓ sandboxing/src/seatbelt.rs         (macOS Seatbelt)
✓ sandboxing/src/landlock.rs         (Linux LSM)
✓ sandboxing/src/policy_transforms.rs (策略转换)
```

**关键枚举**:
- `FileSystemAccessMode`: Read | Write | Deny
- `FileSystemSandboxKind`: Restricted | Unrestricted | ExternalSandbox
- `NetworkSandboxPolicy`: Restricted | Enabled
- `SandboxMode`: ReadOnly | WorkspaceWrite | DangerFullAccess
- `SandboxType`: None | MacosSeatbelt | LinuxSeccomp | WindowsRestrictedToken

**关键结构**:
- `FileSystemSandboxPolicy` - 文件系统沙箱策略
- `FileSystemSandboxEntry` - 文件系统项
- `SandboxExecRequest` - 执行请求
- `SandboxTransformRequest` - 转换请求

**保护元数据**: `.git` | `.agents` | `.codex`

**工作量**: 15-21 天

---

### 3️⃣ 线程支持 (7/10)

**关键文件**: 7 个
```
✓ protocol/src/thread_id.rs          (ThreadId, UUID v7)
✓ thread-store/src/types.rs          (参数和类型)
✓ thread-store/src/store.rs          (ThreadStore trait)
✓ thread-store/src/live_thread.rs    (活跃线程生命周期)
✓ thread-store/src/local/mod.rs      (本地存储实现)
✓ thread-store/src/in_memory.rs      (内存存储)
✓ analytics/src/facts.rs             (初始化模式)
```

**关键类型**:
- `ThreadId` - UUID v7 包装
- `ThreadInitializationMode`: Fresh | Resumed | Forked
- `ThreadPersistenceMetadata` - 元数据
- `CreateThreadParams` - 创建参数
- `ResumeThreadParams` - 恢复参数
- `StoredThread` - 存储的线程

**关键 Trait**:
- `ThreadStore` - 15+ 个异步方法

**工作量**: 14-21 天

---

## 🔗 关键依赖关系

### 跨模块流

```
                  ┌─────────────┐
                  │  审批系统   │
                  └──────┬──────┘
                         │ 请求权限升级
                         ▼
         ┌────────────────────────────┐
         │      沙箱系统             │
         │ (权限验证/应用)           │
         └────────────┬───────────────┘
                      │ 记录到线程
                      ▼
         ┌────────────────────────────┐
         │      线程系统             │
         │ (持久化/恢复)             │
         └────────────────────────────┘
```

### 外部集成

```
Guardian 子代理 ─┐
                ├─► 审批系统
NetworkProxy ────┤
                └─► 沙箱系统

Rollout 系统 ────► 线程系统
```

---

## 📊 模块优先级和依赖顺序

```
第 1 步: 线程基础 (3-5 天)
  └─ ThreadId + 基础类型
     └─ LocalThreadStore 框架

第 2 步: 权限模型 (4-6 天)
  └─ FileSystemAccessMode
     └─ FileSystemSandboxPolicy
        └─ 保护元数据检查

第 3 步: 沙箱应用 (5-8 天)
  └─ SandboxManager
     └─ 平台选择
        └─ 执行转换

第 4 步: 审批基础 (3-4 天)
  └─ AskForApproval
     └─ ApprovalsReviewer
        └─ ExecApprovalRequestEvent

第 5 步: Guardian 集成 (4-5 天)
  └─ GuardianAssessmentEvent
     └─ 决策应用

第 6 步: 集成和测试 (2-3 周)
  └─ 端到端流程
     └─ 平台特定测试
        └─ 性能优化
```

---

## 🚀 快速迁移清单

### 准备阶段

- [ ] 审阅所有 6,900 行代码
- [ ] 理解 Guardian 子代理架构
- [ ] 了解 neurx 的异步运行时 (Tokio)
- [ ] 获得平台访问权限 (Linux/macOS/Windows)
- [ ] 建立测试基础设施

### 第一周: 基础设施

- [ ] 移植 `ThreadId` 和相关类型
- [ ] 实现 `LocalThreadStore`
- [ ] 建立线程生命周期管理
- [ ] 创建测试框架

### 第二周: 权限和沙箱

- [ ] 迁移 `FileSystemAccessMode` 等权限类型
- [ ] 实现 `FileSystemSandboxPolicy` 检查
- [ ] 实现保护元数据强制执行
- [ ] 对 Linux 沙箱进行初始测试

### 第三周: 高级沙箱

- [ ] 实现 `SandboxManager` 核心
- [ ] 移植 bwrap 支持 (Linux)
- [ ] 移植 seatbelt 支持 (macOS)
- [ ] 平台特定测试

### 第四周: 审批系统

- [ ] 迁移审批基础类型
- [ ] 实现 `ExecApprovalRequestEvent` 处理
- [ ] 集成 Guardian 评估
- [ ] 实现决策应用

### 第五周及以后: 集成和优化

- [ ] 端到端集成测试
- [ ] 性能优化
- [ ] Windows 支持 (如需要)
- [ ] 文档和知识转移

---

## ⚠️ 关键风险和缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Guardian 依赖 | 高 | 早期设计审查 |
| 平台差异 | 中 | 逐个平台迁移 |
| 持久化一致性 | 中 | 完整单元测试 |
| 性能回归 | 中 | 基准测试 |
| 向后兼容性 | 高 | API 版本控制 |

---

## 🔑 关键决策点

### 1. 存储后端选择
- **选项 A**: LocalThreadStore (基于 Rollout 文件)
  - ✅ 与 Codex 兼容
  - ✅ 相对简单
  - ❌ 单机限制
- **选项 B**: 分布式存储 (未来)
  - ✅ 可扩展
  - ❌ 复杂度高
- **推荐**: 从 A 开始，为 B 预留接口

### 2. 审批评审者
- **选项 A**: 用户批准 (简单)
- **选项 B**: Guardian 子代理 (高级)
- **推荐**: 支持两者，配置可选

### 3. 沙箱后端优先级
- **阶段 1**: Linux (bwrap + landlock)
- **阶段 2**: macOS (seatbelt)
- **阶段 3**: Windows (restricted token, 可选)

---

## 📚 文件导航

```
关键定义文件:
├─ 审批系统
│  ├─ codex-rs/protocol/src/approvals.rs        ← 开始这里
│  ├─ codex-rs/protocol/src/protocol.rs
│  └─ codex-rs/protocol/src/config_types.rs
├─ 沙箱系统
│  ├─ codex-rs/protocol/src/permissions.rs      ← 开始这里
│  ├─ codex-rs/sandboxing/src/manager.rs
│  └─ codex-rs/sandboxing/src/policy_transforms.rs
└─ 线程系统
   ├─ codex-rs/protocol/src/thread_id.rs        ← 开始这里
   ├─ codex-rs/thread-store/src/types.rs
   └─ codex-rs/thread-store/src/store.rs

实现文件:
├─ 沙箱平台
│  ├─ codex-rs/sandboxing/src/bwrap.rs          (Linux)
│  ├─ codex-rs/sandboxing/src/seatbelt.rs       (macOS)
│  └─ codex-rs/sandboxing/src/landlock.rs       (Linux LSM)
├─ 存储实现
│  ├─ codex-rs/thread-store/src/local/mod.rs    (默认)
│  └─ codex-rs/thread-store/src/in_memory.rs    (测试)
└─ 集成
   ├─ codex-rs/core/src/guardian/approval_request.rs
   └─ codex-rs/core/src/tools/network_approval.rs

测试文件:
├─ codex-rs/core/tests/suite/approvals.rs
├─ codex-rs/sandboxing/src/*_tests.rs
└─ codex-rs/thread-store/ (集成测试)
```

---

## 💡 关键概念总结

### 审批流

```
用户请求
    ↓
AskForApproval 策略
    ├─ UnlessTrusted: 安全命令自动通过
    ├─ OnFailure: 失败时请求 (已弃用)
    ├─ OnRequest: 模型决定
    ├─ Granular: 按类别细粒度
    └─ Never: 全部拒绝
    ↓
ApprovalsReviewer 路由
    ├─ User: 显示给用户
    └─ AutoReview: Guardian 子代理
    ↓
决策应用
    ├─ ExecPolicyAmendment: 更新执行策略
    ├─ NetworkPolicyAmendment: 更新网络策略
    └─ AdditionalPermissions: 扩展权限
```

### 沙箱模式

```
请求执行
    ↓
选择 SandboxMode
    ├─ ReadOnly (默认): 只读 + 网络限制
    ├─ WorkspaceWrite: 工作区写入 + 保护元数据
    ├─ ExternalSandbox: 使用外部沙箱
    └─ DangerFullAccess: 完全访问 (危险)
    ↓
平台选择
    ├─ Linux: bwrap (bubblewrap) + landlock
    ├─ macOS: seatbelt
    └─ Windows: restricted token
    ↓
应用 SandboxTransformRequest
    ├─ 文件系统权限
    ├─ 网络限制
    └─ 平台参数
    ↓
执行受限命令
```

### 线程生命周期

```
会话开始
    ↓
ThreadId 生成 (UUID v7)
    ↓
线程初始化
    ├─ Fresh: 新创建
    ├─ Resumed: 从存储恢复
    └─ Forked: 从现有线程分叉
    ↓
项目追加 (RolloutItem)
    ↓
持久化/刷新
    ↓
会话关闭
    └─ 归档或删除
```

---

## 🎓 学习资源

### 必读代码

1. **审批系统入门** (2 小时)
   - `codex-rs/protocol/src/approvals.rs` (全文)
   - 关注: 所有 pub struct/enum

2. **沙箱系统入门** (3 小时)
   - `codex-rs/protocol/src/permissions.rs` (前 500 行)
   - `codex-rs/sandboxing/src/manager.rs`

3. **线程系统入门** (2 小时)
   - `codex-rs/protocol/src/thread_id.rs` (全文)
   - `codex-rs/thread-store/src/store.rs` (trait 定义)

### 重要测试

- `codex-rs/core/tests/suite/approvals.rs`
- `codex-rs/sandboxing/src/manager_tests.rs`
- `codex-rs/sandboxing/src/policy_transforms_tests.rs`

### 外部参考

- UUID v7: https://github.com/uuid-rs/uuid
- Serde: https://serde.rs/
- Tokio: https://tokio.rs/
- Bubblewrap: https://github.com/containers/bubblewrap
- Landlock: https://www.kernel.org/doc/html/latest/userspace-api/landlock.html

---

## 📞 常见问题

**Q: 可以并行迁移这三个模块吗?**  
A: 不建议。线程系统是基础，其他两个模块都依赖它。建议按顺序: 线程 → 权限/沙箱 → 审批

**Q: Guardian 子代理必须迁移吗?**  
A: 不是。可以先实现基础审批 (用户批准)，后续再添加 Guardian

**Q: 需要支持 Windows 吗?**  
A: 可选。Linux/macOS 是必需的。Windows 支持可以延后

**Q: 如何处理向后兼容性?**  
A: 通过 serde 别名和版本化配置格式。参见 `config_types.rs` 中的 `#[serde(alias)]` 示例

**Q: 迁移过程中如何测试?**  
A: 建立完整的单元测试、集成测试和端到端测试。参见 Codex 中的 `tests/` 目录

---

**更新**: 2026-06-02  
**源**: `/Users/feifei/agent/codex`  
**目标**: neurx Agent Framework
