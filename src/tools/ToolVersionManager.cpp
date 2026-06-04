#include "ToolVersionManager.h"
#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QCryptographicHash>
#include <algorithm>
#include <QRegularExpression>

ToolVersionManager::ToolVersionManager(QObject *parent)
    : QObject(parent) {
    qDebug() << "[ToolVersionManager] Initialized";
}

// ── 版本注册 ────────────────────────────────────────

void ToolVersionManager::registerToolVersion(
    const ToolVersionInfo &versionInfo,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    // 验证版本号格式
    if (!isValidVersion(versionInfo.version)) {
        if (callback) callback(false, "Invalid version format");
        return;
    }
    
    // 创建版本记录
    VersionRecord record;
    record.info = versionInfo;
    record.registeredAt = QDateTime::currentDateTime();
    record.isActive = true;
    
    if (!m_versions.contains(versionInfo.toolId)) {
        m_versions[versionInfo.toolId] = QVector<VersionRecord>();
    }
    
    m_versions[versionInfo.toolId].append(record);
    
    // 按版本号排序
    std::sort(m_versions[versionInfo.toolId].begin(),
              m_versions[versionInfo.toolId].end(),
              [this](const auto &a, const auto &b) {
                  return compareVersions(a.info.version, b.info.version) < 0;
              });
    
    emit versionRegistered(versionInfo.toolId, versionInfo.version);
    
    if (callback) callback(true, "");
    
    qDebug() << "[ToolVersionManager] Version registered:" << versionInfo.toolId << versionInfo.version;
}

ToolVersionInfo ToolVersionManager::getVersionInfo(
    const QString &toolId,
    const QString &version) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        for (const auto &record : m_versions[toolId]) {
            if (record.info.version == version) {
                return record.info;
            }
        }
    }
    
    return ToolVersionInfo();
}

QVector<ToolVersionInfo> ToolVersionManager::getAllVersions(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolVersionInfo> versions;
    
    if (m_versions.contains(toolId)) {
        for (const auto &record : m_versions[toolId]) {
            versions.append(record.info);
        }
    }
    
    return versions;
}

ToolVersionInfo ToolVersionManager::getLatestVersion(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        const auto &records = m_versions[toolId];
        if (!records.isEmpty()) {
            return records.last().info;
        }
    }
    
    return ToolVersionInfo();
}

ToolVersionInfo ToolVersionManager::getVersionByTag(
    const QString &toolId,
    const QString &tag) const {
    
    // 简化实现 - 可以根据tag查找版本
    return ToolVersionInfo();
}

QVector<ToolVersionInfo> ToolVersionManager::getActiveVersions(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolVersionInfo> versions;
    
    if (m_versions.contains(toolId)) {
        for (const auto &record : m_versions[toolId]) {
            if (!record.info.isDeprecated && record.isActive) {
                versions.append(record.info);
            }
        }
    }
    
    return versions;
}

QVector<ToolVersionInfo> ToolVersionManager::getSupportedVersions(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolVersionInfo> versions;
    QDateTime now = QDateTime::currentDateTime();
    
    if (m_versions.contains(toolId)) {
        for (const auto &record : m_versions[toolId]) {
            // 支持窗口内的版本
            if (record.registeredAt < now) {
                versions.append(record.info);
            }
        }
    }
    
    return versions;
}

// ── 版本兼容性 ────────────────────────────────────

bool ToolVersionManager::isCompatible(
    const QString &toolId,
    const QString &sourceVersion,
    const QString &targetVersion,
    QString &incompatibilities) const {
    
    QMutexLocker locker(&m_mutex);
    
    auto sourceInfo = getVersionInfo(toolId, sourceVersion);
    auto targetInfo = getVersionInfo(toolId, targetVersion);
    
    if (sourceInfo.toolId.isEmpty() || targetInfo.toolId.isEmpty()) {
        incompatibilities = "Version not found";
        return false;
    }
    
    // 检查breaking changes
    for (const auto &breaking : targetInfo.breakingChanges) {
        incompatibilities += "Breaking change: " + breaking + "\n";
    }
    
    return incompatibilities.isEmpty();
}

