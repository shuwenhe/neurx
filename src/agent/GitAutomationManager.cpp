#include "GitAutomationManager.h"
#include <QDebug>
#include <QProcess>
#include <QDateTime>
#include <QFile>
#include <QUuid>
#include <QJsonDocument>
#include <QJsonArray>
#include <algorithm>

GitAutomationManager::GitAutomationManager(QObject* parent)
    : QObject(parent),
      m_autoStaging(true),
      m_autoRebase(false)
{
    m_gitPath = "git";
    m_statistics.totalCommits = 0;
    m_statistics.totalBranches = 0;
    m_statistics.totalTags = 0;
    m_statistics.totalPullRequests = 0;
}

GitAutomationManager::~GitAutomationManager() = default;

QString GitAutomationManager::generateCommitMessage(const QStringList& changedFiles, CommitType type)
{
    QString prefix;
    switch (type) {
        case Feature: prefix = "feat"; break;
        case BugFix: prefix = "fix"; break;
        case Refactor: prefix = "refactor"; break;
        case Documentation: prefix = "docs"; break;
        case Performance: prefix = "perf"; break;
        case Security: prefix = "security"; break;
        case ChoreTask: prefix = "chore"; break;
    }

    QString message = prefix + ": ";
    
    if (changedFiles.length() == 1) {
        message += "Update " + changedFiles.first();
    } else {
        message += "Update multiple files";
    }

    return message;
}

bool GitAutomationManager::smartCommit(const QString& message, CommitType type)
{
    // Stage changes if auto-staging enabled
    if (m_autoStaging) {
        executeGitCommandBool("add -A");
    }

    QProcess process;
    process.start(m_gitPath, {"commit", "-m", message});
    process.waitForFinished();
    bool success = (process.exitCode() == 0);

    if (success) {
        m_statistics.totalCommits++;
        emit commitCreated(message);
    }

    return success;
}

bool GitAutomationManager::batchCommit(const QVector<CommitInfo>& commits)
{
    for (const auto& commit : commits) {
        if (!smartCommit(commit.message, ChoreTask)) {
            return false;
        }
    }
    return true;
}

