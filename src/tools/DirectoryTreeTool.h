#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QJsonObject>

/**
 * @class DirectoryTreeTool
 * @brief 目录树和结构管理工具
 * 
 * 从 claude-code 适配：
 * - 生成目录树结构
 * - 列出深度受限的目录
 * - 生成树形可视化
 * - 导出为多种格式（JSON、Markdown、纯文本）
 */
class DirectoryTreeTool : public BaseTool {
    Q_OBJECT
public:
    explicit DirectoryTreeTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "directory_tree"; }
    QString description() const override {
        return "Generate directory tree structures, visualize directory layouts, "
               "and export in multiple formats (JSON, Markdown, text).";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct TreeQuery {
        QString path;
        QString format;  // "text", "json", "markdown"
        int maxDepth;
        QStringList ignoredPatterns;
        bool showSize;
        bool showPermissions;
    };

    TreeQuery parseQuery(const QJsonObject &args);
    
    ToolResult opGenerateTree(const QString &callId, const TreeQuery &query);

    // 辅助方法
    QString safePath(const QString &relPath) const;
    QString buildTextTree(const QString &path, int currentDepth, 
                         const TreeQuery &query, const QString &prefix = "");
    QJsonObject buildJsonTree(const QString &path, int currentDepth, 
                             const TreeQuery &query);
    QString buildMarkdownTree(const QString &path, int currentDepth, 
                             const TreeQuery &query, const QString &prefix = "");
    bool shouldIgnore(const QString &name, const QStringList &patterns);

    QString m_workspaceRoot;
};
