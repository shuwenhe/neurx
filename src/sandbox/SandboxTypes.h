#pragma once

#include <QString>
#include <QStringList>
#include <QFlags>

/**
 * @enum FileSystemAccessMode
 * @brief Permission levels for file system access
 * 
 * Migrated from Codex permissions model for fine-grained sandbox control.
 */
enum class FileSystemAccessMode {
    Read,       ///< Read-only access
    Write,      ///< Read + Write access
    Deny        ///< No access
};

/**
 * @enum FileSystemSandboxKind
 * @brief Type of file system sandboxing to apply
 */
enum class FileSystemSandboxKind {
    Restricted,         ///< Minimal sandbox (only approved paths)
    Unrestricted,       ///< No sandbox (full filesystem)
    ExternalSandbox     ///< Use system sandbox (Seatbelt, SELinux, etc.)
};

/**
 * @enum NetworkSandboxPolicy
 * @brief Network access policy
 */
enum class NetworkSandboxPolicy {
    Restricted,         ///< Only approved network destinations
    Enabled             ///< Full network access
};

/**
 * @enum SandboxMode
 * @brief Execution sandbox mode for agents
 * 
 * Mirrors Codex --sandbox CLI options.
 */
enum class SandboxMode {
    ReadOnly,           ///< Read-only, no modifications
    WorkspaceWrite,     ///< Can write to workspace directory
    DangerFullAccess    ///< Full filesystem access (dangerous)
};

/**
 * @enum SandboxType
 * @brief Platform-specific sandbox implementation type
 */
enum class SandboxType {
    None,               ///< No sandboxing
    MacosSeatbelt,      ///< macOS Seatbelt sandbox
    LinuxSeccomp,       ///< Linux seccomp-bpf or Landlock
    LinuxBubbleWrap,    ///< Linux bubblewrap (bwrap)
    WindowsRestrictedToken ///< Windows Restricted Token
};

/**
 * @struct FileSystemSandboxEntry
 * @brief Configuration for a single file system path in sandbox
 */
struct FileSystemSandboxEntry {
    QString path;                           ///< Absolute path pattern (can include wildcards)
    FileSystemAccessMode accessMode;        ///< Read/Write/Deny
    bool recursive{false};                  ///< Apply recursively to subdirectories
};

/**
 * @struct FileSystemSandboxPolicy
 * @brief Complete file system sandbox configuration
 */
struct FileSystemSandboxPolicy {
    FileSystemSandboxKind kind{FileSystemSandboxKind::Restricted};
    QStringList allowedReadPaths;           ///< Paths that can be read
    QStringList allowedWritePaths;          ///< Paths that can be written
    QStringList deniedPaths;                ///< Explicitly denied paths
    
    /// Protected metadata paths that are never exposed
    /// (e.g., .git, .agents, .codex)
    QStringList protectedMetadataPaths;
    
    bool allowSymlinks{false};              ///< Allow symlink traversal
    bool allowDeviceAccess{false};          ///< Allow /dev access
    bool allowProcAccess{false};            ///< Allow /proc access
};

/**
 * @struct SandboxExecRequest
 * @brief Request to execute a command/tool in sandbox
 */
struct SandboxExecRequest {
    QString commandLine;
    QString workingDirectory;
    SandboxMode sandboxMode{SandboxMode::WorkspaceWrite};
    FileSystemSandboxPolicy fsPolicy;
    NetworkSandboxPolicy netPolicy{NetworkSandboxPolicy::Restricted};
    
    /// Timeout in milliseconds (0 = unlimited)
    int timeoutMs{0};
};

/**
 * @struct SandboxTransformRequest
 * @brief Request to transform permissions for a tool execution
 */
struct SandboxTransformRequest {
    QString toolName;
    QStringList requestedPaths;
    /// Can be "always", "on-request", "on-failure"
    QString approvalPolicy;
    /// Can be "user", "auto-review"
    QString approvalsReviewer;
};
