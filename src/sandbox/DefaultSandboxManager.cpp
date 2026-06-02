#include "DefaultSandboxManager.h"
#include <QDebug>
#include <QStandardPaths>
#include <QSysInfo>
#include <QProcess>
#include <QCoreApplication>

DefaultSandboxManager::DefaultSandboxManager(QObject *parent)
    : SandboxManager(parent)
{
    // Initialize protected metadata paths
    m_protectedMetadataPaths << ".git" << ".agents" << ".codex" << ".env" 
                             << ".ssh" << ".aws" << ".kube";
}

DefaultSandboxManager::~DefaultSandboxManager()
{
}

QVector<SandboxType> DefaultSandboxManager::availableSandboxTypes() const
{
    QVector<SandboxType> available;
    
#ifdef Q_OS_LINUX
    // Check for bwrap
    if (QStandardPaths::findExecutable("bwrap") != "") {
        available.append(SandboxType::LinuxBubbleWrap);
    }
    
    // Check for Landlock support via /proc/sys/kernel/landlock
    // (This is a simplification; real check would need syscall)
    available.append(SandboxType::LinuxSeccomp);
    
#elif defined(Q_OS_MAC)
    available.append(SandboxType::MacosSeatbelt);
    
#elif defined(Q_OS_WIN)
    available.append(SandboxType::WindowsRestrictedToken);
#endif
    
    // None is always available as fallback
    available.append(SandboxType::None);
    
    return available;
}

SandboxType DefaultSandboxManager::recommendedSandboxType() const
{
#ifdef Q_OS_LINUX
    // Prefer bwrap if available, then seccomp
    if (QStandardPaths::findExecutable("bwrap") != "") {
        return SandboxType::LinuxBubbleWrap;
    }
    return SandboxType::LinuxSeccomp;
    
#elif defined(Q_OS_MAC)
    return SandboxType::MacosSeatbelt;
    
#elif defined(Q_OS_WIN)
    return SandboxType::WindowsRestrictedToken;
#endif
    
    return SandboxType::None;
}

bool DefaultSandboxManager::isSandboxTypeAvailable(SandboxType type) const
{
    auto available = availableSandboxTypes();
    return available.contains(type);
}

void DefaultSandboxManager::setDefaultSandboxMode(SandboxMode mode)
{
    QMutexLocker locker(&m_mutex);
    m_defaultMode = mode;
    emit policyChanged();
}

SandboxMode DefaultSandboxManager::getDefaultSandboxMode() const
{
    QMutexLocker locker(&m_mutex);
    return m_defaultMode;
}

void DefaultSandboxManager::setFileSystemPolicy(const FileSystemSandboxPolicy &policy)
{
    QMutexLocker locker(&m_mutex);
    m_fsPolicy = policy;
    emit policyChanged();
}

FileSystemSandboxPolicy DefaultSandboxManager::getFileSystemPolicy() const
{
    QMutexLocker locker(&m_mutex);
    return m_fsPolicy;
}

void DefaultSandboxManager::setNetworkPolicy(NetworkSandboxPolicy policy)
{
    QMutexLocker locker(&m_mutex);
    m_networkPolicy = policy;
    emit policyChanged();
}

NetworkSandboxPolicy DefaultSandboxManager::getNetworkPolicy() const
{
    QMutexLocker locker(&m_mutex);
    return m_networkPolicy;
}

void DefaultSandboxManager::addAllowedReadPath(const QString &path, bool recursive)
{
    QMutexLocker locker(&m_mutex);
    m_fsPolicy.allowedReadPaths.append(path);
    emit policyChanged();
}

void DefaultSandboxManager::addAllowedWritePath(const QString &path, bool recursive)
{
    QMutexLocker locker(&m_mutex);
    m_fsPolicy.allowedWritePaths.append(path);
    emit policyChanged();
}

void DefaultSandboxManager::addDeniedPath(const QString &path)
{
    QMutexLocker locker(&m_mutex);
    m_fsPolicy.deniedPaths.append(path);
    emit policyChanged();
}

void DefaultSandboxManager::clearPaths()
{
    QMutexLocker locker(&m_mutex);
    m_fsPolicy.allowedReadPaths.clear();
    m_fsPolicy.allowedWritePaths.clear();
    m_fsPolicy.deniedPaths.clear();
    emit policyChanged();
}

bool DefaultSandboxManager::canAccess(const QString &path, FileSystemAccessMode mode) const
{
    QMutexLocker locker(&m_mutex);
    
    // Check protected metadata first
    for (const auto &metaPath : m_protectedMetadataPaths) {
        if (path.contains(metaPath)) {
            return false;
        }
    }
    
    // Check explicit deny list
    for (const auto &deniedPath : m_fsPolicy.deniedPaths) {
        if (path.startsWith(deniedPath)) {
            return false;
        }
    }
    
    // Check access mode
    if (mode == FileSystemAccessMode::Read) {
        // Can read if in allowed list or no restrictions
        return m_fsPolicy.allowedReadPaths.empty() || 
               std::any_of(m_fsPolicy.allowedReadPaths.begin(),
                          m_fsPolicy.allowedReadPaths.end(),
                          [&](const QString &p) { return path.startsWith(p); });
    } else if (mode == FileSystemAccessMode::Write) {
        // Can write only if explicitly allowed
        return std::any_of(m_fsPolicy.allowedWritePaths.begin(),
                          m_fsPolicy.allowedWritePaths.end(),
                          [&](const QString &p) { return path.startsWith(p); });
    }
    
    return false;
}

