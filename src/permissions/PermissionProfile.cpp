#include "PermissionProfile.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QDateTime>

// OperationApprovalRule 实现

QJsonObject OperationApprovalRule::toJson() const {
    QJsonObject json;
    json["type"] = static_cast<int>(type);
    json["riskLevel"] = static_cast<int>(riskLevel);
    json["requiresApproval"] = requiresApproval;
    json["autoApproveCooldown"] = autoApproveCooldown;

    // 列表转换
    QJsonArray whitelistArray;
    for (const auto &item : whitelist) {
        whitelistArray.append(item);
    }
    json["whitelist"] = whitelistArray;

    QJsonArray blacklistArray;
    for (const auto &item : blacklist) {
        blacklistArray.append(item);
    }
    json["blacklist"] = blacklistArray;

    return json;
}

OperationApprovalRule OperationApprovalRule::fromJson(const QJsonObject &json) {
    OperationApprovalRule rule;
    rule.type = static_cast<OperationType>(json["type"].toInt());
    rule.riskLevel = static_cast<RiskLevel>(json["riskLevel"].toInt());
    rule.requiresApproval = json["requiresApproval"].toBool();
    rule.autoApproveCooldown = json["autoApproveCooldown"].toInt();

    for (const auto &item : json["whitelist"].toArray()) {
        rule.whitelist.append(item.toString());
    }

    for (const auto &item : json["blacklist"].toArray()) {
        rule.blacklist.append(item.toString());
    }

    return rule;
}

// PermissionProfile 实现

PermissionProfile::PermissionProfile(const QString &name)
    : m_name(name) {
}

PermissionProfile PermissionProfile::loadFromFile(const QString &filePath) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to load permission profile:" << filePath;
        return PermissionProfile("default");
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        qWarning() << "Invalid JSON in permission profile:" << filePath;
        return PermissionProfile("default");
    }

    qDebug() << "Permission profile loaded:" << filePath;
    return fromJson(doc.object());
}

bool PermissionProfile::saveToFile(const QString &filePath) const {
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to save permission profile:" << filePath;
        return false;
    }

    QJsonDocument doc(toJson());
    file.write(doc.toJson());
    file.close();

    qDebug() << "Permission profile saved:" << filePath;
    return true;
}

QString PermissionProfile::defaultFilePath()
{
    return QDir::current().filePath(QStringLiteral(".claude-approval.json"));
}

PermissionProfile PermissionProfile::loadDefault()
{
    return loadFromFile(defaultFilePath());
}

bool PermissionProfile::saveDefault() const
{
    return saveToFile(defaultFilePath());
}

void PermissionProfile::setRule(OperationType type, const OperationApprovalRule &rule) {
    m_rules[type] = rule;
}

OperationApprovalRule PermissionProfile::getRule(OperationType type) const {
    if (m_rules.contains(type)) {
        return m_rules[type];
    }

    // 返回默认规则
    OperationApprovalRule defaultRule;
    defaultRule.type = type;
    defaultRule.riskLevel = RiskLevel::Medium;
    defaultRule.requiresApproval = true;
    return defaultRule;
}

bool PermissionProfile::hasRule(OperationType type) const {
    return m_rules.contains(type);
}

bool PermissionProfile::requiresApproval(OperationType type, const QString &target) const {
    auto rule = getRule(type);

    // 检查风险级别
    if (rule.riskLevel == RiskLevel::Low && m_autoApproveThreshold >= RiskLevel::Low) {
        return false;
    }

    // 检查黑名单
    if (isBlacklisted(type, target)) {
        return true;
    }

    // 检查白名单
    if (isWhitelisted(type, target)) {
        return false;
    }

    return rule.requiresApproval;
}

bool PermissionProfile::isAllowed(OperationType type, const QString &target) const {
    // 检查是否在黑名单中
    if (isBlacklisted(type, target)) {
        return false;
    }

    // 检查是否在白名单中
    if (isWhitelisted(type, target)) {
        return true;
    }

    // 检查风险级别
    auto rule = getRule(type);
    return rule.riskLevel <= m_autoApproveThreshold;
}

