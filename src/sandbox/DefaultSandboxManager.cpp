#include "DefaultSandboxManager.h"
#include <QMutexLocker>
#include <QDebug>
#include <QStandardPaths>
#include <QSysInfo>
#include <QProcess>
#include <QCoreApplication>
#include <algorithm>

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

    if (mode == FileSystemAccessMode::Write)
        return true;

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
    if (m_readOnlyMode && request.sandboxMode != SandboxMode::ReadOnly) {
        if (callback) {
            callback(-1, "", "Read-only mode enabled");
        }
        QMutexLocker locker(&m_mutex);
        m_stats.accessDeniedCount++;
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

void DefaultSandboxManager::recordExecutionEvent(const QVariantMap &event)
{
    emit sandboxExecutionEvent(event);
}

void DefaultSandboxManager::transformPermissions(const SandboxTransformRequest &request,
                                                 std::function<void(const FileSystemSandboxPolicy &)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    FileSystemSandboxPolicy transformed = m_fsPolicy;

    // Apply a lightweight transformation based on the requested tool and paths.
    for (const auto &path : request.requestedPaths) {
        if (!transformed.allowedReadPaths.contains(path)) {
            transformed.allowedReadPaths.append(path);
        }

        const bool looksWritable = request.toolName.contains("patch", Qt::CaseInsensitive)
            || request.toolName.contains("file", Qt::CaseInsensitive)
            || request.toolName.contains("write", Qt::CaseInsensitive)
            || request.toolName.contains("edit", Qt::CaseInsensitive);

        if (looksWritable && !m_readOnlyMode && !transformed.allowedWritePaths.contains(path)) {
            transformed.allowedWritePaths.append(path);
        }

        if (isProtectedMetadata(path) && !transformed.deniedPaths.contains(path)) {
            transformed.deniedPaths.append(path);
        }
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
    args << "--" << "/bin/bash" << "-lc" << request.commandLine;
    
    QProcess process;
    process.start("bwrap", args);

    if (!process.waitForStarted(5000)) {
        QMutexLocker locker(&m_mutex);
        m_stats.failedExecutions++;
        locker.unlock();

        if (callback) {
            callback(-1, "", "Failed to start sandboxed process");
        }
        return;
    }
    
    const int timeoutMs = request.timeoutMs > 0 ? request.timeoutMs : -1;
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        const QString partialOutput = process.readAllStandardOutput();
        const QString partialError = process.readAllStandardError();

        QMutexLocker locker(&m_mutex);
        m_stats.failedExecutions++;
        locker.unlock();
        
        if (callback) {
            callback(-1, partialOutput, partialError.isEmpty() ? "Process timed out" : partialError);
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
    process.start("/bin/bash", QStringList() << "-lc" << request.commandLine);

    if (!process.waitForStarted(5000)) {
        QMutexLocker locker(&m_mutex);
        m_stats.failedExecutions++;
        locker.unlock();

        if (callback) {
            callback(-1, "", "Failed to start process");
        }
        return;
    }
    
    const int timeoutMs = request.timeoutMs > 0 ? request.timeoutMs : -1;
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        const QString partialOutput = process.readAllStandardOutput();
        const QString partialError = process.readAllStandardError();

        QMutexLocker locker(&m_mutex);
        m_stats.failedExecutions++;
        locker.unlock();
        
        if (callback) {
            callback(-1, partialOutput, partialError.isEmpty() ? "Process timed out" : partialError);
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

    if (!request.workingDirectory.isEmpty()) {
        args << "--chdir" << request.workingDirectory;
    }

    const FileSystemSandboxPolicy effectivePolicy = request.fsPolicy.allowedReadPaths.isEmpty()
        && request.fsPolicy.allowedWritePaths.isEmpty()
        && request.fsPolicy.deniedPaths.isEmpty()
        ? m_fsPolicy
        : request.fsPolicy;
    
    // Add allowed read paths
    for (const auto &path : effectivePolicy.allowedReadPaths) {
        args << "--ro-bind" << path << path;
    }
    
    // Add allowed write paths
    for (const auto &path : effectivePolicy.allowedWritePaths) {
        if (m_readOnlyMode || request.sandboxMode == SandboxMode::ReadOnly) {
            args << "--ro-bind" << path << path;
        } else {
            args << "--bind" << path << path;
        }
    }
    
    // Network policy
    if (m_networkPolicy == NetworkSandboxPolicy::Restricted || request.netPolicy == NetworkSandboxPolicy::Restricted) {
        args << "--unshare-net";
    }
    
    return args;
}

#include "moc_DefaultSandboxManager.cpp"
