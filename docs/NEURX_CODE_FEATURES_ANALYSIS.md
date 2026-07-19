# NeurX Code English textimplementationEnglish text

## 📊 English text

NeurX Code English text AI English text, English textpluginEnglish textsystemEnglish text.English text, English text NeurX English textimplementationEnglish text.

---

## 🏗️ English text

### 1. pluginsystem(Plugin System)

**English textdirectoryEnglish text: **
```
plugin-name/
├── .neurx-plugin/
│   └── plugin.json          # pluginEnglish textdata
├── commands/                # Slash commands(English text)
│   └── command.md
├── agents/                  # English text agents(English text)
│   └── agent.md
├── skills/                  # Agent Skills(English text)
│   └── skill.md
├── hooks/                   # English text(English text)
│   ├── hooks.json
│   └── pretooluse.py
├── .mcp.json                # MCP English textconfiguration(English text)
└── README.md
```

**English text: **
- ✅ English textload
- ✅ English textsupport(`${NEURX_PLUGIN_ROOT}`)
- ✅ English textconfiguration(English text, English text, English text)
- ✅ English textload/English text

### 2. Hooks system(English text)

**supportEnglish text Hook English text: **

| Hook English text | English text | English text |
|----------|---------|------|
| `PreToolUse` | toolEnglish text | English text, English text, English text |
| `PostToolUse` | toolEnglish text | English text, English text, English text |
| `SessionStart` | English textstart | English text, English text |
| `SessionEnd` | English text | English text, savestate |
| `Stop` | English text | English text(English text) |
| `SubagentStop` | English text agent English text | resultEnglish text |
| `UserPromptSubmit` | English text | English text, English text |
| `PreCompact` | English text | saveEnglish textinformation |
| `Notification` | English text | English textresponse |

**English textimplementationEnglish text: **

1. **Prompt-based Hooks**(recommended)
   - English text LLM English text
   - English text, English text
   - English text

2. **Command Hooks**
   - English text
   - English text
   - quickresponse

**Hook outputEnglish text: **
```json
{
  "systemMessage": "Message for NeurX",
  "userMessage": "Message for user (optional)",
  "blockOperation": false
}
```

### 3. English textsystem(Slash Commands)

**English text: ** Markdown + YAML frontmatter

```markdown
---
allowed-tools: [Edit, Read, Bash]
model: sonnet
---

System prompt for this command...

User input: $ARGUMENTS
```

**English text: **
- ✅ English textparameter: `$ARGUMENTS`
- ✅ toolEnglish text: `allowed-tools`
- ✅ English text: `/plugin:command`

### 4. Agent system(English text Agent)

**configurationexample: **
```markdown
---
allowed-tools: [Read, Grep, Glob]
model: sonnet
color: blue
---

You are a code exploration specialist...
```

**English text: **
- ✅ English textsystemprompt
- ✅ toolEnglish text
- ✅ modelEnglish text
- ✅ UI English text
- ✅ English text

---

## 🔌 English textpluginEnglish text(14 English textplugin)

### 🔴 English textplugin(English text)

#### 1. **code-review** - English text PR English text ⭐⭐⭐
**English text: **
- English text agent English text(4-5 English text agents)
- **English textsystem**(0-100, English text 80)
- English text:
  - CLAUDE.md English text
  - English text bug English text
  - Git blame/English text
  - PR English text
- **English text**

**neurx-code implementationEnglish text: **
```cpp
class CodeReviewOrchestrator {
    struct ReviewResult {
        QString issue;
        int confidence;  // 0-100
        QString severity;
    };

    QList<ReviewResult> reviewPR(const QString& prUrl);
    QList<ReviewResult> reviewDiff(const QString& diff);

    // English text
    QList<ReviewResult> filterByConfidence(int threshold = 80);
};
```

#### 2. **commit-commands** - Git English text ⭐⭐⭐
**English text: **
- `/commit`: English textgenerate commit message English text
- `/commit-push-pr`: English text commit + push + English text PR
- `/clean_gone`: English text

**neurx-code implementationEnglish text: **
```cpp
class GitWorkflowTools : public BaseTool {
public:
    // English text diff generateEnglish text commit message
    QString generateCommitMessage(const QString& diff);

    // English textfile
    bool hasSensitiveFiles(const QStringList& files);

    // English text PR
    bool createPullRequest(const QString& title, const QString& body);
};
```

