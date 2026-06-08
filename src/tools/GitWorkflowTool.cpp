#include "GitWorkflowTool.h"
#include <QProcess>
#include <QRegularExpression>
#include <QDir>
#include <QDebug>
#include <QJsonArray>

// ── 构造和析构 ──────────────────────────────────────────────────────────────

GitWorkflowTool::GitWorkflowTool(QObject *parent)
    : BaseTool(parent)
{
    // 初始化敏感文件模式
    m_sensitivePatterns = {
        "*.env",
        "*.env.*",
        "*.key",
        "*.pem",
        "*.p12",
        "*.pfx",
        "*_rsa",
        "*_dsa",
        "*_ecdsa",
        "*.crt",
        "*.cer",
        ".aws/credentials",
        ".ssh/id_*",
        "secrets.json",
        "credentials.json",
        "service-account*.json"
    };

    m_sensitiveExtensions = {
        ".env", ".key", ".pem", ".p12", ".pfx", ".crt", ".cer"
    };

    qInfo() << "[GitWorkflowTool] Initialized";
}

GitWorkflowTool::~GitWorkflowTool()
{
    qInfo() << "[GitWorkflowTool] Destroyed";
}

// ── BaseTool 接口实现 ───────────────────────────────────────────────────────

QString GitWorkflowTool::name() const
{
    return "git_workflow";
}

QString GitWorkflowTool::description() const
{
    return "Git workflow automation: generate commit messages, auto-commit, push, and create PRs";
}

QJsonObject GitWorkflowTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    // action
    QJsonObject actionProp;
    actionProp["type"] = "string";
    actionProp["description"] = "Action to perform";
    QJsonArray actionEnum;
    actionEnum.append("generate_commit_message");
    actionEnum.append("auto_commit");
    actionEnum.append("commit_push");
    actionEnum.append("commit_push_pr");
    actionEnum.append("generate_pr_content");
    actionEnum.append("check_sensitive");
    actionProp["enum"] = actionEnum;
    properties["action"] = actionProp;
    
    // commit_message (optional)
    QJsonObject commitMsgProp;
    commitMsgProp["type"] = "string";
    commitMsgProp["description"] = "Commit message (if not provided, will be auto-generated)";
    properties["commit_message"] = commitMsgProp;
    
    // pr_title (optional)
    QJsonObject prTitleProp;
    prTitleProp["type"] = "string";
    prTitleProp["description"] = "Pull request title";
    properties["pr_title"] = prTitleProp;
    
    // pr_body (optional)
    QJsonObject prBodyProp;
    prBodyProp["type"] = "string";
    prBodyProp["description"] = "Pull request body";
    properties["pr_body"] = prBodyProp;
    
    // stage_all (optional)
    QJsonObject stageAllProp;
    stageAllProp["type"] = "boolean";
    stageAllProp["description"] = "Stage all changes before committing";
    stageAllProp["default"] = false;
    properties["stage_all"] = stageAllProp;
    
    schema["properties"] = properties;
    
    QJsonArray required;
    required.append("action");
    schema["required"] = required;
    
    return schema;
}

ToolResult GitWorkflowTool::execute(const QString &callId, const QJsonObject &args)
{
    QString action = args.value("action").toString();
    
    qInfo() << "[GitWorkflowTool]" << callId << "Action:" << action;
    
    if (action == "generate_commit_message") {
        return actionGenerateCommitMessage(args);
    } else if (action == "auto_commit") {
        return actionAutoCommit(args);
    } else if (action == "commit_push") {
        return actionCommitAndPush(args);
    } else if (action == "commit_push_pr") {
        return actionCommitPushPR(args);
    } else if (action == "generate_pr_content") {
        return actionGeneratePRContent(args);
    } else if (action == "check_sensitive") {
        return actionCheckSensitiveFiles(args);
    } else {
        return {callId, name(), true, "Unknown action: " + action};
    }
}

// ── Git 操作 ────────────────────────────────────────────────────────────────

QString GitWorkflowTool::getGitDiff()
{
    return runGitCommand({"diff"});
}

