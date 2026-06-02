#include "DefaultToolSchemaRegistry.h"
#include <QUuid>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QDate>

DefaultToolSchemaRegistry::DefaultToolSchemaRegistry(QObject *parent)
    : ToolSchemaRegistry(parent) {
}

// ── 模式管理 ────────────────────────────────────────

QString DefaultToolSchemaRegistry::registerSchema(
    const ToolSchema &schema,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QString errorMsg;
    if (!validateSchema(schema, errorMsg)) {
        qWarning() << "Schema validation failed:" << errorMsg;
        if (callback) callback(false);
        return "";
    }
    
    ToolSchema mutableSchema = schema;
    if (mutableSchema.createdAt.isNull()) {
        mutableSchema.createdAt = QDateTime::currentDateTime();
    }
    mutableSchema.updatedAt = QDateTime::currentDateTime();
    
    m_schemas[schema.toolId] = mutableSchema;
    
    // 创建初始版本
    SchemaVersion version;
    version.version = "1.0.0";
    version.schema = mutableSchema;
    version.createdAt = QDateTime::currentDateTime();
    version.description = "Initial version";
    
    m_versions[schema.toolId].append(version);
    
    // 更新依赖图
    updateDependencyGraph(schema.toolId);
    
    emit schemaRegistered(schema.toolId);
    
    if (callback) callback(true);
    
    return schema.toolId;
}

void DefaultToolSchemaRegistry::updateSchema(
    const ToolSchema &schema,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(schema.toolId)) {
        if (callback) callback(false);
        return;
    }
    
    ToolSchema mutableSchema = schema;
    mutableSchema.updatedAt = QDateTime::currentDateTime();
    m_schemas[schema.toolId] = mutableSchema;
    
    // 更新依赖
    updateDependencyGraph(schema.toolId);
    
    emit schemaUpdated(schema.toolId);
    
    if (callback) callback(true);
}

void DefaultToolSchemaRegistry::deleteSchema(
    const QString &toolId,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    bool success = m_schemas.remove(toolId) > 0;
    
    if (success) {
        m_capabilities.remove(toolId);
        m_versions.remove(toolId);
        m_usageCount.remove(toolId);
        m_dependencies.remove(toolId);
        
        // 更新依赖关系
        for (auto it = m_dependents.begin(); it != m_dependents.end(); ++it) {
            it.value().removeAll(toolId);
        }
        m_dependents.remove(toolId);
        
        emit schemaDeleted(toolId);
    }
    
    if (callback) callback(success);
}

ToolSchema DefaultToolSchemaRegistry::getSchema(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_schemas.contains(toolId)) {
        m_usageCount[toolId]++;
        return m_schemas[toolId];
    }
    
    return ToolSchema();
}

QVector<ToolSchema> DefaultToolSchemaRegistry::getAllSchemas() const {
    
    QMutexLocker locker(&m_mutex);
    
    return QVector<ToolSchema>(m_schemas.values().begin(), m_schemas.values().end());
}

ToolSchema DefaultToolSchemaRegistry::getSchemaVersion(
    const QString &toolId,
    const QString &version) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_versions.contains(toolId)) {
        for (const auto &v : m_versions[toolId]) {
            if (v.version == version) {
                return v.schema;
            }
        }
    }
    
    return ToolSchema();
}

// ── 能力管理 ────────────────────────────────────────

void DefaultToolSchemaRegistry::addCapability(
    const QString &toolId,
    const ToolCapabilityDefinition &capability,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        if (callback) callback(false);
        return;
    }
    
    auto &capList = m_capabilities[toolId];
    
    // 检查重复
    for (const auto &cap : capList) {
        if (cap.name == capability.name) {
            if (callback) callback(false);
            return;
        }
    }
    
    capList.append(capability);
    
    // 同时更新schema
    m_schemas[toolId].capabilities.append(capability);
    m_schemas[toolId].updatedAt = QDateTime::currentDateTime();
    
    emit capabilityAdded(toolId, capability.name);
    
    if (callback) callback(true);
}

