#include "SkillEnvironmentManager.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QDebug>
#include <QProcessEnvironment>

SkillEnvironmentManager::SkillEnvironmentManager() = default;

DefaultSkillEnvironmentManager::DefaultSkillEnvironmentManager()
{
    // Load from system environment
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    for (const auto &key : env.keys()) {
        m_variables[key] = env.value(key);
    }
}

void DefaultSkillEnvironmentManager::collectEnvironmentVariables(
    const ClaudeSkill &skill,
    EnvPromptCallback promptCallback,
    EnvSecretCallback secretCallback,
    EnvCollectedCallback resultCallback)
{
    QStringList missingVariables;
    
    for (const auto &envVar : skill.requiredEnvironmentVariables) {
        const bool alreadySet = m_variables.contains(envVar.name) || m_secrets.contains(envVar.name);
        if (alreadySet)
            continue;

        if (!envVar.defaultValue.isEmpty()) {
            if (envVar.secret) {
                m_secrets[envVar.name] = envVar.defaultValue;
            } else {
                m_variables[envVar.name] = envVar.defaultValue;
            }
            continue;
        }

        if (!envVar.required)
            continue;

        QString value;

        if (envVar.secret) {
            value = secretCallback(envVar.prompt);
            if (!value.isEmpty()) {
                m_secrets[envVar.name] = value;
            }
        } else {
            value = promptCallback(envVar.prompt, envVar.help);
            if (!value.isEmpty()) {
                m_variables[envVar.name] = value;
            }
        }

        if (value.isEmpty()) {
            missingVariables << envVar.name;
        } else if (!validateVariable(envVar, value)) {
            missingVariables << envVar.name;
        }
    }
    
    QString error;
    if (!missingVariables.isEmpty()) {
        error = QString("Missing required environment variables: %1").arg(missingVariables.join(", "));
        resultCallback(false, error);
    } else {
        resultCallback(true, "");
    }
}

void DefaultSkillEnvironmentManager::setEnvironmentVariable(const QString &name, const QString &value)
{
    m_variables[name] = value;
}

QString DefaultSkillEnvironmentManager::getEnvironmentVariable(const QString &name)
{
    if (m_variables.contains(name)) {
        return m_variables[name];
    }
    if (m_secrets.contains(name)) {
        return m_secrets[name];
    }
    
    // Fall back to system environment
    return qgetenv(name.toUtf8()).constData();
}

bool DefaultSkillEnvironmentManager::validateEnvironmentVariables(
    const ClaudeSkill &skill,
    QStringList &missingVariables,
    QString &error)
{
    missingVariables.clear();
    
    for (const auto &envVar : skill.requiredEnvironmentVariables) {
        if (!envVar.required) {
            continue;
        }
        
        QString value = getEnvironmentVariable(envVar.name);
        
        if (value.isEmpty()) {
            missingVariables << envVar.name;
        } else if (!validateVariable(envVar, value)) {
            error = QString("Environment variable %1 failed validation").arg(envVar.name);
            return false;
        }
    }
    
    if (!missingVariables.isEmpty()) {
        error = QString("Missing required environment variables: %1").arg(missingVariables.join(", "));
        return false;
    }
    
    return true;
}

bool DefaultSkillEnvironmentManager::validateVariable(
    const EnvironmentVariableDef &def,
    const QString &value)
{
    if (value.isEmpty() && def.required) {
        return false;
    }
    
    if (!def.pattern.isEmpty()) {
        return matchesPattern(value, def.pattern);
    }
    
    return true;
}

void DefaultSkillEnvironmentManager::loadFromStorage(const QString &storageFile)
{
    QFile file(storageFile);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Cannot open environment storage file:" << storageFile;
        return;
    }
    
    QString content = QString::fromUtf8(file.readAll());
    file.close();
    
    QMap<QString, QString> loaded = parseDotenv(content);
    for (auto it = loaded.begin(); it != loaded.end(); ++it) {
        m_variables[it.key()] = it.value();
    }
}

