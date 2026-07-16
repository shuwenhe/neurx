# Codex 迁移集成指南

## AgentController 集成

### 1. 头文件引入

在 `AgentController.h` 中添加：

```cpp
#include "src/thread/ThreadId.h"
#include "src/thread/store/ThreadStore.h"
#include "src/thread/store/FileBasedThreadStore.h"
#include "src/approvals/ApprovalManager.h"
#include "src/approvals/DefaultApprovalManager.h"
#include "src/sandbox/SandboxManager.h"
#include "src/sandbox/DefaultSandboxManager.h"
```

### 2. 成员变量

在 `AgentController` 私有成员中添加：

```cpp
private:
    // 线程管理
    FileBasedThreadStorePtr m_threadStore;
    ThreadId m_currentThreadId;
    QMap<ThreadId, QVariantMap> m_activeThreads;
    
    // 审批管理
    ApprovalManagerPtr m_approvalManager;
    
    // 沙箱管理
    SandboxManagerPtr m_sandboxManager;
    
    // 初始化方法
    void initializeThreadSystem();
    void initializeApprovalSystem();
    void initializeSandboxSystem();
```

### 3. 初始化代码

在 `AgentController::AgentController()` 中添加：

```cpp
AgentController::AgentController(QObject *parent)
    : QObject(parent)
{
    // 初始化线程系统
    initializeThreadSystem();
    
    // 初始化审批系统
    initializeApprovalSystem();
    
    // 初始化沙箱系统
    initializeSandboxSystem();
}

void AgentController::initializeThreadSystem()
{
    QString storePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/threads";
    
    m_threadStore = std::make_shared<FileBasedThreadStore>(storePath);
    if (!m_threadStore->initialize()) {
        qWarning() << "Failed to initialize thread store at" << storePath;
    }
    
    // 连接信号
    connect(m_threadStore.get(), &ThreadStore::threadModified, this, &AgentController::onThreadModified);
    connect(m_threadStore.get(), &ThreadStore::threadDeleted, this, &AgentController::onThreadDeleted);
}

void AgentController::initializeApprovalSystem()
{
    m_approvalManager = std::make_shared<DefaultApprovalManager>();
    
    // 设置默认策略
    ApprovalPolicy policy;
    policy.defaultPolicy = AskForApproval::OnRequest;
    policy.defaultReviewer = ApprovalsReviewer::User;
    m_approvalManager->setDefaultPolicy(policy);
    
    // 添加常见工具的细粒度规则
    GranularApprovalConfig gitRule;
    gitRule.toolName = "git";
    gitRule.resourcePattern = ".*";
    gitRule.policy = AskForApproval::OnRequest;
    m_approvalManager->addGranularRule(gitRule);
    
    // 连接信号
    connect(m_approvalManager.get(), &ApprovalManager::approvalRequested, 
            this, &AgentController::onApprovalRequested);
    connect(m_approvalManager.get(), &ApprovalManager::approvalDecided,
            this, &AgentController::onApprovalDecided);
}

void AgentController::initializeSandboxSystem()
{
    m_sandboxManager = std::make_shared<DefaultSandboxManager>();
    
    // 设置默认沙箱模式
    m_sandboxManager->setDefaultSandboxMode(SandboxMode::WorkspaceWrite);
    
    // 配置允许的路径
    QString workspacePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_sandboxManager->addAllowedWritePath(workspacePath);
    m_sandboxManager->addAllowedReadPath("/tmp");
    
    // 连接信号
    connect(m_sandboxManager.get(), &SandboxManager::accessDenied,
            this, &AgentController::onSandboxAccessDenied);
}
```

### 4. 槽函数实现

添加槽函数处理各系统的事件：

```cpp
// 线程系统槽函数
void AgentController::onThreadModified(const ThreadId &threadId)
{
    emit threadStateChanged(threadId.toString());
}

void AgentController::onThreadDeleted(const ThreadId &threadId)
{
    if (m_currentThreadId == threadId) {
        m_currentThreadId = ThreadId();
    }
    emit threadDeleted(threadId.toString());
}

// 审批系统槽函数
void AgentController::onApprovalRequested(const QString &approvalId, const QVariantMap &details)
{
    qInfo() << "Approval requested:" << approvalId;
    // 这里可以发送信号给 QML 显示审批对话框
    emit approvalRequired(approvalId, details);
}

void AgentController::onApprovalDecided(const QString &approvalId, bool approved)
{
    qInfo() << "Approval decided:" << approvalId << "=" << approved;
}

// 沙箱系统槽函数
void AgentController::onSandboxAccessDenied(const QString &path, int mode, const QString &reason)
{
    qWarning() << "Sandbox access denied:" << path << reason;
    emit sandboxAccessDenied(path, reason);
}
```

### 5. 公共 API 方法

添加用于 QML 调用的方法：

```cpp
public:
    // 线程相关
    Q_INVOKABLE void createNewThread();
    Q_INVOKABLE void resumeThread(const QString &threadId);
    Q_INVOKABLE void forkThread(const QString &threadId);
    Q_INVOKABLE void saveThreadCheckpoint(const QString &label);
    Q_INVOKABLE void loadThreadCheckpoint(const QString &checkpointId);
    
    // 审批相关
    Q_INVOKABLE void approveAction(const QString &approvalId);
    Q_INVOKABLE void rejectAction(const QString &approvalId);
    Q_INVOKABLE QVariantMap getApprovalStats();
    
    // 沙箱相关
    Q_INVOKABLE bool canAccessPath(const QString &path, int mode);
    Q_INVOKABLE QVariantMap getSandboxStats();

private:
    void createNewThread_impl();
    void resumeThread_impl(const ThreadId &threadId);
    void forkThread_impl(const ThreadId &threadId);
    void saveThreadCheckpoint_impl(const QString &label);
    void loadThreadCheckpoint_impl(const QString &checkpointId);
    
    void approveAction_impl(const QString &approvalId);
    void rejectAction_impl(const QString &approvalId);
    
    bool canAccessPath_impl(const QString &path, FileSystemAccessMode mode);
```

