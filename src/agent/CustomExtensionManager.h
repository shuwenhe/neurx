#pragma once

#include <QString>
#include <QObject>
#include <QPluginLoader>
#include <memory>
#include <map>

/**
 * @class CustomExtensionManager
 * @brief User-defined extensions and custom tools
 */

class CustomExtensionManager : public QObject {
    Q_OBJECT

public:
    struct ExtensionMetadata {
        QString id;
        QString name;
        QString version;
        QString author;
        QString description;
        QStringList capabilities;
        QString entryPoint;
        bool enabled;
    };

    struct ExtensionContext {
        QString extensionId;
        QJsonObject config;
        QJsonObject state;
        QMap<QString, QString> environment;
    };

    explicit CustomExtensionManager(QObject* parent = nullptr);
    ~CustomExtensionManager();

    void loadExtension(const QString& extensionPath);
    void unloadExtension(const QString& extensionId);
    void enableExtension(const QString& extensionId);
    void disableExtension(const QString& extensionId);

    ExtensionMetadata getExtensionMetadata(const QString& extensionId);
    QVector<ExtensionMetadata> getAllExtensions();
    QVector<ExtensionMetadata> getEnabledExtensions();

    void configureExtension(const QString& extensionId, const QJsonObject& config);
    QJsonObject getExtensionConfig(const QString& extensionId);

    void invokeExtension(const QString& extensionId, const QString& method, const QJsonObject& params);
    QJsonObject executeExtensionMethod(const QString& extensionId, const QString& method, const QJsonObject& inputs);

signals:
    void extensionLoaded(const QString& extensionId);
    void extensionUnloaded(const QString& extensionId);
    void extensionError(const QString& extensionId, const QString& error);

private:
    QMap<QString, ExtensionMetadata> m_extensions;
    QMap<QString, std::unique_ptr<QPluginLoader>> m_loaders;
};
