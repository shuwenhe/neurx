# Phase 1 功能集成指南

## 概述

本文档介绍如何将 Phase 1 的三个核心功能集成到 neurx-code：

1. **HookManager** - 可扩展的 Hook 系统
2. **SecurityScanner** - 安全模式扫描器
3. **GitWorkflowTool** - Git 工作流自动化工具

## 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                        AgentController                          │
│                                                                 │
│  ┌────────────────┐  ┌──────────────────┐  ┌─────────────────┐│
│  │  HookManager   │  │ SecurityScanner  │  │ GitWorkflowTool ││
│  │                │  │                  │  │                 ││
│  │  9 Hook 类型   │  │  20+ 危险模式    │  │  AI 生成 commit ││
│  │  提示/命令模式 │  │  CWE 编号        │  │  一键 Push+PR   ││
│  └────────────────┘  └──────────────────┘  └─────────────────┘│
│                                                                 │
│  生命周期流程：                                                  │
│  SessionStart → PreToolUse → execute() → PostToolUse → Stop    │
└─────────────────────────────────────────────────────────────────┘
```

## 1. HookManager 集成

### 1.1 在 AgentController 中初始化

```cpp
// src/agent/AgentController.h
#include "agent/HookManager.h"

class AgentController : public QObject {
    Q_OBJECT
    
private:
    HookManager* m_hookManager;
    // ... 其他成员
};

// src/agent/AgentController.cpp
AgentController::AgentController(QObject *parent)
    : QObject(parent)
{
    m_hookManager = new HookManager(this);
    
    // 加载默认 hooks（可选）
    loadDefaultHooks();
}

void AgentController::loadDefaultHooks() {
    // 示例：注册安全检查 hook
    HookManager::HookConfig securityHook;
    securityHook.name = "security-check";
    securityHook.type = HookManager::HookType::PreToolUse;
    securityHook.mode = HookManager::HookMode::CommandBased;
    securityHook.command = "/path/to/security-check.sh";
    securityHook.enabled = true;
    
    m_hookManager->registerHook(securityHook);
}
```

### 1.2 在工具调用前执行 Hook

```cpp
void AgentController::executeTool(const QString& toolName, const QJsonObject& args) {
    // 1. PreToolUse Hook
    if (!m_hookManager->shouldAllowToolUse(toolName, args)) {
        qWarning() << "Tool execution blocked by hook:" << toolName;
        emit toolExecutionBlocked(toolName);
        return;
    }
    
    // 2. 执行工具
    ToolResult result = /* ... 实际执行 ... */;
    
    // 3. PostToolUse Hook
    QJsonObject postContext;
    postContext["tool_name"] = toolName;
    postContext["result"] = /* convert ToolResult to JSON */;
    m_hookManager->executeHooks(HookManager::HookType::PostToolUse, postContext);
}
```

### 1.3 会话生命周期 Hooks

```cpp
void AgentController::startSession() {
    // 注入 session start prompt
    QString startPrompt = m_hookManager->getSessionStartPrompt();
    if (!startPrompt.isEmpty()) {
        // 添加到系统提示
        m_systemPrompt += "\n\n" + startPrompt;
    }
    
    // ... 其他启动逻辑
}

void AgentController::stopSession() {
    // 检查是否应该继续（用于自动循环）
    QJsonObject context;
    context["reason"] = "user_stop";
    
    if (m_hookManager->shouldContinueSession(context)) {
        qInfo() << "Session stop blocked by hook, continuing...";
        emit sessionContinued();
        return;
    }
    
    // ... 实际停止逻辑
}
```

## 2. SecurityScanner 集成

### 2.1 在 AgentController 中初始化

```cpp
// src/agent/AgentController.h
#include "security/SecurityScanner.h"

class AgentController : public QObject {
    Q_OBJECT
    
private:
    SecurityScanner* m_securityScanner;
    // ... 其他成员
};

// src/agent/AgentController.cpp
AgentController::AgentController(QObject *parent)
    : QObject(parent)
{
    m_securityScanner = new SecurityScanner(this);
    
    // 连接信号
    connect(m_securityScanner, &SecurityScanner::issueFound,
            this, &AgentController::onSecurityIssueFound);
}

