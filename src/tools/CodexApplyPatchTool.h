#pragma once

#include "agent/AgentToolRegistry.h"
#include "sandbox/SandboxManager.h"
#include <QObject>
#include <QDir>

/**
 * @file CodexApplyPatchTool.h
 * @brief Direct integration with Codex CLI apply_patch command
 * 
 * Complete call chain:
 *   AgentController -> CodexApplyPatchTool.execute()
 *     -> Codex CLI: codex apply-patch
 *     -> Codex apply_patch handler
 *     -> Filesystem operations
 *     -> Returns detailed results
 * 
 * This provides the tightest integration with Codex's validation
 * and safety checks for file modifications.
 */

// ═══════════════════════════════════════════════════════════════════════════════
// CodexApplyPatchTool
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class CodexApplyPatchTool
 * @brief Apply unified diff patches via Codex CLI
 * 
 * Directly invokes: codex apply-patch {patch_file} --cwd {cwd}
 * 
 * This tool bridges the LLM agent directly to Codex's apply_patch
 * command, which handles:
 * - Patch validation and safety checks
 * - File conflict resolution
 * - Automatic approval for safe patches
 * - Detailed result reporting
 * 
 * Parameters:
 * - patch: Unified diff format patch content (required)
 * - cwd: Working directory for application (optional)
 * - auto_approve: Enable auto-approval (optional)
 * - verbose: Enable verbose output (optional)
 */
class CodexApplyPatchTool : public BaseTool {
    Q_OBJECT
public:
    explicit CodexApplyPatchTool(const QString &workspaceRoot, QObject *parent = nullptr);
    
    QString name() const override { return QStringLiteral("codex_apply_patch"); }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;
    
    void setSandboxManager(SandboxManager *manager) { m_sandboxManager = manager; }
    void setCodexCliPath(const QString &path) { m_codexCliPath = path; }

private:
    struct ApplyPatchResult {
        bool success{false};
        int filesChanged{0};
        QStringList changedFiles;
        QString output;
        QString error;
    };
    
    QString findCodexCli() const;
    ApplyPatchResult applyPatchViaCLI(const QString &patchContent, const QString &cwd);
    QString validatePatchFormat(const QString &patch) const;
    QString formatPatchError(const QString &error) const;
    
    QString m_workspaceRoot;
    QString m_codexCliPath;
    SandboxManager *m_sandboxManager{nullptr};
};

// ═══════════════════════════════════════════════════════════════════════════════
// CodexWriteFileTool
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class CodexWriteFileTool
 * @brief Write files using Codex CLI with automatic diff generation
 * 
 * Call chain:
 *   Agent -> CodexWriteFileTool.execute()
 *     -> Generate unified diff from content
 *     -> Codex CLI: codex apply-patch
 *     -> Codex apply_patch handler
 *     -> Filesystem operations
 *     -> Return results
 * 
 * This tool provides a higher-level interface for writing files
 * while leveraging Codex's validation and safety systems.
 * 
 * Parameters:
 * - file_path: Path to file (relative to workspace, required)
 * - content: File content to write (required)
 * - description: Change description for patch header (optional)
 * - auto_approve: Enable auto-approval (optional)
 */
class CodexWriteFileTool : public BaseTool {
    Q_OBJECT
public:
    explicit CodexWriteFileTool(const QString &workspaceRoot, QObject *parent = nullptr);
    
    QString name() const override { return QStringLiteral("codex_write_file"); }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;
    
    void setSandboxManager(SandboxManager *manager) { m_sandboxManager = manager; }
    void setCodexCliPath(const QString &path) { m_codexCliPath = path; }

private:
    QString findCodexCli() const;
    QString generateUnifiedDiff(const QString &filePath, const QString &oldContent,
                                const QString &newContent) const;
    bool ensureDirectoryExists(const QString &dirPath);
    QString safePath(const QString &relOrAbsPath) const;
    QString readExistingFile(const QString &filePath) const;
    
    QString m_workspaceRoot;
    QString m_codexCliPath;
    SandboxManager *m_sandboxManager{nullptr};
    QDir m_root;
};

// ═══════════════════════════════════════════════════════════════════════════════
// CodexFilesystemToolFactory
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @class CodexFilesystemToolFactory
 * @brief Factory for registering Codex CLI filesystem tools
 * 
 * Simplifies registration of:
 * - CodexApplyPatchTool (for patch application)
 * - CodexWriteFileTool (for file writing)
 */
class CodexFilesystemToolFactory {
public:
    /**
     * Register filesystem tools in the agent's tool registry.
     * 
     * This establishes the complete integration chain:
     *   AgentController -> Tool Registry -> [CodexApplyPatchTool | CodexWriteFileTool]
     *     -> Codex CLI -> apply_patch/filesystem handlers
     * 
     * @param workspaceRoot Root directory of the workspace
     * @param registry Tool registry to register tools in
     * @param sandboxManager Sandbox manager for permission checks
     * @param codexCliPath Optional path to codex binary (auto-detected if empty)
     */
    static void registerFilesystemTools(const QString &workspaceRoot,
                                        AgentToolRegistry *registry,
                                        SandboxManager *sandboxManager,
                                        const QString &codexCliPath = "");
};