void DefaultToolSchemaRegistry::removeCapability(
    const QString &toolId,
    const QString &capabilityName,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_capabilities.contains(toolId)) {
        if (callback) callback(false);
        return;
    }
    
    auto &capList = m_capabilities[toolId];
    int removed = 0;
    
    for (int i = 0; i < capList.size(); ++i) {
        if (capList[i].name == capabilityName) {
            capList.removeAt(i);
            removed++;
            break;
        }
    }
    
    if (removed > 0) {
        // 同时更新schema
        m_schemas[toolId].capabilities.removeAll(
            [capabilityName](const ToolCapabilityDefinition &c) {
                return c.name == capabilityName;
            }
        );
        m_schemas[toolId].updatedAt = QDateTime::currentDateTime();
        
        emit capabilityRemoved(toolId, capabilityName);
    }
    
    if (callback) callback(removed > 0);
}

void DefaultToolSchemaRegistry::updateCapability(
    const QString &toolId,
    const ToolCapabilityDefinition &capability,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_capabilities.contains(toolId)) {
        if (callback) callback(false);
        return;
    }
    
    auto &capList = m_capabilities[toolId];
    
    for (int i = 0; i < capList.size(); ++i) {
        if (capList[i].name == capability.name) {
            capList[i] = capability;
            
            // 同时更新schema
            for (int j = 0; j < m_schemas[toolId].capabilities.size(); ++j) {
                if (m_schemas[toolId].capabilities[j].name == capability.name) {
                    m_schemas[toolId].capabilities[j] = capability;
                    break;
                }
            }
            m_schemas[toolId].updatedAt = QDateTime::currentDateTime();
            
            if (callback) callback(true);
            return;
        }
    }
    
    if (callback) callback(false);
}

ToolCapabilityDefinition DefaultToolSchemaRegistry::getCapability(
    const QString &toolId,
    const QString &capabilityName) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_capabilities.contains(toolId)) {
        for (const auto &cap : m_capabilities[toolId]) {
            if (cap.name == capabilityName) {
                return cap;
            }
        }
    }
    
    return ToolCapabilityDefinition();
}

QVector<ToolCapabilityDefinition> DefaultToolSchemaRegistry::getAllCapabilities(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_capabilities.contains(toolId)) {
        return m_capabilities[toolId];
    }
    
    return QVector<ToolCapabilityDefinition>();
}

// ── 模式验证 ────────────────────────────────────────

bool DefaultToolSchemaRegistry::validateSchema(
    const ToolSchema &schema,
    QString &errorMessage) {
    
    // 验证必需字段
    if (schema.toolId.isEmpty()) {
        errorMessage = "Tool ID is required";
        return false;
    }
    
    if (schema.name.isEmpty()) {
        errorMessage = "Tool name is required";
        return false;
    }
    
    if (schema.author.isEmpty()) {
        errorMessage = "Tool author is required";
        return false;
    }
    
    // 检查依赖是否可解决
    if (!schema.dependencies.isEmpty()) {
        for (const auto &dep : schema.dependencies) {
            if (!m_schemas.contains(dep)) {
                errorMessage = QString("Dependency %1 not found").arg(dep);
                return false;
            }
        }
    }
    
    return true;
}

bool DefaultToolSchemaRegistry::validateParameters(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &parameters,
    QString &errorMessage) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        errorMessage = QString("Tool %1 not found").arg(toolId);
        return false;
    }
    
    // 获取能力定义
    ToolCapabilityDefinition cap;
    bool found = false;
    
    for (const auto &c : m_schemas[toolId].capabilities) {
        if (c.name == capabilityName) {
            cap = c;
            found = true;
            break;
        }
    }
    
    if (!found) {
        errorMessage = QString("Capability %1 not found").arg(capabilityName);
        return false;
    }
    
    // 检查必需参数
    for (const auto &param : cap.inputParams) {
        if (!parameters.contains(param)) {
            errorMessage = QString("Required parameter %1 missing").arg(param);
            return false;
        }
    }
    
    return true;
}

