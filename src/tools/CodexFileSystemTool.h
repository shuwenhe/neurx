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
    ToolResult opReadFile(const QString& callId, const QJsonObject& args);
    ToolResult opCreateDirectory(const QString& callId, const QJsonObject& args);
    ToolResult opDeleteFile(const QString& callId, const QJsonObject& args);
    ToolResult opGetMetadata(const QString& callId, const QJsonObject& args);
    ToolResult opWriteBatch(const QString& callId, const QJsonObject& args);

    // Sandbox context creation
    FileSystemSandboxContext* createSandboxContext(const QJsonObject& sandboxSpec) const;

    // Utility
    QJsonObject resultToJson(const FileSystemResult& result);
    QJsonObject batchResultToJson(
        const QList<QPair<QString, FileSystemResult>>& results
    );

    LocalFileSystemPtr m_fileSystem;
};

using CodexFileSystemToolPtr = std::shared_ptr<CodexFileSystemTool>;
