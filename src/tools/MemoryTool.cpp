#include "tools/MemoryTool.h"
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QSaveFile>
#include <QTextStream>
#include <algorithm>

// ── constants ────────────────────────────────────────────────────────────────
const QString MemoryTool::kDelimiter = QStringLiteral("\n§\n");
const int     MemoryTool::kMaxChars  = 24000;

static const char *kStoreNames[] = { "agent", "user" };
static const char *kFileNames[]  = { "MEMORY.md", "USER.md" };

// ── ctor ─────────────────────────────────────────────────────────────────────
MemoryTool::MemoryTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
    // Ensure .neurx/ exists.
    QDir root(workspaceRoot);
    root.mkpath(QStringLiteral(".neurx"));
}

// ── description / schema ─────────────────────────────────────────────────────
QString MemoryTool::description() const
{
    return QStringLiteral(
        "Persistent memory across sessions. Two stores:\n"
        "  agent — your own notes: project conventions, tool quirks, codebase facts.\n"
        "  user  — notes about the user: preferences, workflow, communication style.\n"
        "Actions:\n"
        "  add     — append a new entry (content required).\n"
        "  replace — replace an existing entry matched by a short unique substring (match + content).\n"
        "  remove  — delete an entry matched by a short unique substring (match).\n"
        "  read    — return the current contents of a store.\n"
        "Entries are separated by § (section sign). Max store size: 24 000 chars.");
}

QJsonObject MemoryTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"action",  QJsonObject{{"type","string"},
                {"enum", QJsonArray{"add","replace","remove","read"}}}},
            {"store",   QJsonObject{{"type","string"},
                {"enum", QJsonArray{"agent","user"}},
                {"description","Which memory store to operate on. Default: agent"}}},
            {"content", QJsonObject{{"type","string"},
                {"description","Entry text (required for add / replace)."}}},
            {"match",   QJsonObject{{"type","string"},
                {"description","Short unique substring used to locate an entry for replace / remove."}}},
        }},
        {"required", QJsonArray{"action"}},
    };
}

// ── execute ──────────────────────────────────────────────────────────────────
ToolResult MemoryTool::execute(const QString &callId, const QJsonObject &args)
{
    Q_UNUSED(callId)
    const QString actionStr = args.value("action").toString().trimmed().toLower();
    const QString storeStr  = args.value("store").toString().trimmed().toLower();
    const Store   store     = (storeStr == "user") ? Store::User : Store::Agent;

    if (actionStr == "add")     return opAdd    (store, args);
    if (actionStr == "replace") return opReplace(store, args);
    if (actionStr == "remove")  return opRemove (store, args);
    if (actionStr == "read")    return opRead   (store);

    return ToolResult{ callId, name(), true, "Unknown action: " + actionStr };
}

QString MemoryTool::summary(const QJsonObject &args) const
{
    const QString a = args.value("action").toString();
    const QString s = args.value("store").toString();
    return QStringLiteral("memory %1 [%2]").arg(a, s.isEmpty() ? "agent" : s);
}

// ── buildSnapshot ─────────────────────────────────────────────────────────────
QString MemoryTool::buildSnapshot() const
{
    QString snap;
    const QString agentMem = readRaw(Store::Agent).trimmed();
    const QString userMem  = readRaw(Store::User).trimmed();
    if (!agentMem.isEmpty())
        snap += QStringLiteral("## Agent Memory (MEMORY.md)\n") + agentMem + "\n";
    if (!userMem.isEmpty())
        snap += QStringLiteral("\n## User Memory (USER.md)\n") + userMem + "\n";
    return snap;
}

// ── private operations ────────────────────────────────────────────────────────
ToolResult MemoryTool::opAdd(Store store, const QJsonObject &args)
{
    const QString content = args.value("content").toString().trimmed();
    if (content.isEmpty())
        return ToolResult{ {}, name(), true, "content is required for add" };

    QString raw = readRaw(store);
    if (!raw.isEmpty() && !raw.endsWith(kDelimiter))
        raw += kDelimiter;
    raw += content;

    if (raw.size() > kMaxChars)
        return ToolResult{ {}, name(), true,
            QStringLiteral("Store would exceed %1 chars. Remove old entries first.").arg(kMaxChars) };

    if (!writeRaw(store, raw))
        return ToolResult{ {}, name(), true, "Failed to write memory file." };

    return ToolResult{ {}, name(), false,
        QStringLiteral("Added to %1 memory. Total chars: %2")
            .arg(QLatin1String(kStoreNames[static_cast<int>(store)]))
            .arg(raw.size()) };
}

ToolResult MemoryTool::opReplace(Store store, const QJsonObject &args)
{
    const QString match   = args.value("match").toString().trimmed();
    const QString content = args.value("content").toString().trimmed();
    if (match.isEmpty() || content.isEmpty())
        return ToolResult{ {}, name(), true, "match and content are required for replace" };

    QString raw = readRaw(store);
    QStringList entries = raw.split(kDelimiter);
    bool replaced = false;
    for (auto &entry : entries) {
        if (entry.contains(match)) {
            entry = content;
            replaced = true;
            break;
        }
    }
    if (!replaced)
        return ToolResult{ {}, name(), true, "No entry found matching: " + match };

    const QString newRaw = entries.join(kDelimiter);
    if (newRaw.size() > kMaxChars)
        return ToolResult{ {}, name(), true,
            QStringLiteral("Store would exceed %1 chars after replace.").arg(kMaxChars) };

    if (!writeRaw(store, newRaw))
        return ToolResult{ {}, name(), true, "Failed to write memory file." };

    return ToolResult{ {}, name(), false, "Entry replaced." };
}

ToolResult MemoryTool::opRemove(Store store, const QJsonObject &args)
{
    const QString match = args.value("match").toString().trimmed();
    if (match.isEmpty())
        return ToolResult{ {}, name(), true, "match is required for remove" };

    QString raw = readRaw(store);
    QStringList entries = raw.split(kDelimiter);
    const int before = entries.size();
    entries.erase(
        std::remove_if(entries.begin(), entries.end(),
            [&match](const QString &e){ return e.contains(match); }),
        entries.end());

    if (entries.size() == before)
        return ToolResult{ {}, name(), true, "No entry found matching: " + match };

    if (!writeRaw(store, entries.join(kDelimiter)))
        return ToolResult{ {}, name(), true, "Failed to write memory file." };

    return ToolResult{ {}, name(), false,
        QStringLiteral("Removed %1 entry/entries.").arg(before - entries.size()) };
}

ToolResult MemoryTool::opRead(Store store)
{
    const QString raw = readRaw(store).trimmed();
    if (raw.isEmpty())
        return ToolResult{ {}, name(), false,
            QStringLiteral("%1 memory is empty.")
                .arg(QLatin1String(kStoreNames[static_cast<int>(store)])) };
    return ToolResult{ {}, name(), false, raw };
}

// ── I/O helpers ──────────────────────────────────────────────────────────────
QString MemoryTool::filePath(Store store) const
{
    return m_workspaceRoot + QStringLiteral("/.neurx/")
         + QLatin1String(kFileNames[static_cast<int>(store)]);
}

QString MemoryTool::readRaw(Store store) const
{
    QFile f(filePath(store));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QTextStream(&f).readAll();
}

bool MemoryTool::writeRaw(Store store, const QString &content) const
{
    QSaveFile f(filePath(store));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream out(&f);
    out << content;
    return f.commit();
}