**implementationEnglish text: **
- use `libgit2` English text `git` English text
- English text `gh` CLI(GitHub)English text `glab` CLI(GitLab)
- English textfileEnglish text: `.env`, `.key`, `config.json` English text

#### 3. **feature-dev** - English textpipeline ⭐⭐⭐
**7 phasepipeline: **

| phase | explanation | Agent |
|-----|------|-------|
| 1. Discovery | English text | - |
| 2. Codebase Exploration | English text | 2-3 English text `code-explorer` agents |
| 3. Clarifying Questions | English text | English text |
| 4. Architecture Design | generateEnglish text | 2-3 English text `code-architect` agents |
| 5. Implementation | English textimplementation | - |
| 6. Quality Review | English text | 3 English text `code-reviewer` agents |
| 7. Summary | English text | - |

**neurx-code implementationEnglish text: **
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

**GUI English text: **
- English text "Feature Development" English text
- English textphaseEnglish text
- English textinput

#### 4. **security-guidance** - English textsafetyEnglish text ⭐⭐⭐
**Layer 1: Pattern Warnings**
- English text
- monitoring 25+ English text

**Layer 2: LLM Diff Review**
- Stop hook English text
- quickmodelEnglish text diff
- NeurX English text

**Layer 3: Agentic Commit Review**
- `git commit` English text
- English textfiledataEnglish text
- English textfileEnglish text(IDOR, English text, SSRF, pathEnglish text)

**neurx-code implementationEnglish text: **
```cpp
class SecurityScanner {
public:
    struct SecurityIssue {
        QString filePath;
        int lineNumber;
        QString pattern;
        QString severity;  // "warning" | "critical"
        QString message;
        QString cweId;     // CWE English text
    };

    // Layer 1: English text
    QList<SecurityIssue> scanFile(const QString& filePath);
    QList<SecurityIssue> scanDiff(const QString& diff);

    // Layer 2: LLM English text
    QList<SecurityIssue> llmReviewDiff(const QString& diff);

    // Layer 3: Agent English text
    QList<SecurityIssue> agenticReview(const QStringList& files);

private:
    void initDangerousPatterns();
    QHash<QString, QRegularExpression> m_patterns;
};
```

**English text(English text): **
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

    // English text
    m_patterns["hardcoded_key"] = QRegularExpression("(api[_-]?key|secret[_-]?key)\\s*=\\s*['\"](?!\\$\\{)");
}
```

#### 5. **hookify** - English text Hook generateEnglish text ⭐⭐
**English text: **
- English textsafetyEnglish text
- English text Markdown configuration
- English text
- English text

**English text: **
```bash
/hookify Warn me when I use rm -rf commands
/hookify:list
/hookify:configure
```

**English text: **
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

**neurx-code implementationEnglish text: **
```cpp
class HookRuleManager {
public:
    struct Rule {
        QString name;
        bool enabled;
        QString event;    // "bash", "file", "stop", "prompt", "all"
        QString pattern;  // English text
        QString action;   // "warn" | "block"
        QString message;
    };

    void createRule(const Rule& rule);
    QList<Rule> loadRules();
    bool evaluateRule(const Rule& rule, const QString& input);

    // English text
    Rule generateRuleFromPrompt(const QString& userPrompt);
};
```

**GUI English text: **
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
    QPushButton* m_generateBtn;  // use LLM generateEnglish text
};
```

#### 6. **pr-review-toolkit** - English text PR English text ⭐⭐
**6 English text Agents: **
1. `comment-analyzer`: English text
2. `pr-test-analyzer`: testEnglish text
3. `silent-failure-hunter`: English textfailureEnglish text
4. `type-design-analyzer`: English text
5. `code-reviewer`: English text
6. `code-simplifier`: English text

**English text: **
```bash
/pr-review-toolkit:review-pr [aspects]
# aspects: comments, tests, errors, types, code, simplify, all
```

**neurx-code implementationEnglish text: **
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

### 🟡 English textplugin(English text)

#### 7. **ralph-wiggum** - English textmainEnglish text ⭐⭐
**English text: ** implementationEnglish text AI English text, NeurX English text

**English text: **
```
1. English text: /ralph-loop "implementation TDD test" --max-iterations 50
2. NeurX English text
3. NeurX English text
4. Stop hook English text
5. English text prompt
6. English text 2-5 English text
```

