#pragma once

#include "SandboxManager.h"
#include <QObject>
#include <QProcess>
#include <memory>

/**
 * @class DefaultSandboxManager
 * @brief Default implementation of SandboxManager
 * 
 * Provides platform-specific sandbox execution:
 * - Linux: bubblewrap (bwrap) or Landlock LSM
 * - macOS: Seatbelt (sandbox) framework
 * - Windows: Restricted tokens (future)
 */
class DefaultSandboxManager : public SandboxManager {
    Q_OBJECT
public:
    explicit DefaultSandboxManager(QObject *parent = nullptr);
    ~DefaultSandboxManager();
    
    // Platform detection
    QVector<SandboxType> availableSandboxTypes() const override;
    SandboxType recommendedSandboxType() const override;
    bool isSandboxTypeAvailable(SandboxType type) const override;
    
    // Policy configuration
    void setDefaultSandboxMode(SandboxMode mode) override;
    SandboxMode getDefaultSandboxMode() const override;
    void setFileSystemPolicy(const FileSystemSandboxPolicy &policy) override;
    FileSystemSandboxPolicy getFileSystemPolicy() const override;
    void setNetworkPolicy(NetworkSandboxPolicy policy) override;
    NetworkSandboxPolicy getNetworkPolicy() const override;
    
    // Path management
    void addAllowedReadPath(const QString &path, bool recursive = true) override;
    void addAllowedWritePath(const QString &path, bool recursive = true) override;
    void addDeniedPath(const QString &path) override;
    void clearPaths() override;
    bool canAccess(const QString &path, FileSystemAccessMode mode) const override;
    
    // Execution
    void executeInSandbox(const SandboxExecRequest &request,
                         std::function<void(int exitCode, const QString &output, const QString &error)> callback) override;
    void transformPermissions(const SandboxTransformRequest &request,
                             std::function<void(const FileSystemSandboxPolicy &transformed)> callback) override;
    
    // Protected metadata
    QStringList protectedMetadataPaths() const override;
    void protectMetadataPath(const QString &path) override;
    bool isProtectedMetadata(const QString &path) const override;
    
    // Mode control
    void setReadOnlyMode(bool enabled) override;
    bool isReadOnlyMode() const override;
    
    // Statistics
    QVariantMap getStats() const override;
    void resetStats() override;

private:
    struct ExecutionStats {
        int totalExecutions{0};
        int successfulExecutions{0};
        int failedExecutions{0};
        int accessDeniedCount{0};
    };
    
    SandboxMode m_defaultMode{SandboxMode::ReadOnly};
    FileSystemSandboxPolicy m_fsPolicy;
    NetworkSandboxPolicy m_networkPolicy{NetworkSandboxPolicy::DenyAll};
    QStringList m_protectedMetadataPaths{".git", ".agents", ".codex", ".env"};
    ExecutionStats m_stats;
    bool m_readOnlyMode{false};
    mutable QMutex m_mutex;
    
    // Platform-specific execution
    void executeWithBwrap(const SandboxExecRequest &request,
                         std::function<void(int, const QString &, const QString &)> callback);
    void executeWithSeatbelt(const SandboxExecRequest &request,
                            std::function<void(int, const QString &, const QString &)> callback);
    void executeWithoutSandbox(const SandboxExecRequest &request,
                              std::function<void(int, const QString &, const QString &)> callback);
    
    // Helper methods
    SandboxType detectPlatformSandbox() const;
    QStringList buildBwrapCommand(const SandboxExecRequest &request) const;
};

using DefaultSandboxManagerPtr = std::shared_ptr<DefaultSandboxManager>;
