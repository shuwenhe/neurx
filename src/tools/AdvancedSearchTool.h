#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QJsonObject>
#include <QStringList>

/**
 * @class AdvancedSearchTool
 * @brief 高级搜索工具 - Grep、文件查找、内容搜索
 * 
 * 从 claude-code 适配：
 * - 递归 grep 搜索（正则表达式）
 * - Glob 模式文件查找
 * - 内容搜索（带上下文）
 * - 符号搜索（函数、类等）
 * - 文件类型过滤
 */
class AdvancedSearchTool : public BaseTool {
    Q_OBJECT
public:
    explicit AdvancedSearchTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "search"; }
    QString description() const override {
        return "Search for files and content in the workspace using grep, "
               "glob patterns, or symbol search. Supports regex and context display.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct SearchQuery {
        QString type;  // "grep", "find", "symbol"
        QString pattern;
        QString globPattern;
        QString searchPath;
        bool useRegex;
        bool caseSensitive;
        int contextLines;
        QStringList fileExtensions;
    };

    SearchQuery parseQuery(const QJsonObject &args);
    
    ToolResult opGrep(const QString &callId, const SearchQuery &query);
    ToolResult opFind(const QString &callId, const SearchQuery &query);
    ToolResult opSymbol(const QString &callId, const SearchQuery &query);

    // 辅助方法
    QString safePath(const QString &relPath) const;
    QStringList findFilesRecursive(const QString &basePath, 
                                   const QStringList &extensions);
    QStringList grepInFile(const QString &filePath, const SearchQuery &query);
    QStringList extractSymbols(const QString &filePath, const QString &symbolType);

    QString m_workspaceRoot;
};