void AgentController::onSecurityIssueFound(const SecurityScanner::SecurityIssue& issue) {
    qWarning() << "[Security]" << issue.message << "at" 
               << issue.filePath << ":" << issue.lineNumber;
    
    // 如果是严重问题，警告用户
    if (issue.severity == SecurityScanner::Severity::Critical) {
        emit criticalSecurityIssue(issue);
    }
}
```

### 2.2 在文件写入前扫描

```cpp
void AgentController::onToolWriteFile(const QString& filePath, const QString& content) {
    // 扫描内容
    QList<SecurityScanner::SecurityIssue> issues = 
        m_securityScanner->scanContent(content, filePath);
    
    if (!issues.isEmpty()) {
        // 显示警告
        QString warning = QString("⚠️  Security issues detected (%1):").arg(issues.size());
        for (const auto& issue : issues) {
            warning += QString("\n- Line %1: %2")
                           .arg(issue.lineNumber)
                           .arg(issue.message);
        }
        
        // 询问用户是否继续
        emit securityWarning(warning);
    }
    
    // ... 继续写入文件
}
```

### 2.3 与 HookManager 结合使用

```cpp
void AgentController::loadDefaultHooks() {
    // 注册安全扫描 hook
    HookManager::HookConfig securityHook;
    securityHook.name = "security-scan";
    securityHook.type = HookManager::HookType::PreToolUse;
    securityHook.mode = HookManager::HookMode::PromptBased;
    securityHook.hookPrompt = R"(
Before executing the write_file tool, scan for security issues.
If critical issues are found, set blockOperation=true.
)";
    securityHook.requiresLLMDecision = true;
    
    m_hookManager->registerHook(securityHook);
}
```

## 3. GitWorkflowTool 集成

### 3.1 注册工具

```cpp
// src/agent/AgentController.cpp
void AgentController::registerTools() {
    // ... 注册其他工具
    
    // 注册 GitWorkflowTool
    auto gitTool = new GitWorkflowTool(this);
    AgentToolRegistry::instance().registerTool(gitTool);
    
    qInfo() << "Registered tool:" << gitTool->name();
}
```

### 3.2 使用示例

```cpp
// 用户请求："Generate a commit message"
QJsonObject args;
args["action"] = "generate_commit_message";

ToolResult result = m_gitTool->execute("call-1", args);
if (!result.isError) {
    qInfo() << "Generated commit message:" << result.content;
}

// 用户请求："Commit and push"
args["action"] = "commit_push";
args["stage_all"] = true;
args["commit_message"] = "feat: Add HookManager";

