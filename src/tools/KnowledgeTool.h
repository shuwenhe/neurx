#pragma once
#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QVariantList>

struct sqlite3;

// ── KnowledgeTool ─────────────────────────────────────────────────────────────
//  Local full-text search knowledge base backed by SQLite FTS5.
//  Database stored at <workspace>/.neurx/knowledge.db.
//
//  Actions (arg "action"):
//    index_file       - index a single file path (arg: "path")
//    index_directory  - recursively index a directory (args: "path", "extensions": ["cpp","h"])
//    search           - full-text search (args: "query", "max_results" default 10)
//    list_sources     - list all indexed source paths
//    remove_source    - remove a source path and its chunks (arg: "path")

class KnowledgeTool : public BaseTool {
    Q_OBJECT
public:
    explicit KnowledgeTool(QObject *parent = nullptr);
    ~KnowledgeTool() override;

    void setDbPath(const QString &path);
    QVariantList sources();
    QVariantList searchEntries(const QString &query, int maxResults = 10, QString *error = nullptr);
    bool removeSourcePath(const QString &path, QString *error = nullptr);
    bool removeSourcePrefix(const QString &path, QString *error = nullptr);

    QString     name()        const override { return QStringLiteral("knowledge"); }
    QString     description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    bool ensureOpen();
    void ensureSchema();

    ToolResult actionIndexFile(const QString &callId, const QString &path);
    ToolResult actionIndexDirectory(const QString &callId, const QString &path,
                                    const QStringList &extensions);
    ToolResult actionSearch(const QString &callId, const QString &query, int maxResults);
    ToolResult actionListSources(const QString &callId);
    ToolResult actionRemoveSource(const QString &callId, const QString &path);

    // Splits content into overlapping chunks and stores them.
    // Returns the number of chunks inserted.
    int indexContent(const QString &sourcePath, const QString &content);

    static constexpr int kChunkSize    = 512;
    static constexpr int kChunkOverlap = 64;

    QString   m_dbPath;
    sqlite3  *m_db{nullptr};
};
