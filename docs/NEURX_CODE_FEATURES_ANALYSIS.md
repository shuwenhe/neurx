# NeurX Code 功能分析与实现建议

## 📊 概述

NeurX Code 是一个终端 AI 编程助手，拥有成熟的插件生态系统和强大的自动化能力。本文档分析其核心功能，并提供 NeurX 的实现建议。

---

## 🏗️ 核心架构

### 1. 插件系统（Plugin System）

**标准化目录结构：**
```
plugin-name/
├── .neurx-plugin/
│   └── plugin.json          # 插件元数据
├── commands/                # Slash commands（可选）
│   └── command.md
├── agents/                  # 专业化 agents（可选）
│   └── agent.md
├── skills/                  # Agent Skills（可选）
│   └── skill.md
├── hooks/                   # 事件处理器（可选）
│   ├── hooks.json
│   └── pretooluse.py
├── .mcp.json                # MCP 服务器配置（可选）
└── README.md
```

**关键特性：**
- ✅ 自动发现和加载
- ✅ 环境变量支持（`${NEURX_PLUGIN_ROOT}`）
- ✅ 分层配置（用户级、项目级、本地级）
- ✅ 热加载/卸载

### 2. Hooks 系统（事件驱动架构）

**支持的 Hook 类型：**

| Hook 类型 | 触发时机 | 用途 |
|----------|---------|------|
| `PreToolUse` | 工具调用前 | 验证、警告、阻止危险操作 |
| `PostToolUse` | 工具调用后 | 记录、分析、后处理 |
| `SessionStart` | 会话开始 | 注入初始上下文、设置模式 |
| `SessionEnd` | 会话结束 | 清理、保存状态 |
| `Stop` | 退出前 | 拦截退出（自动循环） |
| `SubagentStop` | 子 agent 停止 | 结果收集 |
| `UserPromptSubmit` | 用户提交前 | 预处理、注入上下文 |
| `PreCompact` | 上下文压缩前 | 保存关键信息 |
| `Notification` | 通知事件 | 自定义响应 |

**两种实现方式：**

1. **Prompt-based Hooks**（推荐）
   - 通过 LLM 决策
   - 灵活、智能
   - 上下文感知

2. **Command Hooks**
   - 通过脚本执行
   - 确定性验证
   - 快速响应

**Hook 输出格式：**
```json
{
  "systemMessage": "Message for NeurX",
  "userMessage": "Message for user (optional)",
  "blockOperation": false
}
```

### 3. 命令系统（Slash Commands）

**格式：** Markdown + YAML frontmatter

```markdown
---
allowed-tools: [Edit, Read, Bash]
model: sonnet
---

System prompt for this command...

User input: $ARGUMENTS
```

**特性：**
- ✅ 动态参数：`$ARGUMENTS`
- ✅ 工具限制：`allowed-tools`
- ✅ 命名空间：`/plugin:command`

### 4. Agent 系统（专业化 Agent）

**配置示例：**
```markdown
---
allowed-tools: [Read, Grep, Glob]
model: sonnet
color: blue
---

You are a code exploration specialist...
```

**特性：**
- ✅ 独立系统提示
- ✅ 工具限制
- ✅ 模型选择
- ✅ UI 颜色标识
- ✅ 并行执行

---

## 🔌 官方插件生态（14 个插件）

### 🔴 高价值插件（必须借鉴）

#### 1. **code-review** - 自动化 PR 审查 ⭐⭐⭐
**功能：**
- 多 agent 并行审查（4-5 个 agents）
- **信心评分系统**（0-100，阈值 80）
- 审查维度：
  - CLAUDE.md 合规性
  - 明显 bug 扫描
  - Git blame/历史分析
  - PR 历史分析
- **过滤假阳性**

**neurx-code 实现建议：**
```cpp
class CodeReviewOrchestrator {
    struct ReviewResult {
        QString issue;
        int confidence;  // 0-100
        QString severity;
    };
    
    QList<ReviewResult> reviewPR(const QString& prUrl);
    QList<ReviewResult> reviewDiff(const QString& diff);
    
    // 过滤低信心问题
    QList<ReviewResult> filterByConfidence(int threshold = 80);
};
```

