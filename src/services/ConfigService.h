#pragma once

#include <QObject>
#include <QVariantMap>
#include <QString>
#include <QJsonObject>

/**
 * @class ConfigService
 * @brief Manages editor configuration
 * 
 * Features:
 * - Load/save settings
 * - Default configuration
 * - Per-workspace overrides
 * - Configuration validation
 */

class ConfigService : public QObject {
    Q_OBJECT

public:
    static ConfigService* instance();
    
    // Configuration access
    QVariant get(const QString& key, const QVariant& defaultValue = QVariant());
    void set(const QString& key, const QVariant& value);
    
    // Batch operations
    void loadConfig(const QString& filePath);
    void saveConfig(const QString& filePath);
    void resetToDefaults();
    
    // Querying
    bool has(const QString& key) const;
    QStringList keys() const;
    QVariantMap all() const;
    
    // Validation
    bool isValid(const QString& key, const QVariant& value);
    void registerValidator(const QString& key, std::function<bool(const QVariant&)> validator);

signals:
    void configChanged(const QString& key, const QVariant& value);
    void configLoaded();
    void configSaved();

private:
    ConfigService();
    ~ConfigService() override = default;
    
    Q_DISABLE_COPY_MOVE(ConfigService)
    
    QVariantMap m_config;
    QVariantMap m_defaults;
    QMap<QString, std::function<bool(const QVariant&)>> m_validators;
    
    void initializeDefaults();
};
