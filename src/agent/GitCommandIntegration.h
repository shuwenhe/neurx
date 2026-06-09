#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QDateTime>

/**
 * @class GitCommandIntegration
 * @brief Git命令集成系统 - 高级Git操作封装
 * 
 * 提供高级Git操作：
 * - 分支管理
 * - 提交历史
 * - 标签管理
 * - Stash操作
 * - 远程操作
 * - 冲突解决
 */
class GitCommandIntegration : public QObject {
    Q_OBJECT

public:
    struct BranchInfo {
        QString name;
        bool isLocal = true;
        bool isTracking = false;
        QString trackingBranch;
        QString lastCommit;
        QDateTime lastModified;
        int commitsAhead = 0;
        int commitsBehind = 0;
    };

    struct CommitInfo {
        QString hash;
        QString shortHash;
        QString author;
        QString message;
        QDateTime date;
        QStringList files;
        int additions = 0;
        int deletions = 0;
    };

    struct DiffInfo {
        QString file;
        int additions = 0;
        int deletions = 0;
        QString status;  // A, M, D, R, etc.
    };

    explicit GitCommandIntegration(QObject *parent = nullptr);
    ~GitCommandIntegration();

    // 初始化
    bool initialize(const QString &workspaceRoot);
    bool isInitialized() const;

    // 分支操作
    QList<BranchInfo> listBranches();
    BranchInfo getCurrentBranch();
    bool switchBranch(const QString &branchName);
    bool createBranch(const QString &branchName, bool switchTo = false);
    bool deleteBranch(const QString &branchName);
    bool mergeBranch(const QString &branchName);

    // 提交操作
    QList<CommitInfo> getCommitHistory(int count = 50);
    CommitInfo getCommitInfo(const QString &commitHash);
    QList<DiffInfo> getCommitDiff(const QString &commitHash);
    bool revertCommit(const QString &commitHash);
    bool cherryPickCommit(const QString &commitHash);

    // 暂存操作
    QStringList listStashes();
    bool createStash(const QString &message = "");
    bool applyStash(int stashIndex = 0);
    bool dropStash(int stashIndex = 0);
    bool popStash(int stashIndex = 0);

    // 远程操作
    QStringList listRemotes();
    bool addRemote(const QString &name, const QString &url);
    bool removeRemote(const QString &name);
    bool fetchFromRemote(const QString &remoteName = "origin");
    bool pushToRemote(const QString &remoteName = "origin", const QString &branch = "");
    bool pullFromRemote(const QString &remoteName = "origin", const QString &branch = "");

    // 标签操作
    QStringList listTags();
    bool createTag(const QString &tagName, const QString &message = "");
    bool deleteTag(const QString &tagName);
    bool pushTag(const QString &tagName, const QString &remoteName = "origin");

    // 状态查询
    QJsonObject getRepositoryStatus();
    int getUncommittedChanges();
    QStringList getUntrackedFiles();
    bool hasConflicts();

    // 冲突解决
    QList<QString> getConflictingFiles();
    QString getConflictContent(const QString &filePath);
    bool resolveConflict(const QString &filePath, const QString &resolution);

    // 配置
    QString getConfigValue(const QString &key);
    void setConfigValue(const QString &key, const QString &value);

    // 统计
    struct RepositoryStats {
        int totalCommits = 0;
        int totalBranches = 0;
        int totalAuthors = 0;
        QStringList topAuthors;
        QDateTime oldestCommit;
        QDateTime newestCommit;
    };
    
    RepositoryStats getRepositoryStats();

signals:
    void branchChanged(const QString &branchName);
    void commitCreated(const QString &commitHash);
    void fileModified(const QString &filePath);
    void conflictDetected(const QStringList &files);
    void pushCompleted(bool success);
    void pullCompleted(bool success);

private:
    QString m_workspaceRoot;
    bool m_initialized = false;

    // 辅助方法
    QString executeGitCommand(const QStringList &args, bool *success = nullptr);
    QJsonObject parseGitOutput(const QString &output);
    bool validateWorkspace();
};

/**
 * @class IterativeFeedbackLoop
 * @brief 迭代反馈循环系统 - 管理代码改进的迭代反馈
 */
class IterativeFeedbackLoop : public QObject {
    Q_OBJECT

public:
    struct FeedbackItem {
        QString id;
        QString category;           // "performance", "quality", "style", etc.
        QString message;
        QString severity;           // "info", "warning", "error"
        QString suggestedFix;
        bool applied = false;
        QDateTime timestamp;
    };

    struct IterationFeedback {
        QString iterationId;
        QList<FeedbackItem> items;
        double overallScore = 0.0;
        int issuesResolved = 0;
        int newIssuesFound = 0;
        QString conclusion;
    };

    explicit IterativeFeedbackLoop(QObject *parent = nullptr);
    ~IterativeFeedbackLoop();

    // 反馈收集
    void collectFeedback(const QString &iterationId,
                        const QString &category,
                        const QString &message,
                        const QString &severity,
                        const QString &suggestedFix = "");
    
    // 反馈应用
    bool applyFeedback(const QString &feedbackId, const QString &fix);
    
    // 迭代分析
    IterationFeedback analyzeIteration(const QString &iterationId);
    double calculateIterationScore(const QString &iterationId);
    QString generateIterationReport(const QString &iterationId);

    // 趋势分析
    double getTrendScore(int recentIterations = 5);
    QStringList getCommonIssues(int topCount = 5);
    QStringList getResolvedIssues();

    // 建议
    QString suggestNextImprovement(const QString &iterationId);
    QStringList getHighPriorityIssues();

    // 历史
    QList<IterationFeedback> getIterationHistory();
    void clearHistory();

signals:
    void feedbackCollected(const FeedbackItem &item);
    void feedbackApplied(const QString &feedbackId);
    void iterationAnalyzed(const QString &iterationId, double score);
    void improvementSuggested(const QString &suggestion);

private:
    QMap<QString, QList<FeedbackItem>> m_feedbackMap;
    QList<IterationFeedback> m_history;

    // 辅助方法
    QString generateFeedbackId();
    double calculateScore(const QList<FeedbackItem> &items);
    QString categorizeFeedback(const QString &message);
};
