#include "tools/KnowledgeTool.h"
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QVariantMap>
#include <QTextStream>
#include <sqlite3.h>

// ── lifecycle ─────────────────────────────────────────────────────────────────

KnowledgeTool::KnowledgeTool(QObject *parent) : BaseTool(parent) {}

KnowledgeTool::~KnowledgeTool()
{
    if (m_db) {
        sqlite3_close(m_db);
        m_db = nullptr;
    }
}

void KnowledgeTool::setDbPath(const QString &path)
{
    if (m_db) { sqlite3_close(m_db); m_db = nullptr; }
    m_dbPath = path;
}

QVariantList KnowledgeTool::searchEntries(const QString &query, int maxResults, QString *error)
{
    QVariantList items;
    if (!ensureOpen()) {
        if (error) *error = QStringLiteral("Cannot open knowledge database at: %1").arg(m_dbPath);
        return items;
    }

    const QString normalizedQuery = query.trimmed();
    if (normalizedQuery.isEmpty()) {
        if (error) *error = QStringLiteral("query is required.");
        return items;
    }

    QString safeQuery = normalizedQuery;
    safeQuery.replace('"', ' ');

    const QString sql = QStringLiteral(
        "SELECT s.path, c.chunk_index, c.content "
        "FROM chunks c "
        "JOIN sources s ON s.id = c.source_id "
        "WHERE chunks MATCH ? "
        "ORDER BY rank "
        "LIMIT ?");

    sqlite3_stmt *stmt = nullptr;
    if (sqlite3_prepare_v2(m_db, sql.toUtf8().constData(), -1, &stmt, nullptr) != SQLITE_OK) {
        if (error) *error = QStringLiteral("Search prepare error: %1").arg(sqlite3_errmsg(m_db));
        return items;
    }

    const QByteArray qBytes = safeQuery.toUtf8();
    sqlite3_bind_text(stmt, 1, qBytes.constData(), qBytes.size(), SQLITE_STATIC);
    sqlite3_bind_int(stmt, 2, qBound(1, maxResults, 50));

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const QString src = QString::fromUtf8(
            reinterpret_cast<const char *>(sqlite3_column_text(stmt, 0)));
        const int chunk = sqlite3_column_int(stmt, 1);
        const QString text = QString::fromUtf8(
            reinterpret_cast<const char *>(sqlite3_column_text(stmt, 2)));

        QVariantMap item;
        item["path"] = src;
        item["chunkIndex"] = chunk;
        item["snippet"] = text.left(280).simplified();
        items.append(item);
    }
    sqlite3_finalize(stmt);

    return items;
}

QVariantList KnowledgeTool::sources()
{
    QVariantList list;
    if (!ensureOpen())
        return list;

    sqlite3_stmt *stmt = nullptr;
    const char *sql =
        "SELECT s.path, s.mtime, COUNT(c.rowid) "
        "FROM sources s "
        "LEFT JOIN chunks c ON c.source_id = s.id "
        "GROUP BY s.id "
        "ORDER BY s.path";

    if (sqlite3_prepare_v2(m_db, sql, -1, &stmt, nullptr) != SQLITE_OK)
        return list;

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        QVariantMap item;
        item["path"] = QString::fromUtf8(
            reinterpret_cast<const char *>(sqlite3_column_text(stmt, 0)));
        const qint64 mtime = sqlite3_column_int64(stmt, 1);
        item["updatedAt"] = QDateTime::fromSecsSinceEpoch(mtime, Qt::UTC)
                                .toString(Qt::ISODateWithMs);
        item["chunkCount"] = sqlite3_column_int(stmt, 2);
        list.append(item);
    }
    sqlite3_finalize(stmt);
    return list;
}

bool KnowledgeTool::removeSourcePath(const QString &path, QString *error)
{
    if (!ensureOpen()) {
        if (error) *error = QStringLiteral("Cannot open knowledge database.");
        return false;
    }

    const QString normalized = path.trimmed();
    if (normalized.isEmpty()) {
        if (error) *error = QStringLiteral("path is required.");
        return false;
    }

    const char *selSql = "SELECT id FROM sources WHERE path=?";
    sqlite3_stmt *sel = nullptr;
    if (sqlite3_prepare_v2(m_db, selSql, -1, &sel, nullptr) != SQLITE_OK) {
        if (error) *error = QStringLiteral("Failed to query source.");
        return false;
    }
    sqlite3_bind_text(sel, 1, normalized.toUtf8().constData(), -1, SQLITE_TRANSIENT);

    int sourceId = -1;
    if (sqlite3_step(sel) == SQLITE_ROW)
        sourceId = sqlite3_column_int(sel, 0);
    sqlite3_finalize(sel);

    if (sourceId == -1) {
        if (error) *error = QStringLiteral("Source not found: %1").arg(normalized);
        return false;
    }

    sqlite3_stmt *del = nullptr;
    sqlite3_prepare_v2(m_db, "DELETE FROM chunks WHERE source_id=?", -1, &del, nullptr);
    sqlite3_bind_int(del, 1, sourceId);
    sqlite3_step(del);
    sqlite3_finalize(del);

    sqlite3_stmt *delSrc = nullptr;
    sqlite3_prepare_v2(m_db, "DELETE FROM sources WHERE id=?", -1, &delSrc, nullptr);
    sqlite3_bind_int(delSrc, 1, sourceId);
    sqlite3_step(delSrc);
    sqlite3_finalize(delSrc);

    return true;
}

