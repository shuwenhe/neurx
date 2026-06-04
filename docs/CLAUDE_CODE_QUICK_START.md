# NeurX Code - Claude Code 功能快速入门

本指南帮助你快速开始使用 NeurX Code 中新实现的 Claude Code 风格功能。

---

## 🚀 快速开始

### 1. 命令系统 (Command System)

#### 基本使用

在聊天界面中使用斜杠命令：

```
/help                          # 显示所有可用命令
/commit                        # 创建 git 提交
/commit -m "feat: add feature" # 带消息的提交
/code-review                   # 启动代码审查
/feature-dev Add user auth     # 启动特性开发工作流
```

#### 注册自定义命令

```cpp
#include "plugins/DefaultCommandSystem.h"

// 创建命令系统
auto cmdSystem = new DefaultCommandSystem(this);

// 定义命令
CommandDefinition def;
def.name = "hello";
def.description = "Say hello";
def.scope = CommandScope::Global;

// 添加参数
CommandParameter param;
param.name = "name";
param.description = "Your name";
param.required = true;
def.parameters.append(param);

// 注册命令
cmdSystem->registerCommand(def, [](const CommandContext& ctx) {
    QString name = ctx.args["name"].toString();
    CommandResult result(true);
    result.message = QString("Hello, %1!").arg(name);
    return result;
});

// 执行命令
CommandContext ctx;
ctx.workspacePath = "/path/to/workspace";
auto result = cmdSystem->executeCommand("/hello --name World", ctx);
qDebug() << result.message; // "Hello, World!"
```

---

### 2. Hook 系统 (Hook System)

#### 监听事件

```cpp
#include "plugins/DefaultHookSystem.h"

// 创建 Hook 系统
auto hookSystem = new DefaultHookSystem(this);

// 定义 Hook
HookDefinition def;
def.id = "auto-save";
def.name = "Auto Save Hook";
def.type = HookType::FileModified;
def.priority = HookPriority::Normal;

// 只监听 .cpp 和 .h 文件
def.filePatterns = QStringList{"*.cpp", "*.h"};

// 注册 Hook
hookSystem->registerHook(def, [](HookEvent& event) {
    QString filePath = event.data["filePath"].toString();
    qDebug() << "File modified:" << filePath;
    
    // 自动保存逻辑
    // ...
    
    return HookResult(true);
});
```

#### 阻止危险操作

```cpp
// 安全检查 Hook
HookDefinition securityDef;
securityDef.id = "security-check";
securityDef.type = HookType::PreToolUse;
securityDef.priority = HookPriority::Critical;
securityDef.cancellable = true;

hookSystem->registerHook(securityDef, [](HookEvent& event) {
    QString toolName = event.data["tool"].toString();
    QString command = event.data["command"].toString();
    
    // 检查危险命令
    if (command.contains("rm -rf /") || command.contains("format c:")) {
        HookResult result(false);
        result.preventDefault = true;
        result.error = "Dangerous command blocked!";
        return result;
    }
    
    return HookResult(true);
});
```

---

### 3. Git 工作流 (Git Workflow)

#### 智能提交

```cpp
#include "plugins/DefaultGitWorkflow.h"

// 创建 Git 工作流
auto git = new DefaultGitWorkflow(this);
git->setLLMProvider(llmProvider); // 设置 LLM 提供者

QString repoPath = "/path/to/repo";

// 生成智能提交消息
git->generateCommitMessage(repoPath, [](const QString& message) {
    qDebug() << "AI 生成的提交消息:" << message;
    // 例如: "feat: add user authentication with JWT tokens"
});

// 暂存并提交
git->stageFiles(repoPath, QStringList{}, [git, repoPath](bool success, const QString&) {
    if (success) {
        CommitOptions options;
        options.message = "feat: add new feature";
        options.addAll = true;
        
        git->commit(repoPath, options, [](bool success, const QString& hash) {
            qDebug() << "Commit hash:" << hash;
        });
    }
});
```

#### 创建 Pull Request

```cpp
// 推送并创建 PR
PushOptions pushOpts;
pushOpts.remote = "origin";
pushOpts.branch = "feature/new-feature";
pushOpts.setUpstream = true;

git->push(repoPath, pushOpts, [git, repoPath](bool success, const QString&) {
    if (success) {
        PROptions prOpts;
        prOpts.title = "Add new feature";
        prOpts.description = "This PR adds a new feature that...";
        prOpts.targetBranch = "main";
        prOpts.labels = QStringList{"enhancement", "feature"};
        prOpts.reviewers = QStringList{"reviewer1", "reviewer2"};
        
        git->createPullRequest(repoPath, prOpts, 
            [](bool success, const PullRequest& pr) {
                if (success) {
                    qDebug() << "PR 创建成功:" << pr.url;
                    qDebug() << "PR #" << pr.id;
                }
            });
    }
});
```

