#include "GitCommandIntegration.h"
#include <QProcess>
#include <QDir>
#include <QDebug>
#include <QDateTime>
#include <QUuid>
#include <algorithm>

// ═══════════════════════════════════════════════════════════════════════════════
// GitCommandIntegration Implementation
// ═══════════════════════════════════════════════════════════════════════════════

GitCommandIntegration::GitCommandIntegration(QObject *parent)
    : QObject(parent), m_initialized(false)
{
}

GitCommandIntegration::~GitCommandIntegration() {}

bool GitCommandIntegration::initialize(const QString &workspaceRoot)
{
    m_workspaceRoot = workspaceRoot;
    m_initialized = validateWorkspace();
    return m_initialized;
}

bool GitCommandIntegration::isInitialized() const
{
    return m_initialized;
}

QList<GitCommandIntegration::BranchInfo> GitCommandIntegration::listBranches()
{
    QList<BranchInfo> branches;

    bool success = false;
    QString output = executeGitCommand({"branch", "-vv"}, &success);
    
    if (!success) {
        return branches;
    }

    for (const auto &line : output.split("\n")) {
        if (line.isEmpty()) continue;

        BranchInfo info;
        info.name = line.mid(2).split(" ").first();  // Skip "* " or "  "
        info.isLocal = true;
        
        branches.append(info);
    }

    return branches;
}

GitCommandIntegration::BranchInfo GitCommandIntegration::getCurrentBranch()
{
    BranchInfo info;
    bool success = false;
    QString output = executeGitCommand({"rev-parse", "--abbrev-ref", "HEAD"}, &success);
    
    if (success) {
        info.name = output.trimmed();
        info.isLocal = true;
    }

    return info;
}

bool GitCommandIntegration::switchBranch(const QString &branchName)
{
    bool success = false;
    executeGitCommand({"checkout", branchName}, &success);
    
    if (success) {
        emit branchChanged(branchName);
    }
    
    return success;
}

bool GitCommandIntegration::createBranch(const QString &branchName, bool switchTo)
{
    bool success = false;
    QStringList args = {"branch", branchName};
    executeGitCommand(args, &success);
    
    if (success && switchTo) {
        switchBranch(branchName);
    }
    
    return success;
}

bool GitCommandIntegration::deleteBranch(const QString &branchName)
{
    bool success = false;
    executeGitCommand({"branch", "-d", branchName}, &success);
    return success;
}

bool GitCommandIntegration::mergeBranch(const QString &branchName)
{
    bool success = false;
    executeGitCommand({"merge", branchName}, &success);
    return success;
}

QList<GitCommandIntegration::CommitInfo> GitCommandIntegration::getCommitHistory(int count)
{
    QList<CommitInfo> commits;

    bool success = false;
    QString output = executeGitCommand(
        {"log", "-n", QString::number(count), "--pretty=format:%H|%an|%s|%ai"},
        &success
    );

    if (!success) {
        return commits;
    }

    for (const auto &line : output.split("\n")) {
        if (line.isEmpty()) continue;

        auto parts = line.split("|");
        if (parts.size() >= 4) {
            CommitInfo info;
            info.hash = parts[0];
            info.shortHash = parts[0].left(7);
            info.author = parts[1];
            info.message = parts[2];
            info.date = QDateTime::fromString(parts[3], Qt::ISODate);
            
            commits.append(info);
        }
    }

    return commits;
}

GitCommandIntegration::CommitInfo GitCommandIntegration::getCommitInfo(const QString &commitHash)
{
    CommitInfo info;
    
    bool success = false;
    QString output = executeGitCommand(
        {"show", "--pretty=format:%H|%an|%s", commitHash},
        &success
    );

    if (success && !output.isEmpty()) {
        auto parts = output.split("|");
        if (parts.size() >= 3) {
            info.hash = parts[0];
            info.author = parts[1];
            info.message = parts[2];
        }
    }

    return info;
}

QList<GitCommandIntegration::DiffInfo> GitCommandIntegration::getCommitDiff(const QString &commitHash)
{
    QList<DiffInfo> diffs;

    bool success = false;
    QString output = executeGitCommand(
        {"diff-tree", "--no-commit-id", "--name-status", "-r", commitHash},
        &success
    );

    if (!success) {
        return diffs;
    }

    for (const auto &line : output.split("\n")) {
        if (line.isEmpty()) continue;

        auto parts = line.split("\t");
        if (parts.size() >= 2) {
            DiffInfo info;
            info.status = parts[0];
            info.file = parts[1];
            diffs.append(info);
        }
    }

    return diffs;
}