QString GitWorkflowTool::getStagedDiff()
{
    return runGitCommand({"diff", "--cached"});
}

QStringList GitWorkflowTool::getRecentCommits(int count)
{
    QString output = runGitCommand({"log", QString("-%1").arg(count), "--pretty=format:%s"});
    return output.split('\n', Qt::SkipEmptyParts);
}

QString GitWorkflowTool::runGitCommand(const QStringList& args, bool* success)
{
    QProcess process;
    process.setWorkingDirectory(QDir::currentPath());
    
    QStringList fullArgs;
    fullArgs << "-c" << "color.ui=false";  // 禁用颜色输出
    fullArgs << args;
    
    process.start("git", fullArgs);
    
    if (!process.waitForFinished(30000)) {
        qWarning() << "[GitWorkflowTool] Git command timeout:" << args.join(" ");
        if (success) *success = false;
        return QString();
    }
    
    if (process.exitCode() != 0) {
        QString error = QString::fromUtf8(process.readAllStandardError());
        qWarning() << "[GitWorkflowTool] Git command failed:" << args.join(" ") << error;
        if (success) *success = false;
        return error;
    }
    
    if (success) *success = true;
    return QString::fromUtf8(process.readAllStandardOutput());
}

// ── AI 功能 ─────────────────────────────────────────────────────────────────

QString GitWorkflowTool::generateCommitMessage()
{
    // 获取 diff
    QString diff = getStagedDiff();
    if (diff.isEmpty()) {
        diff = getGitDiff();
    }
    
    if (diff.isEmpty()) {
        return "chore: Update files";
    }
    
    // TODO: 集成 LLM 分析 diff 生成 commit message
    // 这里需要：
    // 1. 将 diff 发送给 LLM
    // 2. 使用 prompt: "Analyze this git diff and generate a concise commit message following Conventional Commits format..."
    // 3. 解析 LLM 返回的 commit message
    
    qInfo() << "[GitWorkflowTool] Generating commit message (LLM stub)";
    
    // 临时实现：基于文件数量简单生成
    QStringList lines = diff.split('\n');
    int additions = 0;
    int deletions = 0;
    
    for (const QString& line : lines) {
        if (line.startsWith('+') && !line.startsWith("+++")) {
            additions++;
        } else if (line.startsWith('-') && !line.startsWith("---")) {
            deletions++;
        }
    }
    
    return QString("chore: Update %1 additions, %2 deletions").arg(additions).arg(deletions);
}

GitWorkflowTool::PRContent GitWorkflowTool::generatePRContent(const QString& commitMessages)
{
    // TODO: 集成 LLM 基于 commit messages 生成 PR 标题和正文
    
    PRContent content;
    content.title = "Feature: Auto-generated PR";
    content.body = "## Changes\n\n" + commitMessages;
    
    qInfo() << "[GitWorkflowTool] Generating PR content (LLM stub)";
    
    return content;
}

// ── 安全检查 ────────────────────────────────────────────────────────────────

bool GitWorkflowTool::hasSensitiveFiles(const QStringList& files)
{
    return !findSensitiveFiles(files).isEmpty();
}

QStringList GitWorkflowTool::findSensitiveFiles(const QStringList& files)
{
    QStringList sensitiveFiles;
    
    for (const QString& file : files) {
        // 检查文件扩展名
        for (const QString& ext : m_sensitiveExtensions) {
            if (file.endsWith(ext)) {
                sensitiveFiles.append(file);
                break;
            }
        }
        
        // 检查文件名模式
        for (const QString& pattern : m_sensitivePatterns) {
            QRegularExpression re(QRegularExpression::wildcardToRegularExpression(pattern));
            if (re.match(file).hasMatch()) {
                sensitiveFiles.append(file);
                break;
            }
        }
    }
    
    return sensitiveFiles;
}

