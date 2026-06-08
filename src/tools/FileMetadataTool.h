#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QJsonObject>

/**
 * @class FileMetadataTool
 * @brief 文件元数据工具 - 获取文件信息、统计、哈希等
 * 
 * 从 claude-code 适配：
 * - 获取文件大小、修改时间、权限等
 * - 计算文件哈希（MD5、SHA256）
 * - 获取文件类型、编码
 * - 获取目录大小、文件计数
 * - 检查文件是否存在、是否为目录等
 */
class FileMetadataTool : public BaseTool {
    Q_OBJECT
public:
    explicit FileMetadataTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "file_metadata"; }
    QString description() const override {
        return "Get file information, size, modification time, permissions, "
               "encoding, file hashes (MD5, SHA256), directory statistics, "
               "and other metadata.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct MetadataQuery {
        QString type;  // "file_info", "file_hash", "dir_stats", "encoding"
        QString path;
        QString hashAlgo;  // "md5", "sha256"
        bool recursive;
    };

    MetadataQuery parseQuery(const QJsonObject &args);
    
    ToolResult opFileInfo(const QString &callId, const MetadataQuery &query);
    ToolResult opFileHash(const QString &callId, const MetadataQuery &query);
    ToolResult opDirStats(const QString &callId, const MetadataQuery &query);
    ToolResult opEncoding(const QString &callId, const MetadataQuery &query);

    // 辅助方法
    QString safePath(const QString &relPath) const;
    QString calculateFileHash(const QString &filePath, const QString &algo);
    QString detectEncoding(const QString &filePath);
    QString getFileType(const QString &filePath);

    QString m_workspaceRoot;
};