#### 2. **commit-commands** - Git 工作流自动化 ⭐⭐⭐
**命令：**
- `/commit`：自动生成 commit message 并提交
- `/commit-push-pr`：一键 commit + push + 创建 PR
- `/clean_gone`：清理已删除的远程分支

**neurx-code 实现建议：**
```cpp
class GitWorkflowTools : public BaseTool {
public:
    // 分析 diff 生成符合项目风格的 commit message
    QString generateCommitMessage(const QString& diff);
    
    // 检测敏感文件
    bool hasSensitiveFiles(const QStringList& files);
    
    // 一键创建 PR
    bool createPullRequest(const QString& title, const QString& body);
};
```

**实现方案：**
- 使用 `libgit2` 或调用 `git` 命令
- 集成 `gh` CLI（GitHub）或 `glab` CLI（GitLab）
- 敏感文件检测：`.env`、`.key`、`config.json` 等

#### 3. **feature-dev** - 结构化功能开发流程 ⭐⭐⭐
**7 阶段流程：**

| 阶段 | 说明 | Agent |
|-----|------|-------|
| 1. Discovery | 理解需求和约束 | - |
| 2. Codebase Exploration | 并行分析代码库 | 2-3 个 `code-explorer` agents |
| 3. Clarifying Questions | 收集边界情况 | 等待用户回答 |
| 4. Architecture Design | 生成多种方案 | 2-3 个 `code-architect` agents |
| 5. Implementation | 按选定方案实现 | - |
| 6. Quality Review | 多维度审查 | 3 个 `code-reviewer` agents |
| 7. Summary | 记录决策 | - |

**neurx-code 实现建议：**
```cpp
class FeatureDevWorkflow : public QObject {
    Q_OBJECT
public:
    enum Phase {
        Discovery,
        CodebaseExploration,
        ClarifyingQuestions,
        ArchitectureDesign,
        Implementation,
        QualityReview,
        Summary
    };
    
    void startWorkflow(const QString& featureRequest);
    void nextPhase();
    void handleUserInput(const QString& input);
    
signals:
    void phaseChanged(Phase newPhase, const QString& description);
    void questionsReady(const QStringList& questions);
    void userInputRequired();
    void workflowCompleted();
    
private:
    Phase m_currentPhase;
    QList<AgentResult> m_explorationResults;
    QList<ArchitectureProposal> m_proposals;
};
```

**GUI 集成：**
- 添加 "Feature Development" 面板
- 显示当前阶段和进度
- 暂停等待用户输入

#### 4. **security-guidance** - 三层安全防护 ⭐⭐⭐
**Layer 1: Pattern Warnings**
- 基于正则的即时警告
- 监控 25+ 种危险模式

**Layer 2: LLM Diff Review**
- Stop hook 时触发
- 快速模型分析 diff
- NeurX 可在用户看到前修复

**Layer 3: Agentic Commit Review**
- `git commit` 时触发
- 跨文件数据流追踪
- 捕获多文件漏洞（IDOR、认证绕过、SSRF、路径遍历）

**neurx-code 实现建议：**
```cpp
class SecurityScanner {
public:
    struct SecurityIssue {
        QString filePath;
        int lineNumber;
        QString pattern;
        QString severity;  // "warning" | "critical"
        QString message;
        QString cweId;     // CWE 编号
    };
    
    // Layer 1: 模式扫描
    QList<SecurityIssue> scanFile(const QString& filePath);
    QList<SecurityIssue> scanDiff(const QString& diff);
    
    // Layer 2: LLM 审查
    QList<SecurityIssue> llmReviewDiff(const QString& diff);
    
    // Layer 3: Agent 深度审查
    QList<SecurityIssue> agenticReview(const QStringList& files);
    
private:
    void initDangerousPatterns();
    QHash<QString, QRegularExpression> m_patterns;
};
```

