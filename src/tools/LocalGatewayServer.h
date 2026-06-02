#pragma once

#include <QObject>
#include <QJsonObject>
#include <QHash>
#include <QTcpServer>
#include <QTcpSocket>

#include <functional>

class LocalGatewayServer : public QObject {
    Q_OBJECT
public:
    using MessageHandler = std::function<void(const QString &)>;
    using StateProvider = std::function<QJsonObject()>;

    explicit LocalGatewayServer(QObject *parent = nullptr);

    bool start(quint16 preferredPort, MessageHandler messageHandler, StateProvider stateProvider);
    void stop();

    bool isRunning() const;
    QString baseUrl() const;
    quint16 port() const;

private slots:
    void onNewConnection();

private:
    void handleSocketReadyRead(QTcpSocket *socket);
    void processBuffer(QTcpSocket *socket, QByteArray *buffer);
    void handleRequest(QTcpSocket *socket, const QString &method, const QString &path,
                       const QHash<QString, QString> &headers, const QByteArray &body);
    void respondJson(QTcpSocket *socket, int statusCode, const QJsonObject &object);
    void respondText(QTcpSocket *socket, int statusCode, const QString &text, const char *contentType = "text/plain; charset=utf-8");
    static QString statusText(int statusCode);

    QTcpServer m_server;
    quint16 m_port{0};
    MessageHandler m_messageHandler;
    StateProvider m_stateProvider;
    QHash<QTcpSocket *, QByteArray> m_buffers;
};
