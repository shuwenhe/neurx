#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * @file GitWorkflow.h
 * @brief Git workflow automation inspired by Claude Code
 * 
 * Implements:
 * - Smart commit message generation
 * - Staged file analysis
 * - PR creation and management
 * - Branch operations
 * - Diff and status tracking
 */

namespace neurx {

/**
 * @enum GitStatus
 * @brief Git file status
 */
enum class GitStatus {
    Unmodified,
    Modified,
    Added,
    Deleted,
    Renamed,
    Copied,
    Untracked,
    Ignored,
    Conflicted
};

/**
 * @struct GitFileStatus
 * @brief Status of a single file
 */
struct GitFileStatus {
    QString path;                   // File path
    GitStatus status;               // Status
    GitStatus stagedStatus;         // Staged status
    bool staged;                    // Is staged?
    int additions;                  // Lines added
    int deletions;                  // Lines deleted
    QString oldPath;                // Old path (for renames)
};

/**
 * @struct GitCommit
 * @brief Git commit info
 */
struct GitCommit {
    QString hash;                   // Commit hash (SHA)
    QString shortHash;              // Short hash
    QString message;                // Commit message
    QString author;                 // Author name
    QString email;                  // Author email
    QDateTime timestamp;            // Commit time
    QStringList files;              // Changed files
    int additions;                  // Total additions
    int deletions;                  // Total deletions
};

/**
 * @struct GitBranch
 * @brief Git branch info
 */
struct GitBranch {
    QString name;                   // Branch name
    bool current;                   // Is current branch?
    bool remote;                    // Is remote branch?
    QString upstream;               // Upstream branch
    int aheadBy;                    // Commits ahead
    int behindBy;                   // Commits behind
};

/**
 * @struct GitRepository
 * @brief Git repository info
 */
struct GitRepository {
    QString rootPath;               // Repository root
    QString currentBranch;          // Current branch
    bool hasUncommitted;            // Has uncommitted changes?
    bool hasStaged;                 // Has staged changes?
    bool hasUntracked;              // Has untracked files?
    QString remoteUrl;              // Remote URL
    QString remoteName;             // Remote name (usually "origin")
};

/**
 * @struct PullRequest
 * @brief Pull request info
 */
struct PullRequest {
    QString id;                     // PR ID/number
    QString title;                  // PR title
    QString description;            // PR description
    QString sourceBranch;           // Source branch
    QString targetBranch;           // Target branch
    QString url;                    // PR URL
    QString status;                 // open, merged, closed
    QString author;                 // PR author
    QDateTime createdAt;            // Creation time
    QStringList labels;             // Labels
    QStringList reviewers;          // Reviewers
};

/**
 * @struct CommitOptions
 * @brief Options for commit operation
 */
struct CommitOptions {
    QString message;                // Commit message
    bool addAll;                    // Stage all changes?
    bool amend;                     // Amend last commit?
    bool signOff;                   // Add sign-off?
    bool noVerify;                  // Skip hooks?
    QString author;                 // Override author
    QStringList files;              // Specific files to commit
};

/**
 * @struct PushOptions
 * @brief Options for push operation
 */
struct PushOptions {
    QString remote;                 // Remote name (default: "origin")
    QString branch;                 // Branch name (default: current)
    bool force;                     // Force push?
    bool setUpstream;               // Set upstream?
    bool tags;                      // Push tags?
};

/**
 * @struct PROptions
 * @brief Options for PR creation
 */
struct PROptions {
    QString title;                  // PR title
    QString description;            // PR description
    QString targetBranch;           // Target branch (default: main/master)
    QString sourceBranch;           // Source branch (default: current)
    QStringList labels;             // Labels to add
    QStringList reviewers;          // Reviewers to request
    bool draft;                     // Create as draft?
    bool autoMerge;                 // Enable auto-merge?
};

/**
 * @class GitWorkflow
 * @brief Git workflow automation
 */
class GitWorkflow : public QObject {
    Q_OBJECT
    
public:
    explicit GitWorkflow(QObject* parent = nullptr);
    virtual ~GitWorkflow() = default;
    
    // ── Repository Info ─────────────────────────────────────────
    
    /**
     * @brief Check if directory is a git repository
     * @param path Directory path
     * @return true if git repository
     */
    virtual bool isGitRepository(const QString& path) const = 0;
    
    /**
     * @brief Get repository info
     * @param path Repository path
     * @return Repository info
     */
    virtual GitRepository getRepositoryInfo(const QString& path) const = 0;
    
    /**
     * @brief Get current branch name
     * @param path Repository path
     * @return Branch name
     */
    virtual QString getCurrentBranch(const QString& path) const = 0;
    
    /**
     * @brief Get all branches
     * @param path Repository path
     * @param includeRemote Include remote branches?
     * @return List of branches
     */
    virtual QList<GitBranch> getBranches(const QString& path,
                                        bool includeRemote = false) const = 0;
    
    // ── File Status ─────────────────────────────────────────────
    
    /**
     * @brief Get file statuses
     * @param path Repository path
     * @return List of file statuses
     */
    virtual QList<GitFileStatus> getFileStatus(const QString& path) const = 0;
    
    /**
     * @brief Get staged files
     * @param path Repository path
     * @return List of staged files
     */
    virtual QStringList getStagedFiles(const QString& path) const = 0;
    
