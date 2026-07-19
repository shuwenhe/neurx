# Codex migrationquickEnglish text

## 🎯 English text

| English text | English text |
|------|------|
| English textmigrationEnglish text | **7.5/10** (English text) |
| English text | **8-10 English text** |
| English textfileEnglish text | **25+** |
| English text | **~6900** |
| English text | **3** (English text, English text, English text) |

---

## 📋 English text

### 1️⃣ English textsystem (8/10)

**English textfile**: 6 English text
```
✓ protocol/src/approvals.rs          (400 English text, English text)
✓ protocol/src/protocol.rs           (AskForApproval enum)
✓ protocol/src/config_types.rs       (ApprovalsReviewer enum)
✓ execpolicy/src/decision.rs         (Allow/Prompt/Forbidden)
✓ core/src/guardian/...              (Guardian English text)
✓ core/src/tools/network_approval.rs (English text)
```

**English text**:
- `AskForApproval`: UnlessTrusted | OnFailure | OnRequest | Granular | Never
- `ApprovalsReviewer`: User | AutoReview
- `NetworkApprovalProtocol`: Http | Https | Socks5Tcp | Socks5Udp
- `GuardianAssessmentStatus`: InProgress | Approved | Denied | TimedOut | Aborted

**English text**:
- `ExecApprovalRequestEvent` - English textrequest
- `GuardianAssessmentEvent` - Guardian evaluationEnglish text
- `NetworkApprovalContext` - English text
- `GranularApprovalConfig` - English textconfiguration

**English text**: 11-15 English text

---

### 2️⃣ English textsystem (8.5/10)

**English textfile**: 8 English text
```
✓ protocol/src/permissions.rs        (1000 English text, English text)
✓ protocol/src/config_types.rs       (SandboxMode enum)
✓ protocol/src/protocol.rs           (SandboxPolicy enum)
✓ sandboxing/src/manager.rs          (managementEnglish text)
✓ sandboxing/src/bwrap.rs            (Linux bubblewrap)
✓ sandboxing/src/seatbelt.rs         (macOS Seatbelt)
✓ sandboxing/src/landlock.rs         (Linux LSM)
✓ sandboxing/src/policy_transforms.rs (English text)
```

**English text**:
- `FileSystemAccessMode`: Read | Write | Deny
- `FileSystemSandboxKind`: Restricted | Unrestricted | ExternalSandbox
- `NetworkSandboxPolicy`: Restricted | Enabled
- `SandboxMode`: ReadOnly | WorkspaceWrite | DangerFullAccess
- `SandboxType`: None | MacosSeatbelt | LinuxSeccomp | WindowsRestrictedToken

**English text**:
- `FileSystemSandboxPolicy` - filesystemEnglish text
- `FileSystemSandboxEntry` - filesystemEnglish text
- `SandboxExecRequest` - English textrequest
- `SandboxTransformRequest` - English textrequest

**English textdata**: `.git` | `.agents` | `.codex`

**English text**: 15-21 English text

---

### 3️⃣ English textsupport (7/10)

**English textfile**: 7 English text
```
✓ protocol/src/thread_id.rs          (ThreadId, UUID v7)
✓ thread-store/src/types.rs          (parameterEnglish text)
✓ thread-store/src/store.rs          (ThreadStore trait)
✓ thread-store/src/live_thread.rs    (English text)
✓ thread-store/src/local/mod.rs      (English textimplementation)
✓ thread-store/src/in_memory.rs      (English text)
✓ analytics/src/facts.rs             (initializeEnglish text)
```

**English text**:
- `ThreadId` - UUID v7 English text
- `ThreadInitializationMode`: Fresh | Resumed | Forked
- `ThreadPersistenceMetadata` - English textdata
- `CreateThreadParams` - English textparameter
- `ResumeThreadParams` - recoverparameter
- `StoredThread` - English text

**English text Trait**:
- `ThreadStore` - 15+ English textstepEnglish text

**English text**: 14-21 English text

---

## 🔗 English text

### English text