**neurx-code implementationEnglish text: **
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

**English text: **
- TDD English text(English texttest → implementation → English text → English text)
- English text
- English textmain bug English text
- English text

#### 8. **explanatory-output-style** - English textoutput
**English text: ** English text SessionStart hook English text

**neurx-code implementationEnglish text: **
- English text UI English text "Learning Mode" English text
- SessionStart English text prompt
- English textoutput

#### 9. **plugin-dev** - pluginEnglish texttoolEnglish text
**English text: ** 8 phasepluginEnglish textpipeline + 7 English text Skills

**neurx-code implementationEnglish text: **
- English textpluginEnglish text
- English textexample
- English text

### 🟢 English textplugin(English text)

10. **agent-sdk-dev** - Agent SDK English text
11. **neurx-opus-4-5-migration** - modelmigration
12. **frontend-design** - English text
13. **learning-output-style** - English text
14. **commit-messages** - Commit English text

---

## 🚀 neurx-code implementationEnglish text

### Phase 1: English text(1-2 English text)

#### 1.1 Hooks systemextension ⭐⭐⭐
**implementationcontent: **
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

**English text: ** 3-5 English text

#### 1.2 safetyEnglish text ⭐⭐⭐
**implementationcontent: **
- 25+ English text
- fileEnglish text
- Diff English text
- English text FileWatcher

**English text: ** 2-3 English text

#### 1.3 Git English texttool ⭐⭐
**implementationcontent: **
```cpp
// src/tools/GitWorkflowTool.h
class GitWorkflowTool : public BaseTool {
public:
    QString name() const override { return "git_workflow"; }

    // generate commit message
    QString generateCommitMessage();

    // English text commit
    ToolResult autoCommit(const QString& message);

    // commit + push + create PR
    ToolResult commitPushPR(const QString& prTitle, const QString& prBody);
};
```

**English text: ** 3-4 English text

### Phase 2: advancedEnglish text(2-4 English text)

#### 2.1 Hookify English text ⭐⭐
**implementationcontent: **
- GUI English text
- Markdown English text
- English textmanagementEnglish text
- LLM helpergenerate

**English text: ** 4-5 English text

#### 2.2 English text Agent English textsystem ⭐⭐⭐
**implementationcontent: **
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

**English text: ** 5-7 English text

#### 2.3 English textsystem ⭐⭐⭐
**implementationcontent: **
- English text Agent English text
- English text
- English text
- English textgenerate

**English text: ** 5-7 English text

### Phase 3: completeEnglish text(4-8 English text)

#### 3.1 English text ⭐⭐⭐
**implementationcontent: **
- 7 phasestateEnglish text
- English textphaseEnglish text agents
- English text
- GUI English text

**English text: ** 10-14 English text

#### 3.2 Ralph Wiggum English textmainEnglish text ⭐⭐
**implementationcontent: **
- Stop hook English text
- English text prompt English text
- English text
- English text

**English text: ** 5-7 English text

#### 3.3 English textconfigurationsystem ⭐
**implementationcontent: **
- English textconfiguration
- English textconfiguration
- English text
- configurationEnglish text

**English text: ** 3-5 English text

---

## 📋 English text

| English text | neurx-code | neurx-code English text | implementationEnglish text | English text |
|------|-------------|----------------|----------|--------|
| **Hooks system** | 9 English text hook English text | English text hooks | 🔴 English text | 3-5 English text |
| **safetyEnglish text** | English text | English text | 🔴 English text | 2-3 English text |
| **Git English text** | English text commit-push-pr | English text | 🔴 English text | 3-4 English text |
| **Hookify** | English text | English text | 🟡 English text | 4-5 English text |
| **English text Agent** | English text + English text | English text agent | 🟡 English text | 5-7 English text |
| **English text** | English text | English text | 🟡 English text | 5-7 English text |
| **English textpipeline** | 7 phaseEnglish text | English text | 🟡 English text | 10-14 English text |
| **English textmainEnglish text** | Ralph Wiggum | English text | 🟢 English text | 5-7 English text |
| **English textconfiguration** | English text | English text | 🟢 English text | 3-5 English text |
| **pluginEnglish text** | English text | English text | 🟢 English text | English text |

---

## 🎯 English text

