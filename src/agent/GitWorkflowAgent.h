#pragma once

#include "SpecializedAgents.h"
#include <QStringList>
#include <QVariantMap>

class GitAutomationManager;
class CommitCommandManager;

namespace neurx {

/**
 * @class GitWorkflowAgent
 * @brief Specialized agent for Git workflows (commit, push, PR creation)
 *
 * Inspired by Claude Code's git integration.
 */
class GitWorkflowAgent : public SpecializedAgent {
    Q_OBJECT

public:
    explicit GitWorkflowAgent(QObject* parent = nullptr);
    ~GitWorkflowAgent() override;

    void executeTask(const AgentTask& task,
                    std::function<void(const AgentResult&)> callback) override;
    void cancelTask(const QString& taskId) override;

    // Specialized workflow methods
    void createSmartCommit(const QString& context,
                          const QString& workspacePath,
                          std::function<void(const AgentResult&)> callback);

    void executePushAndPR(const QString& title,
                         const QString& description,
                         const QString& workspacePath,
                         std::function<void(const AgentResult&)> callback);

    void cleanupMergedBranches(const QString& workspacePath,
                              std::function<void(const AgentResult&)> callback);

private:
    ::GitAutomationManager* m_gitManager;
    ::CommitCommandManager* m_commitCommandManager;

    // Helper to generate commit message using LLM
    void generateCommitMessageWithLLM(const QString& diff,
                                     const QString& status,
                                     const QString& recentLog,
                                     std::function<void(const QString&)> callback);
};

} // namespace neurx