#### 一键式工作流

```cpp
// /commit-push-pr 命令的实现
void oneClickWorkflow(const QString& message) {
    auto git = new DefaultGitWorkflow(this);
    QString repo = workspacePath();
    
    // 1. 暂存所有更改
    git->stageFiles(repo, {}, [=](bool ok, const QString&) {
        if (!ok) return;
        
        // 2. 提交
        CommitOptions opts;
        opts.message = message;
        opts.addAll = true;
        
        git->commit(repo, opts, [=](bool ok, const QString& hash) {
            if (!ok) return;
            
            // 3. 推送
            PushOptions pushOpts;
            pushOpts.setUpstream = true;
            
            git->push(repo, pushOpts, [=](bool ok, const QString&) {
                if (!ok) return;
                
                // 4. 创建 PR
                PROptions prOpts;
                prOpts.title = message;
                prOpts.targetBranch = "main";
                
                git->createPullRequest(repo, prOpts, 
                    [](bool ok, const PullRequest& pr) {
                        qDebug() << "完成! PR:" << pr.url;
                    });
            });
        });
    });
}
```

---

### 4. 专用 Agent (Specialized Agents)

#### 代码探索

```cpp
#include "agent/SpecializedAgents.h"

// 创建 Agent
auto explorer = new CodeExplorerAgent(this);
explorer->setLLMProvider(llmProvider);
explorer->setToolRegistry(toolRegistry);

// 探索功能实现
explorer->exploreFeature(
    "user authentication",
    "/path/to/workspace",
    [](const CodeExplorerAgent::ExplorationResult& result) {
        qDebug() << "相关文件:" << result.relevantFiles;
        qDebug() << "关键符号:" << result.keySymbols;
        qDebug() << "摘要:" << result.summary;
        
        // 输出示例:
        // 相关文件: ["src/auth/AuthService.cpp", "src/auth/User.h"]
        // 关键符号: ["AuthService::login()", "User::authenticate()"]
        // 摘要: "Authentication is implemented using JWT tokens..."
    }
);
```

#### 架构设计

```cpp
auto architect = new CodeArchitectAgent(this);
architect->setLLMProvider(llmProvider);

// 设计新功能
QVariantMap requirements;
requirements["features"] = QStringList{"login", "logout", "session"};
requirements["security"] = "JWT tokens";

architect->designFeature(
    "user authentication system",
    requirements,
    "/path/to/workspace",
    [](const CodeArchitectAgent::ArchitectureDesign& design) {
        qDebug() << "设计概述:" << design.overview;
        qDebug() << "组件:" << design.components;
        qDebug() << "需要创建的文件:" << design.files;
        qDebug() << "实现计划:" << design.implementation;
    }
);
```

#### 代码审查

```cpp
auto reviewer = new CodeReviewerAgent(this);
reviewer->setLLMProvider(llmProvider);

// 审查代码
QStringList files = {
    "src/auth/AuthService.cpp",
    "src/auth/User.h"
};

reviewer->reviewCode(files, "authentication feature", 
    [](const CodeReviewerAgent::ReviewResult& result) {
        qDebug() << "审查摘要:" << result.summary;
        qDebug() << "质量评分:" << result.qualityScore << "/100";
        
        // 显示问题
        for (const auto& issue : result.issues) {
            qDebug() << "问题:" << issue["description"];
            qDebug() << "文件:" << issue["file"];
            qDebug() << "行:" << issue["line"];
        }
        
        // 显示建议
        for (const auto& suggestion : result.suggestions) {
            qDebug() << "建议:" << suggestion["description"];
        }
    });
```

#### Agent 编排 - 完整工作流

```cpp
// 创建编排器
auto orchestrator = new AgentOrchestrator(this);
orchestrator->setLLMProvider(llmProvider);
orchestrator->setToolRegistry(toolRegistry);

// 注册所有 Agents
orchestrator->registerAgent(std::make_shared<CodeExplorerAgent>());
orchestrator->registerAgent(std::make_shared<CodeArchitectAgent>());
orchestrator->registerAgent(std::make_shared<CodeReviewerAgent>());
orchestrator->registerAgent(std::make_shared<TestAnalyzerAgent>());

// 特性开发工作流
void featureDevelopmentWorkflow(const QString& feature) {
    // 步骤 1: 探索现有代码
    AgentTask exploreTask;
    exploreTask.agentId = "code-explorer";
    exploreTask.query = QString("Find code related to: %1").arg(feature);
    
    // 步骤 2: 设计架构
    AgentTask architectTask;
    architectTask.agentId = "code-architect";
    architectTask.query = QString("Design architecture for: %1").arg(feature);
    
    // 步骤 3: 审查设计
    AgentTask reviewTask;
    reviewTask.agentId = "code-reviewer";
    reviewTask.query = "Review the proposed design";
    
    // 顺序执行
    QList<AgentTask> tasks = {exploreTask, architectTask, reviewTask};
    orchestrator->executeSequential(tasks, 
        [](const QList<AgentResult>& results) {
            for (const auto& result : results) {
                qDebug() << result.agentId << "完成";
                qDebug() << "结果:" << result.result;
            }
        });
}
```