bool ToolVersionManager::checkDependencyVersions(
    const QString &toolId,
    const QString &version,
    const QMap<QString, QString> &dependencies,
    QString &errorMessage) const {
    
    QMutexLocker locker(&m_mutex);
    
    auto versionInfo = getVersionInfo(toolId, version);
    
    if (versionInfo.toolId.isEmpty()) {
        errorMessage = "Version not found";
        return false;
    }
    
    // 检查依赖版本
    for (auto it = dependencies.begin(); it != dependencies.end(); ++it) {
        const auto &depToolId = it.key();
        const auto &depVersion = it.value();
        
        // 这里应该递归检查依赖
        if (!m_versions.contains(depToolId)) {
            errorMessage = QString("Dependency tool %1 not found").arg(depToolId);
            return false;
        }
    }
    
    return true;
}

QVector<QString> ToolVersionManager::getCompatibleVersions(
    const QString &toolId,
    const QString &version) const {
    
    QMutexLocker locker(&m_mutex);
    
    auto versionInfo = getVersionInfo(toolId, version);
    
    return versionInfo.compatibleVersions;
}

QString ToolVersionManager::getMinimumSupportedVersion(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId) && !m_versions[toolId].isEmpty()) {
        return m_versions[toolId].first().info.version;
    }
    
    return "";
}

QString ToolVersionManager::getMaximumSupportedVersion(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId) && !m_versions[toolId].isEmpty()) {
        return m_versions[toolId].last().info.version;
    }
    
    return "";
}

bool ToolVersionManager::isPrerelease(
    const QString &toolId,
    const QString &version) const {
    
    auto versionInfo = getVersionInfo(toolId, version);
    return versionInfo.isPrerelease;
}

bool ToolVersionManager::isDeprecated(
    const QString &toolId,
    const QString &version) const {
    
    auto versionInfo = getVersionInfo(toolId, version);
    return versionInfo.isDeprecated;
}

// ── 版本升级/降级 ──────────────────────────────────

bool ToolVersionManager::canUpgrade(
    const QString &toolId,
    const QString &currentVersion,
    QString &targetVersion,
    QString &reason) const {
    
    QMutexLocker locker(&m_mutex);
    
    auto latestVersion = getLatestVersion(toolId);
    
    if (latestVersion.toolId.isEmpty()) {
        reason = "No newer version available";
        return false;
    }
    
    if (compareVersions(currentVersion, latestVersion.version) < 0) {
        targetVersion = latestVersion.version;
        return true;
    }
    
    reason = "Already at latest version";
    return false;
}

bool ToolVersionManager::canDowngrade(
    const QString &toolId,
    const QString &currentVersion,
    QString &targetVersion,
    QString &reason) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        const auto &records = m_versions[toolId];
        
        for (int i = records.size() - 1; i >= 0; --i) {
            if (compareVersions(records[i].info.version, currentVersion) < 0) {
                targetVersion = records[i].info.version;
                return true;
            }
        }
    }
    
    reason = "No previous version available";
    return false;
}

QVector<QString> ToolVersionManager::getUpgradePath(
    const QString &toolId,
    const QString &fromVersion,
    const QString &toVersion) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> path;
    
    if (m_versions.contains(toolId)) {
        bool collecting = false;
        
        for (const auto &record : m_versions[toolId]) {
            if (record.info.version == fromVersion) {
                collecting = true;
                path.append(fromVersion);
            } else if (collecting) {
                path.append(record.info.version);
                
                if (record.info.version == toVersion) {
                    break;
                }
            }
        }
    }
    
    return path;
}

QString ToolVersionManager::getRecommendedUpgradeVersion(
    const QString &toolId,
    const QString &currentVersion) const {
    
    QMutexLocker locker(&m_mutex);
    
    // 根据升级策略推荐版本
    QString policy = getAutoUpgradePolicy(toolId);
    
    if (policy == "major" || policy == "minor" || policy == "patch") {
        auto latest = getLatestVersion(toolId);
        return latest.version;
    }
    
    return currentVersion;
}

void ToolVersionManager::setAutoUpgradePolicy(
    const QString &toolId,
    const QString &policy) {
    
    QMutexLocker locker(&m_mutex);
    
    UpgradePolicy upgradePolicy;
    upgradePolicy.toolId = toolId;
    upgradePolicy.policy = policy;
    upgradePolicy.lastUpdated = QDateTime::currentDateTime();
    
    m_upgradePolicies[toolId] = upgradePolicy;
}

