#pragma once

#include <QString>
#include <QStringList>
#include <QSet>
#include <memory>

/**
 * @class FileSafetyValidator
 * @brief Security validation for file operations
 * 
 * Migrated from claude-code/hermes-agent file_safety module:
 * - Write-denied path checking
 * - Path traversal prevention
 * - Sensitive file detection
 * - Safe path resolution
 * - Credentials file protection
 */

class FileSafetyValidator {
public:
    explicit FileSafetyValidator(const QString &workspaceRoot);
    ~FileSafetyValidator() = default;

    // Path validation
    bool isPathAllowedForWrite(const QString &path) const;
    bool isPathAllowedForRead(const QString &path) const;
    bool isPathTraversalAttempt(const QString &path) const;
    bool isSensitiveFile(const QString &path) const;

    // Path resolution
    QString resolvePath(const QString &relOrAbsPath) const;
    QString resolveRelativePath(const QString &path) const;

    // Credential file detection
    bool isCredentialFile(const QString &path) const;
    bool isSystemProtectedFile(const QString &path) const;

    // Batch operations
    QStringList filterAllowedPaths(const QStringList &paths, bool forWrite = false) const;
    QString getBlockReason(const QString &path) const;

    // Configuration
    void addWriteDeniedPath(const QString &path);
    void addWriteDeniedPrefix(const QString &prefix);
    void addSensitivePath(const QString &path);
    void setWorkspaceRoot(const QString &root);

private:
    // Deny list checks
    bool isInWriteDenyList(const QString &path) const;
    bool hasWriteDenyPrefix(const QString &path) const;

    // System paths
    bool isBelowSystemRoot(const QString &path) const;
    bool isInHomeDirectory(const QString &path) const;
    bool isDevicePath(const QString &path) const;
    bool isProcPath(const QString &path) const;

    // Helper methods
    QString cleanPath(const QString &path) const;
    QString expandPath(const QString &path) const;
    bool pathStartsWith(const QString &path, const QString &prefix) const;

    QString m_workspaceRoot;
    QSet<QString> m_writeDeniedPaths;
    QSet<QString> m_writeDeniedPrefixes;
    QSet<QString> m_sensitivePaths;
    QSet<QString> m_credentialPatterns;

    void initializeDefaultDenyLists();
};
