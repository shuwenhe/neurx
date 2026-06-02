#include "tools/LocalGatewayServer.h"

#include <QJsonDocument>
#include <QJsonParseError>
#include <QHostAddress>
#include <QUrl>
#include <QUrlQuery>

namespace {

static QHash<QString, QString> parseHeaders(const QList<QByteArray> &lines)
{
    QHash<QString, QString> headers;
    for (const QByteArray &lineBytes : lines) {
        const QString line = QString::fromLatin1(lineBytes).trimmed();
        const int colon = line.indexOf(':');
        if (colon <= 0)
            continue;
        const QString key = line.left(colon).trimmed().toLower();
        const QString value = line.mid(colon + 1).trimmed();
        headers.insert(key, value);
    }
    return headers;
}

static QByteArray jsonBytes(const QJsonObject &object)
{
    return QJsonDocument(object).toJson(QJsonDocument::Compact);
}

static QString formatTaskPrompt(const QJsonObject &object)
{
    const QString title = object.value(QStringLiteral("title")).toString().trimmed();
    const QString description = object.value(QStringLiteral("description")).toString().trimmed();
    const QString details = object.value(QStringLiteral("details")).toString().trimmed();
    const QString source = object.value(QStringLiteral("source")).toString().trimmed();
    const QString priority = object.value(QStringLiteral("priority")).toString().trimmed();
    const QString due = object.value(QStringLiteral("due")).toString().trimmed();

    QStringList lines;
    lines << QStringLiteral("External task received.");
    if (!title.isEmpty())
        lines << QStringLiteral("Title: %1").arg(title);
    if (!description.isEmpty())
        lines << QStringLiteral("Description: %1").arg(description);
    if (!details.isEmpty())
        lines << QStringLiteral("Details: %1").arg(details);
    if (!source.isEmpty())
        lines << QStringLiteral("Source: %1").arg(source);
    if (!priority.isEmpty())
        lines << QStringLiteral("Priority: %1").arg(priority);
    if (!due.isEmpty())
        lines << QStringLiteral("Due: %1").arg(due);

    lines << QStringLiteral("Acknowledge the task, decide the next concrete step, and proceed.");
    return lines.join(QStringLiteral("\n"));
}

} // namespace

LocalGatewayServer::LocalGatewayServer(QObject *parent)
    : QObject(parent)
{
}

bool LocalGatewayServer::start(quint16 preferredPort, MessageHandler messageHandler, StateProvider stateProvider)
{
    stop();
    m_messageHandler = std::move(messageHandler);
    m_stateProvider = std::move(stateProvider);

    const quint16 startPort = preferredPort == 0 ? quint16(18081) : preferredPort;
    for (int i = 0; i < 12; ++i) {
        const quint16 port = quint16(startPort + i);
        if (!m_server.listen(QHostAddress::LocalHost, port))
            continue;
        m_port = m_server.serverPort();
        connect(&m_server, &QTcpServer::newConnection,
                this, &LocalGatewayServer::onNewConnection);
        return true;
    }

    return false;
}

void LocalGatewayServer::stop()
{
    const auto sockets = m_buffers.keys();
    for (QTcpSocket *socket : sockets) {
        if (socket)
            socket->deleteLater();
    }
    m_buffers.clear();

    if (m_server.isListening()) {
        m_server.close();
    }
    m_port = 0;
}

bool LocalGatewayServer::isRunning() const
{
    return m_server.isListening();
}

QString LocalGatewayServer::baseUrl() const
{
    if (!isRunning() || m_port == 0)
        return QString{};
    return QStringLiteral("http://127.0.0.1:%1").arg(m_port);
}

quint16 LocalGatewayServer::port() const
{
    return m_port;
}

void LocalGatewayServer::onNewConnection()
{
    while (QTcpSocket *socket = m_server.nextPendingConnection()) {
        m_buffers.insert(socket, QByteArray{});
        connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
            handleSocketReadyRead(socket);
        });
        connect(socket, &QTcpSocket::disconnected, this, [this, socket]() {
            m_buffers.remove(socket);
            socket->deleteLater();
        });
    }
}

void LocalGatewayServer::handleSocketReadyRead(QTcpSocket *socket)
{
    QByteArray &buffer = m_buffers[socket];
    buffer.append(socket->readAll());
    processBuffer(socket, &buffer);
}