QString ToolVersionManager::getAutoUpgradePolicy(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_upgradePolicies.contains(toolId)) {
        return m_upgradePolicies[toolId].policy;
    }
    
    return "none";  // 默认不自动升级
}

// ── 版本依赖 ────────────────────────────────────────

QString ToolVersionManager::resolveVersionConstraint(
    const QString &toolId,
    const ToolVersionConstraint &constraint,
    QString &errorMessage) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        // 遍历版本并查找满足约束的最新版本
        for (int i = m_versions[toolId].size() - 1; i >= 0; --i) {
            const auto &version = m_versions[toolId][i].info.version;
            
            if (satisfiesConstraint(toolId, version, constraint)) {
                return version;
            }
        }
    }
    
    errorMessage = "No version satisfies the constraint";
    return "";
}

bool ToolVersionManager::satisfiesConstraint(
    const QString &toolId,
    const QString &version,
    const ToolVersionConstraint &constraint) const {
    
    if (!constraint.minVersion.isEmpty()) {
        if (compareVersions(version, constraint.minVersion) < 0) {
            return false;
        }
    }
    
    if (!constraint.maxVersion.isEmpty()) {
        if (compareVersions(version, constraint.maxVersion) > 0) {
            return false;
        }
    }
    
    for (const auto &excluded : constraint.excludedVersions) {
        if (version == excluded) {
            return false;
        }
    }
    
    return true;
}

QVariantMap ToolVersionManager::computeVersionDependencyGraph(
    const QString &toolId,
    const QString &version) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap graph;
    auto versionInfo = getVersionInfo(toolId, version);
    
    // 构建依赖图
    QVariantList dependencies;
    for (const auto &dep : versionInfo.dependencies) {
        dependencies.append(dep);
    }
    
    graph["toolId"] = toolId;
    graph["version"] = version;
    graph["dependencies"] = dependencies;
    
    return graph;
}

bool ToolVersionManager::detectVersionConflicts(
    const QMap<QString, QString> &toolVersions,
    QStringList &conflictDescriptions) const {
    
    QMutexLocker locker(&m_mutex);
    
    bool hasConflicts = false;
    
    // 检查每个工具的版本依赖
    for (auto it = toolVersions.begin(); it != toolVersions.end(); ++it) {
        auto versionInfo = getVersionInfo(it.key(), it.value());
        
        for (const auto &dep : versionInfo.dependencies) {
            // 简化实现 - 更复杂的冲突检测
        }
    }
    
    return hasConflicts;
}

bool ToolVersionManager::resolveVersionConflicts(
    QMap<QString, QString> &toolVersions,
    QString &errorMessage) const {
    
    // 试图自动解决版本冲突
    QStringList conflicts;
    
    if (detectVersionConflicts(toolVersions, conflicts)) {
        // 尝试升级受影响的工具
        for (const auto &toolId : toolVersions.keys()) {
            QString unused;
            if (canUpgrade(toolId, toolVersions[toolId], toolVersions[toolId], unused)) {
                // 尝试升级
            }
        }
    }
    
    return true;
}

QMap<QString, QString> ToolVersionManager::getRecommendedVersionSet(
    int scenarioId) const {
    
    QMap<QString, QString> versions;
    
    // 根据场景返回推荐的版本组合
    for (const auto &toolId : m_versions.keys()) {
        auto latest = getLatestVersion(toolId);
        if (!latest.toolId.isEmpty()) {
            versions[toolId] = latest.version;
        }
    }
    
    return versions;
}

// ── 变更管理 ────────────────────────────────────────

QVariantMap ToolVersionManager::getVersionChanges(
    const QString &toolId,
    const QString &fromVersion,
    const QString &toVersion) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap changes;
    
    auto fromInfo = getVersionInfo(toolId, fromVersion);
    auto toInfo = getVersionInfo(toolId, toVersion);
    
    if (!fromInfo.toolId.isEmpty() && !toInfo.toolId.isEmpty()) {
        changes["breakingChanges"] = QVariant::fromValue(toInfo.breakingChanges);
        changes["newFeatures"] = QVariant::fromValue(toInfo.newFeatures);
        changes["bugFixes"] = QVariant::fromValue(toInfo.bugFixes);
        changes["deprecations"] = QVariant::fromValue(toInfo.deprecations);
    }
    
    return changes;
}

