#pragma once
#include "agent/AgentToolRegistry.h"
#include "tools/McpClient.h"
#include <QSharedPointer>

// ── McpProxyTool ──────────────────────────────────────────────────────────────
//  Wraps one tool exposed by an MCP server as a neurx BaseTool.
//  Multiple McpProxyTool instances share a single McpClient.

class McpProxyTool : public BaseTool {
    Q_OBJECT
public:
    McpProxyTool(const McpToolDef &def,
                 QSharedPointer<McpClient> client,
                 QObject *parent = nullptr);

    QString     name()        const override { return m_def.name; }
    QString     description() const override { return m_def.description; }
    QJsonObject parametersSchema() const override { return m_def.inputSchema; }
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    McpToolDef               m_def;
    QSharedPointer<McpClient> m_client;
};

// ── McpServerLoader ───────────────────────────────────────────────────────────
//  Reads <workspace>/.neurx/mcp.json and creates all proxy tools.
//  mcp.json format:
//    { "servers": [
//        { "name": "...", "command": "...", "args": ["..."], "env": {"K":"V"} }
//      ]
//    }

class McpServerLoader {
public:
    // Returns tools registered from all configured MCP servers.
    // toolOut receives ownership of all created BaseTool objects (parent = nullptr).
    static QList<BaseTool *> loadFromConfig(const QString &workspacePath,
                                            QObject *toolParent = nullptr);
};