bool GitAutomationManager::amendCommit(const QString& newMessage)
{
    QString cmd = QString("commit --amend -m \"%1\"").arg(newMessage);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::revertCommit(const QString& commitHash)
{
    QString cmd = QString("revert %1 --no-edit").arg(commitHash);
    return executeGitCommandBool(cmd);
}

GitAutomationManager::CommitInfo GitAutomationManager::getCommitInfo(const QString& commitHash)
{
    CommitInfo info;
    info.hash = commitHash;

    QString cmd = QString("show --format=fuller %1").arg(commitHash);
    QString output = executeGitCommand(cmd);

    // Parse git output
    if (!output.isEmpty()) {
        info.message = output;
    }

    return info;
}

QVector<GitAutomationManager::CommitInfo> GitAutomationManager::getCommitHistory(int count, const QString& branch)
{
    QVector<CommitInfo> history;
    QString cmd = QString("log -n %1 %2 --format=%H||%s||%an||%ai").arg(count).arg(branch);
    
    QString output = executeGitCommand(cmd);
    QStringList lines = output.split('\n', Qt::SkipEmptyParts);

    for (const auto& line : lines) {
        QStringList parts = line.split("||");
        if (parts.length() >= 4) {
            CommitInfo info;
            info.hash = parts[0];
            info.message = parts[1];
            info.author = parts[2];
            info.timestamp = parts[3];
            history.append(info);
        }
    }

    return history;
}

bool GitAutomationManager::pushBranch(const QString& branch, bool force, int maxRetries)
{
    QString branchName = branch.isEmpty() ? "HEAD" : branch;
    QString cmd = QString("push %1 %2").arg(force ? "-f" : "").arg(branchName);

    for (int i = 0; i < maxRetries; i++) {
        if (executeGitCommandBool(cmd)) {
            emit pushCompleted(branchName);
            return true;
        }
        // Retry logic with backoff
    }

    return false;
}

bool GitAutomationManager::pushTags()
{
    return executeGitCommandBool("push --tags");
}

bool GitAutomationManager::pushWithAutoRebase()
{
    executeGitCommandBool("pull --rebase");
    return pushBranch();
}

bool GitAutomationManager::pushAndCreatePR(const QString& title, const QString& description)
{
    if (!pushBranch()) {
        return false;
    }

    // Create PR using gh CLI or similar
    QString cmd = QString("gh pr create --title \"%1\" --body \"%2\"").arg(title).arg(description);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::createPullRequest(const QString& title, const QString& description,
                                           const QString& targetBranch, const QStringList& reviewers)
{
    QString cmd = QString("gh pr create --base %1 --title \"%2\" --body \"%3\"")
        .arg(targetBranch).arg(title).arg(description);

    for (const auto& reviewer : reviewers) {
        cmd += QString(" --reviewer %1").arg(reviewer);
    }

    return executeGitCommandBool(cmd);
}

GitAutomationManager::PullRequestInfo GitAutomationManager::getPullRequestInfo(const QString& prNumber)
{
    PullRequestInfo info;
    info.number = prNumber;

    // Query GitHub API or gh CLI
    QString cmd = QString("gh pr view %1 --json title,body,state").arg(prNumber);
    QString output = executeGitCommand(cmd);

    return info;
}

bool GitAutomationManager::updatePullRequest(const QString& prNumber, const QString& newTitle,
                                            const QString& newDescription)
{
    QString cmd = QString("gh pr edit %1 --title \"%2\" --body \"%3\"")
        .arg(prNumber).arg(newTitle).arg(newDescription);

    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::addReviewersToPR(const QString& prNumber, const QStringList& reviewers)
{
    QString reviewerStr = reviewers.join(",");
    QString cmd = QString("gh pr edit %1 --add-reviewer %2").arg(prNumber).arg(reviewerStr);

    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::mergePullRequest(const QString& prNumber, MergeStrategy strategy)
{
    QString strategyStr;
    switch (strategy) {
        case Merge: strategyStr = "--merge"; break;
        case Rebase: strategyStr = "--rebase"; break;
        case SquashMerge: strategyStr = "--squash"; break;
        case FastForward: strategyStr = "--ff-only"; break;
    }

    QString cmd = QString("gh pr merge %1 %2").arg(prNumber).arg(strategyStr);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::closePullRequest(const QString& prNumber, const QString& reason)
{
    QString cmd = QString("gh pr close %1").arg(prNumber);
    return executeGitCommandBool(cmd);
}

QVector<GitAutomationManager::PullRequestInfo> GitAutomationManager::listPullRequests(const QString& state)
{
    QVector<PullRequestInfo> prs;

    QString cmd = QString("gh pr list --state %1 --json number,title").arg(state);
    QString output = executeGitCommand(cmd);

    // Parse output
    QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    for (const auto& line : lines) {
        PullRequestInfo pr;
        pr.status = state;
        prs.append(pr);
    }

    return prs;
}

QVector<GitAutomationManager::PullRequestInfo> GitAutomationManager::getPRsByAuthor(const QString& author)
{
    QVector<PullRequestInfo> prs;

    QString cmd = QString("gh pr list --search \"author:%1\" --json number,title").arg(author);
    QString output = executeGitCommand(cmd);

    return prs;
}

QVector<GitAutomationManager::PullRequestInfo> GitAutomationManager::getPRsByLabel(const QString& label)
{
    QVector<PullRequestInfo> prs;

    QString cmd = QString("gh pr list --search \"label:%1\" --json number,title").arg(label);
    QString output = executeGitCommand(cmd);

    return prs;
}

bool GitAutomationManager::createBranch(const QString& branchName, const QString& fromBranch)
{
    QString baseBranch = fromBranch.isEmpty() ? "main" : fromBranch;
    QString cmd = QString("checkout -b %1 %2").arg(branchName).arg(baseBranch);

    bool success = executeGitCommandBool(cmd);
    if (success) {
        m_statistics.totalBranches++;
        emit branchCreated(branchName);
    }

    return success;
}

bool GitAutomationManager::deleteBranch(const QString& branchName, bool force)
{
    QString cmd = QString("branch %1 %2").arg(force ? "-D" : "-d").arg(branchName);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::renameBranch(const QString& oldName, const QString& newName)
{
    QString cmd = QString("branch -m %1 %2").arg(oldName).arg(newName);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::switchBranch(const QString& branchName)
{
    QString cmd = QString("checkout %1").arg(branchName);
    return executeGitCommandBool(cmd);
}

GitAutomationManager::BranchInfo GitAutomationManager::getCurrentBranch()
{
    BranchInfo info;
    QString output = executeGitCommand("rev-parse --abbrev-ref HEAD");
    info.name = output.trimmed();
    info.isLocal = true;

    return info;
}

QVector<GitAutomationManager::BranchInfo> GitAutomationManager::listBranches(bool includeRemote)
{
    QVector<BranchInfo> branches;
    QString cmd = includeRemote ? "branch -a" : "branch";
    QString output = executeGitCommand(cmd);

    QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    for (const auto& line : lines) {
        BranchInfo info;
        info.name = line.trimmed();
        info.isLocal = !line.startsWith("  remotes/");
        info.isRemote = line.startsWith("  remotes/");
        branches.append(info);
    }

    return branches;
}

bool GitAutomationManager::mergeBranch(const QString& sourceBranch, MergeStrategy strategy)
{
    QString cmd = QString("merge %1").arg(sourceBranch);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::rebaseBranch(const QString& targetBranch)
{
    QString cmd = QString("rebase %1").arg(targetBranch);
    return executeGitCommandBool(cmd);
}

QVector<GitAutomationManager::ConflictInfo> GitAutomationManager::detectConflicts()
{
    QVector<ConflictInfo> conflicts;

    QString output = executeGitCommand("diff --name-only --diff-filter=U");
    QStringList files = output.split('\n', Qt::SkipEmptyParts);

    for (const auto& file : files) {
        ConflictInfo info;
        info.file = file;
        conflicts.append(info);
    }

    if (!conflicts.isEmpty()) {
        emit conflictDetected(files);
    }

    return conflicts;
}

bool GitAutomationManager::resolveConflict(const QString& file, const QString& resolution)
{
    QFile conflictFile(file);
    if (!conflictFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }

    conflictFile.write(resolution.toUtf8());
    conflictFile.close();

    return executeGitCommandBool(QString("add %1").arg(file));
}

QString GitAutomationManager::generateMergeCommitMessage(const QString& sourceBranch)
{
    return QString("Merge branch '%1'").arg(sourceBranch);
}

bool GitAutomationManager::abortMerge()
{
    return executeGitCommandBool("merge --abort");
}

bool GitAutomationManager::abortRebase()
{
    return executeGitCommandBool("rebase --abort");
}

bool GitAutomationManager::stashChanges(const QString& message)
{
    QString cmd = message.isEmpty() ? "stash" : QString("stash push -m \"%1\"").arg(message);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::applyStash(const QString& stashId)
{
    QString cmd = QString("stash apply %1").arg(stashId);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::popStash(const QString& stashId)
{
    QString cmd = QString("stash pop %1").arg(stashId);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::dropStash(const QString& stashId)
{
    QString cmd = QString("stash drop %1").arg(stashId);
    return executeGitCommandBool(cmd);
}

QStringList GitAutomationManager::listStashes()
{
    QString output = executeGitCommand("stash list");
    return output.split('\n', Qt::SkipEmptyParts);
}

QStringList GitAutomationManager::getUnstagedFiles()
{
    QString output = executeGitCommand("diff --name-only");
    return output.split('\n', Qt::SkipEmptyParts);
}

QStringList GitAutomationManager::getStagedFiles()
{
    QString output = executeGitCommand("diff --cached --name-only");
    return output.split('\n', Qt::SkipEmptyParts);
}

QStringList GitAutomationManager::getUntrackedFiles()
{
    QString output = executeGitCommand("ls-files --others --exclude-standard");
    return output.split('\n', Qt::SkipEmptyParts);
}

QString GitAutomationManager::getRepositoryStatus()
{
    return executeGitCommand("status --porcelain");
}

bool GitAutomationManager::isRepositoryClean()
{
    QString output = executeGitCommand("status --porcelain");
    return output.trimmed().isEmpty();
}

bool GitAutomationManager::isConflicted()
{
    return !detectConflicts().isEmpty();
}

QString GitAutomationManager::getRemoteUrl(const QString& remoteName)
{
    QString cmd = QString("remote get-url %1").arg(remoteName);
    return executeGitCommand(cmd).trimmed();
}

QStringList GitAutomationManager::getAllRemotes()
{
    QString output = executeGitCommand("remote -v");
    return output.split('\n', Qt::SkipEmptyParts);
}

bool GitAutomationManager::createTag(const QString& tagName, const QString& message)
{
    QString cmd = message.isEmpty() ? QString("tag %1").arg(tagName) :
                                      QString("tag -a %1 -m \"%2\"").arg(tagName).arg(message);
    
    bool success = executeGitCommandBool(cmd);
    if (success) {
        m_statistics.totalTags++;
    }
    return success;
}

bool GitAutomationManager::deleteTag(const QString& tagName)
{
    QString cmd = QString("tag -d %1").arg(tagName);
    return executeGitCommandBool(cmd);
}

QStringList GitAutomationManager::listTags(const QString& pattern)
{
    QString cmd = pattern.isEmpty() ? "tag" : QString("tag -l %1").arg(pattern);
    QString output = executeGitCommand(cmd);
    return output.split('\n', Qt::SkipEmptyParts);
}

QString GitAutomationManager::getTagInfo(const QString& tagName)
{
    QString cmd = QString("show %1").arg(tagName);
    return executeGitCommand(cmd);
}

bool GitAutomationManager::pushTag(const QString& tagName)
{
    QString cmd = QString("push origin %1").arg(tagName);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::squashCommits(int count, const QString& squashMessage)
{
    QString cmd = QString("rebase -i HEAD~%1").arg(count);
    // This would require interactive handling
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::cherryPickCommit(const QString& commitHash)
{
    QString cmd = QString("cherry-pick %1").arg(commitHash);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::resetToCommit(const QString& commitHash, bool hard)
{
    QString cmd = QString("reset %1 %2").arg(hard ? "--hard" : "").arg(commitHash);
    return executeGitCommandBool(cmd);
}

bool GitAutomationManager::bisectStart(const QString& goodCommit, const QString& badCommit)
{
    executeGitCommandBool("bisect start");
    executeGitCommandBool(QString("bisect bad %1").arg(badCommit));
    return executeGitCommandBool(QString("bisect good %1").arg(goodCommit));
}

bool GitAutomationManager::bisectMark(bool good)
{
    QString cmd = good ? "bisect good" : "bisect bad";
    return executeGitCommandBool(cmd);
}

void GitAutomationManager::setGitPath(const QString& path)
{
    m_gitPath = path;
}

void GitAutomationManager::setCommitAuthor(const QString& name, const QString& email)
{
    m_commitAuthor = name;
    m_commitEmail = email;
    executeGitCommandBool(QString("config user.name \"%1\"").arg(name));
    executeGitCommandBool(QString("config user.email \"%1\"").arg(email));
}

void GitAutomationManager::setAutoStagingEnabled(bool enabled)
{
    m_autoStaging = enabled;
}

void GitAutomationManager::setAutoRebaseOnPush(bool enabled)
{
    m_autoRebase = enabled;
}

void GitAutomationManager::setPRTemplate(const QString& templatePath)
{
    m_prTemplate = templatePath;
}

GitAutomationManager::GitStats GitAutomationManager::getStatistics() const
{
    return m_statistics;
}

QString GitAutomationManager::executeGitCommand(const QString& command)
{
    QProcess process;
    process.start(m_gitPath, command.split(' ', Qt::SkipEmptyParts));
    process.waitForFinished();

    return QString::fromUtf8(process.readAllStandardOutput());
}

bool GitAutomationManager::executeGitCommandBool(const QString& command)
{
    QProcess process;
    process.start(m_gitPath, command.split(' ', Qt::SkipEmptyParts));
    process.waitForFinished();

    return process.exitCode() == 0;
}

QStringList GitAutomationManager::executeGitCommandList(const QString& command)
{
    QString output = executeGitCommand(command);
    return output.split('\n', Qt::SkipEmptyParts);
}

QString GitAutomationManager::generateUUID()
{
    return QUuid::createUuid().toString();
}