QStringList ToolVersionManager::getBreakingChanges(
    const QString &toolId,
    const QString &fromVersion,
    const QString &toVersion) const {
    
    auto toInfo = getVersionInfo(toolId, toVersion);
    return toInfo.breakingChanges;
}

QStringList ToolVersionManager::getDeprecations(
    const QString &toolId,
    const QString &version) const {
    
    auto versionInfo = getVersionInfo(toolId, version);
    return versionInfo.deprecations;
}

bool ToolVersionManager::isAPICompatible(
    const QString &toolId,
    const QString &sourceVersion,
    const QString &targetVersion,
    QString &incompatibilities) const {
    
    return isCompatible(toolId, sourceVersion, targetVersion, incompatibilities);
}

QString ToolVersionManager::generateMigrationGuide(
    const QString &toolId,
    const QString &fromVersion,
    const QString &toVersion) const {
    
    QString guide = QString("Migration Guide: %1 %2 -> %3\n\n")
        .arg(toolId, fromVersion, toVersion);
    
    auto breakingChanges = getBreakingChanges(toolId, fromVersion, toVersion);
    
    if (!breakingChanges.isEmpty()) {
        guide += "Breaking Changes:\n";
        for (const auto &change : breakingChanges) {
            guide += "- " + change + "\n";
        }
        guide += "\n";
    }
    
    return guide;
}

bool ToolVersionManager::areParametersCompatible(
    const QString &toolId,
    const QString &sourceVersion,
    const QString &targetVersion,
    const QStringList &parameterNames,
    QString &errorMessage) const {
    
    // 检查参数兼容性
    for (const auto &param : parameterNames) {
        // 这里应该检查参数是否在两个版本中都存在
    }
    
    return true;
}

// ── 版本历史 ────────────────────────────────────────

QVector<ToolVersionInfo> ToolVersionManager::getVersionHistory(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolVersionInfo> history;
    
    if (m_versions.contains(toolId)) {
        const auto &records = m_versions[toolId];
        
        int start = std::max(0, (int)records.size() - limit);
        for (int i = start; i < records.size(); ++i) {
            history.append(records[i].info);
        }
    }
    
    return history;
}

QString ToolVersionManager::generateVersionTimeline(
    const QString &toolId) const {
    
    QString timeline = QString("Version Timeline for %1\n").arg(toolId);
    timeline += "===========================\n\n";
    
    auto versions = getVersionHistory(toolId, 100);
    for (const auto &version : versions) {
        timeline += QString("%1 - %2\n")
            .arg(version.version, version.releasedAt.toString("yyyy-MM-dd"));
    }
    
    return timeline;
}

QVariantMap ToolVersionManager::getVersionReleaseMetrics(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap metrics;
    
    if (m_versions.contains(toolId)) {
        metrics["totalVersions"] = m_versions[toolId].size();
        
        if (m_versions[toolId].size() > 1) {
            auto first = m_versions[toolId].first();
            auto last = m_versions[toolId].last();
            
            qint64 days = first.registeredAt.daysTo(last.registeredAt);
            float releaseFrequency = (float)m_versions[toolId].size() / (days > 0 ? days : 1);
            
            metrics["releaseFrequency"] = releaseFrequency;
        }
    }
    
    return metrics;
}

QVariantMap ToolVersionManager::trackVersionAdoption(
    const QString &toolId) const {
    
    QVariantMap adoption;
    
    // 简化实现 - 追踪版本采用情况
    adoption["totalVersions"] = getAllVersions(toolId).size();
    adoption["activeVersions"] = getActiveVersions(toolId).size();
    
    return adoption;
}

// ── 版本检查和验证 ──────────────────────────────────

bool ToolVersionManager::isValidVersion(const QString &version) const {
    // 检查语义版本控制格式 (semver): major.minor.patch[-prerelease][+build]
    QRegularExpression semverRegex("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$");
    QRegularExpressionMatch match = semverRegex.match(version);
    
    return match.hasMatch();
}

int ToolVersionManager::compareVersions(
    const QString &version1,
    const QString &version2) const {
    
    auto v1 = parseVersionNumbers(version1);
    auto v2 = parseVersionNumbers(version2);
    
    for (int i = 0; i < std::max(v1.size(), v2.size()); ++i) {
        int num1 = i < v1.size() ? v1[i] : 0;
        int num2 = i < v2.size() ? v2[i] : 0;
        
        if (num1 < num2) return -1;
        if (num1 > num2) return 1;
    }
    
    return 0;
}

