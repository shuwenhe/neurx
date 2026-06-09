#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QProcess>
#include <memory>

/**
 * @class GitAutomationManager
 * @brief Automated git operations (commit, push, PR creation)
 * 
 * Features:
 * - Smart commit message generation
 * - Multi-commit batching
 * - Conflict detection and resolution
 * - Push automation with retry
 * - PR creation and template support
 * - Branch management
 * - Stash and rebase automation
 */

class GitAutomationManager : public QObject {
    Q_OBJECT

public:
    enum CommitType {
        Feature,
        BugFix,
        Refactor,
        Documentation,
        Performance,
        Security,
        ChoreTask
    };

    enum MergeStrategy {
        Merge,
        Rebase,
        SquashMerge,
        FastForward
    };

    struct CommitInfo {
        QString hash;
        QString message;
        QString author;
        QString timestamp;
        QStringList filesChanged;
        int additions;
        int deletions;
        CommitType type;
    };

    struct PullRequestInfo {
        QString number;
        QString title;
        QString description;
        QString branch;
        QString targetBranch;
        QString author;
        QStringList reviewers;
        QStringList labels;
        QString status;  // "open", "merged", "closed"
        QJsonObject metadata;
    };

    struct BranchInfo {
        QString name;
        QString remoteName;
        bool isLocal;
        bool isRemote;
        QString lastCommit;
        QString createdAt;
        QString author;
    };

    explicit GitAutomationManager(QObject* parent = nullptr);
    ~GitAutomationManager();

    // Commit operations
    QString generateCommitMessage(const QStringList& changedFiles, CommitType type);
    bool smartCommit(const QString& message, CommitType type = ChoreTask);
    bool batchCommit(const QVector<CommitInfo>& commits);
    bool amendCommit(const QString& newMessage);
    bool revertCommit(const QString& commitHash);
    CommitInfo getCommitInfo(const QString& commitHash);
    QVector<CommitInfo> getCommitHistory(int count = 50, const QString& branch = "HEAD");

    // Push operations
    bool pushBranch(const QString& branch = "", bool force = false, int maxRetries = 3);
    bool pushTags();
    bool pushWithAutoRebase();
    bool pushAndCreatePR(const QString& title, const QString& description);

    // Pull request operations
    bool createPullRequest(const QString& title, const QString& description,
                          const QString& targetBranch = "main",
                          const QStringList& reviewers = {});
    PullRequestInfo getPullRequestInfo(const QString& prNumber);
    bool updatePullRequest(const QString& prNumber, const QString& newTitle, 
                          const QString& newDescription);
    bool addReviewersToPR(const QString& prNumber, const QStringList& reviewers);
    bool mergePullRequest(const QString& prNumber, MergeStrategy strategy = Merge);
    bool closePullRequest(const QString& prNumber, const QString& reason = "");
    QVector<PullRequestInfo> listPullRequests(const QString& state = "open");
    QVector<PullRequestInfo> getPRsByAuthor(const QString& author);
    QVector<PullRequestInfo> getPRsByLabel(const QString& label);

    // Branch management
    bool createBranch(const QString& branchName, const QString& fromBranch = "main");
    bool deleteBranch(const QString& branchName, bool force = false);
    bool renameBranch(const QString& oldName, const QString& newName);
    bool switchBranch(const QString& branchName);
    BranchInfo getCurrentBranch();
    QVector<BranchInfo> listBranches(bool includeRemote = false);
    bool mergeBranch(const QString& sourceBranch, MergeStrategy strategy = Merge);
    bool rebaseBranch(const QString& targetBranch);

    // Conflict resolution
    struct ConflictInfo {
        QString file;
        QStringList conflictMarkers;
        QString currentContent;
        QString incomingContent;
    };
    QVector<ConflictInfo> detectConflicts();
    bool resolveConflict(const QString& file, const QString& resolution);
    QString generateMergeCommitMessage(const QString& sourceBranch);
    bool abortMerge();
    bool abortRebase();

    // Stash operations
    bool stashChanges(const QString& message = "");
    bool applyStash(const QString& stashId = "stash@{0}");
    bool popStash(const QString& stashId = "stash@{0}");
    bool dropStash(const QString& stashId = "stash@{0}");
    QStringList listStashes();

    // Status and information
    QStringList getUnstagedFiles();
    QStringList getStagedFiles();
    QStringList getUntrackedFiles();
    QString getRepositoryStatus();
    bool isRepositoryClean();
    bool isConflicted();
    QString getRemoteUrl(const QString& remoteName = "origin");
    QStringList getAllRemotes();

    // Tag operations
    bool createTag(const QString& tagName, const QString& message = "");
    bool deleteTag(const QString& tagName);
    QStringList listTags(const QString& pattern = "");
    QString getTagInfo(const QString& tagName);
    bool pushTag(const QString& tagName);

    // Advanced operations
    bool squashCommits(int count, const QString& squashMessage = "");
    bool cherryPickCommit(const QString& commitHash);
    bool resetToCommit(const QString& commitHash, bool hard = false);
    bool bisectStart(const QString& goodCommit, const QString& badCommit);
    bool bisectMark(bool good);

    // Configuration
    void setGitPath(const QString& path);
    void setCommitAuthor(const QString& name, const QString& email);
    void setAutoStagingEnabled(bool enabled);
    void setAutoRebaseOnPush(bool enabled);
    void setPRTemplate(const QString& templatePath);

    // Statistics
    struct GitStats {
        int totalCommits;
        int totalBranches;
        int totalTags;
        int totalPullRequests;
        QMap<CommitType, int> commitsByType;
        QString mostActiveAuthor;
    };
    GitStats getStatistics() const;

signals:
    void commitCreated(const QString& hash);
    void pushCompleted(const QString& branch);
    void prCreated(const QString& prNumber);
    void branchCreated(const QString& branchName);
    void conflictDetected(const QStringList& files);
    void operationFailed(const QString& error);

private:
    QString m_gitPath;
    QString m_commitAuthor;
    QString m_commitEmail;
    bool m_autoStaging;
    bool m_autoRebase;
    QString m_prTemplate;
    GitStats m_statistics;

    QString executeGitCommand(const QString& command);
    bool executeGitCommandBool(const QString& command);
    QStringList executeGitCommandList(const QString& command);
    QString generateUUID();
};
