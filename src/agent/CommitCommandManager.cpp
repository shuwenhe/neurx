#include "CommitCommandManager.h"
#include <QProcess>
#include <QProcessEnvironment>
#include <QDir>
#include <QFileInfo>
#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>

CommitCommandManager::CommitCommandManager(QObject *parent)
    : QObject(parent), m_commitStyle("conventional")
{
}

CommitCommandManager::~CommitCommandManager() {}

bool CommitCommandManager::executeCommit(const QString &workspaceRoot)
{
    emit commandStarted("commit");
    
    if (!validateWorkspaceRoot(workspaceRoot)) {
        emit commandFailed("commit", "Invalid workspace root");
        return false;
    }

    try {
        // 获取git状态
        auto staged = getStagedFiles(workspaceRoot);
        auto unstaged = getUnstagedFiles(workspaceRoot);
        auto recent = getRecentCommitMessages(workspaceRoot);

        // 生成提交信息
        QString commitMsg = generateCommitMessage(staged, unstaged, recent);
        
        // 执行提交
        QStringList args = {"commit", "-m", commitMsg};
        QString result = runGitCommand(workspaceRoot, args);
        
        // 提取提交哈希
        QString commitHash = result.split("create mode").first().trimmed();
        
        emit commitCreated(commitHash, commitMsg);
        emit commandCompleted("commit");
        
        return true;
    } catch (const std::exception &e) {
        emit commandFailed("commit", QString::fromStdString(e.what()));
        return false;
    }
}

bool CommitCommandManager::executeCommitPushPR(const QString &workspaceRoot)
{
    emit commandStarted("commit-push-pr");
    
    if (!validateWorkspaceRoot(workspaceRoot)) {
        emit commandFailed("commit-push-pr", "Invalid workspace root");
        return false;
    }

    try {
        // 1. 检查是否在main分支
        QString currentBranch;
        if (!getCurrentBranch(workspaceRoot, currentBranch)) {
            emit commandFailed("commit-push-pr", "Failed to get current branch");
            return false;
        }

        // 2. 如果在main分支，创建特性分支
        QString workingBranch = currentBranch;
        if (isOnMainBranch(workspaceRoot)) {
            workingBranch = QString("feature/%1").arg(QDateTime::currentDateTime().toString("yyyyMMdd-hhmmss"));
            if (!createFeatureBranch(workspaceRoot, workingBranch)) {
                emit commandFailed("commit-push-pr", "Failed to create feature branch");
                return false;
            }
            emit branchCreated(workingBranch);
        }

        // 3. 执行提交
        if (!executeCommit(workspaceRoot)) {
            emit commandFailed("commit-push-pr", "Commit failed");
            return false;
        }

        // 4. Push到origin
        QStringList pushArgs = {"push", "-u", "origin", workingBranch};
        runGitCommand(workspaceRoot, pushArgs);

        // 5. 创建PR
        auto staged = getStagedFiles(workspaceRoot);
        auto recentMessages = getRecentCommitMessages(workspaceRoot, 1);
        QString title = !recentMessages.isEmpty() ? recentMessages.first() : "Feature update";
        QString description = QString("Branch: %1\nStaged changes: %2 files")
                                  .arg(workingBranch)
                                  .arg(staged.size());

        if (!createPullRequest(workspaceRoot, title, description)) {
            emit commandFailed("commit-push-pr", "Failed to create PR");
            return false;
        }

        QString prUrl = getPRUrl(workspaceRoot, workingBranch);
        emit prCreated(prUrl);
        emit commandCompleted("commit-push-pr");

        return true;
    } catch (const std::exception &e) {
        emit commandFailed("commit-push-pr", QString::fromStdString(e.what()));
        return false;
    }
}