void DefaultSandboxManager::executeInSandbox(const SandboxExecRequest &request,
                                            std::function<void(int, const QString &, const QString &)> callback)
{
    if (m_readOnlyMode && request.writePermission != FileSystemAccessMode::Read) {
        if (callback) {
            callback(-1, "", "Read-only mode enabled");
        }
        return;
    }
    
    SandboxType sandboxType = recommendedSandboxType();
    
    if (sandboxType == SandboxType::LinuxBubbleWrap) {
        executeWithBwrap(request, callback);
    } else if (sandboxType == SandboxType::MacosSeatbelt) {
        executeWithSeatbelt(request, callback);
    } else {
        executeWithoutSandbox(request, callback);
    }
}

void DefaultSandboxManager::transformPermissions(const SandboxTransformRequest &request,
                                                 std::function<void(const FileSystemSandboxPolicy &)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    FileSystemSandboxPolicy transformed = m_fsPolicy;
    
    // Apply granular rules based on tool context
    if (!request.toolContext.isEmpty()) {
        // Could apply tool-specific policies here
    }
    
    locker.unlock();
    
    if (callback) {
        callback(transformed);
    }
}

QStringList DefaultSandboxManager::protectedMetadataPaths() const
{
    QMutexLocker locker(&m_mutex);
    return m_protectedMetadataPaths;
}

void DefaultSandboxManager::protectMetadataPath(const QString &path)
{
    QMutexLocker locker(&m_mutex);
    if (!m_protectedMetadataPaths.contains(path)) {
        m_protectedMetadataPaths.append(path);
    }
}

bool DefaultSandboxManager::isProtectedMetadata(const QString &path) const
{
    QMutexLocker locker(&m_mutex);
    return std::any_of(m_protectedMetadataPaths.begin(),
                      m_protectedMetadataPaths.end(),
                      [&](const QString &p) { return path.contains(p); });
}

void DefaultSandboxManager::setReadOnlyMode(bool enabled)
{
    QMutexLocker locker(&m_mutex);
    m_readOnlyMode = enabled;
}

bool DefaultSandboxManager::isReadOnlyMode() const
{
    QMutexLocker locker(&m_mutex);
    return m_readOnlyMode;
}

QVariantMap DefaultSandboxManager::getStats() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalExecutions"] = m_stats.totalExecutions;
    stats["successfulExecutions"] = m_stats.successfulExecutions;
    stats["failedExecutions"] = m_stats.failedExecutions;
    stats["accessDeniedCount"] = m_stats.accessDeniedCount;
    
    if (m_stats.totalExecutions > 0) {
        int successRate = (m_stats.successfulExecutions * 100) / m_stats.totalExecutions;
        stats["successRate"] = QString("%1%").arg(successRate);
    }
    
    return stats;
}

void DefaultSandboxManager::resetStats()
{
    QMutexLocker locker(&m_mutex);
    m_stats = ExecutionStats();
}

void DefaultSandboxManager::executeWithBwrap(const SandboxExecRequest &request,
                                            std::function<void(int, const QString &, const QString &)> callback)
{
    QStringList args = buildBwrapCommand(request);
    args << request.command;
    
    QProcess process;
    process.start("bwrap", args);
    
    if (!process.waitForFinished()) {
        QMutexLocker locker(&m_mutex);
        m_stats.failedExecutions++;
        locker.unlock();
        
        if (callback) {
            callback(-1, "", "Process failed to complete");
        }
        return;
    }
    
    QString output = process.readAllStandardOutput();
    QString error = process.readAllStandardError();
    int exitCode = process.exitCode();
    
    QMutexLocker locker(&m_mutex);
    m_stats.totalExecutions++;
    if (exitCode == 0) {
        m_stats.successfulExecutions++;
    } else {
        m_stats.failedExecutions++;
    }
    locker.unlock();
    
    if (callback) {
        callback(exitCode, output, error);
    }
}

void DefaultSandboxManager::executeWithSeatbelt(const SandboxExecRequest &request,
                                               std::function<void(int, const QString &, const QString &)> callback)
{
    // macOS Seatbelt integration would go here
    // For now, execute without sandbox
    executeWithoutSandbox(request, callback);
}

void DefaultSandboxManager::executeWithoutSandbox(const SandboxExecRequest &request,
                                                 std::function<void(int, const QString &, const QString &)> callback)
{
    QProcess process;
    process.start("/bin/bash", QStringList() << "-c" << request.command);
    
    if (!process.waitForFinished()) {
        QMutexLocker locker(&m_mutex);
        m_stats.failedExecutions++;
        locker.unlock();
        
        if (callback) {
            callback(-1, "", "Process failed");
        }
        return;
    }
    
    QString output = process.readAllStandardOutput();
    QString error = process.readAllStandardError();
    int exitCode = process.exitCode();
    
    QMutexLocker locker(&m_mutex);
    m_stats.totalExecutions++;
    if (exitCode == 0) {
        m_stats.successfulExecutions++;
    } else {
        m_stats.failedExecutions++;
    }
    locker.unlock();
    
    if (callback) {
        callback(exitCode, output, error);
    }
}

SandboxType DefaultSandboxManager::detectPlatformSandbox() const
{
    return recommendedSandboxType();
}

QStringList DefaultSandboxManager::buildBwrapCommand(const SandboxExecRequest &request) const
{
    QStringList args;
    
    args << "--tmpfs" << "/tmp";
    
    // Add allowed read paths
    for (const auto &path : m_fsPolicy.allowedReadPaths) {
        args << "--bind" << path << path;
    }
    
    // Add allowed write paths
    for (const auto &path : m_fsPolicy.allowedWritePaths) {
        args << "--bind" << path << path;
    }
    
    // Network policy
    if (m_networkPolicy == NetworkSandboxPolicy::DenyAll) {
        args << "--unshare-net";
    }
    
    return args;
}

#include "moc_DefaultSandboxManager.cpp"
