#pragma once

#include "GitWorkflow.h"
#include <QProcess>
#include <QMutex>

namespace neurx {

// Forward declaration
class LLMProvider;

/**
 * @class DefaultGitWorkflow
 * @brief Default implementation of Git workflow automation
 */
class DefaultGitWorkflow : public GitWorkflow {
    Q_OBJECT
    
public:
    explicit DefaultGitWorkflow(QObject* parent = nullptr);
    ~DefaultGitWorkflow() override = default;
    
    // Set LLM provider for commit message generation
    void setLLMProvider(LLMProvider* provider);
    
    // GitWorkflow interface
    bool isGitRepository(const QString& path) const override;
    GitRepository getRepositoryInfo(const QString& path) const override;
    QString getCurrentBranch(const QString& path) const override;
    QList<GitBranch> getBranches(const QString& path, bool includeRemote) const override;
    
    QList<GitFileStatus> getFileStatus(const QString& path) const override;
    QStringList getStagedFiles(const QString& path) const override;
    QStringList getUnstagedFiles(const QString& path) const override;
    QString getFileDiff(const QString& path, const QString& filePath, bool staged) const override;
    
    void generateCommitMessage(const QString& path,
                              std::function<void(const QString&)> callback) override;
    void commit(const QString& path,
               const CommitOptions& options,
               std::function<void(bool, const QString&)> callback) override;
    void stageFiles(const QString& path,
                   const QStringList& files,
                   std::function<void(bool, const QString&)> callback) override;
    void unstageFiles(const QString& path,
                     const QStringList& files,
                     std::function<void(bool, const QString&)> callback) override;
    
    void createBranch(const QString& path,
                     const QString& branchName,
                     bool checkout,
                     std::function<void(bool, const QString&)> callback) override;
    void checkoutBranch(const QString& path,
                       const QString& branchName,
                       std::function<void(bool, const QString&)> callback) override;
    void deleteBranch(const QString& path,
                     const QString& branchName,
                     bool force,
                     std::function<void(bool, const QString&)> callback) override;
    
    void push(const QString& path,
             const PushOptions& options,
             std::function<void(bool, const QString&)> callback) override;
    void pull(const QString& path,
             bool rebase,
             std::function<void(bool, const QString&)> callback) override;
    void fetch(const QString& path,
              const QString& remote,
              std::function<void(bool, const QString&)> callback) override;
    
    void createPullRequest(const QString& path,
                          const PROptions& options,
                          std::function<void(bool, const PullRequest&)> callback) override;
    void getPullRequests(const QString& path,
                        std::function<void(const QList<PullRequest>&)> callback) override;
    
    QList<GitCommit> getCommitHistory(const QString& path, int maxCount) const override;
    QList<GitCommit> getFileHistory(const QString& path,
                                   const QString& filePath,
                                   int maxCount) const override;
    
private:
    LLMProvider* m_llmProvider;
    mutable QMutex m_mutex;
    
    // Helper methods
    QString runGitCommand(const QString& workdir,
                         const QStringList& args,
                         bool* success = nullptr) const;
    void runGitCommandAsync(const QString& workdir,
                           const QStringList& args,
                           std::function<void(bool, const QString&)> callback);
    
    GitFileStatus parseFileStatus(const QString& line) const;
    GitCommit parseCommit(const QString& output) const;
    GitBranch parseBranch(const QString& line) const;
    
    QString detectRemoteService(const QString& remoteUrl) const;
    void createGitHubPR(const QString& path,
                       const PROptions& options,
                       std::function<void(bool, const PullRequest&)> callback);
    void createGitLabPR(const QString& path,
                       const PROptions& options,
                       std::function<void(bool, const PullRequest&)> callback);
    
    QString analyzeChangesForCommit(const QString& path) const;
    QString generateCommitPrompt(const QString& diffContent) const;
};

} // namespace neurx
