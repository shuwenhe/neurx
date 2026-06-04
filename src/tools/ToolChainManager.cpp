#include "ToolChainManager.h"
#include <QUuid>
#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

ToolChainManager::ToolChainManager(QObject *parent)
    : QObject(parent) {
    qDebug() << "[ToolChainManager] Initialized";
}

// ── 工具链管理 ────────────────────────────────────

QString ToolChainManager::createChain(
    const ToolChainDefinition &chain,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    // 验证链
    ChainValidationResult result;
    if (!validateChainInternal(chain, result)) {
        QString errorMsg = result.errors.join("; ");
        if (callback) callback(false, errorMsg);
        return "";
    }
    
    // 生成ID
    QString chainId = generateChainId();
    auto modifiedChain = chain;
    modifiedChain.chainId = chainId;
    modifiedChain.createdAt = QDateTime::currentDateTime();
    
    // 保存
    m_chains[chainId] = modifiedChain;
    
    // 保存元数据
    ChainMetadata metadata;
    metadata.chainId = chainId;
    metadata.createdAt = QDateTime::currentDateTime();
    metadata.lastModifiedAt = QDateTime::currentDateTime();
    m_metadata[chainId] = metadata;
    
    emit chainCreated(chainId);
    
    if (callback) callback(true, chainId);
    
    qDebug() << "[ToolChainManager] Chain created:" << chainId;
    return chainId;
}

ToolChainDefinition ToolChainManager::getChain(const QString &chainId) const {
    QMutexLocker locker(&m_mutex);
    
    if (m_chains.contains(chainId)) {
        return m_chains[chainId];
    }
    
    return ToolChainDefinition();
}

void ToolChainManager::updateChain(
    const ToolChainDefinition &chain,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    // 验证链存在
    if (!m_chains.contains(chain.chainId)) {
        if (callback) callback(false, "Chain not found");
        return;
    }
    
    // 验证新链
    ChainValidationResult result;
    if (!validateChainInternal(chain, result)) {
        QString errorMsg = result.errors.join("; ");
        if (callback) callback(false, errorMsg);
        return;
    }
    
    // 更新
    m_chains[chain.chainId] = chain;
    m_metadata[chain.chainId].lastModifiedAt = QDateTime::currentDateTime();
    
    emit chainUpdated(chain.chainId);
    
    if (callback) callback(true, "");
    
    qDebug() << "[ToolChainManager] Chain updated:" << chain.chainId;
}

void ToolChainManager::deleteChain(
    const QString &chainId,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_chains.contains(chainId)) {
        m_chains.remove(chainId);
        m_metadata.remove(chainId);
        m_executionHistory.remove(chainId);
        
        emit chainDeleted(chainId);
        
        if (callback) callback(true, "");
        
        qDebug() << "[ToolChainManager] Chain deleted:" << chainId;
    } else {
        if (callback) callback(false, "Chain not found");
    }
}

QVector<ToolChainDefinition> ToolChainManager::listChains() const {
    QMutexLocker locker(&m_mutex);
    
    return m_chains.values().toVector();
}

QVector<ToolChainDefinition> ToolChainManager::searchChains(
    const QString &keyword) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ToolChainDefinition> results;
    
    for (const auto &chain : m_chains) {
        if (chain.name.contains(keyword, Qt::CaseInsensitive) ||
            chain.description.contains(keyword, Qt::CaseInsensitive)) {
            results.append(chain);
        }
    }
    
    return results;
}

// ── 链验证 ─────────────────────────────────────────

ChainValidationResult ToolChainManager::validateChain(
    const ToolChainDefinition &chain) const {
    
    ChainValidationResult result;
    validateChainInternal(chain, result);
    return result;
}

bool ToolChainManager::validateStepDependencies(
    const ToolChainStep &step,
    const QVector<ToolExecutionResult> &previousResults,
    QString &errorMessage) const {
    
    // 检查所需输入是否来自前一个步骤
    for (const auto &input : step.inputFromPrevious) {
        bool found = false;
        
        if (!previousResults.isEmpty()) {
            const auto &lastResult = previousResults.last();
            if (lastResult.result.contains(input)) {
                found = true;
            }
        }
        
        if (!found) {
            errorMessage = QString("Required input '%1' not found in previous results")
                .arg(input);
            return false;
        }
    }
    
    return true;
}

bool ToolChainManager::checkVersionCompatibility(
    const QString &toolId,
    const QString &version,
    QString &errorMessage) const {
    
    // 这将与版本管理器集成
    // 暂时返回true
    return true;
}

