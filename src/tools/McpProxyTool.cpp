#include "tools/McpProxyTool.h"
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

// ── McpProxyTool ──────────────────────────────────────────────────────────────

McpProxyTool::McpProxyTool(const McpToolDef &def,
                           QSharedPointer<McpClient> client,
                           QObject *parent)
    : BaseTool(parent), m_def(def), m_client(client)
{
}

QString McpProxyTool::summary(const QJsonObject &args) const
{
    const QString firstArg = args.isEmpty()
        ? QString()
        : args.begin().value().toString();
    return QStringLiteral("[%1] %2 %3")
        .arg(m_client->serverName(), m_def.name, firstArg);
}

ToolResult McpProxyTool::execute(const QString &callId, const QJsonObject &args)
{
    if (!m_client->isRunning()) {
        return {callId, name(), true,
                QStringLiteral("MCP server '%1' is not running.")
                    .arg(m_client->serverName())};
    }

    bool isError = false;
    const QString result = m_client->callTool(m_def.name, args, isError);
    return {callId, name(), isError, result};
}

// ── McpServerLoader ───────────────────────────────────────────────────────────

QList<BaseTool *> McpServerLoader::loadFromConfig(const QString &workspacePath,
                                                   QObject *toolParent)
{
    QList<BaseTool *> tools;

    const QString configPath =
        QDir(workspacePath).filePath(QStringLiteral(".neurx/mcp.json"));
    QFile f(configPath);
    if (!f.exists()) return tools;
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "[MCP] Cannot open" << configPath;
        return tools;
    }

    QJsonParseError pe;
    const auto doc = QJsonDocument::fromJson(f.readAll(), &pe);
    f.close();
    if (pe.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[MCP] Parse error in" << configPath << ":" << pe.errorString();
        return tools;
    }

    const auto servers = doc.object().value("servers").toArray();
    for (const auto &sv : servers) {
        const auto s = sv.toObject();
        const QString sname   = s.value("name").toString();
        const QString command = s.value("command").toString();
        if (sname.isEmpty() || command.isEmpty()) continue;

        QStringList args;
        for (const auto &a : s.value("args").toArray())
            args << a.toString();

        QHash<QString, QString> env;
        const auto envObj = s.value("env").toObject();
        for (auto it = envObj.constBegin(); it != envObj.constEnd(); ++it)
            env[it.key()] = it.value().toString();

        auto client = QSharedPointer<McpClient>::create(
            sname, command, args, env);

        if (!client->start()) {
            qWarning() << "[MCP] Failed to start server:" << sname;
            continue;
        }

        const auto toolDefs = client->listTools();
        qDebug() << "[MCP]" << sname << "provides" << toolDefs.size() << "tools";

        for (const auto &def : toolDefs) {
            auto *proxy = new McpProxyTool(def, client, toolParent);
            tools.append(proxy);
        }
    }

    return tools;
}