void DefaultSkillEnvironmentManager::saveToStorage(const QString &storageFile)
{
    QString dir = QFileInfo(storageFile).dir().absolutePath();
    QDir().mkpath(dir);
    
    QFile file(storageFile);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Cannot write to environment storage file:" << storageFile;
        return;
    }
    
    file.write(serializeToDotenv().toUtf8());
    file.close();
    
    // Set restrictive permissions (600)
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

void DefaultSkillEnvironmentManager::clearStorage()
{
    m_variables.clear();
    m_secrets.clear();
}

QMap<QString, QString> DefaultSkillEnvironmentManager::getAllVariables() const
{
    return m_variables;
}

QStringList DefaultSkillEnvironmentManager::getRequiredVariablesForSkill(const ClaudeSkill &skill) const
{
    QStringList required;
    
    for (const auto &envVar : skill.requiredEnvironmentVariables) {
        if (envVar.required) {
            required << envVar.name;
        }
    }
    
    return required;
}

bool DefaultSkillEnvironmentManager::areAllRequiredVariablesSet(const ClaudeSkill &skill) const
{
    for (const auto &envVar : skill.requiredEnvironmentVariables) {
        if (envVar.required) {
            if (!m_variables.contains(envVar.name) && !m_secrets.contains(envVar.name)) {
                return false;
            }
        }
    }
    return true;
}

bool DefaultSkillEnvironmentManager::matchesPattern(const QString &value, const QString &pattern) const
{
    QRegularExpression regex(pattern);
    return regex.match(value).hasMatch();
}

QString DefaultSkillEnvironmentManager::maskSecret(const QString &value) const
{
    if (value.length() <= 4) {
        return "****";
    }
    return value.left(2) + "****" + value.right(2);
}

QMap<QString, QString> DefaultSkillEnvironmentManager::parseDotenv(const QString &content) const
{
    QMap<QString, QString> result;
    
    QStringList lines = content.split("\n");
    for (const QString &line : lines) {
        QString trimmed = line.trimmed();
        
        // Skip empty lines and comments
        if (trimmed.isEmpty() || trimmed.startsWith("#")) {
            continue;
        }
        
        int eqPos = trimmed.indexOf("=");
        if (eqPos > 0) {
            QString key = trimmed.left(eqPos).trimmed();
            QString value = trimmed.mid(eqPos + 1).trimmed();
            
            // Remove quotes if present
            if ((value.startsWith("\"") && value.endsWith("\"")) ||
                (value.startsWith("'") && value.endsWith("'"))) {
                value = value.mid(1, value.length() - 2);
            }
            
            result[key] = value;
        }
    }
    
    return result;
}

QString DefaultSkillEnvironmentManager::serializeToDotenv() const
{
    QString result;
    
    for (auto it = m_variables.begin(); it != m_variables.end(); ++it) {
        result += QString("%1=\"%2\"\n").arg(it.key(), it.value());
    }
    
    // Secrets are not persisted (they stay in memory only)
    
    return result;
}

// ── EnvironmentVariableValidator Implementation ─────────────

bool EnvironmentVariableValidator::validatePattern(const QString &value, const QString &pattern)
{
    QRegularExpression regex(pattern);
    return regex.match(value).hasMatch();
}

bool EnvironmentVariableValidator::validateUrl(const QString &value)
{
    QRegularExpression urlRegex(
        "^(https?|ftp)://[^\\s/$.?#].[^\\s]*$",
        QRegularExpression::CaseInsensitiveOption
    );
    return urlRegex.match(value).hasMatch();
}

bool EnvironmentVariableValidator::validateEmail(const QString &value)
{
    QRegularExpression emailRegex(
        "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    );
    return emailRegex.match(value).hasMatch();
}

bool EnvironmentVariableValidator::validateIpAddress(const QString &value)
{
    QRegularExpression ipRegex(
        "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}"
        "(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    );
    return ipRegex.match(value).hasMatch();
}

bool EnvironmentVariableValidator::validateApiKey(const QString &value)
{
    // Basic API key validation: non-empty, reasonable length
    return !value.isEmpty() && value.length() >= 8 && value.length() <= 512;
}