    /**
     * @brief Get unstaged files
     * @param path Repository path
     * @return List of unstaged files
     */
    virtual QStringList getUnstagedFiles(const QString& path) const = 0;
    
    /**
     * @brief Get diff for file
     * @param path Repository path
     * @param filePath File path
     * @param staged Get staged diff?
     * @return Diff content
     */
    virtual QString getFileDiff(const QString& path,
                               const QString& filePath,
                               bool staged = false) const = 0;
    
    // ── Commit Operations ───────────────────────────────────────
    
    /**
     * @brief Generate commit message from staged changes
     * @param path Repository path
     * @param callback Callback with generated message
     */
    virtual void generateCommitMessage(const QString& path,
                                      std::function<void(const QString&)> callback) = 0;
    
    /**
     * @brief Create commit
     * @param path Repository path
     * @param options Commit options
     * @param callback Callback with result
     */
    virtual void commit(const QString& path,
                       const CommitOptions& options,
                       std::function<void(bool, const QString&)> callback) = 0;
    
    /**
     * @brief Stage files
     * @param path Repository path
     * @param files Files to stage (empty = all)
     * @param callback Callback with result
     */
    virtual void stageFiles(const QString& path,
                           const QStringList& files,
                           std::function<void(bool, const QString&)> callback) = 0;
    
    /**
     * @brief Unstage files
     * @param path Repository path
     * @param files Files to unstage (empty = all)
     * @param callback Callback with result
     */
    virtual void unstageFiles(const QString& path,
                             const QStringList& files,
                             std::function<void(bool, const QString&)> callback) = 0;
    
    // ── Branch Operations ───────────────────────────────────────
    
    /**
     * @brief Create new branch
     * @param path Repository path
     * @param branchName Branch name
     * @param checkout Checkout after creation?
     * @param callback Callback with result
     */
    virtual void createBranch(const QString& path,
                             const QString& branchName,
                             bool checkout,
                             std::function<void(bool, const QString&)> callback) = 0;
    
    /**
     * @brief Switch to branch
     * @param path Repository path
     * @param branchName Branch name
     * @param callback Callback with result
     */
    virtual void checkoutBranch(const QString& path,
                               const QString& branchName,
                               std::function<void(bool, const QString&)> callback) = 0;
    
    /**
     * @brief Delete branch
     * @param path Repository path
     * @param branchName Branch name
     * @param force Force deletion?
     * @param callback Callback with result
     */
    virtual void deleteBranch(const QString& path,
                             const QString& branchName,
                             bool force,
                             std::function<void(bool, const QString&)> callback) = 0;
    
    // ── Remote Operations ───────────────────────────────────────
    
    /**
     * @brief Push commits
     * @param path Repository path
     * @param options Push options
     * @param callback Callback with result
     */
    virtual void push(const QString& path,
                     const PushOptions& options,
                     std::function<void(bool, const QString&)> callback) = 0;
    
    /**
     * @brief Pull commits
     * @param path Repository path
     * @param rebase Use rebase?
     * @param callback Callback with result
     */
    virtual void pull(const QString& path,
                     bool rebase,
                     std::function<void(bool, const QString&)> callback) = 0;
    
    /**
     * @brief Fetch from remote
     * @param path Repository path
     * @param remote Remote name
     * @param callback Callback with result
     */
    virtual void fetch(const QString& path,
                      const QString& remote,
                      std::function<void(bool, const QString&)> callback) = 0;
    
    // ── Pull Request Operations ─────────────────────────────────
    
    /**
     * @brief Create pull request
     * @param path Repository path
     * @param options PR options
     * @param callback Callback with PR info
     */
    virtual void createPullRequest(const QString& path,
                                  const PROptions& options,
                                  std::function<void(bool, const PullRequest&)> callback) = 0;
    
    /**
     * @brief Get pull requests
     * @param path Repository path
     * @param callback Callback with PR list
     */
    virtual void getPullRequests(const QString& path,
                                std::function<void(const QList<PullRequest>&)> callback) = 0;
    
    // ── History ─────────────────────────────────────────────────
    
    /**
     * @brief Get commit history
     * @param path Repository path
     * @param maxCount Max commits to retrieve
     * @return List of commits
     */
    virtual QList<GitCommit> getCommitHistory(const QString& path,
                                             int maxCount = 100) const = 0;
    
    /**
     * @brief Get commits for file
     * @param path Repository path
     * @param filePath File path
     * @param maxCount Max commits
     * @return List of commits
     */
    virtual QList<GitCommit> getFileHistory(const QString& path,
                                           const QString& filePath,
                                           int maxCount = 50) const = 0;
    
signals:
    /**
     * @brief Emitted when commit is created
     * @param commitHash Commit hash
     */
    void commitCreated(const QString& commitHash);
    
    /**
     * @brief Emitted when changes are pushed
     * @param branch Branch name
     */
    void pushed(const QString& branch);
    
    /**
     * @brief Emitted when PR is created
     * @param pr Pull request info
     */
    void pullRequestCreated(const PullRequest& pr);
    
    /**
     * @brief Emitted when repository status changes
     * @param path Repository path
     */
    void statusChanged(const QString& path);
};

// Utility functions
QString gitStatusToString(GitStatus status);
GitStatus stringToGitStatus(const QString& str);

} // namespace neurx