```
                  ┌─────────────┐
                  │  English textsystem   │
                  └──────┬──────┘
                         │ requestEnglish text
                         ▼
         ┌────────────────────────────┐
         │      English textsystem             │
         │ (English text/English text)           │
         └────────────┬───────────────┘
                      │ English text
                      ▼
         ┌────────────────────────────┐
         │      English textsystem             │
         │ (English text/recover)             │
         └────────────────────────────┘
```

### English text

```
Guardian English text ─┐
                ├─► English textsystem
NetworkProxy ────┤
                └─► English textsystem

Rollout system ────► English textsystem
```

---

## 📊 English text

```
English text 1 step: English text (3-5 English text)
  └─ ThreadId + English text
     └─ LocalThreadStore framework

English text 2 step: English textmodel (4-6 English text)
  └─ FileSystemAccessMode
     └─ FileSystemSandboxPolicy
        └─ English textdataEnglish text

English text 3 step: English text (5-8 English text)
  └─ SandboxManager
     └─ English text
        └─ English text

English text 4 step: English text (3-4 English text)
  └─ AskForApproval
     └─ ApprovalsReviewer
        └─ ExecApprovalRequestEvent

English text 5 step: Guardian English text (4-5 English text)
  └─ GuardianAssessmentEvent
     └─ English text

English text 6 step: English texttest (2-3 English text)
  └─ English textpipeline
     └─ English texttest
        └─ English textoptimize
```

---

## 🚀 quickmigrationEnglish text

### English textphase

- [ ] English text 6,900 English text
- [ ] English text Guardian English text
- [ ] English text neurx English textsteprunEnglish text (Tokio)
- [ ] English text (Linux/macOS/Windows)
- [ ] English texttestEnglish text

### English text: English text

- [ ] English text `ThreadId` English text
- [ ] implementation `LocalThreadStore`
- [ ] English textmanagement
- [ ] English texttestframework

### English text: English text

- [ ] migration `FileSystemAccessMode` English text
- [ ] implementation `FileSystemSandboxPolicy` English text
- [ ] implementationEnglish textdataEnglish text
- [ ] English text Linux English texttest

### English text: advancedEnglish text

- [ ] implementation `SandboxManager` English text
- [ ] English text bwrap support (Linux)
- [ ] English text seatbelt support (macOS)
- [ ] English texttest

### English text: English textsystem

- [ ] migrationEnglish text
- [ ] implementation `ExecApprovalRequestEvent` English text
- [ ] English text Guardian evaluation
- [ ] implementationEnglish text

### English text: English textoptimize

- [ ] English texttest
- [ ] English textoptimize
- [ ] Windows support (English textRequired)
- [ ] English text

---

## ⚠️ English text

| English text | English text | English text |
|------|------|------|
| Guardian English text | English text | English text |
| English text | English text | English textmigration |
| English text | English text | completeEnglish texttest |
| English text | English text | English texttest |
| English text | English text | API English text |

---

## 🔑 English text

### 1. English text
- **English text A**: LocalThreadStore (English text Rollout file)
  - ✅ English text Codex English text
  - ✅ English text
  - ❌ English text
- **English text B**: English text (English text)
  - ✅ English textextension
  - ❌ English text
- **recommended**: English text A start, English text B English text

### 2. English text
- **English text A**: English text (English text)
- **English text B**: Guardian English text (advanced)
- **recommended**: supportEnglish text, configurationEnglish text

### 3. English text
- **phase 1**: Linux (bwrap + landlock)
- **phase 2**: macOS (seatbelt)
- **phase 3**: Windows (restricted token, English text)

---

## 📚 fileEnglish text

```
English textfile:
├─ English textsystem
│  ├─ codex-rs/protocol/src/approvals.rs        ← startEnglish text
│  ├─ codex-rs/protocol/src/protocol.rs
│  └─ codex-rs/protocol/src/config_types.rs
├─ English textsystem
│  ├─ codex-rs/protocol/src/permissions.rs      ← startEnglish text
│  ├─ codex-rs/sandboxing/src/manager.rs
│  └─ codex-rs/sandboxing/src/policy_transforms.rs
└─ English textsystem
   ├─ codex-rs/protocol/src/thread_id.rs        ← startEnglish text
   ├─ codex-rs/thread-store/src/types.rs
   └─ codex-rs/thread-store/src/store.rs

implementationfile:
├─ English text
│  ├─ codex-rs/sandboxing/src/bwrap.rs          (Linux)
│  ├─ codex-rs/sandboxing/src/seatbelt.rs       (macOS)
│  └─ codex-rs/sandboxing/src/landlock.rs       (Linux LSM)
├─ English textimplementation
│  ├─ codex-rs/thread-store/src/local/mod.rs    (default)
│  └─ codex-rs/thread-store/src/in_memory.rs    (test)
└─ English text
   ├─ codex-rs/core/src/guardian/approval_request.rs
   └─ codex-rs/core/src/tools/network_approval.rs

testfile:
├─ codex-rs/core/tests/suite/approvals.rs
├─ codex-rs/sandboxing/src/*_tests.rs
└─ codex-rs/thread-store/ (English texttest)
```

