#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>

/**
 * @class CommitCommandManager
 * @brief Git提交命令管理器 - 实现/commit, /commit-push-pr, /clean_gone命令
 */
class CommitCommandManager : public QObject {
    Q_OBJECT

public:
    explicit CommitCommandManager(QObject *parent = nullptr);
    ~CommitCommandManager();

    // 命令执行接口
    bool executeCommit(const QString &workspaceRoot);
    bool executeCommitPushPR(const QString &workspaceRoot);
    bool executeCleanGone(const QString &workspaceRoot);

    // 提交信息生成
    QString generateCommitMessage(const QStringList &stagedChanges, 
                                  const QStringList &unstagedChanges,
                                  const QStringList &recentMessages);

    // Git状态检查
    QJsonObject getGitStatus(const QString &workspaceRoot);
    QStringList getStagedFiles(const QString &workspaceRoot);
    QStringList getUnstagedFiles(const QString &workspaceRoot);
    QStringList getRecentCommitMessages(const QString &workspaceRoot, int count = 5);

    // 分支管理
    bool createFeatureBranch(const QString &workspaceRoot, const QString &branchName);
    bool getCurrentBranch(const QString &workspaceRoot, QString &branchName);
    bool isOnMainBranch(const QString &workspaceRoot);

    // PR创建
    bool createPullRequest(const QString &workspaceRoot, 
                          const QString &title,
                          const QString &description);
    QString getPRUrl(const QString &workspaceRoot, const QString &branchName);

    // 清理操作
    QStringList getGoneBranches(const QString &workspaceRoot);
    bool deleteGoneBranch(const QString &workspaceRoot, const QString &branchName);
    bool deleteWorktree(const QString &workspaceRoot, const QString &branchName);

    // 配置
    void setCommitStyle(const QString &style);  // "conventional", "descriptive", etc.
    QString getCommitStyle() const;

signals:
    void commitCreated(const QString &commitHash, const QString &message);
    void branchCreated(const QString &branchName);
    void prCreated(const QString &prUrl);
    void branchCleaned(const QStringList &deletedBranches);
    void commandStarted(const QString &command);
    void commandCompleted(const QString &command);
    void commandFailed(const QString &command, const QString &error);

private:
    QString m_commitStyle;
    QMap<QString, QString> m_lastCommitHash;

    // 辅助方法
    QString runGitCommand(const QString &workspaceRoot, const QStringList &args);
    QStringList parseGitOutput(const QString &output);
    bool validateWorkspaceRoot(const QString &workspaceRoot);
    bool hasGitRepository(const QString &workspaceRoot);
};