bool GitCommandIntegration::revertCommit(const QString &commitHash)
{
    bool success = false;
    executeGitCommand({"revert", commitHash}, &success);
    return success;
}

bool GitCommandIntegration::cherryPickCommit(const QString &commitHash)
{
    bool success = false;
    executeGitCommand({"cherry-pick", commitHash}, &success);
    return success;
}

QStringList GitCommandIntegration::listStashes()
{
    QStringList stashes;

    bool success = false;
    QString output = executeGitCommand({"stash", "list"}, &success);

    if (success) {
        stashes = output.split("\n", Qt::SkipEmptyParts);
    }

    return stashes;
}

bool GitCommandIntegration::createStash(const QString &message)
{
    bool success = false;
    if (message.isEmpty()) {
        executeGitCommand({"stash"}, &success);
    } else {
        executeGitCommand({"stash", "push", "-m", message}, &success);
    }
    return success;
}

bool GitCommandIntegration::applyStash(int stashIndex)
{
    bool success = false;
    executeGitCommand({"stash", "apply", QString("stash@{%1}").arg(stashIndex)}, &success);
    return success;
}

bool GitCommandIntegration::dropStash(int stashIndex)
{
    bool success = false;
    executeGitCommand({"stash", "drop", QString("stash@{%1}").arg(stashIndex)}, &success);
    return success;
}

bool GitCommandIntegration::popStash(int stashIndex)
{
    bool success = false;
    executeGitCommand({"stash", "pop", QString("stash@{%1}").arg(stashIndex)}, &success);
    return success;
}

QStringList GitCommandIntegration::listRemotes()
{
    QStringList remotes;

    bool success = false;
    QString output = executeGitCommand({"remote", "-v"}, &success);

    if (success) {
        for (const auto &line : output.split("\n")) {
            if (!line.isEmpty()) {
                remotes.append(line.split("\t").first());
            }
        }
    }

    return remotes;
}

bool GitCommandIntegration::addRemote(const QString &name, const QString &url)
{
    bool success = false;
    executeGitCommand({"remote", "add", name, url}, &success);
    return success;
}

bool GitCommandIntegration::removeRemote(const QString &name)
{
    bool success = false;
    executeGitCommand({"remote", "remove", name}, &success);
    return success;
}

bool GitCommandIntegration::fetchFromRemote(const QString &remoteName)
{
    bool success = false;
    executeGitCommand({"fetch", remoteName}, &success);
    return success;
}

bool GitCommandIntegration::pushToRemote(const QString &remoteName, const QString &branch)
{
    bool success = false;
    if (branch.isEmpty()) {
        executeGitCommand({"push", remoteName}, &success);
    } else {
        executeGitCommand({"push", remoteName, branch}, &success);
    }
    
    if (success) {
        emit pushCompleted(true);
    }
    
    return success;
}

bool GitCommandIntegration::pullFromRemote(const QString &remoteName, const QString &branch)
{
    bool success = false;
    if (branch.isEmpty()) {
        executeGitCommand({"pull", remoteName}, &success);
    } else {
        executeGitCommand({"pull", remoteName, branch}, &success);
    }
    
    if (success) {
        emit pullCompleted(true);
    }
    
    return success;
}

QStringList GitCommandIntegration::listTags()
{
    QStringList tags;

    bool success = false;
    QString output = executeGitCommand({"tag"}, &success);

    if (success) {
        tags = output.split("\n", Qt::SkipEmptyParts);
    }

    return tags;
}

bool GitCommandIntegration::createTag(const QString &tagName, const QString &message)
{
    bool success = false;
    if (message.isEmpty()) {
        executeGitCommand({"tag", tagName}, &success);
    } else {
        executeGitCommand({"tag", "-a", tagName, "-m", message}, &success);
    }
    return success;
}

bool GitCommandIntegration::deleteTag(const QString &tagName)
{
    bool success = false;
    executeGitCommand({"tag", "-d", tagName}, &success);
    return success;
}

bool GitCommandIntegration::pushTag(const QString &tagName, const QString &remoteName)
{
    bool success = false;
    executeGitCommand({"push", remoteName, "refs/tags/" + tagName}, &success);
    return success;
}

QJsonObject GitCommandIntegration::getRepositoryStatus()
{
    QJsonObject status;

    bool success = false;
    QString output = executeGitCommand({"status", "--porcelain"}, &success);

    if (success) {
        int modified = 0, added = 0, deleted = 0;
        for (const auto &line : output.split("\n")) {
            if (line.isEmpty()) continue;
            if (line.at(0) == 'M') modified++;
            else if (line.at(0) == 'A') added++;
            else if (line.at(0) == 'D') deleted++;
        }
        
        status["modified"] = modified;
        status["added"] = added;
        status["deleted"] = deleted;
    }

    return status;
}

