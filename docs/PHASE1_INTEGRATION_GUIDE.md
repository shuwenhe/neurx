# Phase 1 English text

## English text

English text Phase 1 English text neurx-code:

1. **HookManager** - English textextensionEnglish text Hook system
2. **SecurityScanner** - safetyEnglish text
3. **GitWorkflowTool** - Git English texttool

## English text

```
┌─────────────────────────────────────────────────────────────────┐
│                        AgentController                          │
│                                                                 │
│  ┌────────────────┐  ┌──────────────────┐  ┌─────────────────┐│
│  │  HookManager   │  │ SecurityScanner  │  │ GitWorkflowTool ││
│  │                │  │                  │  │                 ││
│  │  9 Hook English text   │  │  20+ English text    │  │  AI generate commit ││
│  │  prompt/English text │  │  CWE English text        │  │  English text Push+PR   ││
│  └────────────────┘  └──────────────────┘  └─────────────────┘│
│                                                                 │
│  English textpipeline:                                                   │
│  SessionStart → PreToolUse → execute() → PostToolUse → Stop    │
└─────────────────────────────────────────────────────────────────┘
```

## 1. HookManager English text

### 1.1 English text AgentController English textinitialize

```cpp
// src/agent/AgentController.h
#include "agent/HookManager.h"

class AgentController : public QObject {
    Q_OBJECT

private:
    HookManager* m_hookManager;
    // ... English text
};

// src/agent/AgentController.cpp
AgentController::AgentController(QObject *parent)
    : QObject(parent)
{
    m_hookManager = new HookManager(this);

    // loaddefault hooks(English text)
    loadDefaultHooks();
}

void AgentController::loadDefaultHooks() {
    // example: English textsafetyEnglish text hook
    HookManager::HookConfig securityHook;
    securityHook.name = "security-check";
    securityHook.type = HookManager::HookType::PreToolUse;
    securityHook.mode = HookManager::HookMode::CommandBased;
    securityHook.command = "/path/to/security-check.sh";
    securityHook.enabled = true;

    m_hookManager->registerHook(securityHook);
}
```

### 1.2 English texttoolEnglish text Hook

```cpp
void AgentController::executeTool(const QString& toolName, const QJsonObject& args) {
    // 1. PreToolUse Hook
    if (!m_hookManager->shouldAllowToolUse(toolName, args)) {
        qWarning() << "Tool execution blocked by hook:" << toolName;
        emit toolExecutionBlocked(toolName);
        return;
    }

    // 2. English texttool
    ToolResult result = /* ... actualEnglish text ... */;

    // 3. PostToolUse Hook
    QJsonObject postContext;
    postContext["tool_name"] = toolName;
    postContext["result"] = /* convert ToolResult to JSON */;
    m_hookManager->executeHooks(HookManager::HookType::PostToolUse, postContext);
}
```

### 1.3 English text Hooks

```cpp
void AgentController::startSession() {
    // English text session start prompt
    QString startPrompt = m_hookManager->getSessionStartPrompt();
    if (!startPrompt.isEmpty()) {
        // English textsystemprompt
        m_systemPrompt += "\n\n" + startPrompt;
    }

    // ... English textstartEnglish text
}

void AgentController::stopSession() {
    // English text(English text)
    QJsonObject context;
    context["reason"] = "user_stop";

    if (m_hookManager->shouldContinueSession(context)) {
        qInfo() << "Session stop blocked by hook, continuing...";
        emit sessionContinued();
        return;
    }

    // ... actualEnglish text
}
```

## 2. SecurityScanner English text

### 2.1 English text AgentController English textinitialize

```cpp
// src/agent/AgentController.h
#include "security/SecurityScanner.h"

class AgentController : public QObject {
    Q_OBJECT

private:
    SecurityScanner* m_securityScanner;
    // ... English text
};

// src/agent/AgentController.cpp
AgentController::AgentController(QObject *parent)
    : QObject(parent)
{
    m_securityScanner = new SecurityScanner(this);

    // English text
    connect(m_securityScanner, &SecurityScanner::issueFound,
            this, &AgentController::onSecurityIssueFound);
}

void AgentController::onSecurityIssueFound(const SecurityScanner::SecurityIssue& issue) {
    qWarning() << "[Security]" << issue.message << "at"
               << issue.filePath << ":" << issue.lineNumber;

    // English text, English text
    if (issue.severity == SecurityScanner::Severity::Critical) {
        emit criticalSecurityIssue(issue);
    }
}
```

### 2.2 English textfileEnglish text

```cpp
void AgentController::onToolWriteFile(const QString& filePath, const QString& content) {
    // English textcontent
    QList<SecurityScanner::SecurityIssue> issues =
        m_securityScanner->scanContent(content, filePath);

    if (!issues.isEmpty()) {
        // English text
        QString warning = QString("⚠️  Security issues detected (%1):").arg(issues.size());
        for (const auto& issue : issues) {
            warning += QString("\n- Line %1: %2")
                           .arg(issue.lineNumber)
                           .arg(issue.message);
        }

        // English text
        emit securityWarning(warning);
    }

    // ... English textfile
}
```

### 2.3 English text HookManager English textuse

```cpp
void AgentController::loadDefaultHooks() {
    // English textsafetyEnglish text hook
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

## 3. GitWorkflowTool English text

### 3.1 English texttool

```cpp
// src/agent/AgentController.cpp
void AgentController::registerTools() {
    // ... English texttool

    // English text GitWorkflowTool
    auto gitTool = new GitWorkflowTool(this);
    AgentToolRegistry::instance().registerTool(gitTool);

    qInfo() << "Registered tool:" << gitTool->name();
}
```

### 3.2 useexample

```cpp
// English textrequest: "Generate a commit message"
QJsonObject args;
args["action"] = "generate_commit_message";