bool ToolVersionManager::validateVersionInfo(
    const ToolVersionInfo &versionInfo,
    QString &errorMessage) const {
    
    if (versionInfo.toolId.isEmpty()) {
        errorMessage = "Tool ID is empty";
        return false;
    }
    
    if (versionInfo.version.isEmpty()) {
        errorMessage = "Version is empty";
        return false;
    }
    
    if (!isValidVersion(versionInfo.version)) {
        errorMessage = "Invalid version format";
        return false;
    }
    
    return true;
}

QString ToolVersionManager::generateVersionChecksum(
    const QString &toolId,
    const QString &version) const {
    
    QString data = toolId + version;
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(data.toUtf8());
    
    return hash.result().toHex();
}

bool ToolVersionManager::verifyVersionChecksum(
    const QString &toolId,
    const QString &version,
    const QString &checksum) const {
    
    QString expected = generateVersionChecksum(toolId, version);
    return expected == checksum;
}

// ── 报告生成 ────────────────────────────────────────

QString ToolVersionManager::generateCompatibilityReport(
    const QString &toolId) const {
    
    QString report = QString("Compatibility Report for %1\n").arg(toolId);
    report += "================================\n\n";
    
    auto versions = getAllVersions(toolId);
    
    report += "Active Versions:\n";
    for (const auto &version : getActiveVersions(toolId)) {
        report += QString("  %1 %2\n").arg(version.name, version.version);
    }
    
    report += "\nDeprecated Versions:\n";
    for (const auto &version : versions) {
        if (version.isDeprecated) {
            report += QString("  %1 (deprecated)\n").arg(version.version);
        }
    }
    
    return report;
}

QString ToolVersionManager::generateReleaseNotes(
    const QString &toolId,
    const QString &version) const {
    
    auto versionInfo = getVersionInfo(toolId, version);
    
    QString notes = QString("%1 v%2 - Release Notes\n")
        .arg(toolId, version);
    notes += "================================\n\n";
    
    notes += QString("Released: %1\n\n")
        .arg(versionInfo.releasedAt.toString("yyyy-MM-dd"));
    
    notes += "New Features:\n";
    for (const auto &feature : versionInfo.newFeatures) {
        notes += QString("  - %1\n").arg(feature);
    }
    
    notes += "\nBug Fixes:\n";
    for (const auto &fix : versionInfo.bugFixes) {
        notes += QString("  - %1\n").arg(fix);
    }
    
    if (!versionInfo.breakingChanges.isEmpty()) {
        notes += "\nBreaking Changes:\n";
        for (const auto &change : versionInfo.breakingChanges) {
            notes += QString("  - %1\n").arg(change);
        }
    }
    
    return notes;
}

QByteArray ToolVersionManager::exportVersionsAsJSON(
    const QString &toolId) const {
    
    QJsonObject root;
    root["toolId"] = toolId;
    
    QJsonArray versionsArray;
    for (const auto &version : getAllVersions(toolId)) {
        QJsonObject versionObj;
        versionObj["version"] = version.version;
        versionObj["released"] = version.releasedAt.toString();
        versionObj["isDeprecated"] = version.isDeprecated;
        versionsArray.append(versionObj);
    }
    
    root["versions"] = versionsArray;
    
    QJsonDocument doc(root);
    return doc.toJson();
}

bool ToolVersionManager::importVersionsFromJSON(
    const QByteArray &jsonData,
    QString &errorMessage) {
    
    QJsonDocument doc = QJsonDocument::fromJson(jsonData);
    if (!doc.isObject()) {
        errorMessage = "Invalid JSON format";
        return false;
    }
    
    QJsonObject root = doc.object();
    QString toolId = root["toolId"].toString();
    
    if (toolId.isEmpty()) {
        errorMessage = "Tool ID not found in JSON";
        return false;
    }
    
    QJsonArray versionsArray = root["versions"].toArray();
    
    for (const auto &versionJson : versionsArray) {
        QJsonObject versionObj = versionJson.toObject();
        
        ToolVersionInfo info;
        info.toolId = toolId;
        info.version = versionObj["version"].toString();
        info.releasedAt = QDateTime::fromString(versionObj["released"].toString());
        info.isDeprecated = versionObj["isDeprecated"].toBool();
        
        registerToolVersion(info);
    }
    
    return true;
}