---

## 💡 English text

### English text

```
English textrequest
    ↓
AskForApproval English text
    ├─ UnlessTrusted: safetyEnglish text
    ├─ OnFailure: failureEnglish textrequest (English text)
    ├─ OnRequest: modelEnglish text
    ├─ Granular: English text
    └─ Never: English text
    ↓
ApprovalsReviewer English text
    ├─ User: English text
    └─ AutoReview: Guardian English text
    ↓
English text
    ├─ ExecPolicyAmendment: English text
    ├─ NetworkPolicyAmendment: English text
    └─ AdditionalPermissions: extensionEnglish text
```

### English text

```
requestEnglish text
    ↓
English text SandboxMode
    ├─ ReadOnly (default): English text + English text
    ├─ WorkspaceWrite: English text + English textdata
    ├─ ExternalSandbox: useEnglish text
    └─ DangerFullAccess: English text (English text)
    ↓
English text
    ├─ Linux: bwrap (bubblewrap) + landlock
    ├─ macOS: seatbelt
    └─ Windows: restricted token
    ↓
English text SandboxTransformRequest
    ├─ filesystemEnglish text
    ├─ English text
    └─ English textparameter
    ↓
English text
```

### English text

```
English textstart
    ↓
ThreadId generate (UUID v7)
    ↓
English textinitialize
    ├─ Fresh: English text
    ├─ Resumed: English textrecover
    └─ Forked: English text
    ↓
English text (RolloutItem)
    ↓
English text/English text
    ↓
English text
    └─ English text
```

---

## 🎓 English text

### English text

1. **English textsystemEnglish text** (2 English text)
   - `codex-rs/protocol/src/approvals.rs` (English text)
   - English text: English text pub struct/enum

2. **English textsystemEnglish text** (3 English text)
   - `codex-rs/protocol/src/permissions.rs` (English text 500 English text)
   - `codex-rs/sandboxing/src/manager.rs`

3. **English textsystemEnglish text** (2 English text)
   - `codex-rs/protocol/src/thread_id.rs` (English text)
   - `codex-rs/thread-store/src/store.rs` (trait English text)

### English texttest

- `codex-rs/core/tests/suite/approvals.rs`
- `codex-rs/sandboxing/src/manager_tests.rs`
- `codex-rs/sandboxing/src/policy_transforms_tests.rs`

### English text

- UUID v7: https://github.com/uuid-rs/uuid
- Serde: https://serde.rs/
- Tokio: https://tokio.rs/
- Bubblewrap: https://github.com/containers/bubblewrap
- Landlock: https://www.kernel.org/doc/html/latest/userspace-api/landlock.html

---

## 📞 English text

**Q: AllowedEnglish textmigrationEnglish text?**
A: English text.English textsystemEnglish text, English text.English text: English text → English text/English text → English text

**Q: Guardian English textmigrationEnglish text?**
A: English text.AllowedEnglish textimplementationEnglish text (English text), English text Guardian

**Q: Requiredsupport Windows English text?**
A: English text.Linux/macOS English text.Windows supportAllowedEnglish text

**Q: English text?**
A: English text serde English textconfigurationEnglish text.English text `config_types.rs` English text `#[serde(alias)]` example

**Q: migrationEnglish texttest?**
A: English textcompleteEnglish texttest, English texttestEnglish texttest.English text Codex English text `tests/` directory

---

**English text**: 2026-06-02
**English text**: `/Users/feifei/agent/codex`
**English text**: neurx Agent Framework
