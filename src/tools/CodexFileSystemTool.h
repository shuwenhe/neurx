#pragma once

#include "agent/AgentToolRegistry.h"
#include "filesystem/LocalFileSystem.h"
#include <memory>

class SandboxManager;

/**
 * @file CodexFileSystemTool.h
 * @brief Integration tool for Codex-style file system operations
 * 
 * Exposes LocalFileSystem as a tool for LLM agents.
 * Supports both direct and sandboxed file operations.
 * 
 * Inspired by Codex file_system_handler.rs RPC layer.
 */
class CodexFileSystemTool : public BaseTool {
    Q_OBJECT

public:
    explicit CodexFileSystemTool(const QString& workspaceRoot, QObject* parent = nullptr);
    ~CodexFileSystemTool() override;

    QString name() const override { return "codex_file_system"; }
    QString description() const override {
        return "Codex-style file system operations with sandboxing support. "
               "Provides atomic writes, metadata preservation, and access control.";
    }

    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;

    void setSandboxManager(SandboxManager* manager);

    // Access to underlying file system
    LocalFileSystemPtr fileSystem() const { return m_fileSystem; }

private:
    // Operations
    ToolResult opWriteFile(const QString& callId, const QJsonObject& args);
    ToolResult opCreateFile(const QString& callId, const QJsonObject& args);
    ToolResult opReadFile(const QString& callId, const QJsonObject& args);
    ToolResult opCreateDirectory(const QString& callId, const QJsonObject& args);
    ToolResult opDeleteFile(const QString& callId, const QJsonObject& args);
    ToolResult opGetMetadata(const QString& callId, const QJsonObject& args);
    ToolResult opStatFile(const QString& callId, const QJsonObject& args);
    ToolResult opHashFile(const QString& callId, const QJsonObject& args);
    ToolResult opChmodFile(const QString& callId, const QJsonObject& args);
    ToolResult opSymlinkFile(const QString& callId, const QJsonObject& args);
    ToolResult opTouchFile(const QString& callId, const QJsonObject& args);
    ToolResult opTruncateFile(const QString& callId, const QJsonObject& args);
    ToolResult opReadRangeFile(const QString& callId, const QJsonObject& args);
    ToolResult opTailFile(const QString& callId, const QJsonObject& args);
    ToolResult opWriteBatch(const QString& callId, const QJsonObject& args);
    ToolResult opExists(const QString& callId, const QJsonObject& args);
    ToolResult opListDirectory(const QString& callId, const QJsonObject& args);
    ToolResult opFindFiles(const QString& callId, const QJsonObject& args);
    ToolResult opReadManyFiles(const QString& callId, const QJsonObject& args);
    ToolResult opSearchInFiles(const QString& callId, const QJsonObject& args);
    ToolResult opMoveFile(const QString& callId, const QJsonObject& args);
    ToolResult opCopyFile(const QString& callId, const QJsonObject& args);
    ToolResult opAppendFile(const QString& callId, const QJsonObject& args);
    ToolResult opRenameFile(const QString& callId, const QJsonObject& args);

    // Sandbox context creation
    FileSystemSandboxContext* createSandboxContext(const QJsonObject& sandboxSpec) const;

    // Utility
    QString safePath(const QString& relOrAbsPath) const;
    QString workspaceRelativePath(const QString& relOrAbsPath) const;
    bool ensureParentDirectory(const QString& absPath) const;
    bool copyRecursive(const QString& source, const QString& destination) const;
    bool moveRecursive(const QString& source, const QString& destination) const;
    QStringList collectFilesByPatterns(
        const QString& baseDir,
        const QStringList& patterns,
        bool includeHidden,
        int maxResults) const;
    QJsonObject resultToJson(const FileSystemResult& result);
    QJsonObject batchResultToJson(
        const QList<QPair<QString, FileSystemResult>>& results
    );

    LocalFileSystemPtr m_fileSystem;
    QString m_workspaceRoot;
    QDir m_root;
};

using CodexFileSystemToolPtr = std::shared_ptr<CodexFileSystemTool>;
