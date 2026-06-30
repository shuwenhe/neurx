# TIER 3 - neurx用户体验和可靠性增强

## 🎯 目标

实现Claude Code的P0优先级功能，重点：
- ✅ 用户可信度 (任务持久化、规划可视化)
- ✅ 安全执行 (细粒度权限)
- ✅ 生产就绪

**核心承诺**：用户能看到代理在干什么，并相信他们的工作不会丢失。

---

## 📋 P0功能实现清单

### 1. 任务持久化和恢复 (TaskPersistence)

**文件**：
- `src/persistence/TaskSession.h/cpp` (250行) - 会话定义
- `src/persistence/TaskPersistence.h/cpp` (300行) - 持久化引擎
- `src/persistence/CheckpointStore.h/cpp` (200行) - 检查点存储

**功能**：
- 将执行状态保存到磁盘 (JSON格式)
- 恢复中断的会话
- 保存规划历史和工具结果
- 自动检查点保存

**预期成果**：
```cpp
// 保存会话
taskPersistence.saveSession(taskId, session);

// 恢复会话
auto session = taskPersistence.loadSession(taskId);

// 检查点
auto checkpoint = session.getLatestCheckpoint();
auto plan = checkpoint.getPlan();
```

---

### 2. 规划可视化数据结构 (PlanPanel)

**文件**：
- `src/planning/PlanStep.h` (150行) - 步骤定义
- `src/planning/ExecutionPlan.h` (200行) - 执行计划
- `src/planning/PlanHistory.h` (150行) - 规划历史

**功能**：
- 定义步骤状态转换 (pending→in_progress→completed/blocked/failed)
- 记录每个步骤的决策
- 追踪步骤间的依赖关系
- 保存规划历史树

**数据结构**：
```cpp
enum class StepStatus {
    Pending,        // 等待执行
    InProgress,     // 执行中
    Completed,      // 完成
    Blocked,        // 被阻塞
    Failed,         // 失败
    Cancelled       // 取消
};

struct PlanStep {
    QString stepId;
    QString action;           // 要执行的操作描述
    StepStatus status;
    QVariantMap input;        // 输入参数
    QVariantMap output;       // 执行结果
    QString blockedReason;    // 被阻塞的原因
    QDateTime createdAt;
    int durationMs;           // 执行耗时
};

struct ExecutionPlan {
    QString planId;
    QVector<PlanStep> steps;
    int currentStepIndex;
    QString goal;
};
```

**预期成果**：
```cpp
// 更新步骤状态
plan.updateStepStatus(stepId, StepStatus::InProgress);

// 记录结果
plan.recordStepOutput(stepId, result);

// 查询规划
auto currentStep = plan.getCurrentStep();
auto history = plan.getPlanHistory();
```

---

### 3. 细粒度权限配置 (PermissionProfile)

**文件**：
- `src/permissions/PermissionProfile.h` (200行) - 权限配置文件
- `src/permissions/OperationApprovalRule.h` (150行) - 操作批准规则
- `src/permissions/ApprovalConfig.h/cpp` (250行) - 审批配置

**功能**：
- 按操作类型的权限 (FileWrite/CommandExec/NetworkAccess/etc)
- 按风险级别的自动批准 (Low/Medium/High)
- 权限配置文件 (.claude-approval.json)
- "信任此操作"的永久豁免

**配置文件示例** (.claude-approval.json):
```json
{
  "approvalRules": {
    "fileWrite": {
      "riskLevel": "HIGH",
      "requiresApproval": true,
      "whitelist": ["src/", "docs/"],
      "blacklist": ["package.json", ".env"]
    },
    "commandExecution": {
      "riskLevel": "HIGH",
      "requiresApproval": true,
      "allowedCommands": ["npm", "cargo", "cmake"],
      "forbiddenCommands": ["rm -rf", "shutdown"]
    },
    "networkAccess": {
      "riskLevel": "MEDIUM",
      "requiresApproval": false,
      "trustedDomains": ["github.com", "npmjs.org"]
    }
  },
  "autoApproveThreshold": "LOW"
}
```

**数据结构**：
```cpp
enum class OperationType {
    FileWrite,
    FileDelete,
    CommandExecution,
    NetworkAccess,
    ShellCommand,
    EnvironmentModification
};

enum class RiskLevel { Low, Medium, High };

struct OperationApprovalRule {
    OperationType type;
    RiskLevel riskLevel;
    bool requiresApproval;
    QStringList whitelist;    // 允许列表
    QStringList blacklist;    // 禁止列表
    int autoApproveCooldown;  // 自动批准冷却时间 (秒)
};

struct PermissionProfile {
    QString name;
    QMap<OperationType, OperationApprovalRule> rules;
    RiskLevel autoApproveThreshold;
    QSet<QString> trustedOperations;  // 一次性信任
};
```

**预期成果**：
```cpp
// 加载配置
auto profile = PermissionProfile::loadFromFile(".claude-approval.json");

// 检查是否需要批准
bool needsApproval = profile.requiresApproval(OperationType::FileWrite, "src/main.cpp");

// 信任操作
profile.trustOperation("FileWrite:src/main.cpp", 3600);  // 信任1小时

// 保存配置
profile.saveToFile(".claude-approval.json");
```

---

## 📊 工作量统计

| 模块 | 文件 | 行数 | 工作 |
|------|------|------|------|
| TaskPersistence | 3 | 750 | 0.5天 |
| PlanPanel | 3 | 500 | 0.5天 |
| PermissionProfile | 3 | 600 | 0.5天 |
| 集成 & 测试 | 2 | 300 | 0.5天 |
| **总计** | **11** | **2150** | **2天** |

---

## 🏗️ 架构集成

```
┌─────────────────────────────────────┐
│       AgentEngine                   │
├─────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐ │
│  │ PlanPanel    │  │ TaskSession  │ │
│  │ (可视化)     │  │ (执行状态)   │ │
│  └──────────────┘  └──────────────┘ │
│          ↓                ↓          │
│  ┌─────────────────────────────────┐│
│  │ TaskPersistence (持久化引擎)   ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│ Executor ← PermissionProfile (权限)│
├─────────────────────────────────────┤
│  ToolBridge (TIER 2 - 已有)        │
└─────────────────────────────────────┘
```

---

## ✨ 核心特性

✅ **任务恢复**：中断后自动恢复
✅ **规划可视化**：清晰的执行流程
✅ **细粒度权限**：安全且灵活
✅ **配置文件**：团队共享规则
✅ **性能优化**：高效的持久化

---

## 📈 预期成果

完成后：
1. ✅ 用户能看到代理在执行哪一步
2. ✅ 用户对规划历史有完整记录
3. ✅ 会话中断后能继续
4. ✅ 权限和批准更灵活
5. ✅ 可以通过配置文件共享规则

**用户体验升级**：从"黑箱"变成"透明可控"

---

## 🚀 实现顺序

1. **Day 1 上午**：TaskPersistence 完成
2. **Day 1 下午**：PlanPanel 完成
3. **Day 2 上午**：PermissionProfile 完成
4. **Day 2 下午**：集成测试和优化