QStringList ToolChainManager::getMissingDependencies(
    const ToolChainDefinition &chain) const {
    
    QStringList missing;
    
    // 检查工具是否存在
    for (const auto &step : chain.steps) {
        // 这将与工具注册表集成
    }
    
    return missing;
}

qint64 ToolChainManager::estimateChainDuration(
    const ToolChainDefinition &chain) const {
    
    qint64 totalDuration = 0;
    
    for (const auto &step : chain.steps) {
        // 这将从工具元数据获取
        totalDuration += 1000;  // 默认1秒
    }
    
    return totalDuration;
}

float ToolChainManager::estimateChainCost(
    const ToolChainDefinition &chain) const {
    
    float totalCost = 0.0f;
    
    for (const auto &step : chain.steps) {
        // 这将从工具元数据获取
        totalCost += 0.01f;  // 默认0.01
    }
    
    return totalCost;
}

// ── 链分析 ─────────────────────────────────────────

bool ToolChainManager::hasCyclicDependencies(
    const ToolChainDefinition &chain,
    QString &errorMessage) const {
    
    // 使用拓扑排序检测循环
    // 简化实现
    return false;
}

QVector<int> ToolChainManager::getCriticalPath(
    const ToolChainDefinition &chain) const {
    
    QVector<int> path;
    
    for (int i = 0; i < chain.steps.size(); ++i) {
        path.append(i);
    }
    
    return path;
}

QVector<QVector<int>> ToolChainManager::findParallelizableSteps(
    const ToolChainDefinition &chain) const {
    
    QVector<QVector<int>> parallel;
    
    // 分析依赖关系，找出可并行的步骤
    // 简化实现
    
    return parallel;
}

ToolChainDefinition ToolChainManager::optimizeChainExecution(
    const ToolChainDefinition &chain) const {
    
    auto optimized = chain;
    
    // 根据并行机会重新排序步骤
    // 简化实现
    
    return optimized;
}

// ── 链模板 ─────────────────────────────────────────

QString ToolChainManager::saveAsTemplate(
    const ToolChainDefinition &chain,
    const QString &templateName,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    QString templateId = generateChainId();
    
    auto template_chain = chain;
    template_chain.name = templateName;
    template_chain.chainId = templateId;
    
    m_templates[templateId] = template_chain;
    
    if (callback) callback(true, templateId);
    
    return templateId;
}

ToolChainDefinition ToolChainManager::createFromTemplate(
    const QString &templateId,
    const QVariantMap &parameters) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_templates.contains(templateId)) {
        auto chain = m_templates[templateId];
        
        // 应用参数替换
        for (auto it = parameters.begin(); it != parameters.end(); ++it) {
            for (auto &step : chain.steps) {
                if (step.parameters.contains(it.key())) {
                    step.parameters[it.key()] = it.value();
                }
            }
        }
        
        return chain;
    }
    
    return ToolChainDefinition();
}

QVector<ToolChainDefinition> ToolChainManager::listTemplates() const {
    QMutexLocker locker(&m_mutex);
    
    return m_templates.values().toVector();
}

void ToolChainManager::deleteTemplate(
    const QString &templateId,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_templates.contains(templateId)) {
        m_templates.remove(templateId);
        if (callback) callback(true, "");
    } else {
        if (callback) callback(false, "Template not found");
    }
}

// ── 链历史 ─────────────────────────────────────────

QVector<QVector<ToolExecutionResult>> ToolChainManager::getChainExecutionHistory(
    const QString &chainId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executionHistory.contains(chainId)) {
        auto history = m_executionHistory[chainId];
        if (history.size() > limit) {
            history = history.mid(history.size() - limit);
        }
        return history;
    }
    
    return QVector<QVector<ToolExecutionResult>>();
}

QVariantMap ToolChainManager::getChainStatistics(
    const QString &chainId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    if (m_metadata.contains(chainId)) {
        const auto &metadata = m_metadata[chainId];
        stats["createdAt"] = metadata.createdAt.toString();
        stats["lastModifiedAt"] = metadata.lastModifiedAt.toString();
        stats["executionCount"] = metadata.executionCount;
        stats["successRate"] = metadata.averageSuccessRate;
    }
    
    return stats;
}

