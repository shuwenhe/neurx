#include "services/ConfigService.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QSettings>

ConfigService* g_configService = nullptr;

ConfigService* ConfigService::instance()
{
    if (!g_configService) {
        g_configService = new ConfigService();
    }
    return g_configService;
}

ConfigService::ConfigService()
{
    initializeDefaults();
    m_config = m_defaults;
}

void ConfigService::initializeDefaults()
{
    // Editor defaults
    m_defaults["editor.fontSize"] = 14;
    m_defaults["editor.fontFamily"] = "Menlo";
    m_defaults["editor.tabSize"] = 4;
    m_defaults["editor.insertSpaces"] = true;
    m_defaults["editor.lineNumbers"] = true;
    m_defaults["editor.minimap.enabled"] = true;
    m_defaults["editor.wordWrap"] = "off";
    m_defaults["editor.autoSave"] = "afterDelay";
    m_defaults["editor.autoSaveDelay"] = 1000;
    m_defaults["editor.formatOnSave"] = false;
    m_defaults["editor.trimTrailingWhitespace"] = false;
    m_defaults["editor.trimAutoWhitespace"] = true;
    m_defaults["editor.largeFileOptimizations"] = true;
    
    // Theme defaults
    m_defaults["workbench.colorTheme"] = "Dark";
    m_defaults["workbench.iconTheme"] = "vs-seti";
    m_defaults["workbench.startupEditor"] = "welcomePage";
    
    // File defaults
    m_defaults["files.encoding"] = "utf8";
    m_defaults["files.eol"] = "\n";
    m_defaults["files.trimFinalNewlines"] = false;
    m_defaults["files.insertFinalNewline"] = false;
    m_defaults["files.autoGuessEncoding"] = false;
    m_defaults["files.exclude"] = ".git,.DS_Store";
    
    // Terminal defaults
    m_defaults["terminal.integrated.fontSize"] = 12;
    m_defaults["terminal.integrated.fontFamily"] = "Menlo";
    
    // Search defaults
    m_defaults["search.smartCase"] = true;
    m_defaults["search.followSymlinks"] = true;
    m_defaults["search.exclude"] = "node_modules,.git";
}

QVariant ConfigService::get(const QString& key, const QVariant& defaultValue)
{
    if (m_config.contains(key)) {
        return m_config[key];
    }
    return defaultValue.isValid() ? defaultValue : m_defaults.value(key);
}

void ConfigService::set(const QString& key, const QVariant& value)
{
    if (!isValid(key, value)) {
        qWarning() << "Invalid value for config key:" << key;
        return;
    }
    
    m_config[key] = value;
    emit configChanged(key, value);
}

void ConfigService::loadConfig(const QString& filePath)
{
    QFile file(filePath);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        file.close();
        
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            for (auto it = obj.begin(); it != obj.end(); ++it) {
                m_config[it.key()] = it.value().toVariant();
            }
            emit configLoaded();
            qDebug() << "Config loaded from:" << filePath;
        }
    } else {
        qWarning() << "Failed to open config file:" << filePath;
    }
}

void ConfigService::saveConfig(const QString& filePath)
{
    QJsonObject obj;
    for (auto it = m_config.begin(); it != m_config.end(); ++it) {
        obj[it.key()] = QJsonValue::fromVariant(it.value());
    }
    
    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(obj).toJson());
        file.close();
        emit configSaved();
        qDebug() << "Config saved to:" << filePath;
    } else {
        qWarning() << "Failed to save config file:" << filePath;
    }
}

void ConfigService::resetToDefaults()
{
    m_config = m_defaults;
    qDebug() << "Config reset to defaults";
}

bool ConfigService::has(const QString& key) const
{
    return m_config.contains(key) || m_defaults.contains(key);
}

QStringList ConfigService::keys() const
{
    QStringList result;
    for (const auto& key : m_config.keys()) {
        result.append(key);
    }
    return result;
}

QVariantMap ConfigService::all() const
{
    return m_config;
}

bool ConfigService::isValid(const QString& key, const QVariant& value)
{
    if (m_validators.contains(key)) {
        return m_validators[key](value);
    }
    return true;
}

void ConfigService::registerValidator(const QString& key, std::function<bool(const QVariant&)> validator)
{
    m_validators[key] = validator;
}