bool PermissionProfile::isBlacklisted(OperationType type, const QString &target) const {
    auto rule = getRule(type);

    for (const auto &pattern : rule.blacklist) {
        if (target.contains(pattern, Qt::CaseInsensitive)) {
            return true;
        }
    }

    return false;
}

bool PermissionProfile::isWhitelisted(OperationType type, const QString &target) const {
    auto rule = getRule(type);

    if (rule.whitelist.isEmpty()) {
        return false;  // 空白名单表示无默认允许
    }

    for (const auto &pattern : rule.whitelist) {
        if (target.contains(pattern, Qt::CaseInsensitive)) {
            return true;
        }
    }

    return false;
}

void PermissionProfile::trustOperation(const QString &operationKey, int durationSeconds) {
    qint64 expiryTime = QDateTime::currentMSecsSinceEpoch() + (durationSeconds * 1000);
    m_trustedOperations[operationKey] = expiryTime;
    qDebug() << "Operation trusted:" << operationKey << "for" << durationSeconds << "seconds";
}

bool PermissionProfile::isTrusted(const QString &operationKey) const {
    if (!m_trustedOperations.contains(operationKey)) {
        return false;
    }

    qint64 expiryTime = m_trustedOperations[operationKey];
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    if (currentTime > expiryTime) {
        return false;
    }

    return true;
}

void PermissionProfile::clearTrusted(const QString &operationKey) {
    m_trustedOperations.remove(operationKey);
}

void PermissionProfile::setAutoApproveThreshold(RiskLevel threshold) {
    m_autoApproveThreshold = threshold;
}

RiskLevel PermissionProfile::getAutoApproveThreshold() const {
    return m_autoApproveThreshold;
}

QMap<OperationType, OperationApprovalRule> PermissionProfile::getAllRules() const {
    return m_rules;
}

QJsonObject PermissionProfile::toJson() const {
    QJsonObject json;
    json["name"] = m_name;
    json["autoApproveThreshold"] = static_cast<int>(m_autoApproveThreshold);

    // 规则转换
    QJsonObject rulesJson;
    for (auto it = m_rules.begin(); it != m_rules.end(); ++it) {
        QString typeKey = QString::number(static_cast<int>(it.key()));
        rulesJson[typeKey] = it.value().toJson();
    }
    json["rules"] = rulesJson;

    return json;
}

PermissionProfile PermissionProfile::fromJson(const QJsonObject &json) {
    PermissionProfile profile(json["name"].toString("default"));
    profile.m_autoApproveThreshold = static_cast<RiskLevel>(json["autoApproveThreshold"].toInt());

    // 规则恢复
    QJsonObject rulesJson = json["rules"].toObject();
    for (const auto &typeKey : rulesJson.keys()) {
        int typeInt = typeKey.toInt();
        auto rule = OperationApprovalRule::fromJson(rulesJson[typeKey].toObject());
        profile.m_rules[static_cast<OperationType>(typeInt)] = rule;
    }

    return profile;
}

OperationType PermissionProfile::parseOperationType(const QString &typeStr) const {
    if (typeStr == "FileWrite") return OperationType::FileWrite;
    if (typeStr == "FileDelete") return OperationType::FileDelete;
    if (typeStr == "CommandExecution") return OperationType::CommandExecution;
    if (typeStr == "NetworkAccess") return OperationType::NetworkAccess;
    return OperationType::Unknown;
}

QString PermissionProfile::operationTypeToString(OperationType type) const {
    switch (type) {
    case OperationType::FileWrite: return "FileWrite";
    case OperationType::FileDelete: return "FileDelete";
    case OperationType::FileModify: return "FileModify";
    case OperationType::CommandExecution: return "CommandExecution";
    case OperationType::ShellCommand: return "ShellCommand";
    case OperationType::NetworkAccess: return "NetworkAccess";
    case OperationType::EnvironmentModification: return "EnvironmentModification";
    case OperationType::PluginLoad: return "PluginLoad";
    case OperationType::Unknown:
    default: return "Unknown";
    }
}
