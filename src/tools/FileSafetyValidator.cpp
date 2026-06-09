#include "tools/FileSafetyValidator.h"
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <QProcess>
#include <algorithm>

FileSafetyValidator::FileSafetyValidator(const QString &workspaceRoot)
    : m_workspaceRoot(QDir(workspaceRoot).absolutePath())
{
    initializeDefaultDenyLists();
}

void FileSafetyValidator::initializeDefaultDenyLists()
{
    const QString homeDir = QDir::homePath();

    // System-critical paths (write denied)
    m_writeDeniedPaths << "/etc/passwd"
                       << "/etc/shadow"
                       << "/etc/sudoers"
                       << "/etc/ssh"
                       << "/root/.ssh"
                       << "/root/.gnupg"
                       << "/root/.aws"
                       << homeDir + "/.ssh"
                       << homeDir + "/.gnupg"
                       << homeDir + "/.aws"
                       << homeDir + "/.kube"
                       << homeDir + "/.docker"
                       << homeDir + "/.config/gcloud";

    // System prefixes (write denied)
    m_writeDeniedPrefixes << "/etc/"
                          << "/sys/"
                          << "/proc/"
                          << "/boot/"
                          << "/root/"
                          << "/var/lib/";

    // Sensitive patterns (read-with-warning)
    m_sensitivePaths << homeDir + "/.bash_history"
                     << homeDir + "/.zsh_history"
                     << homeDir + "/.bash_profile"
                     << homeDir + "/.bashrc"
                     << homeDir + "/.env"
                     << "/etc/hostname"
                     << "/etc/hosts"
                     << "/etc/fstab";

    // Credential file patterns
    m_credentialPatterns << "token"
                         << "secret"
                         << "password"
                         << "api_key"
                         << "apikey"
                         << "credentials"
                         << "private_key"
                         << "id_rsa"
                         << "id_ed25519"
                         << ".pem"
                         << ".key"
                         << ".crt"
                         << ".pfx";
}

bool FileSafetyValidator::isPathAllowedForWrite(const QString &path) const
{
    const QString cleaned = cleanPath(path);

    // Check deny lists
    if (isInWriteDenyList(cleaned)) {
        return false;
    }

    if (hasWriteDenyPrefix(cleaned)) {
        return false;
    }

    // Must be within or relative to workspace
    const QString absPath = resolvePath(path);
    const QString absWorkspace = QDir(m_workspaceRoot).absolutePath();

    QFileInfo absInfo(absPath);
    QFileInfo wsInfo(absWorkspace);

    if (!absPath.startsWith(absWorkspace)) {
        // Allow relative paths that resolve within workspace
        return false;
    }

    return true;
}

bool FileSafetyValidator::isPathAllowedForRead(const QString &path) const
{
    const QString cleaned = cleanPath(path);

    // Reads of system paths are generally allowed, but device paths are blocked
    if (isDevicePath(cleaned) || isProcPath(cleaned)) {
        return false;
    }

    return true;
}

bool FileSafetyValidator::isPathTraversalAttempt(const QString &path) const
{
    if (path.contains("..")) {
        // Check if traversal escapes workspace
        const QString resolved = resolvePath(path);
        const QString absWorkspace = QDir(m_workspaceRoot).absolutePath();

        if (!resolved.startsWith(absWorkspace)) {
            return true;
        }

        // Simple .. in relative paths within workspace is OK
        return false;
    }

    return false;
}

bool FileSafetyValidator::isSensitiveFile(const QString &path) const
{
    const QString cleaned = cleanPath(path);

    // Check explicit sensitive paths
    if (m_sensitivePaths.contains(cleaned)) {
        return true;
    }

    // Check patterns in filename
    const QString filename = QFileInfo(cleaned).fileName().toLower();
    for (const QString &pattern : m_credentialPatterns) {
        if (filename.contains(pattern, Qt::CaseInsensitive)) {
            return true;
        }
    }

    return isCredentialFile(cleaned);
}

QString FileSafetyValidator::resolvePath(const QString &relOrAbsPath) const
{
    QFileInfo fi(relOrAbsPath);

    if (fi.isAbsolute()) {
        return QDir::cleanPath(fi.absoluteFilePath());
    }

    // Resolve relative to workspace
    return QDir::cleanPath(QDir(m_workspaceRoot).absoluteFilePath(relOrAbsPath));
}

QString FileSafetyValidator::resolveRelativePath(const QString &path) const
{
    const QString abs = resolvePath(path);
    return QDir(m_workspaceRoot).relativeFilePath(abs);
}

bool FileSafetyValidator::isCredentialFile(const QString &path) const
{
    const QString lower = path.toLower();

    // Check for common credential file locations
    if (lower.contains("/.ssh/") || lower.contains("\\.ssh\\")) {
        return true;
    }
    if (lower.contains("/.gnupg/") || lower.contains("\\.gnupg\\")) {
        return true;
    }
    if (lower.contains("/.aws/") || lower.contains("\\.aws\\")) {
        return true;
    }
    if (lower.contains("/.kube/") || lower.contains("\\.kube\\")) {
        return true;
    }
    if (lower.contains("/.docker/") || lower.contains("\\.docker\\")) {
        return true;
    }

    // Check filename patterns
    const QString filename = QFileInfo(path).fileName().toLower();
    for (const QString &pattern : m_credentialPatterns) {
        if (filename.contains(pattern)) {
            return true;
        }
    }

    return false;
}