QString ToolChainManager::cloneChain(
    const QString &sourceChainId,
    const QString &newName,
    std::function<void(bool, const QString&)> callback) {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_chains.contains(sourceChainId)) {
        if (callback) callback(false, "Source chain not found");
        return "";
    }
    
    auto sourceChain = m_chains[sourceChainId];
    sourceChain.name = newName;
    sourceChain.chainId = generateChainId();
    sourceChain.createdAt = QDateTime::currentDateTime();
    
    QString newChainId = sourceChain.chainId;
    m_chains[newChainId] = sourceChain;
    
    ChainMetadata metadata;
    metadata.chainId = newChainId;
    metadata.createdAt = QDateTime::currentDateTime();
    m_metadata[newChainId] = metadata;
    
    if (callback) callback(true, newChainId);
    
    return newChainId;
}

// ── 可视化和导出 ──────────────────────────────────

QString ToolChainManager::generateFlowDiagram(
    const ToolChainDefinition &chain) const {
    
    QString dot = "digraph {\n";
    dot += QString("  label=\"%1\"\n").arg(chain.name);
    
    for (const auto &step : chain.steps) {
        dot += QString("  step_%1 [label=\"%2\\n(%3)\"]\n")
            .arg(step.stepId)
            .arg(step.capabilityName)
            .arg(step.toolId);
    }
    
    // 添加边
    for (int i = 0; i < chain.steps.size() - 1; ++i) {
        dot += QString("  step_%1 -> step_%2\n")
            .arg(chain.steps[i].stepId)
            .arg(chain.steps[i + 1].stepId);
    }
    
    dot += "}\n";
    
    return dot;
}

QByteArray ToolChainManager::exportChainAsJson(
    const ToolChainDefinition &chain) const {
    
    QJsonObject json;
    json["chainId"] = chain.chainId;
    json["name"] = chain.name;
    json["description"] = chain.description;
    
    QJsonArray stepsArray;
    for (const auto &step : chain.steps) {
        QJsonObject stepObj;
        stepObj["stepId"] = step.stepId;
        stepObj["toolId"] = step.toolId;
        stepObj["capabilityName"] = step.capabilityName;
        stepsArray.append(stepObj);
    }
    json["steps"] = stepsArray;
    
    QJsonDocument doc(json);
    return doc.toJson();
}

ToolChainDefinition ToolChainManager::importChainFromJson(
    const QByteArray &jsonData,
    QString &errorMessage) const {
    
    QJsonDocument doc = QJsonDocument::fromJson(jsonData);
    if (!doc.isObject()) {
        errorMessage = "Invalid JSON format";
        return ToolChainDefinition();
    }
    
    // 解析JSON并构建ToolChainDefinition
    QJsonObject json = doc.object();
    
    ToolChainDefinition chain;
    chain.chainId = json["chainId"].toString();
    chain.name = json["name"].toString();
    chain.description = json["description"].toString();
    
    QJsonArray stepsArray = json["steps"].toArray();
    for (const auto &stepJson : stepsArray) {
        QJsonObject stepObj = stepJson.toObject();
        ToolChainStep step;
        step.stepId = stepObj["stepId"].toInt();
        step.toolId = stepObj["toolId"].toString();
        step.capabilityName = stepObj["capabilityName"].toString();
        chain.steps.append(step);
    }
    
    return chain;
}

QString ToolChainManager::generateExecutionReport(
    const QString &chainId,
    const QString &executionId) const {
    
    QString report = QString("Chain Execution Report\n");
    report += QString("Chain ID: %1\n").arg(chainId);
    report += QString("Execution ID: %1\n").arg(executionId);
    
    return report;
}

// ── 辅助方法 ────────────────────────────────────────

QString ToolChainManager::generateChainId() const {
    return "chain_" + QUuid::createUuid().toString(QUuid::WithoutBraces);
}

bool ToolChainManager::validateChainInternal(
    const ToolChainDefinition &chain,
    ChainValidationResult &result) const {
    
    result.isValid = true;
    result.canExecute = true;
    
    if (chain.steps.isEmpty()) {
        result.isValid = false;
        result.errors.append("Chain has no steps");
        return false;
    }
    
    if (chain.name.isEmpty()) {
        result.isValid = false;
        result.errors.append("Chain name is empty");
        return false;
    }
    
    // 更多验证...
    
    return result.isValid;
}

void ToolChainManager::recordChainExecution(
    const QString &chainId,
    const QVector<ToolExecutionResult> &results) {
    
    QMutexLocker locker(&m_mutex);
    
    m_executionHistory[chainId].append(results);
    
    if (m_metadata.contains(chainId)) {
        m_metadata[chainId].executionCount++;
    }
}