int GitCommandIntegration::getUncommittedChanges()
{
    bool success = false;
    QString output = executeGitCommand({"status", "--porcelain"}, &success);

    return success ? output.split("\n", Qt::SkipEmptyParts).size() : 0;
}

QStringList GitCommandIntegration::getUntrackedFiles()
{
    QStringList files;

    bool success = false;
    QString output = executeGitCommand({"ls-files", "--others", "--exclude-standard"}, &success);

    if (success) {
        files = output.split("\n", Qt::SkipEmptyParts);
    }

    return files;
}

bool GitCommandIntegration::hasConflicts()
{
    bool success = false;
    QString output = executeGitCommand({"diff", "--name-only", "--diff-filter=U"}, &success);

    return success && !output.isEmpty();
}

QList<QString> GitCommandIntegration::getConflictingFiles()
{
    QList<QString> files;

    bool success = false;
    QString output = executeGitCommand({"diff", "--name-only", "--diff-filter=U"}, &success);

    if (success) {
        files = output.split("\n", Qt::SkipEmptyParts);
    }

    return files;
}

QString GitCommandIntegration::getConflictContent(const QString &filePath)
{
    QProcess process;
    process.setWorkingDirectory(m_workspaceRoot);
    process.start("cat", QStringList() << filePath);
    process.waitForFinished();

    return QString::fromUtf8(process.readAllStandardOutput());
}

bool GitCommandIntegration::resolveConflict(const QString &filePath, const QString &resolution)
{
    // 实现冲突解决逻辑
    bool success = false;
    executeGitCommand({"add", filePath}, &success);
    return success;
}

QString GitCommandIntegration::getConfigValue(const QString &key)
{
    bool success = false;
    QString output = executeGitCommand({"config", key}, &success);
    return success ? output.trimmed() : "";
}

void GitCommandIntegration::setConfigValue(const QString &key, const QString &value)
{
    executeGitCommand({"config", key, value});
}

GitCommandIntegration::RepositoryStats GitCommandIntegration::getRepositoryStats()
{
    RepositoryStats stats;

    bool success = false;
    
    // 获取总提交数
    QString commitCount = executeGitCommand({"rev-list", "--count", "HEAD"}, &success);
    if (success) {
        stats.totalCommits = commitCount.trimmed().toInt();
    }

    // 获取分支数
    QString branchCount = executeGitCommand({"branch", "-r"}, &success);
    if (success) {
        stats.totalBranches = branchCount.split("\n", Qt::SkipEmptyParts).size();
    }

    return stats;
}

QString GitCommandIntegration::executeGitCommand(const QStringList &args, bool *success)
{
    QProcess process;
    process.setWorkingDirectory(m_workspaceRoot);
    process.start("git", args);

    if (!process.waitForFinished()) {
        if (success) *success = false;
        return "";
    }

    if (process.exitCode() != 0) {
        if (success) *success = false;
        return "";
    }

    if (success) *success = true;
    return QString::fromUtf8(process.readAllStandardOutput());
}

QJsonObject GitCommandIntegration::parseGitOutput(const QString &output)
{
    QJsonObject result;
    result["raw"] = output;
    return result;
}

bool GitCommandIntegration::validateWorkspace()
{
    QDir dir(m_workspaceRoot);
    if (!dir.exists()) {
        return false;
    }

    QDir gitDir(m_workspaceRoot + "/.git");
    return gitDir.exists();
}

// ═══════════════════════════════════════════════════════════════════════════════
// IterativeFeedbackLoop Implementation
// ═══════════════════════════════════════════════════════════════════════════════

IterativeFeedbackLoop::IterativeFeedbackLoop(QObject *parent)
    : QObject(parent)
{
}

IterativeFeedbackLoop::~IterativeFeedbackLoop() {}

void IterativeFeedbackLoop::collectFeedback(const QString &iterationId,
                                            const QString &category,
                                            const QString &message,
                                            const QString &severity,
                                            const QString &suggestedFix)
{
    FeedbackItem item;
    item.id = generateFeedbackId();
    item.category = category;
    item.message = message;
    item.severity = severity;
    item.suggestedFix = suggestedFix;
    item.timestamp = QDateTime::currentDateTime();

    m_feedbackMap[iterationId].append(item);
    emit feedbackCollected(item);
}

bool IterativeFeedbackLoop::applyFeedback(const QString &feedbackId, const QString &fix)
{
    for (auto &items : m_feedbackMap) {
        for (auto &item : items) {
            if (item.id == feedbackId) {
                item.applied = true;
                emit feedbackApplied(feedbackId);
                return true;
            }
        }
    }
    return false;
}