result = m_gitTool->execute("call-2", args);
```

## 4. 完整工作流示例

### 场景：用户修改文件并提交

```cpp
void AgentController::handleUserCommit() {
    // 1. 扫描文件
    QList<SecurityScanner::SecurityIssue> issues;
    QStringList modifiedFiles = getModifiedFiles();
    
    for (const QString& file : modifiedFiles) {
        issues.append(m_securityScanner->scanFile(file));
    }
    
    // 2. 如果有严重问题，阻止提交
    bool hasCritical = false;
    for (const auto& issue : issues) {
        if (issue.severity == SecurityScanner::Severity::Critical) {
            hasCritical = true;
            break;
        }
    }
    
    if (hasCritical) {
        emit commitBlocked("Critical security issues detected");
        return;
    }
    
    // 3. 生成 commit message
    QJsonObject args;
    args["action"] = "generate_commit_message";
    ToolResult msgResult = m_gitTool->execute("gen-msg", args);
    
    QString commitMessage = msgResult.content;
    
    // 4. 执行 commit hook
    QJsonObject hookContext;
    hookContext["commit_message"] = commitMessage;
    hookContext["modified_files"] = QJsonArray::fromStringList(modifiedFiles);
    
    QList<HookManager::HookResult> hookResults = 
        m_hookManager->executeHooks(HookManager::HookType::PreToolUse, hookContext);
    
    // 5. 如果 hook 阻止，停止
    for (const auto& hookResult : hookResults) {
        if (hookResult.blockOperation) {
            emit commitBlocked(hookResult.systemMessage);
            return;
        }
    }
    
    // 6. 执行提交
    args["action"] = "auto_commit";
    args["commit_message"] = commitMessage;
    ToolResult commitResult = m_gitTool->execute("commit", args);
    
    if (!commitResult.isError) {
        emit commitSuccess(commitResult.content);
    }
}
```

## 5. 编译和测试

### 5.1 编译

```bash
cd /Users/feifei/agent/neurx-code
cmake -B build -G Ninja
cmake --build build
```

### 5.2 测试 HookManager

```cpp
// 测试代码（可以加到 tests/ 目录）
void testHookManager() {
    HookManager manager;
    
    // 注册一个简单的 hook
    HookManager::HookConfig config;
    config.name = "test-hook";
    config.type = HookManager::HookType::PreToolUse;
    config.mode = HookManager::HookMode::CommandBased;
    config.command = "echo";
    config.args = {"{\"blockOperation\": false}"};
    
    manager.registerHook(config);
    
    // 执行 hook
    QJsonObject context;
    context["tool_name"] = "write_file";
    
    QList<HookManager::HookResult> results = 
        manager.executeHooks(HookManager::HookType::PreToolUse, context);
    
    qInfo() << "Hook executed, results:" << results.size();
}
```

### 5.3 测试 SecurityScanner

```cpp
void testSecurityScanner() {
    SecurityScanner scanner;
    
    // 测试危险代码
    QString dangerousCode = R"(
import yaml
data = yaml.load(user_input)  # 危险！
password = "hardcoded123"     # 危险！
eval(user_code)               # 危险！
)";
    
    QList<SecurityScanner::SecurityIssue> issues = 
        scanner.scanContent(dangerousCode, "test.py");
    
    qInfo() << "Found" << issues.size() << "security issues";
    for (const auto& issue : issues) {
        qInfo() << "-" << issue.pattern << ":" << issue.message;
    }
}
```

### 5.4 测试 GitWorkflowTool

```bash
# 在真实 git 仓库中测试
cd /Users/feifei/agent/neurx-code

# 创建一些改动
echo "// Test" >> test.txt
git add test.txt

# 使用工具生成 commit message
# （需要在 neurx-code 中调用）
```

## 6. 待完善功能

### 6.1 HookManager

- [ ] LLM 集成（executePromptHook）
- [ ] Markdown + YAML frontmatter 解析（loadHookFromFile）
- [ ] Hook 配置 UI
- [ ] Hook 市场/仓库

### 6.2 SecurityScanner

- [ ] 更多语言支持（Rust, Go, Java）
- [ ] Layer 2: LLM diff 审查
- [ ] Layer 3: Agent commit 审查
- [ ] 自定义规则编辑器

### 6.3 GitWorkflowTool

- [ ] LLM 集成（generateCommitMessage, generatePRContent）
- [ ] GitHub API 集成（创建 PR）
- [ ] GitLab / Gitea 支持
- [ ] 提交模板系统

## 7. 参考资料

- **HookManager**: 参考 claude-code 的 Hook 系统设计
  - 文件: `/Users/feifei/agent/claude-code/src/core/hooks.ts`
  
- **SecurityScanner**: 参考 claude-code 的 security-guidance 插件
  - 文件: `/Users/feifei/agent/claude-code/plugins/security-guidance/`
  
- **GitWorkflowTool**: 参考 claude-code 的 commit-commands 插件
  - 文件: `/Users/feifei/agent/claude-code/plugins/commit-commands/`

## 8. 下一步

1. **编译验证**: 确保所有文件编译通过
2. **集成到 AgentController**: 按照本文档的示例集成
3. **编写单元测试**: 为三个组件编写测试用例
4. **UI 集成**: 在 UI 中添加 Hook 管理、安全警告显示
5. **LLM 集成**: 实现 prompt-based hook 和 AI commit message 生成
6. **文档完善**: 编写用户文档和 API 文档

---

**创建时间**: 2025-01-XX  
**版本**: 1.0 (框架/原型)  
**状态**: 可编译，待集成和测试
