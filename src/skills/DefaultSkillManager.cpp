#include "DefaultSkillManager.h"
#include <QDebug>
#include <algorithm>

DefaultSkillManager::DefaultSkillManager(QObject *parent)
    : SkillManager(parent)
{
}

void DefaultSkillManager::registerSkill(const SkillCapability &skill,
                                       std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (skill.skillId.isEmpty()) {
        if (callback) callback(false);
        return;
    }
    
    SkillEntry entry;
    entry.capability = skill;
    
    m_skills[skill.skillId] = entry;
    
    locker.unlock();
    
    emit skillRegistered(skill.skillId);
    
    if (callback) callback(true);
}

void DefaultSkillManager::unregisterSkill(const QString &skillId,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        m_skills.erase(it);
        locker.unlock();
        
        emit skillUnregistered(skillId);
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

QVector<SkillCapability> DefaultSkillManager::getAllSkills() const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<SkillCapability> skills;
    for (const auto &entry : m_skills) {
        skills.append(entry.capability);
    }
    
    return skills;
}

SkillCapability DefaultSkillManager::getSkill(const QString &skillId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        return it->capability;
    }
    
    return SkillCapability();
}

QVector<SkillCapability> DefaultSkillManager::searchSkills(const SkillFilter &filter) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<SkillCapability> results;
    int count = 0;
    
    for (const auto &entry : m_skills) {
        const auto &skill = entry.capability;
        
        if (filter.availableOnly && !entry.enabled) {
            continue;
        }
        
        // Search query
        if (!filter.query.isEmpty()) {
            QString query = filter.query.toLower();
            if (!skill.name.toLower().contains(query) &&
                !skill.description.toLower().contains(query) &&
                !skill.skillId.toLower().contains(query)) {
                continue;
            }
        }
        
        // Category filter
        if (!filter.categories.isEmpty()) {
            if (!filter.categories.contains(skill.skillId.section('.', 0, 1))) {
                continue;
            }
        }
        
        // Tag filter
        if (!filter.tags.isEmpty()) {
            bool hasTag = false;
            for (const auto &tag : filter.tags) {
                if (skill.skillId.contains(tag)) {
                    hasTag = true;
                    break;
                }
            }
            if (!hasTag) continue;
        }
        
        results.append(skill);
        count++;
        
        if (count >= filter.maxResults) {
            break;
        }
    }
    
    return results;
}

QVector<SkillAvailability> DefaultSkillManager::checkAvailability(const QVariantMap &context) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<SkillAvailability> availability;
    
    for (const auto &entry : m_skills) {
        SkillAvailability avail;
        avail.skillId = entry.capability.skillId;
        avail.available = entry.enabled;
        
        // Check permissions
        avail.hasPermissions = true;
        
        // Check context
        avail.availableInContext = true;
        
        availability.append(avail);
    }
    
    return availability;
}

SkillAvailability DefaultSkillManager::checkSkillAvailability(const QString &skillId,
                                                              const QVariantMap &context) const
{
    QMutexLocker locker(&m_mutex);
    
    SkillAvailability avail;
    avail.skillId = skillId;
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        avail.available = it->enabled;
        avail.hasPermissions = true;
        avail.availableInContext = true;
    } else {
        avail.available = false;
        avail.unavailableReason = "Skill not found";
    }
    
    return avail;
}

QVector<SkillCapability> DefaultSkillManager::getAvailableSkills(const QVariantMap &context) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<SkillCapability> available;
    
    for (const auto &entry : m_skills) {
        if (entry.enabled) {
            available.append(entry.capability);
        }
    }
    
    return available;
}