**危险模式库（部分）：**
```cpp
void SecurityScanner::initDangerousPatterns() {
    // Python
    m_patterns["unsafe_yaml"] = QRegularExpression("yaml\\.load\\((?!.*Loader=)");
    m_patterns["unsafe_pickle"] = QRegularExpression("pickle\\.load\\(");
    m_patterns["torch_unsafe"] = QRegularExpression("torch\\.load\\([^)]*weights_only=False");
    
    // JavaScript
    m_patterns["eval"] = QRegularExpression("\\beval\\s*\\(");
    m_patterns["innerHTML"] = QRegularExpression("innerHTML\\s*=");
    m_patterns["dangerouslySetInnerHTML"] = QRegularExpression("dangerouslySetInnerHTML");
    
    // Shell
    m_patterns["os_system"] = QRegularExpression("os\\.system\\(");
    m_patterns["subprocess_shell"] = QRegularExpression("subprocess\\..*shell\\s*=\\s*True");
    
    // 密钥检测
    m_patterns["hardcoded_key"] = QRegularExpression("(api[_-]?key|secret[_-]?key)\\s*=\\s*['\"](?!\\$\\{)");
}
```

#### 5. **hookify** - 自定义 Hook 生成器 ⭐⭐
**功能：**
- 对话式创建安全规则
- 简单的 Markdown 配置
- 正则模式匹配
- 无需编码

**命令：**
```bash
/hookify Warn me when I use rm -rf commands
/hookify:list
/hookify:configure
```

**规则格式：**
```markdown
---
name: block-dangerous-rm
enabled: true
event: bash
pattern: rm\s+-rf
action: block
---

⚠️ **Dangerous rm command detected!**

This command will recursively delete files. Are you sure?
```

**neurx-code 实现建议：**
```cpp
class HookRuleManager {
public:
    struct Rule {
        QString name;
        bool enabled;
        QString event;    // "bash", "file", "stop", "prompt", "all"
        QString pattern;  // 正则表达式
        QString action;   // "warn" | "block"
        QString message;
    };
    
    void createRule(const Rule& rule);
    QList<Rule> loadRules();
    bool evaluateRule(const Rule& rule, const QString& input);
    
    // 对话式创建
    Rule generateRuleFromPrompt(const QString& userPrompt);
};
```

**GUI 对话框：**
```cpp
class HookRuleDialog : public QDialog {
    Q_OBJECT
public:
    HookRuleDialog(QWidget* parent = nullptr);
    
private:
    QLineEdit* m_nameEdit;
    QComboBox* m_eventCombo;
    QLineEdit* m_patternEdit;
    QComboBox* m_actionCombo;
    QTextEdit* m_messageEdit;
    QPushButton* m_generateBtn;  // 使用 LLM 生成规则
};
```

#### 6. **pr-review-toolkit** - 多维度 PR 审查 ⭐⭐
**6 个专业 Agents：**
1. `comment-analyzer`：代码注释质量
2. `pr-test-analyzer`：测试覆盖和质量
3. `silent-failure-hunter`：静默失败检测
4. `type-design-analyzer`：类型设计
5. `code-reviewer`：代码质量
6. `code-simplifier`：简化建议

**命令：**
```bash
/pr-review-toolkit:review-pr [aspects]
# aspects: comments, tests, errors, types, code, simplify, all
```

**neurx-code 实现建议：**
```cpp
class PRReviewToolkit {
public:
    enum ReviewAspect {
        Comments,
        Tests,
        Errors,
        Types,
        Code,
        Simplify
    };
    
    struct ReviewReport {
        ReviewAspect aspect;
        QList<Issue> issues;
        int totalIssues;
        int criticalIssues;
    };
    
    QList<ReviewReport> reviewPR(const QString& prUrl, 
                                  QFlags<ReviewAspect> aspects);
                                  
private:
    ReviewReport analyzeComments(const QString& diff);
    ReviewReport analyzeTests(const QString& diff);
    ReviewReport findSilentFailures(const QString& diff);
    ReviewReport analyzeTypeDesign(const QString& diff);
    ReviewReport reviewCodeQuality(const QString& diff);
    ReviewReport suggestSimplifications(const QString& diff);
};
```

### 🟡 中价值插件（选择性借鉴）

#### 7. **ralph-wiggum** - 自主迭代循环 ⭐⭐
**核心概念：** 实现持续 AI 循环，NeurX 自动重复执行直到完成