bool KnowledgeTool::removeSourcePrefix(const QString &path, QString *error)
{
    if (!ensureOpen()) {
        if (error) *error = QStringLiteral("Cannot open knowledge database.");
        return false;
    }

    const QString normalized = path.trimmed();
    if (normalized.isEmpty()) {
        if (error) *error = QStringLiteral("path is required.");
        return false;
    }

    const QString likePrefix = normalized + QStringLiteral("/%");
    sqlite3_stmt *sel = nullptr;
    if (sqlite3_prepare_v2(m_db,
                           "SELECT id FROM sources WHERE path = ? OR path LIKE ?",
                           -1, &sel, nullptr) != SQLITE_OK) {
        if (error) *error = QStringLiteral("Failed to query sources.");
        return false;
    }
    const QByteArray pathBytes = normalized.toUtf8();
    const QByteArray likeBytes = likePrefix.toUtf8();
    sqlite3_bind_text(sel, 1, pathBytes.constData(), pathBytes.size(), SQLITE_TRANSIENT);
    sqlite3_bind_text(sel, 2, likeBytes.constData(), likeBytes.size(), SQLITE_TRANSIENT);

    QList<int> sourceIds;
    while (sqlite3_step(sel) == SQLITE_ROW)
        sourceIds.append(sqlite3_column_int(sel, 0));
    sqlite3_finalize(sel);

    if (sourceIds.isEmpty())
        return true;

    sqlite3_stmt *delChunks = nullptr;
    sqlite3_prepare_v2(m_db, "DELETE FROM chunks WHERE source_id = ?", -1, &delChunks, nullptr);
    sqlite3_stmt *delSrc = nullptr;
    sqlite3_prepare_v2(m_db, "DELETE FROM sources WHERE id = ?", -1, &delSrc, nullptr);

    for (int id : sourceIds) {
        sqlite3_bind_int(delChunks, 1, id);
        sqlite3_step(delChunks);
        sqlite3_reset(delChunks);

        sqlite3_bind_int(delSrc, 1, id);
        sqlite3_step(delSrc);
        sqlite3_reset(delSrc);
    }

    sqlite3_finalize(delChunks);
    sqlite3_finalize(delSrc);
    return true;
}

// ── metadata ──────────────────────────────────────────────────────────────────

QString KnowledgeTool::description() const
{
    return QStringLiteral(
        "Local full-text knowledge base. Index files or directories, then search them. "
        "Actions: index_file, index_directory, search, list_sources, remove_source. "
        "Useful for ingesting codebases, docs, or notes and querying them with natural language.");
}

QJsonObject KnowledgeTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"action", QJsonObject{
                {"type", "string"},
                {"enum", QJsonArray{"index_file","index_directory","search",
                                    "list_sources","remove_source"}},
                {"description", "Operation to perform."},
            }},
            {"path", QJsonObject{
                {"type", "string"},
                {"description", "File or directory path (for index_file, index_directory, remove_source)."},
            }},
            {"extensions", QJsonObject{
                {"type", "array"},
                {"items", QJsonObject{{"type","string"}}},
                {"description", "File extensions to include when indexing a directory (e.g. [\"cpp\",\"h\",\"md\"])."},
            }},
            {"query", QJsonObject{
                {"type", "string"},
                {"description", "Full-text search query (for search action)."},
            }},
            {"max_results", QJsonObject{
                {"type", "integer"},
                {"description", "Maximum number of chunks to return (default 10, max 50)."},
            }},
        }},
        {"required", QJsonArray{"action"}},
    };
}

QString KnowledgeTool::summary(const QJsonObject &args) const
{
    const QString action = args.value("action").toString();
    const QString path   = args.value("path").toString();
    const QString query  = args.value("query").toString();
    if (!path.isEmpty()) return QStringLiteral("knowledge %1: %2").arg(action, path);
    if (!query.isEmpty()) return QStringLiteral("knowledge search: %1").arg(query);
    return QStringLiteral("knowledge %1").arg(action);
}