bool DefaultToolSchemaRegistry::validateConfiguration(
    const QString &toolId,
    const QVariantMap &config,
    QString &errorMessage) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        errorMessage = QString("Tool %1 not found").arg(toolId);
        return false;
    }
    
    // 简单验证：配置不为空
    if (config.isEmpty()) {
        errorMessage = "Configuration cannot be empty";
        return false;
    }
    
    return true;
}

bool DefaultToolSchemaRegistry::validateResult(
    const QString &toolId,
    const QString &capabilityName,
    const QVariantMap &result,
    QString &errorMessage) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        errorMessage = QString("Tool %1 not found").arg(toolId);
        return false;
    }
    
    // 获取能力定义
    for (const auto &cap : m_schemas[toolId].capabilities) {
        if (cap.name == capabilityName) {
            // 检查结果字段
            for (const auto &field : cap.outputParams) {
                if (!result.contains(field)) {
                    errorMessage = QString("Required output field %1 missing").arg(field);
                    return false;
                }
            }
            return true;
        }
    }
    
    errorMessage = QString("Capability %1 not found").arg(capabilityName);
    return false;
}

// ── 模式版本控制 ────────────────────────────────────

QString DefaultToolSchemaRegistry::createVersion(
    const QString &toolId,
    const ToolSchema &schema,
    const QString &description,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        if (callback) callback(false);
        return "";
    }
    
    SchemaVersion version;
    version.version = generateVersion();
    version.schema = schema;
    version.createdAt = QDateTime::currentDateTime();
    version.description = description.isEmpty() ? "Auto-created version" : description;
    
    m_versions[toolId].append(version);
    
    if (callback) callback(true);
    
    return version.version;
}

QVector<QString> DefaultToolSchemaRegistry::getVersionHistory(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> history;
    
    if (m_versions.contains(toolId)) {
        for (const auto &v : m_versions[toolId]) {
            history.append(v.version);
        }
    }
    
    return history;
}

void DefaultToolSchemaRegistry::rollbackToVersion(
    const QString &toolId,
    const QString &version,
    std::function<void(bool)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_versions.contains(toolId)) {
        if (callback) callback(false);
        return;
    }
    
    for (const auto &v : m_versions[toolId]) {
        if (v.version == version) {
            m_schemas[toolId] = v.schema;
            m_schemas[toolId].updatedAt = QDateTime::currentDateTime();
            emit schemaUpdated(toolId);
            if (callback) callback(true);
            return;
        }
    }
    
    if (callback) callback(false);
}

QVariantMap DefaultToolSchemaRegistry::compareVersions(
    const QString &toolId,
    const QString &version1,
    const QString &version2) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap comparison;
    comparison["toolId"] = toolId;
    comparison["version1"] = version1;
    comparison["version2"] = version2;
    
    ToolSchema schema1, schema2;
    bool found1 = false, found2 = false;
    
    if (m_versions.contains(toolId)) {
        for (const auto &v : m_versions[toolId]) {
            if (v.version == version1) {
                schema1 = v.schema;
                found1 = true;
            }
            if (v.version == version2) {
                schema2 = v.schema;
                found2 = true;
            }
        }
    }
    
    if (!found1 || !found2) {
        comparison["error"] = "One or both versions not found";
        return comparison;
    }
    
    // 比较差异
    if (schema1.name != schema2.name) {
        comparison["nameDiff"] = true;
    }
    
    if (schema1.capabilities.size() != schema2.capabilities.size()) {
        comparison["capabilitiesDiff"] = true;
        comparison["v1Capabilities"] = schema1.capabilities.size();
        comparison["v2Capabilities"] = schema2.capabilities.size();
    }
    
    return comparison;
}

// ── 模式搜索和过滤 ──────────────────────────────────

