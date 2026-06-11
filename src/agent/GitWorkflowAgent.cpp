#include "GitWorkflowAgent.h"
#include "GitAutomationManager.h"
#include "CommitCommandManager.h"
#include <QDebug>
#include <QDateTime>

namespace neurx {

GitWorkflowAgent::GitWorkflowAgent(QObject* parent)
    : SpecializedAgent(AgentConfig{
        "git-workflow-agent",
        "Git Workflow Agent",
        "Expert in Git operations, commit message generation, and PR management",
        AgentExpertise::General,
        // System Prompt
        "You are a Git expert. Your goal is to help users manage their Git workflows. "
        "When generating commit messages, use the Conventional Commits format. "
        "Be concise but descriptive. Analyze the diff to understand the changes.",
        "gpt-4o", // Default model
        0.3,      // Lower temperature for consistent messages
        1000,
        128000,
        {"git-add", "git-commit", "git-push", "gh-pr-create"},
        {"git", "gh"},
        {},
        false,
        60,
        3,
        false,
        "What changes should I commit?",
        {"/commit", "/commit-push-pr"},
        {}
    }, parent)
{
    m_gitManager = new ::GitAutomationManager(this);
    m_commitCommandManager = new ::CommitCommandManager(this);
}

GitWorkflowAgent::~GitWorkflowAgent() = default;

void GitWorkflowAgent::executeTask(const AgentTask& task,
                                 std::function<void(const AgentResult&)> callback)
{
    QString query = task.query.trimmed();
    QString workspacePath = task.context.value("workspacePath").toString();

    if (workspacePath.isEmpty()) {
        workspacePath = ".";
    }

    emit taskStarted(task.taskId);

    if (query.startsWith("/commit-push-pr")) {
        // Implement commit-push-pr logic
        executePushAndPR("Feature update", "Automated PR created by NeurX Code", workspacePath, callback);
    } else if (query.startsWith("/commit")) {
        createSmartCommit(query, workspacePath, callback);
    } else if (query.startsWith("/clean_gone")) {
        cleanupMergedBranches(workspacePath, callback);
    } else {
        // General git advice or other operations
        AgentResult result;
        result.success = false;
        result.taskId = task.taskId;
        result.agentId = id();
        result.error = "Unknown git command: " + query;
        callback(result);
        emit taskCompleted(task.taskId, false);
    }
}

void GitWorkflowAgent::cancelTask(const QString& taskId)
{
    // Implementation for cancellation if needed
}

void GitWorkflowAgent::createSmartCommit(const QString& context,
                                        const QString& workspacePath,
                                        std::function<void(const AgentResult&)> callback)
{
    // 1. Get Git context via the public API.
    const QString status = m_gitManager->getRepositoryStatus();
    const QStringList stagedFiles = m_gitManager->getStagedFiles();
    const QStringList unstagedFiles = m_gitManager->getUnstagedFiles();
    const auto recentCommits = m_gitManager->getCommitHistory(5);
    QStringList recentMessages;
    for (const auto &commit : recentCommits) {
        recentMessages.append(commit.message);
    }
    const QString diff = QStringLiteral("Staged files: %1\nUnstaged files: %2")
                             .arg(stagedFiles.join(", "))
                             .arg(unstagedFiles.join(", "));
    const QString recentLog = recentMessages.join("\n");

    // 2. Generate Commit Message with LLM
    generateCommitMessageWithLLM(diff, status, recentLog, [this, workspacePath, callback](const QString& message) {
        AgentResult result;
        result.agentId = id();

        if (message.isEmpty()) {
            result.success = false;
            result.error = "Failed to generate commit message";
            callback(result);
            return;
        }

        // 3. Execute Commit
        bool success = m_gitManager->smartCommit(message);
        result.success = success;
        if (success) {
            result.result = "Successfully created commit: " + message;
        } else {
            result.error = "Failed to execute git commit";
        }

        callback(result);
    });
}

void GitWorkflowAgent::executePushAndPR(const QString& title,
                                      const QString& description,
                                      const QString& workspacePath,
                                      std::function<void(const AgentResult&)> callback)
{
    // Implementation of the full workflow
    bool success = m_commitCommandManager->executeCommitPushPR(workspacePath);

    AgentResult result;
    result.success = success;
    result.agentId = id();
    if (success) {
        result.result = "Successfully pushed and created PR";
    } else {
        result.error = "Failed to push and create PR";
    }
    callback(result);
}

void GitWorkflowAgent::cleanupMergedBranches(const QString& workspacePath,
                                           std::function<void(const AgentResult&)> callback)
{
    bool success = m_commitCommandManager->executeCleanGone(workspacePath);

    AgentResult result;
    result.success = success;
    result.agentId = id();
    if (success) {
        result.result = "Successfully cleaned up gone branches";
    } else {
        result.error = "Failed to cleanup branches";
    }
    callback(result);
}

void GitWorkflowAgent::generateCommitMessageWithLLM(const QString& diff,
                                                  const QString& status,
                                                  const QString& recentLog,
                                                  std::function<void(const QString&)> callback)
{
    // In a real implementation, this would call m_llmProvider
    // For now, we'll simulate or use a fallback

    if (diff.isEmpty()) {
        callback("");
        return;
    }

    // Mocking the LLM response for now as we don't have the full LLMProvider implementation details here
    // In a full implementation, we'd use m_llmProvider->complete()

    QString prompt = QString(
        "Generate a commit message for the following changes:\n\n"
        "Status:\n%1\n\n"
        "Diff:\n%2\n\n"
        "Recent commits:\n%3\n\n"
        "Return ONLY the commit message."
    ).arg(status).arg(diff).arg(recentLog);

    // TODO: Connect to actual LLM provider.
    // For now, use the manager's basic generator as fallback.
    QStringList changedFiles = m_gitManager->getStagedFiles();
    callback(m_gitManager->generateCommitMessage(changedFiles, ::GitAutomationManager::Feature));
}

} // namespace neurx