IterativeFeedbackLoop::IterationFeedback IterativeFeedbackLoop::analyzeIteration(const QString &iterationId)
{
    IterationFeedback feedback;
    feedback.iterationId = iterationId;
    
    if (m_feedbackMap.contains(iterationId)) {
        feedback.items = m_feedbackMap[iterationId];
        feedback.overallScore = calculateScore(feedback.items);
        
        for (const auto &item : feedback.items) {
            if (item.severity == "error") {
                feedback.newIssuesFound++;
            }
        }
    }

    emit iterationAnalyzed(iterationId, feedback.overallScore);
    return feedback;
}

double IterativeFeedbackLoop::calculateIterationScore(const QString &iterationId)
{
    if (!m_feedbackMap.contains(iterationId)) {
        return 0.0;
    }

    return calculateScore(m_feedbackMap[iterationId]);
}

QString IterativeFeedbackLoop::generateIterationReport(const QString &iterationId)
{
    auto feedback = analyzeIteration(iterationId);
    
    QString report = QString("Iteration Report: %1\n").arg(iterationId);
    report += QString("Overall Score: %1\n").arg(feedback.overallScore);
    report += QString("Issues Found: %1\n").arg(feedback.newIssuesFound);
    report += QString("Issues Resolved: %1\n").arg(feedback.issuesResolved);
    
    for (const auto &item : feedback.items) {
        report += QString("\n[%1] %2: %3\n").arg(item.severity, item.category, item.message);
        if (!item.suggestedFix.isEmpty()) {
            report += QString("Fix: %1\n").arg(item.suggestedFix);
        }
    }

    return report;
}

double IterativeFeedbackLoop::getTrendScore(int recentIterations)
{
    if (m_history.size() < recentIterations) {
        recentIterations = m_history.size();
    }

    double sum = 0.0;
    for (int i = m_history.size() - recentIterations; i < m_history.size(); ++i) {
        sum += m_history[i].overallScore;
    }

    return recentIterations > 0 ? sum / recentIterations : 0.0;
}

QStringList IterativeFeedbackLoop::getCommonIssues(int topCount)
{
    QMap<QString, int> issueCount;

    for (const auto &feedback : m_history) {
        for (const auto &item : feedback.items) {
            issueCount[item.message]++;
        }
    }

    QList<QPair<int, QString>> sorted;
    for (auto it = issueCount.begin(); it != issueCount.end(); ++it) {
        sorted.append({it.value(), it.key()});
    }

    std::sort(sorted.rbegin(), sorted.rend());

    QStringList result;
    for (int i = 0; i < qMin(topCount, sorted.size()); ++i) {
        result.append(sorted[i].second);
    }

    return result;
}

QStringList IterativeFeedbackLoop::getResolvedIssues()
{
    QStringList resolved;

    for (const auto &feedback : m_history) {
        for (const auto &item : feedback.items) {
            if (item.applied) {
                resolved.append(item.message);
            }
        }
    }

    return resolved;
}

QString IterativeFeedbackLoop::suggestNextImprovement(const QString &iterationId)
{
    auto feedback = analyzeIteration(iterationId);
    
    if (feedback.items.isEmpty()) {
        return "No issues found. Continue with next iteration.";
    }

    // 返回第一个未应用的反馈
    for (const auto &item : feedback.items) {
        if (!item.applied && item.severity == "error") {
            return item.suggestedFix.isEmpty() ? item.message : item.suggestedFix;
        }
    }

    return feedback.items.first().message;
}

QList<IterativeFeedbackLoop::IterationFeedback> IterativeFeedbackLoop::getIterationHistory()
{
    return m_history;
}

void IterativeFeedbackLoop::clearHistory()
{
    m_history.clear();
    m_feedbackMap.clear();
}

QString IterativeFeedbackLoop::generateFeedbackId()
{
    return QUuid::createUuid().toString();
}

double IterativeFeedbackLoop::calculateScore(const QList<FeedbackItem> &items)
{
    if (items.isEmpty()) {
        return 100.0;
    }

    double score = 100.0;
    for (const auto &item : items) {
        if (item.severity == "error") {
            score -= 20.0;
        } else if (item.severity == "warning") {
            score -= 5.0;
        }
    }

    return qMax(0.0, score);
}

QString IterativeFeedbackLoop::categorizeFeedback(const QString &message)
{
    if (message.contains("performance", Qt::CaseInsensitive)) {
        return "performance";
    } else if (message.contains("quality", Qt::CaseInsensitive)) {
        return "quality";
    } else if (message.contains("style", Qt::CaseInsensitive)) {
        return "style";
    }
    return "other";
}
