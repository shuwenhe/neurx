#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QJsonObject>

/**
 * @class EditFileTool
 * @brief 高级文件编辑工具 - Find & Replace、多行编辑、正则支持
 * 
 * 从 claude-code 的 find-replace 功能适配：
 * - 支持简单文本替换、正则表达式替换
 * - 支持多次替换、预览模式
 * - 保留原文件备份
 */
class EditFileTool : public BaseTool {
    Q_OBJECT
public:
    explicit EditFileTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "edit_file"; }
    QString description() const override {
        return "Find and replace text in files, edit specific line ranges, "
               "or apply transformations. Supports regex, preview mode, "
               "and preserves backup copies.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct EditOperation {
        QString type;  // "find_replace", "edit_lines", "apply_patch"
        QString filePath;
        QString searchPattern;
        QString replacement;
        bool useRegex;
        bool caseSensitive;
        bool preview;
        int lineStart;
        int lineEnd;
        QString lineContent;  // for edit_lines
    };

    // 解析编辑操作
    EditOperation parseEditOp(const QJsonObject &args);
    
    // 执行具体操作
    ToolResult opFindReplace(const QString &callId, const EditOperation &op);
    ToolResult opEditLines(const QString &callId, const EditOperation &op);
    ToolResult opApplyPatch(const QString &callId, const EditOperation &op);

    // 辅助方法
    QString safePath(const QString &relPath) const;
    QString createBackup(const QString &filePath);
    QString performFindReplace(const QString &content, const EditOperation &op, bool *success);
    QString performLineEdit(const QString &content, const EditOperation &op, bool *success);

    QString m_workspaceRoot;
};
