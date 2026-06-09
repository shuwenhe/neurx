#include "CustomExtensionManager.h"
#include <QDebug>

CustomExtensionManager::CustomExtensionManager(QObject* parent)
    : QObject(parent) {
}

CustomExtensionManager::~CustomExtensionManager() {
}

void CustomExtensionManager::loadExtension(const QString& extensionPath) {
    qDebug() << "Loading extension from:" << extensionPath;
    ExtensionMetadata metadata;
    metadata.id = extensionPath;
    metadata.enabled = true;
    emit extensionLoaded(metadata.id);
}

void CustomExtensionManager::unloadExtension(const QString& extensionId) {
    if (m_extensions.contains(extensionId)) {
        m_extensions.remove(extensionId);
        emit extensionUnloaded(extensionId);
    }
}

void CustomExtensionManager::enableExtension(const QString& extensionId) {
    if (m_extensions.contains(extensionId)) {
        m_extensions[extensionId].enabled = true;
    }
}

void CustomExtensionManager::disableExtension(const QString& extensionId) {
    if (m_extensions.contains(extensionId)) {
        m_extensions[extensionId].enabled = false;
    }
}

CustomExtensionManager::ExtensionMetadata CustomExtensionManager::getExtensionMetadata(const QString& extensionId) {
    return m_extensions.value(extensionId);
}

QVector<CustomExtensionManager::ExtensionMetadata> CustomExtensionManager::getAllExtensions() {
    return QVector<ExtensionMetadata>(m_extensions.values().begin(), m_extensions.values().end());
}

QVector<CustomExtensionManager::ExtensionMetadata> CustomExtensionManager::getEnabledExtensions() {
    QVector<ExtensionMetadata> enabled;
    for (const auto& ext : m_extensions.values()) {
        if (ext.enabled) {
            enabled.append(ext);
        }
    }
    return enabled;
}

void CustomExtensionManager::configureExtension(const QString& extensionId, const QJsonObject& config) {
    qDebug() << "Configured extension:" << extensionId;
}

QJsonObject CustomExtensionManager::getExtensionConfig(const QString& extensionId) {
    return QJsonObject();
}

void CustomExtensionManager::invokeExtension(const QString& extensionId, const QString& method, const QJsonObject& params) {
    qDebug() << "Invoking method" << method << "on extension" << extensionId;
}

QJsonObject CustomExtensionManager::executeExtensionMethod(const QString& extensionId, const QString& method, const QJsonObject& inputs) {
    return QJsonObject();
}
