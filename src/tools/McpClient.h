#pragma once
#include <QByteArray>
#include <QHash>
#include <QJsonObject>
#include <QJsonArray>
#include <QMutex>
#include <QObject>
#include <QProcess>
#include <QString>
#include <QVariant>

// ── McpClient ─────────────────────────────────────────────────────────────────
//  Minimal MCP (Model Context Protocol) client over stdio JSON-RPC 2.0.
//  Each McpClient owns exactly one server process.
//  Thread-safe: call all methods from any thread; responses are waited
//  on synchronously (blocking) up to a configurable timeout.

struct McpToolDef {
    QString     name;
    QString     description;
    QJsonObject inputSchema;
};

class McpClient : public QObject {
    Q_OBJECT
public:
    explicit McpClient(const QString &serverName,
                       const QString &command,
                       const QStringList &args,
                       const QHash<QString, QString> &env,
                       QObject *parent = nullptr);
    ~McpClient() override;

    // Start the server process and perform the MCP initialization handshake.
    // Returns true on success.  Must be called before listTools() / callTool().
    bool start(int timeoutMs = 10000);

    // Retrieve the list of tools advertised by this server.
    QList<McpToolDef> listTools(int timeoutMs = 10000);

    // Call a tool. Returns the plain-text / JSON result or an error string.
    // isError is set to true if the server returned an error.
    QString callTool(const QString &toolName, const QJsonObject &args,
                     bool &isError, int timeoutMs = 30000);

    QString serverName() const { return m_serverName; }
    bool    isRunning()  const;

private:
    QJsonObject sendRequest(const QString &method,
                            const QJsonObject &params,
                            int timeoutMs);
    void sendNotification(const QString &method, const QJsonObject &params);

    QString         m_serverName;
    QString         m_command;
    QStringList     m_args;
    QHash<QString, QString> m_env;
    QProcess       *m_process{nullptr};
    int             m_nextId{1};
    mutable QMutex  m_mutex;
};
