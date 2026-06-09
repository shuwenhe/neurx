#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class CustomWebhookManager
 * @brief Webhook management and routing
 */

class CustomWebhookManager : public QObject {
    Q_OBJECT

public:
    struct WebhookConfig {
        QString id;
        QString url;
        QString event;
        bool active;
        QJsonObject headers;
        int retryCount;
        int timeoutSeconds;
    };

    struct WebhookDelivery {
        QString webhookId;
        QString deliveryId;
        int statusCode;
        QString responseBody;
        qint64 timestamp;
        int attemptCount;
    };

    explicit CustomWebhookManager(QObject* parent = nullptr);
    ~CustomWebhookManager();

    void registerWebhook(const WebhookConfig& config);
    void unregisterWebhook(const QString& webhookId);
    WebhookConfig getWebhook(const QString& webhookId);
    QVector<WebhookConfig> getWebhooksByEvent(const QString& event);

    QString deliverWebhook(const QString& webhookId, const QJsonObject& payload);
    void retryDelivery(const QString& deliveryId);
    WebhookDelivery getDeliveryStatus(const QString& deliveryId);

    void setEventFilter(const QString& event, const QString& filter);
    void transformPayload(const QString& event, const QString& transformation);

signals:
    void webhookDelivered(const QString& deliveryId, int statusCode);
    void deliveryFailed(const QString& deliveryId, const QString& error);

private:
    QMap<QString, WebhookConfig> m_webhooks;
    QMap<QString, WebhookDelivery> m_deliveries;
};