bool FileSafetyValidator::isSystemProtectedFile(const QString &path) const
{
    const QString cleaned = cleanPath(path);

    // System files that should not be modified
    static const QStringList systemFiles{
        "/etc/passwd", "/etc/shadow", "/etc/sudoers",
        "/etc/fstab", "/etc/hosts", "/etc/hostname"
    };

    if (systemFiles.contains(cleaned)) {
        return true;
    }

    if (isInWriteDenyList(cleaned) || hasWriteDenyPrefix(cleaned)) {
        return true;
    }

    return false;
}

QStringList FileSafetyValidator::filterAllowedPaths(const QStringList &paths, bool forWrite) const
{
    QStringList allowed;

    for (const QString &path : paths) {
        bool pathAllowed = forWrite ? isPathAllowedForWrite(path) : isPathAllowedForRead(path);
        if (pathAllowed && !isPathTraversalAttempt(path)) {
            allowed.append(path);
        }
    }

    return allowed;
}

QString FileSafetyValidator::getBlockReason(const QString &path) const
{
    const QString cleaned = cleanPath(path);

    if (isInWriteDenyList(cleaned)) {
        return "File is on the write-denied list";
    }

    if (hasWriteDenyPrefix(cleaned)) {
        return "Path prefix is write-protected";
    }

    if (isDevicePath(cleaned)) {
        return "Device paths cannot be accessed";
    }

    if (isProcPath(cleaned)) {
        return "Proc filesystem paths are protected";
    }

    if (isPathTraversalAttempt(path)) {
        return "Path traversal attempt detected";
    }

    if (!isPathAllowedForWrite(path)) {
        return "Path is outside workspace";
    }

    return "Path blocked by security policy";
}

void FileSafetyValidator::addWriteDeniedPath(const QString &path)
{
    m_writeDeniedPaths.insert(cleanPath(path));
}

void FileSafetyValidator::addWriteDeniedPrefix(const QString &prefix)
{
    m_writeDeniedPrefixes.insert(cleanPath(prefix));
}

void FileSafetyValidator::addSensitivePath(const QString &path)
{
    m_sensitivePaths.insert(cleanPath(path));
}

void FileSafetyValidator::setWorkspaceRoot(const QString &root)
{
    m_workspaceRoot = QDir(root).absolutePath();
}

bool FileSafetyValidator::isInWriteDenyList(const QString &path) const
{
    return m_writeDeniedPaths.contains(path);
}

bool FileSafetyValidator::hasWriteDenyPrefix(const QString &path) const
{
    for (const QString &prefix : m_writeDeniedPrefixes) {
        if (pathStartsWith(path, prefix)) {
            return true;
        }
    }
    return false;
}

bool FileSafetyValidator::isBelowSystemRoot(const QString &path) const
{
    // Paths like /usr, /bin, /lib, /opt are system directories
    static const QStringList systemRoots{
        "/usr", "/bin", "/sbin", "/lib", "/lib64", "/opt", "/srv"
    };

    for (const QString &root : systemRoots) {
        if (pathStartsWith(path, root)) {
            return true;
        }
    }

    return false;
}

bool FileSafetyValidator::isInHomeDirectory(const QString &path) const
{
    const QString homeDir = QDir::homePath();
    return pathStartsWith(path, homeDir);
}

bool FileSafetyValidator::isDevicePath(const QString &path) const
{
    static const QStringList devicePaths{
        "/dev/zero", "/dev/null", "/dev/random", "/dev/urandom",
        "/dev/stdin", "/dev/stdout", "/dev/stderr", "/dev/tty",
        "/dev/fd/"
    };

    for (const QString &devicePath : devicePaths) {
        if (pathStartsWith(path, devicePath)) {
            return true;
        }
    }

    return false;
}

bool FileSafetyValidator::isProcPath(const QString &path) const
{
    static const QStringList procPaths{
        "/proc/", "/sys/"
    };

    for (const QString &procPath : procPaths) {
        if (pathStartsWith(path, procPath)) {
            return true;
        }
    }

    return false;
}

QString FileSafetyValidator::cleanPath(const QString &path) const
{
    return QDir::cleanPath(path);
}

QString FileSafetyValidator::expandPath(const QString &path) const
{
    if (path.startsWith("~")) {
        return QDir::homePath() + path.mid(1);
    }
    return path;
}

bool FileSafetyValidator::pathStartsWith(const QString &path, const QString &prefix) const
{
    // Ensure prefix ends with / for directory matching
    QString prefixWithSlash = prefix;
    if (!prefixWithSlash.endsWith("/")) {
        prefixWithSlash += "/";
    }

    return path.startsWith(prefixWithSlash) || path == prefix;
}