// ── execute dispatch ──────────────────────────────────────────────────────────

ToolResult KnowledgeTool::execute(const QString &callId, const QJsonObject &args)
{
    if (!ensureOpen())
        return {callId, name(), true,
                QStringLiteral("Cannot open knowledge database at: %1").arg(m_dbPath)};

    const QString action = args.value("action").toString().trimmed();
    if (action == "index_file") {
        return actionIndexFile(callId, args.value("path").toString());
    } else if (action == "index_directory") {
        QStringList exts;
        for (const auto &v : args.value("extensions").toArray())
            exts << v.toString();
        return actionIndexDirectory(callId, args.value("path").toString(), exts);
    } else if (action == "search") {
        const int maxR = qBound(1, args.value("max_results").toInt(10), 50);
        return actionSearch(callId, args.value("query").toString(), maxR);
    } else if (action == "list_sources") {
        return actionListSources(callId);
    } else if (action == "remove_source") {
        return actionRemoveSource(callId, args.value("path").toString());
    }
    return {callId, name(), true, QStringLiteral("Unknown action: %1").arg(action)};
}

// ── database setup ────────────────────────────────────────────────────────────

bool KnowledgeTool::ensureOpen()
{
    if (m_db) return true;
    if (m_dbPath.isEmpty()) return false;

    // Ensure directory exists.
    QDir().mkpath(QFileInfo(m_dbPath).absolutePath());

    if (sqlite3_open(m_dbPath.toUtf8().constData(), &m_db) != SQLITE_OK) {
        qWarning() << "[KnowledgeTool] sqlite3_open failed:" << sqlite3_errmsg(m_db);
        sqlite3_close(m_db);
        m_db = nullptr;
        return false;
    }
    ensureSchema();
    return true;
}

void KnowledgeTool::ensureSchema()
{
    const char *ddl =
        "PRAGMA journal_mode=WAL;"
        "CREATE TABLE IF NOT EXISTS sources("
        "  id   INTEGER PRIMARY KEY,"
        "  path TEXT UNIQUE NOT NULL,"
        "  mtime INTEGER NOT NULL DEFAULT 0"
        ");"
        "CREATE VIRTUAL TABLE IF NOT EXISTS chunks USING fts5("
        "  source_id UNINDEXED,"
        "  chunk_index UNINDEXED,"
        "  content,"
        "  tokenize='porter ascii'"
        ");";
    char *errMsg = nullptr;
    sqlite3_exec(m_db, ddl, nullptr, nullptr, &errMsg);
    if (errMsg) {
        qWarning() << "[KnowledgeTool] schema error:" << errMsg;
        sqlite3_free(errMsg);
    }
}

// ── actions ───────────────────────────────────────────────────────────────────

ToolResult KnowledgeTool::actionIndexFile(const QString &callId, const QString &path)
{
    if (path.isEmpty())
        return {callId, name(), true, "path is required."};

    QFile f(path);
    if (!f.exists())
        return {callId, name(), true, QStringLiteral("File not found: %1").arg(path)};
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {callId, name(), true, QStringLiteral("Cannot read: %1").arg(path)};

    const QString content = QTextStream(&f).readAll();
    f.close();

    const int n = indexContent(path, content);
    return {callId, name(), false,
            QStringLiteral("Indexed %1: %2 chunks").arg(path).arg(n)};
}

ToolResult KnowledgeTool::actionIndexDirectory(const QString &callId,
                                               const QString &dirPath,
                                               const QStringList &extensions)
{
    if (dirPath.isEmpty())
        return {callId, name(), true, "path is required."};

    QDir dir(dirPath);
    if (!dir.exists())
        return {callId, name(), true, QStringLiteral("Directory not found: %1").arg(dirPath)};

    QStringList filters;
    if (!extensions.isEmpty()) {
        for (const auto &e : extensions)
            filters << QStringLiteral("*.%1").arg(e);
    }

    QDirIterator it(dirPath, filters.isEmpty() ? QStringList{"*"} : filters,
                    QDir::Files | QDir::Readable,
                    QDirIterator::Subdirectories);

    int fileCount = 0, chunkCount = 0;
    while (it.hasNext()) {
        const QString filePath = it.next();
        // Skip binary files by size guess; skip very large files.
        const qint64 sz = QFileInfo(filePath).size();
        if (sz > 5 * 1024 * 1024 || sz == 0) continue;

        QFile f(filePath);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        const QString content = QTextStream(&f).readAll();
        f.close();
        chunkCount += indexContent(filePath, content);
        ++fileCount;
    }

    return {callId, name(), false,
            QStringLiteral("Indexed %1 files, %2 chunks from %3")
                .arg(fileCount).arg(chunkCount).arg(dirPath)};
}

