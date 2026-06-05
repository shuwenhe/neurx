#include "GitService.h"
#include <QProcess>
#include <QDir>
#include <QFileInfo>

class GitService::Impl {
public:
    QString gitPath = "git";
    QString workingDirectory;
    
    QString executeGit(const QStringList& args) {
        QProcess process;
        process.setWorkingDirectory(workingDirectory);
        process.start(gitPath, args);
        
        if (!process.waitForFinished()) {
            return QString();
        }
        
        return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    }
};

GitService* GitService::instance() {
    static GitService s_instance;
    return &s_instance;
}

GitService::GitService()
    : m_impl(std::make_unique<Impl>()) {
}

GitService::~GitService() = default;

bool GitService::initRepository(const QString& path) {
    m_impl->workingDirectory = path;
    QString result = m_impl->executeGit(QStringList() << "init");
    return !result.isEmpty();
}

bool GitService::isRepository(const QString& path) const {
    QDir dir(path);
    return dir.exists(".git");
}

QString GitService::getRepositoryRoot(const QString& path) const {
    QDir dir(path);
    while (!dir.isRoot()) {
        if (dir.exists(".git")) {
            return dir.absolutePath();
        }
        if (!dir.cdUp()) {
            break;
        }
    }
    return QString();
}

QList<GitFileStatus> GitService::getStatus() {
    QList<GitFileStatus> results;
    
    QString output = m_impl->executeGit(QStringList() << "status" << "--porcelain");
    auto lines = output.split('\n', Qt::SkipEmptyParts);
    
    for (const auto& line : lines) {
        if (line.size() < 3) continue;
        
        GitFileStatus status;
        status.stagedStatus = line[0];
        status.workingStatus = line[1];
        status.path = line.mid(3);
        status.status = (status.stagedStatus == ' ' && status.workingStatus == ' ') 
                       ? "unchanged" : "modified";
        
        results.append(status);
    }
    
    return results;
}

QString GitService::getStatus(const QString& filePath) {
    for (const auto& status : getStatus()) {
        if (status.path == filePath) {
            return status.status;
        }
    }
    return QString();
}

QList<GitCommit> GitService::getLog(int maxCount) {
    QList<GitCommit> results;
    
    QString output = m_impl->executeGit(QStringList()
        << "log"
        << "-n" << QString::number(maxCount)
        << "--format=%H|%an|%ae|%s|%ct");
    
    auto lines = output.split('\n', Qt::SkipEmptyParts);
    for (const auto& line : lines) {
        auto parts = line.split('|');
        if (parts.size() >= 5) {
            GitCommit commit;
            commit.hash = parts[0];
            commit.author = parts[1];
            commit.email = parts[2];
            commit.message = parts[3];
            commit.timestamp = parts[4].toLongLong();
            results.append(commit);
        }
    }
    
    return results;
}

QList<GitCommit> GitService::getBlame(const QString& filePath) {
    // Placeholder - would need full blame parsing
    return QList<GitCommit>();
}

GitCommit GitService::getCommit(const QString& hash) {
    GitCommit commit;
    
    QString output = m_impl->executeGit(QStringList()
        << "show" << hash << "--format=%H|%an|%ae|%s|%ct" << "-s");
    
    auto parts = output.split('|');
    if (parts.size() >= 5) {
        commit.hash = parts[0];
        commit.author = parts[1];
        commit.email = parts[2];
        commit.message = parts[3];
        commit.timestamp = parts[4].toLongLong();
    }
    
    return commit;
}

QList<GitBranch> GitService::getBranches() {
    QList<GitBranch> results;
    
    QString output = m_impl->executeGit(QStringList() << "branch" << "-a");
    auto lines = output.split('\n', Qt::SkipEmptyParts);
    
    for (const auto& line : lines) {
        GitBranch branch;
        branch.isCurrent = line[0] == '*';
        branch.name = line.mid(2).trimmed();
        branch.isLocal = !branch.name.startsWith("remotes/");
        
        results.append(branch);
    }
    
    return results;
}

QString GitService::getCurrentBranch() {
    QString output = m_impl->executeGit(QStringList() << "rev-parse" << "--abbrev-ref" << "HEAD");
    return output;
}

bool GitService::createBranch(const QString& name) {
    QString output = m_impl->executeGit(QStringList() << "branch" << name);
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::deleteBranch(const QString& name) {
    QString output = m_impl->executeGit(QStringList() << "branch" << "-d" << name);
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::switchBranch(const QString& name) {
    QString output = m_impl->executeGit(QStringList() << "checkout" << name);
    if (!output.contains("error", Qt::CaseInsensitive)) {
        emit branchChanged(name);
        return true;
    }
    return false;
}

bool GitService::stage(const QString& filePath) {
    QString output = m_impl->executeGit(QStringList() << "add" << filePath);
    emit statusChanged();
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::stageAll() {
    QString output = m_impl->executeGit(QStringList() << "add" << ".");
    emit statusChanged();
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::unstage(const QString& filePath) {
    QString output = m_impl->executeGit(QStringList() << "reset" << "HEAD" << filePath);
    emit statusChanged();
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::unstageAll() {
    QString output = m_impl->executeGit(QStringList() << "reset" << "HEAD");
    emit statusChanged();
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::commit(const QString& message) {
    QString output = m_impl->executeGit(QStringList() << "commit" << "-m" << message);
    emit statusChanged();
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::push(const QString& remote, const QString& branch) {
    QStringList args;
    args << "push" << remote;
    if (!branch.isEmpty()) {
        args << branch;
    }
    QString output = m_impl->executeGit(args);
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::pull(const QString& remote, const QString& branch) {
    QStringList args;
    args << "pull" << remote;
    if (!branch.isEmpty()) {
        args << branch;
    }
    QString output = m_impl->executeGit(args);
    emit statusChanged();
    return !output.contains("error", Qt::CaseInsensitive);
}

QString GitService::getDiff(const QString& filePath) {
    return m_impl->executeGit(QStringList() << "diff" << filePath);
}

QString GitService::getDiffStaged(const QString& filePath) {
    return m_impl->executeGit(QStringList() << "diff" << "--staged" << filePath);
}

QString GitService::getDiffCommit(const QString& hash) {
    return m_impl->executeGit(QStringList() << "show" << hash);
}

QStringList GitService::getRemotes() {
    QString output = m_impl->executeGit(QStringList() << "remote");
    return output.split('\n', Qt::SkipEmptyParts);
}

QString GitService::getRemoteUrl(const QString& remote) {
    return m_impl->executeGit(QStringList() << "remote" << "get-url" << remote);
}

bool GitService::addRemote(const QString& name, const QString& url) {
    QString output = m_impl->executeGit(QStringList() << "remote" << "add" << name << url);
    return !output.contains("error", Qt::CaseInsensitive);
}

bool GitService::removeRemote(const QString& name) {
    QString output = m_impl->executeGit(QStringList() << "remote" << "remove" << name);
    return !output.contains("error", Qt::CaseInsensitive);
}
