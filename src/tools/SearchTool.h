#pragma once
#include "agent/ToolRegistry.h"

// ── SearchTool ────────────────────────────────────────────────────────────────
//  Two operations:
//    • grep_search  — regex search across workspace files (like ripgrep)
//    • semantic_search — optional vector-similarity search via local embeddings

class SearchTool : public BaseTool {
    Q_OBJECT
public:
    explicit SearchTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name()        const override { return "search"; }
    QString description() const override {
        return "Search code and files in the workspace. "
               "Operations: grep_search (regex/text across files), "
               "find_files (glob pattern matching), "
               "semantic_search (natural language code search, if index available).";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    ToolResult opGrepSearch(const QString &callId, const QJsonObject &args);
    ToolResult opFindFiles(const QString &callId, const QJsonObject &args);

    QString m_workspaceRoot;
};