QVector<ToolSchema> DefaultToolSchemaRegistry::searchSchemas(
    const QString &keyword) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    QString keywordLower = keyword.toLower();
    
    for (const auto &schema : m_schemas) {
        if (schema.name.toLower().contains(keywordLower) ||
            schema.description.toLower().contains(keywordLower) ||
            schema.toolId.toLower().contains(keywordLower)) {
            results.append(schema);
        }
    }
    
    return results;
}

QVector<ToolSchema> DefaultToolSchemaRegistry::getSchemasByCategory(
    const QString &category) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    for (const auto &schema : m_schemas) {
        if (schema.category == category) {
            results.append(schema);
        }
    }
    
    return results;
}

QVector<ToolSchema> DefaultToolSchemaRegistry::getSchemasByTag(
    const QString &tag) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    for (const auto &schema : m_schemas) {
        if (schema.tags.contains(tag)) {
            results.append(schema);
        }
    }
    
    return results;
}

QVector<ToolSchema> DefaultToolSchemaRegistry::getSchemasByCapability(
    const QString &capabilityName) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> results;
    
    for (const auto &schema : m_schemas) {
        for (const auto &cap : schema.capabilities) {
            if (cap.name == capabilityName) {
                results.append(schema);
                break;
            }
        }
    }
    
    return results;
}

// ── 模式依赖分析 ────────────────────────────────────

QStringList DefaultToolSchemaRegistry::getToolDependencies(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_dependencies.contains(toolId)) {
        return m_dependencies[toolId];
    }
    
    if (m_schemas.contains(toolId)) {
        return m_schemas[toolId].dependencies;
    }
    
    return QStringList();
}

QStringList DefaultToolSchemaRegistry::getToolDependents(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_dependents.contains(toolId)) {
        return m_dependents[toolId];
    }
    
    return QStringList();
}

bool DefaultToolSchemaRegistry::canResolveDependencies(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        return false;
    }
    
    const auto &deps = m_schemas[toolId].dependencies;
    
    for (const auto &dep : deps) {
        if (!m_schemas.contains(dep)) {
            return false;
        }
    }
    
    return true;
}

QVariantMap DefaultToolSchemaRegistry::getDependencyTree(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap tree;
    tree["toolId"] = toolId;
    
    if (!m_schemas.contains(toolId)) {
        tree["error"] = "Tool not found";
        return tree;
    }
    
    QStringList dependencies = m_schemas[toolId].dependencies;
    tree["directDependencies"] = dependencies;
    
    // 收集所有传递依赖
    QSet<QString> allDeps;
    QQueue<QString> queue;
    
    for (const auto &dep : dependencies) {
        queue.enqueue(dep);
    }
    
    while (!queue.isEmpty()) {
        QString current = queue.dequeue();
        if (allDeps.contains(current)) continue;
        
        allDeps.insert(current);
        
        if (m_schemas.contains(current)) {
            for (const auto &dep : m_schemas[current].dependencies) {
                if (!allDeps.contains(dep)) {
                    queue.enqueue(dep);
                }
            }
        }
    }
    
    tree["allDependencies"] = QStringList(allDeps.begin(), allDeps.end());
    
    return tree;
}

// ── 模式导入导出 ────────────────────────────────────

QString DefaultToolSchemaRegistry::exportSchemaAsJson(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        return "";
    }
    
    const auto &schema = m_schemas[toolId];
    
    QJsonObject obj;
    obj["toolId"] = schema.toolId;
    obj["name"] = schema.name;
    obj["description"] = schema.description;
    obj["version"] = schema.version;
    obj["author"] = schema.author;
    obj["category"] = schema.category;
    
    QJsonArray tagsArray;
    for (const auto &tag : schema.tags) {
        tagsArray.append(tag);
    }
    obj["tags"] = tagsArray;
    
    QJsonDocument doc(obj);
    return QString::fromUtf8(doc.toJson());
}

