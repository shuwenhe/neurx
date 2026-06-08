#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QJsonObject>
#include <QStringList>

/**
 * @class BatchFileOperationsTool
 * @brief 批量文件操作工具 - 事务性的多文件操作
 * 
 * 从 claude-code 适配：
 * - 批量创建文件/目录（原子操作）
 * - 批量删除、移动、复制
 * - 文件夹结构创建
 * - 操作回滚支持（通过检查点）
 * - 干运行（预览）模式
 */
class BatchFileOperationsTool : public BaseTool {
    Q_OBJECT
public:
    explicit BatchFileOperationsTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "batch_files"; }
    QString description() const override {
        return "Perform batch file operations: create multiple files/directories, "
               "delete, move, copy in a transactional manner with rollback support.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct FileSpec {
        QString path;
        QString content;  // for files
        bool isDirectory;
    };

    struct BatchOperation {
        QString type;  // "batch_create", "batch_delete", "batch_move", "batch_copy"
        QList<FileSpec> specs;
        bool dryRun;
        bool rollbackOnError;
        QStringList source;
        QStringList destination;  // for move/copy
    };

    BatchOperation parseOperation(const QJsonObject &args);
    
    ToolResult opBatchCreate(const QString &callId, const BatchOperation &op);
    ToolResult opBatchDelete(const QString &callId, const BatchOperation &op);
    ToolResult opBatchMove(const QString &callId, const BatchOperation &op);
    ToolResult opBatchCopy(const QString &callId, const BatchOperation &op);
    ToolResult opCreateStructure(const QString &callId, const BatchOperation &op);

    // 辅助方法
    QString safePath(const QString &relPath) const;
    bool createFileWithParents(const QString &path, const QString &content);
    bool deleteFileRecursive(const QString &path);
    QJsonArray generateOperationReport(const QStringList &successful, 
                                      const QStringList &failed);

    QString m_workspaceRoot;
};
