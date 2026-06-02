#include "tools/SessionStore.h"
#include <QDir>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUuid>
#include <sqlite3.h>

// ── helpers ───────────────────────────────────────────────────────────────────
static inline sqlite3 *db_cast(void *p) { return static_cast<sqlite3 *>(p); }

// ── ctor / dtor ───────────────────────────────────────────────────────────────
SessionStore::SessionStore(QObject *parent) : BaseTool(parent)
{
    const QString dataDir =
        QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
        + QStringLiteral("/.neurx");
    QDir().mkpath(dataDir);
    m_dbPath = dataDir + QStringLiteral("/sessions.db");
    openDb();
}

SessionStore::~SessionStore()
{
    if (m_db) sqlite3_close(db_cast(m_db));
}

// ── openDb / ensureSchema ─────────────────────────────────────────────────────
bool SessionStore::openDb()
{
    sqlite3 *raw = nullptr;
    if (sqlite3_open(m_dbPath.toUtf8().constData(), &raw) != SQLITE_OK) {
        sqlite3_close(raw);
        return false;
    }
    m_db = raw;
    sqlite3_exec(db_cast(m_db), "PRAGMA journal_mode=WAL;", nullptr, nullptr, nullptr);
    return ensureSchema();
}

bool SessionStore::ensureSchema()
{
    const char *ddl = R"(
        CREATE TABLE IF NOT EXISTS sessions (
            id          TEXT PRIMARY KEY,
            workspace   TEXT,
            started_at  INTEGER
        );
        CREATE TABLE IF NOT EXISTS messages (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id  TEXT,
            role        TEXT,
            content     TEXT,
            ts          INTEGER
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts
            USING fts5(content, content='messages', content_rowid='id');
        CREATE TRIGGER IF NOT EXISTS messages_ai
            AFTER INSERT ON messages BEGIN
                INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
            END;
    )";
    return sqlite3_exec(db_cast(m_db), ddl, nullptr, nullptr, nullptr) == SQLITE_OK;
}

// ── beginSession / appendMessage ─────────────────────────────────────────────
void SessionStore::beginSession(const QString &workspacePath)
{
    if (!m_db) return;
    m_sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const qint64 now = QDateTime::currentSecsSinceEpoch();

    sqlite3_stmt *stmt = nullptr;
    const char *sql = "INSERT INTO sessions(id, workspace, started_at) VALUES (?,?,?)";
    if (sqlite3_prepare_v2(db_cast(m_db), sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, m_sessionId.toUtf8().constData(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, workspacePath.toUtf8().constData(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 3, now);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
}

void SessionStore::appendMessage(const QString &role, const QString &content)
{
    if (!m_db || m_sessionId.isEmpty()) return;
    const qint64 now = QDateTime::currentSecsSinceEpoch();

    sqlite3_stmt *stmt = nullptr;
    const char *sql =
        "INSERT INTO messages(session_id, role, content, ts) VALUES (?,?,?,?)";
    if (sqlite3_prepare_v2(db_cast(m_db), sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, m_sessionId.toUtf8().constData(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, role.toUtf8().constData(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, content.toUtf8().constData(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 4, now);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
}

// ── search ───────────────────────────────────────────────────────────────────
QString SessionStore::search(const QString &query, int maxResults)
{
    if (!m_db) return "Session database not available.";

    // FTS5 match to find relevant message rows.
    const char *sql = R"(
        SELECT m.session_id, s.workspace, s.started_at,
               snippet(messages_fts, 0, '[', ']', '...', 32) AS excerpt,
               m.role
        FROM messages_fts
        JOIN messages m    ON messages_fts.rowid = m.id
        JOIN sessions s    ON m.session_id = s.id
        WHERE messages_fts MATCH ?
          AND m.session_id != ?
        ORDER BY rank
        LIMIT ?
    )";

    sqlite3_stmt *stmt = nullptr;
    if (sqlite3_prepare_v2(db_cast(m_db), sql, -1, &stmt, nullptr) != SQLITE_OK)
        return "Search error: " + QString::fromUtf8(sqlite3_errmsg(db_cast(m_db)));

    // Escape FTS special chars simply.
    const QString escaped = "\"" + query.trimmed().replace("\"","\"\"") + "\"";
    sqlite3_bind_text(stmt, 1, escaped.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, m_sessionId.toUtf8().constData(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 3, maxResults * 5); // over-fetch; de-dup by session below

    // Collect unique sessions.
    QStringList sessionsSeen;
    QStringList results;
    while (sqlite3_step(stmt) == SQLITE_ROW && sessionsSeen.size() < maxResults) {
        const QString sid      = QString::fromUtf8((const char *)sqlite3_column_text(stmt, 0));
        const QString wsp      = QString::fromUtf8((const char *)sqlite3_column_text(stmt, 1));
        const qint64  ts       = sqlite3_column_int64(stmt, 2);
        const QString excerpt  = QString::fromUtf8((const char *)sqlite3_column_text(stmt, 3));
        const QString role     = QString::fromUtf8((const char *)sqlite3_column_text(stmt, 4));

        if (sessionsSeen.contains(sid)) continue;
        sessionsSeen << sid;

        const QString date = QDateTime::fromSecsSinceEpoch(ts).toString("yyyy-MM-dd");
        results << QStringLiteral("[%1 | %2]\n%3: %4")
                       .arg(date, wsp, role, excerpt);
    }
    sqlite3_finalize(stmt);

    if (results.isEmpty())
        return QStringLiteral("No past sessions found matching: %1").arg(query);
    return QStringLiteral("Past sessions matching \"%1\":\n\n%2")
        .arg(query, results.join("\n\n---\n\n"));
}

// ── BaseTool interface ────────────────────────────────────────────────────────
QString SessionStore::description() const
{
    return QStringLiteral(
        "Search past conversation sessions for relevant context. "
        "Useful for recalling how a problem was solved before, or what was discussed about a topic. "
        "Returns excerpts from matching past sessions. "
        "Parameters: query (FTS5 text search), max_results (default 3).");
}

QJsonObject SessionStore::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"query", QJsonObject{
                {"type","string"},
                {"description","Natural language or keyword search over past sessions."},
            }},
            {"max_results", QJsonObject{
                {"type","integer"},
                {"description","Number of past sessions to return (default 3, max 10)."},
            }},
        }},
        {"required", QJsonArray{"query"}},
    };
}

ToolResult SessionStore::execute(const QString &callId, const QJsonObject &args)
{
    const QString query = args.value("query").toString().trimmed();
    if (query.isEmpty())
        return ToolResult{ callId, name(), true, "query is required." };
    const int maxR = qBound(1, args.value("max_results").toInt(3), 10);
    return ToolResult{ callId, name(), false, search(query, maxR) };
}

QString SessionStore::summary(const QJsonObject &args) const
{
    return QStringLiteral("session_search: %1").arg(args.value("query").toString());
}