void LocalGatewayServer::processBuffer(QTcpSocket *socket, QByteArray *buffer)
{
    if (!socket || !buffer)
        return;

    while (true) {
        const int headerEnd = buffer->indexOf("\r\n\r\n");
        if (headerEnd < 0)
            return;

        const QByteArray headerBytes = buffer->left(headerEnd);
        const QList<QByteArray> headerLines = headerBytes.split('\n');
        if (headerLines.isEmpty()) {
            respondText(socket, 400, QStringLiteral("Bad request"));
            socket->disconnectFromHost();
            buffer->clear();
            return;
        }

        const QString requestLine = QString::fromLatin1(headerLines.first()).trimmed();
        const QStringList requestParts = requestLine.split(' ', Qt::SkipEmptyParts);
        if (requestParts.size() < 2) {
            respondText(socket, 400, QStringLiteral("Bad request"));
            socket->disconnectFromHost();
            buffer->clear();
            return;
        }

        const QString method = requestParts.at(0).trimmed().toUpper();
        const QUrl requestUrl = QUrl::fromEncoded(requestParts.at(1).toLatin1());
        const QString path = requestUrl.path().isEmpty() ? QStringLiteral("/") : requestUrl.path();
        const QHash<QString, QString> headers = parseHeaders(headerLines.mid(1));
        const int contentLength = headers.value(QStringLiteral("content-length")).toInt();
        const int totalNeeded = headerEnd + 4 + contentLength;
        if (buffer->size() < totalNeeded)
            return;

        const QByteArray body = buffer->mid(headerEnd + 4, contentLength);
        buffer->remove(0, totalNeeded);
        handleRequest(socket, method, path, headers, body);

        if (buffer->isEmpty())
            return;
    }
}

void LocalGatewayServer::handleRequest(QTcpSocket *socket, const QString &method, const QString &path,
                                       const QHash<QString, QString> &, const QByteArray &body)
{
    const auto stateProvider = m_stateProvider;
    if (method == QLatin1String("GET") && (path == QLatin1String("/") || path == QLatin1String("/health"))) {
        QJsonObject payload = stateProvider ? stateProvider() : QJsonObject{};
        payload.insert(QStringLiteral("ok"), true);
        respondJson(socket, 200, payload);
        socket->disconnectFromHost();
        return;
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/state")) {
        QJsonObject payload = stateProvider ? stateProvider() : QJsonObject{};
        payload.insert(QStringLiteral("ok"), true);
        respondJson(socket, 200, payload);
        socket->disconnectFromHost();
        return;
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/message")) {
        QJsonParseError error{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &error);
        if (error.error != QJsonParseError::NoError || !doc.isObject()) {
            respondJson(socket, 400, QJsonObject{{"ok", false}, {"error", "Invalid JSON body"}});
            socket->disconnectFromHost();
            return;
        }

        const QJsonObject object = doc.object();
        const QString text = object.value(QStringLiteral("message")).toString().trimmed().isEmpty()
            ? object.value(QStringLiteral("text")).toString().trimmed()
            : object.value(QStringLiteral("message")).toString().trimmed();
        const QString prompt = text.isEmpty()
            ? object.value(QStringLiteral("prompt")).toString().trimmed()
            : text;
        if (prompt.isEmpty()) {
            respondJson(socket, 400, QJsonObject{{"ok", false}, {"error", "Missing message text"}});
            socket->disconnectFromHost();
            return;
        }

        if (m_messageHandler)
            m_messageHandler(prompt);

        respondJson(socket, 200, QJsonObject{{"ok", true}, {"queued", true}, {"message", prompt}});
        socket->disconnectFromHost();
        return;
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/task")) {
        QJsonParseError error{};
        const QJsonDocument doc = QJsonDocument::fromJson(body, &error);
        if (error.error != QJsonParseError::NoError || !doc.isObject()) {
            respondJson(socket, 400, QJsonObject{{"ok", false}, {"error", "Invalid JSON body"}});
            socket->disconnectFromHost();
            return;
        }

        const QJsonObject object = doc.object();
        const QString prompt = formatTaskPrompt(object);
        if (prompt.trimmed().isEmpty()) {
            respondJson(socket, 400, QJsonObject{{"ok", false}, {"error", "Missing task fields"}});
            socket->disconnectFromHost();
            return;
        }

        if (m_messageHandler)
            m_messageHandler(prompt);

        respondJson(socket, 200, QJsonObject{
            {"ok", true},
            {"queued", true},
            {"type", "task"},
            {"message", prompt},
        });
        socket->disconnectFromHost();
        return;
    }

    respondJson(socket, 404, QJsonObject{{"ok", false}, {"error", "Not found"}});
    socket->disconnectFromHost();
}

void LocalGatewayServer::respondJson(QTcpSocket *socket, int statusCode, const QJsonObject &object)
{
    respondText(socket, statusCode, QString::fromUtf8(jsonBytes(object)), "application/json; charset=utf-8");
}

void LocalGatewayServer::respondText(QTcpSocket *socket, int statusCode, const QString &text, const char *contentType)
{
    if (!socket)
        return;

    const QByteArray body = text.toUtf8();
    QByteArray response;
    response += "HTTP/1.1 ";
    response += QByteArray::number(statusCode);
    response += ' ';
    response += statusText(statusCode).toUtf8();
    response += "\r\nContent-Type: ";
    response += contentType;
    response += "\r\nContent-Length: ";
    response += QByteArray::number(body.size());
    response += "\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n";
    response += body;
    socket->write(response);
    socket->flush();
}

QString LocalGatewayServer::statusText(int statusCode)
{
    switch (statusCode) {
    case 200: return QStringLiteral("OK");
    case 400: return QStringLiteral("Bad Request");
    case 404: return QStringLiteral("Not Found");
    default:  return QStringLiteral("OK");
    }
}
