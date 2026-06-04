#pragma once

#include "agent/AgentToolRegistry.h"
#include <QDir>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>

class SandboxManager;
class CheckpointManager;

/**
 * @file FileCreationTool.h
 * @brief Advanced file creation tool with atomic writes and metadata preservation
 * 
 * Implements best practices from Claude Code:
 * - Atomic file writing (temp + rename)
 * - Automatic directory creation  
 * - Line ending preservation
 * - UTF-8 BOM handling
 * - File permission copying
 * - Checkpoint/backup support
 */

class FileCreationTool : public BaseTool {
    Q_OBJECT
    
public:
    explicit FileCreationTool(const QString& workspaceRoot, QObject* parent = nullptr);
    ~FileCreationTool() override;
    
    QString name() const override { return "file_creation"; }
    QString description() const override {
        return "Create and write files with atomic operations, directory creation, "
               "line ending preservation, and integrity validation.";
    }
    
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;
    
    void setSandboxManager(SandboxManager* manager);
    void setCheckpointManager(CheckpointManager* manager);
    
private:
    struct FileSpec {
        QString path;
        QString content;
        bool overwrite{false};
        bool createDirs{true};
        QString lineEnding{"auto"};
        bool preserveExisting{false};
    };
    
    struct WriteResultData {
        int bytesWritten{0};
        bool dirsCreated{false};
        QString filepath;
        QString lineEndingDetected;
        bool hadBOM{false};
        bool preservedBOM{false};
        QJsonObject lintResults;
        QString error;
    };
    
    // Core operations
    ToolResult opCreateFile(const QString& callId, const QJsonObject& args);
    ToolResult opWriteFile(const QString& callId, const QJsonObject& args);
    ToolResult opCreateBatch(const QString& callId, const QJsonObject& args);
    
    // Write implementation
    WriteResultData writeFileAtomic(const FileSpec& spec);
    bool ensureDirectories(const QString& path);
    QString detectLineEnding(const QString& path, const QString& existingContent = "");
    bool detectBOM(const QString& path, const QString& existingContent = "");
    QString normalizeLineEndings(const QString& content, const QString& targetEnding);
    bool copyFilePermissions(const QString& from, const QString& to);
    QString readExistingContent(const QString& path);
    
    // Security
    bool isWriteAllowed(const QString& path);
    bool isSensitivePath(const QString& path) const;
    QString safePath(const QString& relOrAbsPath) const;
    
    // Validation
    QJsonObject checkSyntax(const QString& path, const QString& content);
    bool checkJSONSyntax(const QString& content, QString& error);
    bool checkPythonSyntax(const QString& content, QString& error);
    
    // Utility
    QString createCheckpoint(const QString& path, const QString& description);
    QJsonObject resultToJson(const WriteResultData& result);
    
    QDir m_workspaceRoot;
    SandboxManager* m_sandboxManager{nullptr};
    CheckpointManager* m_checkpointManager{nullptr};
    QSet<QString> m_protectedPaths;
    
    static constexpr int MAX_FILE_SIZE = 50 * 1024 * 1024;
    static constexpr const char* TEMP_FILE_SUFFIX = ".neurx-tmp";
};