bool GitWorkflowTool::hasSecrets(const QString& diff)
{
    // 检查常见的密钥模式
    QStringList secretPatterns = {
        "AKIA[0-9A-Z]{16}",  // AWS Access Key
        "['\\\"][a-zA-Z0-9_-]{32,}['\\\"]",  // 长字符串（可能是密钥）
        "password\\s*=\\s*['\\\"]",
        "api[_-]?key\\s*=\\s*['\\\"]"
    };
    
    for (const QString& pattern : secretPatterns) {
        QRegularExpression re(pattern, QRegularExpression::CaseInsensitiveOption);
        if (re.match(diff).hasMatch()) {
            qWarning() << "[GitWorkflowTool] Potential secret detected in diff";
            return true;
        }
    }
    
    return false;
}

// ── 工作流操作 ──────────────────────────────────────────────────────────────

ToolResult GitWorkflowTool::actionAutoCommit(const QJsonObject& args)
{
    QString callId = args.value("_callId").toString();
    
    // Stage all if requested
    if (args.value("stage_all").toBool(false)) {
        bool success;
        runGitCommand({"add", "."}, &success);
        if (!success) {
            return {callId, name(), true, "Failed to stage files"};
        }
    }
    
    // Generate or use provided commit message
    QString message = args.value("commit_message").toString();
    if (message.isEmpty()) {
        message = generateCommitMessage();
    }
    
    // Validate message
    if (!isValidCommitMessage(message)) {
        message = formatCommitMessage(message);
    }
    
    // Check for sensitive files
    QString status = runGitCommand({"status", "--porcelain"});
    QStringList files;
    for (const QString& line : status.split('\n')) {
        if (line.length() > 3) {
            files.append(line.mid(3).trimmed());
        }
    }
    
    QStringList sensitiveFiles = findSensitiveFiles(files);
    if (!sensitiveFiles.isEmpty()) {
        QString warning = QString("⚠️  Warning: Sensitive files detected:\n%1")
                              .arg(sensitiveFiles.join('\n'));
        qWarning() << "[GitWorkflowTool]" << warning;
        return {callId, name(), true, warning};
    }
    
    // Check for secrets in diff
    QString diff = getStagedDiff();
    if (hasSecrets(diff)) {
        return {callId, name(), true, "⚠️  Warning: Potential secrets detected in diff. Commit blocked."};
    }
    
    // Commit
    bool success;
    QString result = runGitCommand({"commit", "-m", message}, &success);
    
    if (success) {
        return {callId, name(), false, "✅ Committed: " + message + "\n\n" + result};
    } else {
        return {callId, name(), true, "Failed to commit: " + result};
    }
}

ToolResult GitWorkflowTool::actionCommitAndPush(const QJsonObject& args)
{
    QString callId = args.value("_callId").toString();
    
    // First commit
    ToolResult commitResult = actionAutoCommit(args);
    if (commitResult.isError) {
        return commitResult;
    }
    
    // Then push
    QString branch = getCurrentBranch();
    bool success;
    QString pushResult = runGitCommand({"push", "origin", branch}, &success);
    
    if (success) {
        return {callId, name(), false, commitResult.content + "\n\n✅ Pushed to " + branch};
    } else {
        return {callId, name(), true, "Committed but push failed: " + pushResult};
    }
}

ToolResult GitWorkflowTool::actionCommitPushPR(const QJsonObject& args)
{
    QString callId = args.value("_callId").toString();
    
    // First commit and push
    ToolResult pushResult = actionCommitAndPush(args);
    if (pushResult.isError) {
        return pushResult;
    }
    
    // Parse repo info
    QString remoteUrl = getRemoteUrl();
    RepoInfo repo = parseGitHubRepo(remoteUrl);
    
    if (!repo.valid) {
        return {callId, name(), true, "Failed to parse GitHub repository from remote URL: " + remoteUrl};
    }
    
    // Get PR content
    QString prTitle = args.value("pr_title").toString();
    QString prBody = args.value("pr_body").toString();
    
    if (prTitle.isEmpty()) {
        QStringList commits = getRecentCommits(5);
        PRContent prContent = generatePRContent(commits.join('\n'));
        prTitle = prContent.title;
        prBody = prContent.body;
    }
    
    // TODO: Create PR using GitHub API
    // This requires:
    // 1. GitHub token (from environment or config)
    // 2. HTTP request to GitHub API
    // 3. Handle response
    
    QString message = pushResult.content + "\n\n📝 PR creation requires GitHub CLI or API integration (stub)";
    message += QString("\n\nRepo: %1/%2").arg(repo.owner, repo.repo);
    message += "\nTitle: " + prTitle;
    message += "\nBody: " + prBody;
    
    qInfo() << "[GitWorkflowTool] PR creation stub";
    
    return {callId, name(), false, message};
}

