#pragma once

#include "SandboxTypes.h"
#include <QObject>
#include <QVector>
#include <QVariantMap>
#include <functional>
#include <memory>

/**
 * @class SandboxManager
 * @brief Central manager for sandbox policies and execution isolation
 * 
 * Handles:
 * - Sandbox policy configuration
 * - Platform-specific sandbox setup
 * - Command/tool execution in sandboxed environment
 * - Permission transformation based on policies
 * 
 * Migrated from Codex's sandboxing system for agent isolation.
 */
class SandboxManager : public QObject {
    Q_OBJECT
public:
    explicit SandboxManager(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~SandboxManager() = default;
    
    // ── Detection and Platform Info ────────────────────────────────────
    
    /// Get available sandbox types for this platform
    virtual QVector<SandboxType> availableSandboxTypes() const = 0;
    
    /// Get recommended sandbox type for this platform
    virtual SandboxType recommendedSandboxType() const = 0;
    
    /// Check if specific sandbox type is available
    virtual bool isSandboxTypeAvailable(SandboxType type) const = 0;
    
    // ── Policy Configuration ───────────────────────────────────────────
    
    /// Set default sandbox mode for agents
    virtual void setDefaultSandboxMode(SandboxMode mode) = 0;
    
    /// Get current default sandbox mode
    virtual SandboxMode getDefaultSandboxMode() const = 0;
    
    /// Set file system sandbox policy
    virtual void setFileSystemPolicy(const FileSystemSandboxPolicy &policy) = 0;
    
    /// Get file system policy
    virtual FileSystemSandboxPolicy getFileSystemPolicy() const = 0;
    
    /// Set network sandbox policy
    virtual void setNetworkPolicy(NetworkSandboxPolicy policy) = 0;
    
    /// Get network policy
    virtual NetworkSandboxPolicy getNetworkPolicy() const = 0;
    
    // ── Path Management ────────────────────────────────────────────────
    
    /// Add path to allowed read locations
    virtual void addAllowedReadPath(const QString &path, bool recursive = true) = 0;
    
    /// Add path to allowed write locations
    virtual void addAllowedWritePath(const QString &path, bool recursive = true) = 0;
    
    /// Add path to deny list
    virtual void addDeniedPath(const QString &path) = 0;
    
    /// Clear all configured paths
    virtual void clearPaths() = 0;
    
    /// Check if path is accessible under current policy
    virtual bool canAccess(const QString &path, FileSystemAccessMode mode) const = 0;
    
    // ── Execution ──────────────────────────────────────────────────────
    
    /// Execute command/tool in sandbox
    virtual void executeInSandbox(const SandboxExecRequest &request,
                                 std::function<void(int exitCode, const QString &output, const QString &error)> callback) = 0;

    /// Record a sandbox execution event for unified timeline/logging.
    virtual void recordExecutionEvent(const QVariantMap &event) = 0;
    
    /// Transform permissions for tool execution (apply approval/granular policies)
    virtual void transformPermissions(const SandboxTransformRequest &request,
                                     std::function<void(const FileSystemSandboxPolicy &transformed)> callback) = 0;
    
    // ── Protected Metadata ─────────────────────────────────────────────
    
    /// Get list of protected metadata paths
    virtual QStringList protectedMetadataPaths() const = 0;
    
    /// Add path to protected metadata list (always denied)
    virtual void protectMetadataPath(const QString &path) = 0;
    
    /// Check if path is protected metadata
    virtual bool isProtectedMetadata(const QString &path) const = 0;
    
    // ── Read-Only Mode ────────────────────────────────────────────────
    
    /// Enable read-only mode (no write operations allowed)
    virtual void setReadOnlyMode(bool enabled) = 0;
    
    /// Check if read-only mode is active
    virtual bool isReadOnlyMode() const = 0;
    
    // ── Statistics ─────────────────────────────────────────────────────
    
    /// Get sandbox statistics
    virtual QVariantMap getStats() const = 0;
    
    /// Reset statistics
    virtual void resetStats() = 0;

signals:
    /// Emitted when path access is denied
    void accessDenied(const QString &path, FileSystemAccessMode mode, const QString &reason);
    
    /// Emitted when policy changes
    void policyChanged();
    
    /// Emitted on sandbox error
    void sandboxError(const QString &error);

    /// Emitted when sandbox execution activity is recorded
    void sandboxExecutionEvent(const QVariantMap &event);
};

using SandboxManagerPtr = std::shared_ptr<SandboxManager>;