**工作原理：**
```
1. 用户：/ralph-loop "实现 TDD 测试" --max-iterations 50
2. NeurX 执行任务
3. NeurX 尝试退出
4. Stop hook 拦截
5. 重新注入相同 prompt
6. 重复 2-5 直到完成或达到最大迭代次数
```

**neurx-code 实现建议：**
```cpp
class AutoIterationLoop : public QObject {
    Q_OBJECT
public:
    void startLoop(const QString& task, 
                   const QString& completionPromise,
                   int maxIterations = 50);
    void stopLoop();
    
    bool isRunning() const;
    int currentIteration() const;
    QString status() const;
    
signals:
    void iterationCompleted(int iteration, const QString& summary);
    void loopFinished(bool success, const QString& finalResult);
    
private slots:
    void onAgentAttemptExit();
    void onFileChanged(const QString& filePath);
    
private:
    bool shouldContinue();
    void reinjectPrompt();
    
    QString m_taskPrompt;
    QString m_completionPromise;
    int m_maxIterations;
    int m_currentIteration;
    bool m_stopRequested;
};
```

**适用场景：**
- TDD 开发（写测试 → 实现 → 修复 → 重构）
- 持续改进代码质量
- 自主 bug 修复
- 探索性编程

#### 8. **explanatory-output-style** - 教育性输出
**功能：** 通过 SessionStart hook 注入教育性指令

**neurx-code 实现建议：**
- 在 UI 中添加 "Learning Mode" 开关
- SessionStart 时注入教育性 prompt
- 格式化洞察输出

#### 9. **plugin-dev** - 插件开发工具包
**功能：** 8 阶段插件创建流程 + 7 个专业 Skills

**neurx-code 实现建议：**
- 创建插件开发向导
- 提供模板和示例
- 集成验证器

### 🟢 低价值插件（可选）

10. **agent-sdk-dev** - Agent SDK 开发
11. **neurx-opus-4-5-migration** - 模型迁移
12. **frontend-design** - 前端设计指导
13. **learning-output-style** - 学习模式
14. **commit-messages** - Commit 消息规范

---

## 🚀 neurx-code 实现建议

### Phase 1: 基础增强（1-2 周）

#### 1.1 Hooks 系统扩展 ⭐⭐⭐
**实现内容：**
```cpp
// src/agent/HookManager.h
class HookManager : public QObject {
    Q_OBJECT
public:
    enum HookType {
        PreToolUse,
        PostToolUse,
        SessionStart,
        SessionEnd,
        Stop,
        PreCompact
    };
    
    struct HookResult {
        QString systemMessage;
        QString userMessage;
        bool blockOperation;
    };
    
    void registerHook(HookType type, const QString& hookScript);
    HookResult executeHook(HookType type, const QJsonObject& context);
    
private:
    QHash<HookType, QList<QString>> m_hooks;
    HookResult executePromptHook(const QString& hookPrompt, const QJsonObject& context);
    HookResult executeCommandHook(const QString& command, const QJsonObject& context);
};
```

**工作量：** 3-5 天

#### 1.2 安全模式扫描 ⭐⭐⭐
**实现内容：**
- 25+ 危险模式库
- 文件扫描器
- Diff 扫描器
- 集成到 FileWatcher

**工作量：** 2-3 天

#### 1.3 Git 工作流工具 ⭐⭐
**实现内容：**
```cpp
// src/tools/GitWorkflowTool.h
class GitWorkflowTool : public BaseTool {
public:
    QString name() const override { return "git_workflow"; }
    
    // 生成 commit message
    QString generateCommitMessage();
    
    // 自动 commit
    ToolResult autoCommit(const QString& message);
    
    // commit + push + create PR
    ToolResult commitPushPR(const QString& prTitle, const QString& prBody);
};
```

**工作量：** 3-4 天

### Phase 2: 高级功能（2-4 周）

#### 2.1 Hookify 规则创建器 ⭐⭐
**实现内容：**
- GUI 对话框
- Markdown 规则格式
- 规则管理器
- LLM 辅助生成

**工作量：** 4-5 天