ToolResult GitWorkflowTool::actionGenerateCommitMessage(const QJsonObject& args)
{
    QString callId = args.value("_callId").toString();
    
    QString message = generateCommitMessage();
    return {callId, name(), false, message};
}

ToolResult GitWorkflowTool::actionGeneratePRContent(const QJsonObject& args)
{
    QString callId = args.value("_callId").toString();
    
    QStringList commits = getRecentCommits(10);
    PRContent content = generatePRContent(commits.join('\n'));
    
    QString result = "Title: " + content.title + "\n\nBody:\n" + content.body;
    return {callId, name(), false, result};
}

ToolResult GitWorkflowTool::actionCheckSensitiveFiles(const QJsonObject& args)
{
    QString callId = args.value("_callId").toString();
    
    QString status = runGitCommand({"status", "--porcelain"});
    QStringList files;
    for (const QString& line : status.split('\n')) {
        if (line.length() > 3) {
            files.append(line.mid(3).trimmed());
        }
    }
    
    QStringList sensitiveFiles = findSensitiveFiles(files);
    
    if (sensitiveFiles.isEmpty()) {
        return {callId, name(), false, "✅ No sensitive files detected"};
    } else {
        QString result = QString("⚠️  Sensitive files detected (%1):\n%2")
                             .arg(sensitiveFiles.size())
                             .arg(sensitiveFiles.join('\n'));
        return {callId, name(), false, result};
    }
}

// ── 辅助方法 ────────────────────────────────────────────────────────────────

QString GitWorkflowTool::formatCommitMessage(const QString& message)
{
    // 确保遵循 Conventional Commits 格式
    // 格式: <type>(<scope>): <subject>
    
    QStringList validTypes = {"feat", "fix", "docs", "style", "refactor", "test", "chore"};
    
    QString lower = message.toLower();
    for (const QString& type : validTypes) {
        if (lower.startsWith(type + ":") || lower.startsWith(type + "(")) {
            return message;  // Already in correct format
        }
    }
    
    // 默认添加 chore: 前缀
    return "chore: " + message;
}

bool GitWorkflowTool::isValidCommitMessage(const QString& message)
{
    // 检查是否符合 Conventional Commits 格式
    QRegularExpression re("^(feat|fix|docs|style|refactor|test|chore)(\\([^)]+\\))?:\\s.+");
    return re.match(message).hasMatch();
}

QString GitWorkflowTool::getCurrentBranch()
{
    QString branch = runGitCommand({"rev-parse", "--abbrev-ref", "HEAD"}).trimmed();
    return branch.isEmpty() ? "main" : branch;
}

QString GitWorkflowTool::getRemoteUrl()
{
    return runGitCommand({"remote", "get-url", "origin"}).trimmed();
}

GitWorkflowTool::RepoInfo GitWorkflowTool::parseGitHubRepo(const QString& url)
{
    RepoInfo info;
    info.valid = false;
    
    // 支持多种 GitHub URL 格式
    // - https://github.com/owner/repo.git
    // - git@github.com:owner/repo.git
    // - https://github.com/owner/repo
    
    QRegularExpression re("github\\.com[:/]([^/]+)/([^/.]+)");
    QRegularExpressionMatch match = re.match(url);
    
    if (match.hasMatch()) {
        info.owner = match.captured(1);
        info.repo = match.captured(2);
        info.valid = true;
    }
    
    return info;
}