void DefaultSkillManager::invokeSkill(const SkillInvocation &invocation,
                                     SkillCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(invocation.skillId);
    if (it == m_skills.end()) {
        locker.unlock();
        
        SkillResult result;
        result.skillId = invocation.skillId;
        result.invocationId = invocation.invocationId;
        result.success = false;
        result.errorMessage = "Skill not found";
        
        if (callback) callback(result);
        return;
    }
    
    if (!it->enabled) {
        locker.unlock();
        
        SkillResult result;
        result.skillId = invocation.skillId;
        result.invocationId = invocation.invocationId;
        result.success = false;
        result.errorMessage = "Skill is disabled";
        
        if (callback) callback(result);
        return;
    }
    
    // Validate parameters
    QString errorMsg;
    if (!validateSkillParameters(invocation.skillId, invocation.parameters, errorMsg)) {
        locker.unlock();
        
        SkillResult result;
        result.skillId = invocation.skillId;
        result.invocationId = invocation.invocationId;
        result.success = false;
        result.errorMessage = "Parameter validation failed: " + errorMsg;
        
        if (callback) callback(result);
        return;
    }
    
    // Update stats
    it->invocationCount++;
    it->lastInvokedAt = QDateTime::currentDateTime();
    
    SkillCapability skill = it->capability;
    locker.unlock();
    
    emit skillInvoked(invocation.skillId, invocation);
    
    // Simulate skill execution
    SkillResult result;
    result.skillId = invocation.skillId;
    result.invocationId = invocation.invocationId;
    result.success = true;
    result.output = QVariantMap{
        {"skill", invocation.skillId},
        {"message", "Skill executed successfully"}
    };
    result.tokensUsed = skill.costTokens;
    result.durationMs = 100;
    
    QMutexLocker locker2(&m_mutex);
    m_invocationHistory.append(result);
    
    auto statIt = m_skills.find(invocation.skillId);
    if (statIt != m_skills.end()) {
        statIt->successCount++;
        statIt->totalTokensUsed += result.tokensUsed;
    }
    locker2.unlock();
    
    emit skillCompleted(invocation.skillId, result);
    
    if (callback) callback(result);
}

void DefaultSkillManager::invokeSkills(const QVector<SkillInvocation> &invocations,
                                      std::function<void(const QVector<SkillResult> &results)> callback)
{
    QVector<SkillResult> results;
    
    for (const auto &invocation : invocations) {
        invokeSkill(invocation, [&results](const SkillResult &result) {
            results.append(result);
        });
    }
    
    if (callback) callback(results);
}

void DefaultSkillManager::cancelSkillInvocation(const QString &invocationId,
                                               std::function<void(bool success)> callback)
{
    // Would cancel in-progress invocation
    if (callback) callback(true);
}

void DefaultSkillManager::updateContext(const QVariantMap &context)
{
    QMutexLocker locker(&m_mutex);
    m_context = context;
    locker.unlock();
    
    emit contextChanged(context);
}

QVariantMap DefaultSkillManager::getCurrentContext() const
{
    QMutexLocker locker(&m_mutex);
    return m_context;
}

QVector<SkillMention> DefaultSkillManager::getSkillsForLLMContext(const QVariantMap &context,
                                                                  int maxSkills) const
{
    QVector<SkillMention> mentions;
    
    auto available = getAvailableSkills(context);
    qsizetype limit = static_cast<qsizetype>(maxSkills);

    for (qsizetype i = 0; i < std::min(available.size(), limit); ++i) {
        const auto &skill = available[i];
        
        SkillMention mention;
        mention.skillId = skill.skillId;
        mention.skillName = skill.name;
        mention.description = skill.description;
        mention.mentioned = true;
        mention.relevanceScore = 50 + (i * 5);
        
        mentions.append(mention);
    }
    
    return mentions;
}

QString DefaultSkillManager::renderSkillsForLLM(const QVector<SkillMention> &mentions) const
{
    QString output = "Available Skills:\n";
    
    for (const auto &mention : mentions) {
        if (mention.mentioned) {
            output += QString("\n- **%1** (%2)\n  %3\n")
                .arg(mention.skillName, mention.skillId, mention.description);
        }
    }
    
    return output;
}

QVector<SkillCapability> DefaultSkillManager::getRelevantSkills(const QString &userQuery,
                                                                const QVariantMap &context,
                                                                int maxResults) const
{
    QVector<SkillCapability> relevant;
    QMultiMap<int, SkillCapability> scored;
    
    auto available = getAvailableSkills(context);
    
    for (const auto &skill : available) {
        int score = calculateRelevanceScore(skill, userQuery, context);
        if (score > 0) {
            scored.insert(score, skill);
        }
    }
    
    // Get top N
    auto it = scored.end();
    int count = 0;
    while (it != scored.begin() && count < maxResults) {
        --it;
        relevant.append(*it);
        count++;
    }
    
    return relevant;
}

void DefaultSkillManager::setSkillPolicy(const QString &skillId,
                                        SkillPolicy policy)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        it->policy = policy;
    }
}

SkillPolicy DefaultSkillManager::getSkillPolicy(const QString &skillId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        return it->policy;
    }
    
    return SkillPolicy::Auto;
}

void DefaultSkillManager::setSkillEnabled(const QString &skillId, bool enabled)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        it->enabled = enabled;
    }
}

bool DefaultSkillManager::isSkillEnabled(const QString &skillId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        return it->enabled;
    }
    
    return false;
}