#### 2.2 多 Agent 并行系统 ⭐⭐⭐
**实现内容：**
```cpp
// src/agent/MultiAgentOrchestrator.h
class MultiAgentOrchestrator : public QObject {
    Q_OBJECT
public:
    struct AgentTask {
        QString systemPrompt;
        QStringList allowedTools;
        QString model;
        QVariantMap context;
    };
    
    struct AgentResult {
        QString output;
        int confidence;  // 0-100
        QStringList issues;
    };
    
    QList<AgentResult> runParallel(const QList<AgentTask>& tasks);
    AgentResult aggregateResults(const QList<AgentResult>& results);
    
private:
    QThreadPool* m_threadPool;
};
```

**工作量：** 5-7 天

#### 2.3 代码审查系统 ⭐⭐⭐
**实现内容：**
- 集成多 Agent 并行
- 信心评分算法
- 假阳性过滤
- 审查报告生成

**工作量：** 5-7 天

### Phase 3: 完整工作流（4-8 周）

#### 3.1 功能开发工作流 ⭐⭐⭐
**实现内容：**
- 7 阶段状态机
- 每阶段专用 agents
- 用户交互点
- GUI 进度显示

**工作量：** 10-14 天

#### 3.2 Ralph Wiggum 自主循环 ⭐⭐
**实现内容：**
- Stop hook 拦截
- 自动 prompt 重注入
- 完成条件检测
- 迭代计数和限制

**工作量：** 5-7 天

#### 3.3 分层配置系统 ⭐
**实现内容：**
- 用户级配置
- 项目级配置
- 本地覆盖
- 配置合并逻辑

**工作量：** 3-5 天

---

## 📋 功能对比表

| 功能 | neurx-code | neurx-code 现状 | 实现优先级 | 工作量 |
|------|-------------|----------------|----------|--------|
| **Hooks 系统** | 9 种 hook 类型 | 基础 hooks | 🔴 高 | 3-5 天 |
| **安全扫描** | 三层防护 | 无 | 🔴 高 | 2-3 天 |
| **Git 工作流** | 一键 commit-push-pr | 基础 | 🔴 高 | 3-4 天 |
| **Hookify** | 对话式规则创建 | 无 | 🟡 中 | 4-5 天 |
| **多 Agent** | 并行 + 信心评分 | 单 agent | 🟡 中 | 5-7 天 |
| **代码审查** | 多维度并行 | 基础 | 🟡 中 | 5-7 天 |
| **功能开发流程** | 7 阶段工作流 | 无 | 🟡 中 | 10-14 天 |
| **自主循环** | Ralph Wiggum | 无 | 🟢 低 | 5-7 天 |
| **分层配置** | 企业级 | 单层 | 🟢 低 | 3-5 天 |
| **插件市场** | 官方市场 | 无 | 🟢 低 | 长期 |

---

## 🎯 实施路线图

### 里程碑 1: 基础增强（完成 Phase 1）
**时间：** 1-2 周  
**目标：** 补齐核心安全和 Git 功能

- ✅ Hooks 系统扩展（3-5 天）
- ✅ 安全模式扫描（2-3 天）
- ✅ Git 工作流工具（3-4 天）

**交付物：**
- SessionStart、Stop、PostToolUse hooks
- 25+ 安全模式检测
- `/commit` 和 `/commit-push-pr` 命令

### 里程碑 2: 高级功能（完成 Phase 2）
**时间：** 2-4 周  
**目标：** 引入多 Agent 和智能规则

- ✅ Hookify 规则创建器（4-5 天）
- ✅ 多 Agent 并行系统（5-7 天）
- ✅ 代码审查系统（5-7 天）

**交付物：**
- GUI 规则创建对话框
- 多 Agent 调度器
- PR 审查工具

### 里程碑 3: 完整工作流（完成 Phase 3）
**时间：** 4-8 周  
**目标：** 系统化开发流程

- ✅ 功能开发工作流（10-14 天）
- ✅ 自主循环（5-7 天）
- ✅ 分层配置（3-5 天）

**交付物：**
- Feature Development 向导
- Ralph 循环模式
- 企业级配置管理

