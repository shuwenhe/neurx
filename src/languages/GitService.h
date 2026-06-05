#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QStringList>

/**
 * @class GitService
 * @brief Git operations enhancement
 * 
 * Features:
 * - Git status
 * - Commit/Push/Pull
 * - Branch management
 * - Blame information
 * - Diff viewing
 */

struct GitCommit {
    QString hash;
    QString author;
    QString email;
    QString message;
    qint64 timestamp = 0;
};

struct GitBranch {
    QString name;
    bool isLocal = true;
    bool isCurrent = false;
    QString upstream;
};

struct GitFileStatus {
    QString path;
    QString status;  // "M", "A", "D", "??", etc.
    QString stagedStatus;
    QString workingStatus;
};

class GitService : public QObject {
    Q_OBJECT

public:
    static GitService* instance();
    
    // Repository management
    bool initRepository(const QString& path);
    bool isRepository(const QString& path) const;
    QString getRepositoryRoot(const QString& path) const;
    
    // Status
    QList<GitFileStatus> getStatus();
    QString getStatus(const QString& filePath);
    
    // Commits
    QList<GitCommit> getLog(int maxCount = 50);
    QList<GitCommit> getBlame(const QString& filePath);
    GitCommit getCommit(const QString& hash);
    
    // Branches
    QList<GitBranch> getBranches();
    QString getCurrentBranch();
    bool createBranch(const QString& name);
    bool deleteBranch(const QString& name);
    bool switchBranch(const QString& name);
    
    // Operations
    bool stage(const QString& filePath);
    bool stageAll();
    bool unstage(const QString& filePath);
    bool unstageAll();
    bool commit(const QString& message);
    bool push(const QString& remote = "origin", const QString& branch = QString());
    bool pull(const QString& remote = "origin", const QString& branch = QString());
    
    // Diff
    QString getDiff(const QString& filePath);
    QString getDiffStaged(const QString& filePath);
    QString getDiffCommit(const QString& hash);
    
    // Remote
    QStringList getRemotes();
    QString getRemoteUrl(const QString& remote);
    bool addRemote(const QString& name, const QString& url);
    bool removeRemote(const QString& name);

signals:
    void statusChanged();
    void branchChanged(const QString& branchName);
    void repositoryDetected(const QString& path);
    void gitError(const QString& error);

private:
    GitService();
    ~GitService() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