### 6. 实现示例

```cpp
void AgentController::createNewThread()
{
    CreateThreadParams params;
    params.mode = ThreadInitializationMode::Fresh;
    params.metadata["createdBy"] = "user";
    
    m_threadStore->createThread(params, [this](ThreadStoreError err, ThreadId id) {
        if (err == ThreadStoreError::Success) {
            m_currentThreadId = id;
            emit threadCreated(id.toString());
        } else {
            emit error("Failed to create thread");
        }
    });
}

void AgentController::approveAction(const QString &approvalId)
{
    m_approvalManager->recordDecision(approvalId, ApprovalDecision::Accept, "User approved");
}

void AgentController::saveThreadCheckpoint(const QString &label)
{
    QVariantMap state = m_activeThreads[m_currentThreadId];
    m_threadStore->saveCheckpoint(m_currentThreadId, state, label, 
        [this](ThreadStoreError err) {
            if (err == ThreadStoreError::Success) {
                emit checkpointSaved(label);
            }
        });
}
```

### 7. 信号定义

在 `AgentController` 中添加信号：

```cpp
signals:
    // 线程信号
    void threadCreated(const QString &threadId);
    void threadStateChanged(const QString &threadId);
    void threadDeleted(const QString &threadId);
    void checkpointSaved(const QString &label);
    void checkpointLoaded(const QString &checkpointId);
    
    // 审批信号
    void approvalRequired(const QString &approvalId, const QVariantMap &details);
    void approvalProcessed(const QString &approvalId, bool approved);
    
    // 沙箱信号
    void sandboxAccessDenied(const QString &path, const QString &reason);
    void sandboxError(const QString &error);
```

### 8. CMakeLists.txt 更新

确保在 `CMakeLists.txt` 中包含新文件：

```cmake
set(SOURCES
    # ... 现有源文件 ...
    
    # 线程系统
    src/thread/ThreadId.cpp
    src/thread/store/InMemoryThreadStore.cpp
    src/thread/store/FileBasedThreadStore.cpp
    
    # 审批系统
    src/approvals/DefaultApprovalManager.cpp
    
    # 沙箱系统
    src/sandbox/DefaultSandboxManager.cpp
)

set(HEADERS
    # ... 现有头文件 ...
    
    # 线程系统
    src/thread/ThreadId.h
    src/thread/ThreadTypes.h
    src/thread/store/ThreadStore.h
    src/thread/store/InMemoryThreadStore.h
    src/thread/store/FileBasedThreadStore.h
    
    # 审批系统
    src/approvals/ApprovalTypes.h
    src/approvals/ApprovalManager.h
    src/approvals/DefaultApprovalManager.h
    
    # 沙箱系统
    src/sandbox/SandboxTypes.h
    src/sandbox/SandboxManager.h
    src/sandbox/DefaultSandboxManager.h
)
```

## QML 集成示例

### 新建线程对话框

```qml
// ThreadDialog.qml
import QtQuick
import QtQuick.Controls
import org.neurx.agent 1.0

Dialog {
    id: threadDialog
    title: "New Thread"
    
    Column {
        spacing: 10
        
        TextField {
            id: threadNameField
            placeholderText: "Thread name..."
        }
        
        Button {
            text: "Create"
            onClicked: {
                AgentController.createNewThread()
                threadDialog.close()
            }
        }
    }
}
```

### 审批对话框

```qml
// ApprovalDialog.qml
import QtQuick
import QtQuick.Controls
import org.neurx.agent 1.0

Dialog {
    id: approvalDialog
    title: "Approval Required"
    
    property string approvalId
    property var details
    
    Column {
        spacing: 10
        
        Text {
            text: "Tool: " + details.toolName
        }
        
        Text {
            text: "Action: " + details.command
        }
        
        Row {
            spacing: 10
            
            Button {
                text: "Approve"
                onClicked: {
                    AgentController.approveAction(approvalDialog.approvalId)
                    approvalDialog.close()
                }
            }
            
            Button {
                text: "Reject"
                onClicked: {
                    AgentController.rejectAction(approvalDialog.approvalId)
                    approvalDialog.close()
                }
            }
        }
    }
}
```

## 测试计划

### 单元测试

```cpp
// tests/TestThreadSystem.cpp
void TestThreadSystem::testCreateThread()
{
    FileBasedThreadStore store(m_tempDir);
    QVERIFY(store.initialize());
    
    CreateThreadParams params;
    params.mode = ThreadInitializationMode::Fresh;
    
    ThreadId createdId;
    ThreadStoreError error = ThreadStoreError::StorageError;
    
    store.createThread(params, [&](auto err, auto id) {
        error = err;
        createdId = id;
    });
    
    QCOMPARE(error, ThreadStoreError::Success);
    QVERIFY(!createdId.isNull());
}
```

## 性能优化建议

1. **缓存**: 使用 LRU 缓存存储最近访问的线程
2. **批处理**: 组合多个检查点操作
3. **异步 I/O**: 使用 QThreadPool 进行文件操作
4. **索引**: 为线程元数据创建 SQLite 索引

## 故障排查

### 常见问题

1. **线程存储初始化失败**
   - 检查数据目录权限
   - 确保有足够的磁盘空间

2. **沙箱执行失败**
   - 检查 bwrap 是否已安装
   - 验证允许的路径配置

3. **审批超时**
   - 增加超时时间
   - 检查 Guardian 服务连接

---
**版本**: 1.0
**最后更新**: 2025-06-02