### English text 1: English text(English text Phase 1)
**time: ** 1-2 English text
**English text: ** English textsafetyEnglish text Git English text

- ✅ Hooks systemextension(3-5 English text)
- ✅ safetyEnglish text(2-3 English text)
- ✅ Git English texttool(3-4 English text)

**English text: **
- SessionStart, Stop, PostToolUse hooks
- 25+ safetyEnglish text
- `/commit` English text `/commit-push-pr` English text

### English text 2: advancedEnglish text(English text Phase 2)
**time: ** 2-4 English text
**English text: ** English text Agent English text

- ✅ Hookify English text(4-5 English text)
- ✅ English text Agent English textsystem(5-7 English text)
- ✅ English textsystem(5-7 English text)

**English text: **
- GUI English text
- English text Agent English text
- PR English texttool

### English text 3: completeEnglish text(English text Phase 3)
**time: ** 4-8 English text
**English text: ** systemEnglish textpipeline

- ✅ English text(10-14 English text)
- ✅ English textmainEnglish text(5-7 English text)
- ✅ English textconfiguration(3-5 English text)

**English text: **
- Feature Development English text
- Ralph English text
- English textconfigurationmanagement

---

## 🔑 English text

### 1. JSON English text

**Hook input: **
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

**Hook output: **
```json
{
  "systemMessage": "⚠️ Security warning: detected eval() usage",
  "userMessage": "Consider using JSON.parse() instead",
  "blockOperation": false
}
```

### 2. English text

```cpp
int calculateConfidence(const Issue& issue) {
    int score = 50;  // English text

    // English text
    if (issue.hasExplicitViolation) score += 30;
    if (issue.matchesProjectStandards) score += 20;
    if (issue.hasCodeEvidence) score += 10;

    // English text
    if (issue.isPreExisting) score -= 40;
    if (issue.isPedantic) score -= 20;
    if (issue.hasLintIgnore) score -= 30;

    return qBound(0, score, 100);
}
```

### 3. English text

```cpp
QString expandVariables(const QString& path) {
    QString result = path;

    // pluginEnglish textdirectory
    result.replace("${NEURX_PLUGIN_ROOT}", m_pluginRootDir);
    result.replace("${NEURX_PLUGIN_ROOT}", m_pluginRootDir);

    // English textpath
    result.replace("${HOME}", QDir::homePath());
    result.replace("${WORKSPACE}", m_workspacePath);

    // English text
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

## 📊 English text

### neurx-code English text

1. **English textpluginEnglish text**: 14 English textplugin
2. **English text Hooks system**: 9 English text hook English text, English text
3. **English text Agent English text**: English text, English text, English text
4. **English text**: 7 phaseEnglish textpipeline
5. **safetyEnglish text**: English text(English text + LLM + Agent)
6. **Git English text**: English text
7. **English textmainEnglish text**: Ralph Wiggum English text
8. **English text**: English textconfiguration, English text, English textmanagement

### neurx-code English textimplementation

#### English textstart(1-2 English text)
1. **Hooks systemextension**: English text SessionStart, Stop, PostToolUse
2. **safetyEnglish text**: 25+ English text
3. **Git English text**: English text commit message + English text PR

#### English text(2-4 English text)
4. **Hookify English text**: GUI English text + Markdown English text
5. **English text Agent system**: English text + English text
6. **English text**: English text PR English text

#### English text(4-8 English text)
7. **English textpipeline**: 7 phaseEnglish text
8. **English textmainEnglish text**: Ralph Wiggum English text
9. **English textconfiguration**: English textconfigurationmanagement

### English text

**phaseEnglish text: **
1. English textimplementationEnglish text Hooks English textsafetyEnglish text(quickEnglish text)
2. English text Agent English text(English text)
3. English text(systemEnglish text)

**English text: **
- ✅ English text(Git English text, safetyEnglish text)
- ✅ English text(English text)
- ✅ English text(Hooks, English text Agent)

**English text: **
- ❌ English textimplementationEnglish text(English text)
- ❌ English textimplementation(English text neurx-code English text)
- ❌ English texttest(English textsafetyEnglish text)

---

**English text: ** neurx-code English textpluginEnglish text, neurx-code AllowedEnglish text(Hooks, safetyEnglish text, Git English text, English text Agent), English text 1-2 English text.
