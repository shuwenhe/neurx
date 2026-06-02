#include "tools/McpClient.h"
#include <QDebug>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QJsonDocument>
#include <QMutexLocker>
#include <QProcessEnvironment>
#include <QTimer>

// MCP protocol version we advertise.
static const char kMcpVersion[] = "2024-11-05";

McpClient::McpClient(const QString &serverName,
                     const QString &command,
                     const QStringList &args,
                     const QHash<QString, QString> &env,
                     QObject *parent)
    : QObject(parent)
    , m_serverName(serverName)
    , m_command(command)
    , m_args(args)
    , m_env(env)
{
}

McpClient::~McpClient()
{
    if (m_process && m_process->state() != QProcess::NotRunning) {
        m_process->terminate();
        m_process->waitForFinished(2000);
    }
    delete m_process;
}

bool McpClient::isRunning() const
{
    return m_process && m_process->state() == QProcess::Running;
}

bool McpClient::start(int timeoutMs)
{
    if (isRunning()) return true;

    delete m_process;
    m_process = new QProcess(this);

    // Apply custom environment variables.
    if (!m_env.isEmpty()) {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        for (auto it = m_env.constBegin(); it != m_env.constEnd(); ++it)
            env.insert(it.key(), it.value());
        m_process->setProcessEnvironment(env);
    }

    m_process->setReadChannel(QProcess::StandardOutput);
    m_process->start(m_command, m_args);
    if (!m_process->waitForStarted(timeoutMs)) {
        qWarning() << "[MCP]" << m_serverName << "failed to start:" << m_process->errorString();
        return false;
    }

    // Send initialize request.
    const QJsonObject initParams{
        {"protocolVersion", kMcpVersion},
        {"clientInfo", QJsonObject{{"name", "neurx"}, {"version", "1.0.0"}}},
        {"capabilities", QJsonObject{}},
    };

    const auto resp = sendRequest("initialize", initParams, timeoutMs);
    if (resp.contains("error")) {
        qWarning() << "[MCP]" << m_serverName << "initialize error:" << resp;
        return false;
    }

    // Send 'initialized' notification (no response expected).
    sendNotification("notifications/initialized", {});
    qDebug() << "[MCP]" << m_serverName << "ready. Protocol:"
             << resp.value("result").toObject().value("protocolVersion").toString();
    return true;
}

QList<McpToolDef> McpClient::listTools(int timeoutMs)
{
    const auto resp = sendRequest("tools/list", QJsonObject{}, timeoutMs);
    const auto result = resp.value("result").toObject();
    const auto tools  = result.value("tools").toArray();

    QList<McpToolDef> defs;
    defs.reserve(tools.size());
    for (const auto &v : tools) {
        const auto t = v.toObject();
        McpToolDef d;
        d.name        = t.value("name").toString();
        d.description = t.value("description").toString();
        d.inputSchema = t.value("inputSchema").toObject();
        if (!d.name.isEmpty())
            defs.append(d);
    }
    return defs;
}

QString McpClient::callTool(const QString &toolName, const QJsonObject &args,
                            bool &isError, int timeoutMs)
{
    const QJsonObject params{
        {"name", toolName},
        {"arguments", args},
    };

    const auto resp = sendRequest("tools/call", params, timeoutMs);

    if (resp.contains("error")) {
        isError = true;
        const auto errObj = resp.value("error").toObject();
        return errObj.value("message").toString(
            QJsonDocument(errObj).toJson(QJsonDocument::Compact));
    }

    const auto result = resp.value("result").toObject();
    if (result.value("isError").toBool()) {
        isError = true;
    }

    const auto content = result.value("content").toArray();
    QStringList parts;
    for (const auto &cv : content) {
        const auto c = cv.toObject();
        const QString type = c.value("type").toString();
        if (type == "text")
            parts << c.value("text").toString();
        else
            parts << QJsonDocument(c).toJson(QJsonDocument::Compact);
    }
    return parts.join("\n");
}

// ── internal JSON-RPC helpers ─────────────────────────────────────────────────

void McpClient::sendNotification(const QString &method, const QJsonObject &params)
{
    if (!isRunning()) return;
    QJsonObject msg{
        {"jsonrpc", "2.0"},
        {"method",  method},
    };
    if (!params.isEmpty()) msg["params"] = params;
    m_process->write(QJsonDocument(msg).toJson(QJsonDocument::Compact) + "\n");
}

QJsonObject McpClient::sendRequest(const QString &method,
                                   const QJsonObject &params,
                                   int timeoutMs)
{
    QMutexLocker lock(&m_mutex);

    if (!m_process || m_process->state() == QProcess::NotRunning)
        return {{"error", QJsonObject{{"code", -32000}, {"message", "Server not running"}}}};

    const int id = m_nextId++;
    QJsonObject msg{
        {"jsonrpc", "2.0"},
        {"id",      id},
        {"method",  method},
    };
    if (!params.isEmpty()) msg["params"] = params;

    const QByteArray line = QJsonDocument(msg).toJson(QJsonDocument::Compact) + "\n";
    m_process->write(line);

    // Wait for a response line with matching id.
    QByteArray accumulated;
    QElapsedTimer elapsed;
    elapsed.start();

    while (elapsed.elapsed() < timeoutMs) {
        if (!m_process->waitForReadyRead(
                qMax(100, (int)(timeoutMs - elapsed.elapsed()))))
            break;

        accumulated += m_process->readAllStandardOutput();

        // Process all complete lines.
        while (true) {
            const int nl = accumulated.indexOf('\n');
            if (nl == -1) break;
            const QByteArray jsonLine = accumulated.left(nl).trimmed();
            accumulated.remove(0, nl + 1);

            if (jsonLine.isEmpty()) continue;

            QJsonParseError pe;
            const auto doc = QJsonDocument::fromJson(jsonLine, &pe);
            if (pe.error != QJsonParseError::NoError) continue;

            const auto obj = doc.object();
            if (obj.value("id").toInt(-1) == id)
                return obj; // matched
        }
    }

    return {{"error", QJsonObject{{"code", -32001}, {"message", "Timeout waiting for response"}}}};
}
