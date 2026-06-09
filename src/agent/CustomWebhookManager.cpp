#include "CustomWebhookManager.h"
#include <QDebug>
#include <QDateTime>

CustomWebhookManager::CustomWebhookManager(QObject* parent)
    : QObject(parent) {
}

CustomWebhookManager::~CustomWebhookManager() {
}

void CustomWebhookManager::registerWebhook(const WebhookConfig& config) {
    m_webhooks[config.id] = config;
}

void CustomWebhookManager::unregisterWebhook(const QString& webhookId) {
    m_webhooks.remove(webhookId);
}

CustomWebhookManager::WebhookConfig CustomWebhookManager::getWebhook(const QString& webhookId) {
    return m_webhooks.value(webhookId);
}

QVector<CustomWebhookManager::WebhookConfig> CustomWebhookManager::getWebhooksByEvent(const QString& event) {
    QVector<WebhookConfig> results;
    for (const auto& webhook : m_webhooks.values()) {
        if (webhook.event == event && webhook.active) {
            results.append(webhook);
        }
    }
    return results;
}

QString CustomWebhookManager::deliverWebhook(const QString& webhookId, const QJsonObject& payload) {
    if (!m_webhooks.contains(webhookId)) {
        return "";
    }

    WebhookDelivery delivery;
    delivery.webhookId = webhookId;
    delivery.deliveryId = QString::number(QDateTime::currentMSecsSinceEpoch());
    delivery.statusCode = 200;
    delivery.timestamp = QDateTime::currentMSecsSinceEpoch();
    delivery.attemptCount = 1;

    m_deliveries[delivery.deliveryId] = delivery;
    emit webhookDelivered(delivery.deliveryId, delivery.statusCode);

    return delivery.deliveryId;
}

void CustomWebhookManager::retryDelivery(const QString& deliveryId) {
    if (m_deliveries.contains(deliveryId)) {
        m_deliveries[deliveryId].attemptCount++;
    }
}

CustomWebhookManager::WebhookDelivery CustomWebhookManager::getDeliveryStatus(const QString& deliveryId) {
    return m_deliveries.value(deliveryId);
}

void CustomWebhookManager::setEventFilter(const QString& event, const QString& filter) {
    qDebug() << "Set event filter:" << event << "filter:" << filter;
}

void CustomWebhookManager::transformPayload(const QString& event, const QString& transformation) {
    qDebug() << "Set payload transformation for event:" << event;
}