bool CommitCommandManager::executeCleanGone(const QString &workspaceRoot)
{
    emit commandStarted("clean_gone");
    
    if (!validateWorkspaceRoot(workspaceRoot)) {
        emit commandFailed("clean_gone", "Invalid workspace root");
        return false;
    }

    try {
        // 获取已删除的分支
        auto goneBranches = getGoneBranches(workspaceRoot);
        
        QStringList deletedBranches;
        for (const auto &branch : goneBranches) {
            // 删除关联的worktree
            deleteWorktree(workspaceRoot, branch);
            
            // 删除分支
            if (deleteGoneBranch(workspaceRoot, branch)) {
                deletedBranches.append(branch);
            }
        }

        if (!deletedBranches.isEmpty()) {
            emit branchCleaned(deletedBranches);
        }
        
        emit commandCompleted("clean_gone");
        return true;
    } catch (const std::exception &e) {
        emit commandFailed("clean_gone", QString::fromStdString(e.what()));
        return false;
    }
}

QString CommitCommandManager::generateCommitMessage(const QStringList &stagedChanges,
                                                    const QStringList &unstagedChanges,
                                                    const QStringList &recentMessages)
{
    if (m_commitStyle == "conventional") {
        // conventional commit format
        QString type = "feat";
        
        // 分析变更确定类型
        bool hasTests = false;
        bool hasDocs = false;
        bool hasBreaking = false;
        
        for (const auto &change : stagedChanges) {
            if (change.contains("test", Qt::CaseInsensitive)) hasTests = true;
            if (change.contains("README", Qt::CaseInsensitive) || change.contains("doc", Qt::CaseInsensitive)) hasDocs = true;
        }
        
        if (hasDocs) type = "docs";
        else if (hasTests) type = "test";
        
        // 生成消息
        QString scope;
        if (!stagedChanges.isEmpty()) {
            scope = stagedChanges.first().split("/").first();
        }
        
        QString message = QString("%1(%2): %3")
                              .arg(type)
                              .arg(scope.isEmpty() ? "core" : scope)
                              .arg(stagedChanges.size() > 0 ? "Update " + QString::number(stagedChanges.size()) + " file(s)" : "Update files");
        
        message += "\n\nApplied by Claude Code";
        return message;
    }
    
    // 默认描述性消息
    return QString("Update %1 file(s)\n\nApplied by Claude Code").arg(stagedChanges.size());
}

QJsonObject CommitCommandManager::getGitStatus(const QString &workspaceRoot)
{
    QJsonObject status;
    
    try {
        QStringList args = {"status", "--porcelain=v1"};
        QString output = runGitCommand(workspaceRoot, args);
        
        QJsonArray staged;
        QJsonArray unstaged;
        
        for (const auto &line : output.split("\n")) {
            if (line.isEmpty()) continue;
            
            if (line.at(0) == 'M' || line.at(0) == 'A' || line.at(0) == 'D') {
                staged.append(line.mid(3));
            } else if (line.at(1) == 'M' || line.at(1) == 'D') {
                unstaged.append(line.mid(3));
            }
        }
        
        status["staged"] = staged;
        status["unstaged"] = unstaged;
    } catch (...) {
        status["error"] = "Failed to get git status";
    }
    
    return status;
}

QStringList CommitCommandManager::getStagedFiles(const QString &workspaceRoot)
{
    QStringList files;
    try {
        QStringList args = {"diff", "--cached", "--name-only"};
        QString output = runGitCommand(workspaceRoot, args);
        files = output.split("\n", Qt::SkipEmptyParts);
    } catch (...) {
        // Silent failure
    }
    return files;
}

QStringList CommitCommandManager::getUnstagedFiles(const QString &workspaceRoot)
{
    QStringList files;
    try {
        QStringList args = {"diff", "--name-only"};
        QString output = runGitCommand(workspaceRoot, args);
        files = output.split("\n", Qt::SkipEmptyParts);
    } catch (...) {
        // Silent failure
    }
    return files;
}

QStringList CommitCommandManager::getRecentCommitMessages(const QString &workspaceRoot, int count)
{
    QStringList messages;
    try {
        QStringList args = {"log", "-n", QString::number(count), "--pretty=format:%s"};
        QString output = runGitCommand(workspaceRoot, args);
        messages = output.split("\n", Qt::SkipEmptyParts);
    } catch (...) {
        // Silent failure
    }
    return messages;
}

bool CommitCommandManager::createFeatureBranch(const QString &workspaceRoot, const QString &branchName)
{
    try {
        QStringList args = {"checkout", "-b", branchName};
        runGitCommand(workspaceRoot, args);
        return true;
    } catch (...) {
        return false;
    }
}