QVector<SkillResult> DefaultSkillManager::getSkillHistory(const QString &skillId,
                                                          int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<SkillResult> history;
    
    for (int i = m_invocationHistory.size() - 1; i >= 0 && history.size() < limit; --i) {
        if (m_invocationHistory[i].skillId == skillId) {
            history.append(m_invocationHistory[i]);
        }
    }
    
    return history;
}

QVector<SkillResult> DefaultSkillManager::getInvocationHistory(int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<SkillResult> history;
    qsizetype totalSize = m_invocationHistory.size();
    qsizetype start = std::max(static_cast<qsizetype>(0), totalSize - static_cast<qsizetype>(limit));

    for (qsizetype i = start; i < totalSize; ++i) {
        history.append(m_invocationHistory[i]);
    }
    
    return history;
}

void DefaultSkillManager::clearHistory(std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    m_invocationHistory.clear();
    locker.unlock();
    
    if (callback) callback(true);
}

QVariantMap DefaultSkillManager::getSkillStats(const QString &skillId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        stats["skillId"] = it->capability.skillId;
        stats["name"] = it->capability.name;
        stats["invocationCount"] = it->invocationCount;
        stats["successCount"] = it->successCount;
        stats["errorCount"] = it->errorCount;
        stats["totalTokensUsed"] = it->totalTokensUsed;
        stats["lastInvokedAt"] = it->lastInvokedAt;
        stats["enabled"] = it->enabled;
        stats["policy"] = static_cast<int>(it->policy);
    }
    
    return stats;
}

QVariantMap DefaultSkillManager::getAllStats() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalSkills"] = m_skills.size();
    stats["enabledSkills"] = 0;
    stats["totalInvocations"] = m_invocationHistory.size();
    
    for (const auto &entry : m_skills) {
        if (entry.enabled) {
            stats["enabledSkills"] = stats["enabledSkills"].toInt() + 1;
        }
    }
    
    return stats;
}

bool DefaultSkillManager::validateSkillParameters(const QString &skillId,
                                                  const QVariantMap &parameters,
                                                  QString &errorMsg)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it == m_skills.end()) {
        errorMsg = "Skill not found";
        return false;
    }
    
    const auto &skill = it->capability;
    
    for (const auto &param : skill.input.parameters) {
        if (param.required && !parameters.contains(param.name)) {
            errorMsg = QString("Missing required parameter: %1").arg(param.name);
            return false;
        }
        
        if (parameters.contains(param.name)) {
            if (!validateParameter(param, parameters[param.name])) {
                errorMsg = QString("Invalid value for parameter: %1").arg(param.name);
                return false;
            }
        }
    }
    
    return true;
}

QVariantMap DefaultSkillManager::getParameterSchema(const QString &skillId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_skills.find(skillId);
    if (it != m_skills.end()) {
        QVariantMap schema;
        schema["type"] = "object";
        schema["properties"] = QVariantMap();
        
        for (const auto &param : it->capability.input.parameters) {
            QVariantMap prop;
            prop["type"] = param.type;
            prop["description"] = param.description;
            prop["required"] = param.required;
            
            auto props = schema["properties"].toMap();
            props[param.name] = prop;
            schema["properties"] = props;
        }
        
        return schema;
    }
    
    return QVariantMap();
}

bool DefaultSkillManager::validateParameter(const SkillParameter &param,
                                           const QVariant &value)
{
    if (param.type == "string" && !value.canConvert(QVariant::String)) {
        return false;
    }
    
    if (param.type == "number" && !value.canConvert(QVariant::Double)) {
        return false;
    }
    
    if (param.type == "boolean" && !value.canConvert(QVariant::Bool)) {
        return false;
    }
    
    if (!param.enumValues.isEmpty()) {
        if (!param.enumValues.contains(value.toString())) {
            return false;
        }
    }
    
    return true;
}

int DefaultSkillManager::calculateRelevanceScore(const SkillCapability &skill,
                                                const QString &query,
                                                const QVariantMap &context) const
{
    int score = 0;
    
    if (skill.name.contains(query, Qt::CaseInsensitive)) {
        score += 50;
    }
    
    if (skill.description.contains(query, Qt::CaseInsensitive)) {
        score += 30;
    }
    
    if (skill.skillId.contains(query, Qt::CaseInsensitive)) {
        score += 20;
    }
    
    return score;
}

QString DefaultSkillManager::formatSkillForLLM(const SkillMention &mention) const
{
    return QString("**%1** (%2): %3")
        .arg(mention.skillName, mention.skillId, mention.description);
}

#include "moc_DefaultSkillManager.cpp"