ToolResult result = m_gitTool->execute("call-1", args);
if (!result.isError) {
    qInfo() << "Generated commit message:" << result.content;
}

// English textrequest: "Commit and push"
args["action"] = "commit_push";
args["stage_all"] = true;
args["commit_message"] = "feat: Add HookManager";

result = m_gitTool->execute("call-2", args);
```

## 4. completeEnglish textexample

### English text: English textfileEnglish text

```cpp
void AgentController::handleUserCommit() {
    // 1. English textfile
    QList<SecurityScanner::SecurityIssue> issues;
    QStringList modifiedFiles = getModifiedFiles();

    for (const QString& file : modifiedFiles) {
        issues.append(m_securityScanner->scanFile(file));
    }

    // 2. English text, English text
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

    // 3. generate commit message
    QJsonObject args;
    args["action"] = "generate_commit_message";
    ToolResult msgResult = m_gitTool->execute("gen-msg", args);

    QString commitMessage = msgResult.content;

    // 4. English text commit hook
    QJsonObject hookContext;
    hookContext["commit_message"] = commitMessage;
    hookContext["modified_files"] = QJsonArray::fromStringList(modifiedFiles);

    QList<HookManager::HookResult> hookResults =
        m_hookManager->executeHooks(HookManager::HookType::PreToolUse, hookContext);

    // 5. English text hook English text, English text
    for (const auto& hookResult : hookResults) {
        if (hookResult.blockOperation) {
            emit commitBlocked(hookResult.systemMessage);
            return;
        }
    }

    // 6. English text
    args["action"] = "auto_commit";
    args["commit_message"] = commitMessage;
    ToolResult commitResult = m_gitTool->execute("commit", args);

    if (!commitResult.isError) {
        emit commitSuccess(commitResult.content);
    }
}
```

## 5. compileEnglish texttest

### 5.1 compile

```bash
cd /Users/feifei/agent/neurx-code
cmake -B build -G Ninja
cmake --build build
```

### 5.2 test HookManager

```cpp
// testEnglish text(AllowedEnglish text tests/ directory)
void testHookManager() {
    HookManager manager;

    // English text hook
    HookManager::HookConfig config;
    config.name = "test-hook";
    config.type = HookManager::HookType::PreToolUse;
    config.mode = HookManager::HookMode::CommandBased;
    config.command = "echo";
    config.args = {"{\"blockOperation\": false}"};

    manager.registerHook(config);

    // English text hook
    QJsonObject context;
    context["tool_name"] = "write_file";

    QList<HookManager::HookResult> results =
        manager.executeHooks(HookManager::HookType::PreToolUse, context);

    qInfo() << "Hook executed, results:" << results.size();
}
```

### 5.3 test SecurityScanner

```cpp
void testSecurityScanner() {
    SecurityScanner scanner;

    // testEnglish text
    QString dangerousCode = R"(
import yaml
data = yaml.load(user_input)  # English text!
password = "hardcoded123"     # English text!
eval(user_code)               # English text!
)";

    QList<SecurityScanner::SecurityIssue> issues =
        scanner.scanContent(dangerousCode, "test.py");

    qInfo() << "Found" << issues.size() << "security issues";
    for (const auto& issue : issues) {
        qInfo() << "-" << issue.pattern << ":" << issue.message;
    }
}
```

### 5.4 test GitWorkflowTool

```bash
# English texttruthful git English texttest
cd /Users/feifei/agent/neurx-code

# English text
echo "// Test" >> test.txt
git add test.txt

# usetoolgenerate commit message
# (RequiredEnglish text neurx-code English text)
```

## 6. English text

### 6.1 HookManager

- [ ] LLM English text(executePromptHook)
- [ ] Markdown + YAML frontmatter English text(loadHookFromFile)
- [ ] Hook configuration UI
- [ ] Hook English text/English text

### 6.2 SecurityScanner

- [ ] English textlanguagesupport(Rust, Go, Java)
- [ ] Layer 2: LLM diff English text
- [ ] Layer 3: Agent commit English text
- [ ] English text

### 6.3 GitWorkflowTool

- [ ] LLM English text(generateCommitMessage, generatePRContent)
- [ ] GitHub API English text(English text PR)
- [ ] GitLab / Gitea support
- [ ] English textsystem

## 7. English text

- **HookManager**: English text claude-code English text Hook systemEnglish text
  - file: `/Users/feifei/agent/claude-code/src/core/hooks.ts`

- **SecurityScanner**: English text claude-code English text security-guidance plugin
  - file: `/Users/feifei/agent/claude-code/plugins/security-guidance/`

- **GitWorkflowTool**: English text claude-code English text commit-commands plugin
  - file: `/Users/feifei/agent/claude-code/plugins/commit-commands/`

## 8. English textstep

1. **compileEnglish text**: English textfilecompileEnglish text
2. **English text AgentController**: English textexampleEnglish text
3. **English texttest**: English texttestEnglish text
4. **UI English text**: English text UI English text Hook management, safetyEnglish text
5. **LLM English text**: implementation prompt-based hook English text AI commit message generate
6. **English text**: English text API English text

---

**English texttime**: 2025-01-XX
**English text**: 1.0 (framework/English text)
**state**: English textcompile, English texttest
