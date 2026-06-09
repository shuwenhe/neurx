#pragma once

#include "agent/AgentToolRegistry.h"
#include <QDir>
#include <memory>

/**
 * @class IncrementalEditTool
 * @brief Edit files by line ranges without full file replacement
 * 
 * Migrated from claude-code concepts:
 * - Insert lines at specific positions
 * - Replace line ranges
 * - Delete line ranges
 * - Append to end of file
 * - Edit validation (conflict detection)
 * - Atomic multi-edit support
 */

class IncrementalEditTool : public BaseTool {
    Q_OBJECT

public:
    explicit IncrementalEditTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "incremental_edit"; }
    QString description() const override {
        return "Edit files incrementally by line ranges - insert, replace, delete, "
               "and append without full file replacement.";
    }

    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct EditOperation {
        enum Type { Insert, Replace, Delete, Append } type;
        QString filepath;
        int startLine{1};  // 1-based
        int endLine{1};    // 1-based, inclusive
        QString content;
        bool createIfMissing{false};
        bool previewOnly{false};
    };

    struct EditResult {
        bool success{false};
        QString filepath;
        int linesModified{0};
        int linesAdded{0};
        int linesRemoved{0};
        QString preview;  // Before/after preview
        QString error;
    };

    // Individual edit operations
    EditResult opInsertLines(const EditOperation &op);
    EditResult opReplaceLines(const EditOperation &op);
    EditResult opDeleteLines(const EditOperation &op);
    EditResult opAppendLines(const EditOperation &op);

    // Multi-edit operations
    ToolResult opBatchEdit(const QString &callId, const QJsonObject &args);

    // Validation
    bool validateLineRange(const QString &filepath, int startLine, int endLine) const;
    bool validateContent(const QString &content) const;
    QString detectConflicts(const QString &filepath, int startLine, int endLine) const;

    // Helper methods
    QStringList readFileLines(const QString &filepath) const;
    bool writeFileLines(const QString &filepath, const QStringList &lines) const;
    QString safePath(const QString &relOrAbsPath) const;
    QString generatePreview(
        const QStringList &oldLines,
        const QStringList &newLines,
        int contextLines = 3
    ) const;

    QString formatEditResult(const EditResult &result) const;

    QDir m_root;
    static constexpr int MAX_BATCH_EDITS = 100;
    static constexpr int DEFAULT_PREVIEW_CONTEXT = 3;
};