QString DefaultToolSchemaRegistry::importSchemaFromJson(
    const QString &jsonData,
    std::function<void(bool success)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QJsonDocument doc = QJsonDocument::fromJson(jsonData.toUtf8());
    if (!doc.isObject()) {
        if (callback) callback(false);
        return "";
    }
    
    QJsonObject obj = doc.object();
    
    ToolSchema schema;
    schema.toolId = obj["toolId"].toString();
    schema.name = obj["name"].toString();
    schema.description = obj["description"].toString();
    schema.version = obj["version"].toString();
    schema.author = obj["author"].toString();
    schema.category = obj["category"].toString();
    
    QJsonArray tagsArray = obj["tags"].toArray();
    for (const auto &tag : tagsArray) {
        schema.tags.append(tag.toString());
    }
    
    // 注册模式
    m_schemas[schema.toolId] = schema;
    
    emit schemaRegistered(schema.toolId);
    
    if (callback) callback(true);
    
    return schema.toolId;
}

QString DefaultToolSchemaRegistry::exportAsOpenAPI(const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_schemas.contains(toolId)) {
        return "";
    }
    
    // 简化的OpenAPI导出
    QString openapi = "openapi: 3.0.0\n";
    openapi += "info:\n";
    
    const auto &schema = m_schemas[toolId];
    openapi += QString("  title: %1\n").arg(schema.name);
    openapi += QString("  description: %1\n").arg(schema.description);
    openapi += QString("  version: %1\n").arg(schema.version);
    
    openapi += "paths: {}\n";
    
    return openapi;
}

// ── 模式统计 ────────────────────────────────────────

QVariantMap DefaultToolSchemaRegistry::getSchemaStatistics() const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalSchemas"] = m_schemas.size();
    stats["totalVersions"] = m_versions.size();
    stats["totalCapabilities"] = 0;
    
    int totalCaps = 0;
    for (const auto &caps : m_capabilities) {
        totalCaps += caps.size();
    }
    stats["totalCapabilities"] = totalCaps;
    
    return stats;
}

QVariantMap DefaultToolSchemaRegistry::getCapabilityStatistics(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    if (m_capabilities.contains(toolId)) {
        stats["totalCapabilities"] = m_capabilities[toolId].size();
    } else {
        stats["totalCapabilities"] = 0;
    }
    
    return stats;
}

QVector<ToolSchema> DefaultToolSchemaRegistry::getPopularSchemas(int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolSchema> allSchemas = getAllSchemas();
    
    // 按使用量排序
    std::sort(allSchemas.begin(), allSchemas.end(),
        [this](const ToolSchema &a, const ToolSchema &b) {
            return m_usageCount.value(a.toolId, 0) > 
                   m_usageCount.value(b.toolId, 0);
        }
    );
    
    if (allSchemas.size() > limit) {
        allSchemas.resize(limit);
    }
    
    return allSchemas;
}

// ── 辅助方法 ────────────────────────────────────────

QString DefaultToolSchemaRegistry::generateVersion() {
    static int versionNumber = 0;
    versionNumber++;
    return QString("1.0.%1").arg(versionNumber);
}

bool DefaultToolSchemaRegistry::validateToolId(const QString &toolId) {
    return !toolId.isEmpty() && !m_schemas.contains(toolId);
}

void DefaultToolSchemaRegistry::updateDependencyGraph(const QString &toolId) {
    
    if (!m_schemas.contains(toolId)) {
        return;
    }
    
    const auto &deps = m_schemas[toolId].dependencies;
    m_dependencies[toolId] = deps;
    
    // 更新反向依赖
    for (const auto &dep : deps) {
        if (!m_dependents[dep].contains(toolId)) {
            m_dependents[dep].append(toolId);
        }
    }
}

bool DefaultToolSchemaRegistry::hasCircularDependency(
    const QString &toolId,
    QSet<QString> &visited) {
    
    if (visited.contains(toolId)) {
        return true;
    }
    
    visited.insert(toolId);
    
    if (m_schemas.contains(toolId)) {
        for (const auto &dep : m_schemas[toolId].dependencies) {
            if (hasCircularDependency(dep, visited)) {
                return true;
            }
        }
    }
    
    visited.remove(toolId);
    return false;
}