---

## 🔑 关键技术要点

### 1. JSON 协议设计

**Hook 输入：**
```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/path/to/file",
    "new_text": "content"
  },
  "context": {
    "session_id": "abc123",
    "user_prompt": "original request",
    "workspace_path": "/project/root"
  }
}
```

**Hook 输出：**
```json
{
  "systemMessage": "⚠️ Security warning: detected eval() usage",
  "userMessage": "Consider using JSON.parse() instead",
  "blockOperation": false
}
```

### 2. 信心评分算法

```cpp
int calculateConfidence(const Issue& issue) {
    int score = 50;  // 基准分
    
    // 增加分数
    if (issue.hasExplicitViolation) score += 30;
    if (issue.matchesProjectStandards) score += 20;
    if (issue.hasCodeEvidence) score += 10;
    
    // 减少分数
    if (issue.isPreExisting) score -= 40;
    if (issue.isPedantic) score -= 20;
    if (issue.hasLintIgnore) score -= 30;
    
    return qBound(0, score, 100);
}
```

### 3. 环境变量展开

```cpp
QString expandVariables(const QString& path) {
    QString result = path;
    
    // 插件根目录
    result.replace("${NEURX_PLUGIN_ROOT}", m_pluginRootDir);
    result.replace("${NEURX_PLUGIN_ROOT}", m_pluginRootDir);
    
    // 标准路径
    result.replace("${HOME}", QDir::homePath());
    result.replace("${WORKSPACE}", m_workspacePath);
    
    // 环境变量
    QRegularExpression envVar("\\$\\{([^}]+)\\}");
    QRegularExpressionMatchIterator it = envVar.globalMatch(result);
    while (it.hasNext()) {
        QRegularExpressionMatch match = it.next();
        QString varName = match.captured(1);
        QString varValue = qgetenv(varName.toUtf8());
        result.replace(match.captured(0), varValue);
    }
    
    return result;
}
```

---

## 📊 总结

### neurx-code 的核心优势

1. **成熟的插件生态**：14 个高质量官方插件
2. **灵活的 Hooks 系统**：9 种 hook 类型，智能和确定性结合
3. **多 Agent 协作**：并行执行、信心评分、假阳性过滤
4. **结构化工作流**：7 阶段功能开发流程
5. **安全优先**：三层防护（模式 + LLM + Agent）
6. **Git 深度集成**：一键自动化工作流
7. **自主迭代**：Ralph Wiggum 循环
8. **企业级**：分层配置、沙盒化、权限管理

### neurx-code 应该优先实现

#### 立即开始（1-2 周）
1. **Hooks 系统扩展**：添加 SessionStart、Stop、PostToolUse
2. **安全模式扫描**：25+ 危险模式检测
3. **Git 工作流**：自动 commit message + 一键 PR

#### 近期计划（2-4 周）
4. **Hookify 规则**：GUI 对话框 + Markdown 规则
5. **多 Agent 系统**：并行调度 + 信心评分
6. **代码审查**：多维度 PR 审查

#### 中期计划（4-8 周）
7. **功能开发流程**：7 阶段结构化工作流
8. **自主循环**：Ralph Wiggum 模式
9. **分层配置**：企业级配置管理

### 实施建议

**阶段性推进：**
1. 先实现基础的 Hooks 和安全扫描（快速见效）
2. 再引入多 Agent 和智能审查（提升质量）
3. 最后完善工作流和企业功能（系统化）

**优先考虑：**
- ✅ 对用户价值高的功能（Git 工作流、安全扫描）
- ✅ 技术难度适中的功能（避免长期阻塞）
- ✅ 可复用的基础设施（Hooks、多 Agent）

**避免陷阱：**
- ❌ 不要一次实现所有功能（聚焦核心价值）
- ❌ 不要照搬实现（根据 neurx-code 架构调整）
- ❌ 不要忽视测试（特别是安全功能）

---

**结论：** neurx-code 的插件生态和自动化能力非常强大，neurx-code 可以选择性地借鉴其核心功能（Hooks、安全扫描、Git 工作流、多 Agent），在 1-2 个月内显著提升产品竞争力。