bool CommitCommandManager::getCurrentBranch(const QString &workspaceRoot, QString &branchName)
{
    try {
        QStringList args = {"rev-parse", "--abbrev-ref", "HEAD"};
        branchName = runGitCommand(workspaceRoot, args).trimmed();
        return !branchName.isEmpty();
    } catch (...) {
        return false;
    }
}

bool CommitCommandManager::isOnMainBranch(const QString &workspaceRoot)
{
    QString branch;
    if (!getCurrentBranch(workspaceRoot, branch)) {
        return false;
    }
    return branch == "main" || branch == "master";
}

bool CommitCommandManager::createPullRequest(const QString &workspaceRoot,
                                            const QString &title,
                                            const QString &description)
{
    try {
        QString escapedTitle = title;
        escapedTitle.replace("'", "\\'");
        
        QString escapedDesc = description;
        escapedDesc.replace("'", "\\'");
        
        QString cmd = QString("cd '%1' && gh pr create --title '%2' --body '%3'")
                          .arg(workspaceRoot)
                          .arg(escapedTitle)
                          .arg(escapedDesc);
        
        QProcess process;
        process.start("/bin/bash", QStringList() << "-c" << cmd);
        process.waitForFinished();
        
        return process.exitCode() == 0;
    } catch (...) {
        return false;
    }
}

QString CommitCommandManager::getPRUrl(const QString &workspaceRoot, const QString &branchName)
{
    try {
        QStringList args = {"pr", "view", branchName, "--json", "url", "--jq", ".url"};
        QString output = runGitCommand(workspaceRoot, args);
        return output.trimmed();
    } catch (...) {
        return "";
    }
}

QStringList CommitCommandManager::getGoneBranches(const QString &workspaceRoot)
{
    QStringList branches;
    try {
        QStringList args = {"branch", "-v"};
        QString output = runGitCommand(workspaceRoot, args);
        
        for (const auto &line : output.split("\n")) {
            if (line.contains("[gone]")) {
                QString branch = line.split("/").last().split("]").first();
                branches.append(branch.trimmed());
            }
        }
    } catch (...) {
        // Silent failure
    }
    return branches;
}

bool CommitCommandManager::deleteGoneBranch(const QString &workspaceRoot, const QString &branchName)
{
    try {
        QStringList args = {"branch", "-D", branchName};
        runGitCommand(workspaceRoot, args);
        return true;
    } catch (...) {
        return false;
    }
}

bool CommitCommandManager::deleteWorktree(const QString &workspaceRoot, const QString &branchName)
{
    try {
        QStringList args = {"worktree", "remove", branchName};
        runGitCommand(workspaceRoot, args);
        return true;
    } catch (...) {
        return false;
    }
}

void CommitCommandManager::setCommitStyle(const QString &style)
{
    m_commitStyle = style;
}

QString CommitCommandManager::getCommitStyle() const
{
    return m_commitStyle;
}

QString CommitCommandManager::runGitCommand(const QString &workspaceRoot, const QStringList &args)
{
    QProcess process;
    process.setWorkingDirectory(workspaceRoot);
    
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    process.setProcessEnvironment(env);
    
    process.start("git", args);
    
    if (!process.waitForFinished()) {
        throw std::runtime_error("Git command timeout");
    }
    
    if (process.exitCode() != 0) {
        QString errorMsg = QString::fromUtf8(process.readAllStandardError());
        throw std::runtime_error(errorMsg.toStdString());
    }
    
    return QString::fromUtf8(process.readAllStandardOutput());
}

QStringList CommitCommandManager::parseGitOutput(const QString &output)
{
    return output.split("\n", Qt::SkipEmptyParts);
}

bool CommitCommandManager::validateWorkspaceRoot(const QString &workspaceRoot)
{
    QDir dir(workspaceRoot);
    return dir.exists() && hasGitRepository(workspaceRoot);
}

bool CommitCommandManager::hasGitRepository(const QString &workspaceRoot)
{
    QDir gitDir(workspaceRoot + "/.git");
    return gitDir.exists();
}