ToolResult KnowledgeTool::actionSearch(const QString &callId,
                                       const QString &query, int maxResults)
{
    QString error;
    const QVariantList entries = searchEntries(query, maxResults, &error);
    if (!error.isEmpty())
        return {callId, name(), true, error};
    if (entries.isEmpty())
        return {callId, name(), false,
                QStringLiteral("No results found for: %1").arg(query)};

    QStringList results;
    results << QStringLiteral("Search results for: %1\n").arg(query);
    int idx = 1;
    for (const auto &value : entries) {
        const auto map = value.toMap();
        results << QStringLiteral("[%1] %2 (chunk %3)\n%4")
                       .arg(idx++)
                       .arg(map.value("path").toString())
                       .arg(map.value("chunkIndex").toInt())
                       .arg(map.value("snippet").toString());
    }
    return {callId, name(), false, results.join("\n\n")};
}

ToolResult KnowledgeTool::actionListSources(const QString &callId)
{
    const QVariantList items = sources();
    if (items.isEmpty())
        return {callId, name(), false, "No sources indexed yet."};
    QStringList lines;
    for (const auto &value : items) {
        const auto map = value.toMap();
        lines << QStringLiteral("- %1 (%2 chunks, %3)")
                     .arg(map.value("path").toString(),
                          map.value("chunkCount").toString(),
                          map.value("updatedAt").toString());
    }
    return {callId, name(), false,
            QStringLiteral("Indexed sources (%1):\n").arg(items.size())
            + lines.join("\n")};
}

ToolResult KnowledgeTool::actionRemoveSource(const QString &callId,
                                             const QString &path)
{
    QString error;
    if (!removeSourcePath(path, &error))
        return {callId, name(), false, error.isEmpty()
            ? QStringLiteral("Source removal failed.")
            : error};
    return {callId, name(), false,
            QStringLiteral("Removed source: %1").arg(path)};
}

// ── chunking ──────────────────────────────────────────────────────────────────

int KnowledgeTool::indexContent(const QString &sourcePath, const QString &content)
{
    // Upsert source row.
    sqlite3_stmt *upsert = nullptr;
    sqlite3_prepare_v2(m_db,
        "INSERT OR REPLACE INTO sources(path, mtime) VALUES(?, ?)",
        -1, &upsert, nullptr);
    const QByteArray pathBytes = sourcePath.toUtf8();
    sqlite3_bind_text(upsert, 1, pathBytes.constData(), pathBytes.size(), SQLITE_STATIC);
    sqlite3_bind_int64(upsert, 2, QFileInfo(sourcePath).lastModified().toSecsSinceEpoch());
    sqlite3_step(upsert); sqlite3_finalize(upsert);

    // Get source id.
    sqlite3_stmt *idSel = nullptr;
    sqlite3_prepare_v2(m_db, "SELECT id FROM sources WHERE path=?", -1, &idSel, nullptr);
    sqlite3_bind_text(idSel, 1, pathBytes.constData(), pathBytes.size(), SQLITE_STATIC);
    int sourceId = 0;
    if (sqlite3_step(idSel) == SQLITE_ROW) sourceId = sqlite3_column_int(idSel, 0);
    sqlite3_finalize(idSel);

    // Delete existing chunks for this source.
    sqlite3_stmt *delOld = nullptr;
    sqlite3_prepare_v2(m_db,
        "DELETE FROM chunks WHERE source_id=?", -1, &delOld, nullptr);
    sqlite3_bind_int(delOld, 1, sourceId);
    sqlite3_step(delOld); sqlite3_finalize(delOld);

    // Chunk content with overlap.
    sqlite3_stmt *ins = nullptr;
    sqlite3_prepare_v2(m_db,
        "INSERT INTO chunks(source_id, chunk_index, content) VALUES(?,?,?)",
        -1, &ins, nullptr);

    int chunkIdx  = 0;
    int offset    = 0;
    const int len = content.length();
    while (offset < len) {
        const QString chunk = content.mid(offset, kChunkSize);
        const QByteArray cb = chunk.toUtf8();
        sqlite3_bind_int(ins,  1, sourceId);
        sqlite3_bind_int(ins,  2, chunkIdx);
        sqlite3_bind_text(ins, 3, cb.constData(), cb.size(), SQLITE_TRANSIENT);
        sqlite3_step(ins);
        sqlite3_reset(ins);
        ++chunkIdx;
        offset += kChunkSize - kChunkOverlap;
    }
    sqlite3_finalize(ins);
    return chunkIdx;
}