QString ToolVersionManager::generateSupportMatrix(
    const QString &toolId) const {
    
    QString matrix = QString("Support Matrix for %1\n").arg(toolId);
    matrix += "=======================\n\n";
    
    matrix += "Version | Status | EOL Date\n";
    matrix += "--------|--------|----------\n";
    
    for (const auto &version : getAllVersions(toolId)) {
        QString status = version.isDeprecated ? "Deprecated" : "Active";
        matrix += QString("%1 | %2 | %3\n")
            .arg(version.version, status, 
                 version.releaseNotes);
    }
    
    return matrix;
}

// ── 维护操作 ────────────────────────────────────────

void ToolVersionManager::deprecateVersion(
    const QString &toolId,
    const QString &version,
    const QString &reason,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        for (auto &record : m_versions[toolId]) {
            if (record.info.version == version) {
                record.info.isDeprecated = true;
                emit versionDeprecated(toolId, version);
                
                if (callback) callback(true);
                
                qDebug() << "[ToolVersionManager] Version deprecated:" << version;
                return;
            }
        }
    }
    
    if (callback) callback(false);
}

void ToolVersionManager::removeVersion(
    const QString &toolId,
    const QString &version,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        auto &records = m_versions[toolId];
        
        for (int i = 0; i < records.size(); ++i) {
            if (records[i].info.version == version) {
                records.removeAt(i);
                emit versionRemoved(toolId, version);
                
                if (callback) callback(true, "");
                
                qDebug() << "[ToolVersionManager] Version removed:" << version;
                return;
            }
        }
    }
    
    if (callback) callback(false, "Version not found");
}

void ToolVersionManager::setEndOfSupportDate(
    const QString &toolId,
    const QString &version,
    const QDateTime &date) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        for (auto &record : m_versions[toolId]) {
            if (record.info.version == version) {
                record.info.expiresAt = date;
                return;
            }
        }
    }
}

QString ToolVersionManager::getVersionSupportStatus(
    const QString &toolId,
    const QString &version) const {
    
    auto versionInfo = getVersionInfo(toolId, version);
    
    if (versionInfo.toolId.isEmpty()) {
        return "unknown";
    }
    
    if (versionInfo.isDeprecated) {
        return "deprecated";
    }
    
    QDateTime now = QDateTime::currentDateTime();
    if (now > versionInfo.expiresAt && versionInfo.expiresAt.isValid()) {
        return "ended";
    }
    
    return "active";
}

int ToolVersionManager::cleanupExpiredVersions(int daysToKeep) {
    QMutexLocker locker(&m_mutex);
    
    QDateTime cutoff = QDateTime::currentDateTime().addDays(-daysToKeep);
    int removed = 0;
    
    for (auto it = m_versions.begin(); it != m_versions.end(); ++it) {
        auto &records = it.value();
        
        for (int i = records.size() - 1; i >= 0; --i) {
            if (records[i].info.isDeprecated && 
                records[i].registeredAt < cutoff) {
                records.removeAt(i);
                removed++;
            }
        }
    }
    
    return removed;
}

// ── 辅助方法 ────────────────────────────────────────

bool ToolVersionManager::isVersionInRange(
    const QString &version,
    const QString &minVersion,
    const QString &maxVersion) const {
    
    if (!minVersion.isEmpty() && compareVersions(version, minVersion) < 0) {
        return false;
    }
    
    if (!maxVersion.isEmpty() && compareVersions(version, maxVersion) > 0) {
        return false;
    }
    
    return true;
}

QVector<int> ToolVersionManager::parseVersionNumbers(
    const QString &version) const {
    
    QVector<int> numbers;
    
    // 移除任何非数字部分
    QString versionStr = version;
    int dotPos = -1;
    
    for (int i = 0; i < versionStr.length(); ++i) {
        if (versionStr[i].isDigit() || versionStr[i] == '.') {
            continue;
        }
        versionStr = versionStr.left(i);
        break;
    }
    
    auto parts = versionStr.split('.');
    for (const auto &part : parts) {
        numbers.append(part.toInt());
    }
    
    return numbers;
}

QString ToolVersionManager::normalizeVersion(
    const QString &version) const {
    
    // 规范化版本字符串
    return version;
}