---

## 🔧 集成到现有代码

### 在 QML 中使用

```qml
// CommandPalette.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: commandInput
    placeholderText: "输入命令 (例如: /commit)"
    
    onAccepted: {
        if (text.startsWith("/")) {
            // 调用 C++ 命令系统
            agentController.executeCommand(text)
            text = ""
        }
    }
    
    // 自动补全
    Keys.onPressed: {
        if (event.key === Qt.Key_Tab) {
            var commands = agentController.getMatchingCommands(text)
            // 显示自动补全
        }
    }
}
```

### 在 AgentController 中集成

```cpp
// AgentController.h
class AgentController : public QObject {
    Q_OBJECT
    
public:
    Q_INVOKABLE void executeCommand(const QString& input);
    Q_INVOKABLE QStringList getMatchingCommands(const QString& prefix);
    
private:
    DefaultCommandSystem* m_commandSystem;
    DefaultHookSystem* m_hookSystem;
    DefaultGitWorkflow* m_gitWorkflow;
    AgentOrchestrator* m_agentOrchestrator;
};

// AgentController.cpp
void AgentController::executeCommand(const QString& input) {
    CommandContext ctx;
    ctx.workspacePath = m_workspacePath;
    ctx.sessionId = m_sessionId;
    
    auto result = m_commandSystem->executeCommand(input, ctx);
    
    if (result.success) {
        emit commandExecuted(result.message);
    } else {
        emit commandFailed(result.error);
    }
}
```

---

## 📚 更多示例

### 创建自定义插件

创建 `~/.neurx/plugins/my-plugin/.neurx-plugin/plugin.json`:

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "My custom plugin",
  "commands": [
    {
      "name": "hello",
      "description": "Say hello",
      "scope": "global"
    }
  ],
  "hooks": [
    {
      "id": "auto-format",
      "type": "file-saved",
      "filePatterns": ["*.cpp", "*.h"]
    }
  ]
}
```

### 使用内置命令

```bash
# 在 NeurX Code 聊天界面中
/help                    # 查看所有命令
/commit                  # 智能提交
/commit-push-pr          # 提交、推送并创建 PR
/code-review             # 启动代码审查
/feature-dev login       # 开发登录功能
```

---

## 🎯 最佳实践

### 1. 命令系统
- ✅ 使用清晰的命令名称
- ✅ 提供详细的参数描述
- ✅ 添加使用示例
- ✅ 实现参数验证
- ✅ 检查前置条件

### 2. Hook 系统
- ✅ 使用合适的优先级
- ✅ 添加文件模式过滤
- ✅ 处理异步操作
- ✅ 提供清晰的错误信息
- ✅ 记录 Hook 执行统计

### 3. Git 工作流
- ✅ 使用 AI 生成的提交消息
- ✅ 在操作前检查状态
- ✅ 提供详细的错误处理
- ✅ 支持取消长时间操作
- ✅ 记录操作历史

### 4. 专用 Agent
- ✅ 为每个任务选择合适的 Agent
- ✅ 提供足够的上下文信息
- ✅ 设置合理的超时时间
- ✅ 处理并行执行的结果
- ✅ 缓存 Agent 结果

---

## 🐛 常见问题

### Q: 命令无法执行？
A: 检查：
1. 命令是否已注册
2. 作用域是否匹配
3. 前置条件是否满足
4. 参数是否正确

### Q: Hook 没有触发？
A: 检查：
1. Hook 是否已注册和启用
2. 事件类型是否匹配
3. 文件模式是否匹配
4. 优先级设置

### Q: Git 操作失败？
A: 检查：
1. 是否在 Git 仓库中
2. Git 是否已安装
3. 是否有未解决的冲突
4. 远程仓库配置

### Q: Agent 执行缓慢？
A: 优化：
1. 减少上下文大小
2. 使用更快的模型
3. 启用缓存
4. 并行执行任务

---

## 📖 相关文档

- [完整实现文档](CLAUDE_CODE_FEATURES_IMPLEMENTATION.md)
- [命令系统 API](../src/plugins/CommandSystem.h)
- [Hook 系统 API](../src/plugins/HookSystem.h)
- [Git 工作流 API](../src/plugins/GitWorkflow.h)
- [专用 Agent API](../src/agent/SpecializedAgents.h)

---

## 🤝 贡献

欢迎贡献新的命令、Hook 和 Agent！

1. Fork 项目
2. 创建功能分支
3. 实现并测试
4. 提交 PR

---

**Happy Coding with NeurX!** 🚀
