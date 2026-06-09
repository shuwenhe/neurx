#include "SkillSystem.h"
#include <QUuid>
#include <QDateTime>
#include <algorithm>

SkillSystem::SkillSystem(QObject* parent)
    : QObject(parent), m_autoInvokeEnabled(true), m_autoInvokeThreshold(0.7f) {
    m_statistics = {0, 0, 0, {}, 0.0f, 0};
}

SkillSystem::~SkillSystem() {
    m_skills.clear();
    m_performance.clear();
}

void SkillSystem::registerSkill(const SkillDefinition& skill) {
    m_skills[skill.id] = skill;
    m_performance[skill.id] = {0.0f, 0.0f, 0, 0, 0.0f};
    m_statistics.totalSkills++;
    if (skill.enabled) {
        m_statistics.enabledSkills++;
    }
    m_statistics.skillsByType[skill.type]++;
    emit skillRegistered(skill.id);
}

void SkillSystem::unregisterSkill(const QString& skillId) {
    if (m_skills.contains(skillId)) {
        auto skill = m_skills.value(skillId);
        m_skills.remove(skillId);
        m_performance.remove(skillId);
        m_statistics.totalSkills--;
        if (skill.enabled) {
            m_statistics.enabledSkills--;
        }
        emit skillUnregistered(skillId);
    }
}

void SkillSystem::updateSkill(const QString& skillId, const SkillDefinition& newDef) {
    if (m_skills.contains(skillId)) {
        auto oldSkill = m_skills.value(skillId);
        m_skills[skillId] = newDef;
        if (oldSkill.enabled != newDef.enabled) {
            if (newDef.enabled) {
                m_statistics.enabledSkills++;
            } else {
                m_statistics.enabledSkills--;
            }
        }
    }
}

SkillSystem::SkillDefinition SkillSystem::getSkill(const QString& skillId) {
    return m_skills.value(skillId);
}

QVector<SkillSystem::SkillDefinition> SkillSystem::getAllSkills() {
    return QVector<SkillDefinition>(m_skills.values().begin(), m_skills.values().end());
}

QVector<SkillSystem::SkillDefinition> SkillSystem::getSkillsByType(SkillType type) {
    QVector<SkillDefinition> result;
    for (const auto& skill : m_skills.values()) {
        if (skill.type == type && skill.enabled) {
            result.append(skill);
        }
    }
    return result;
}

SkillSystem::SkillResult SkillSystem::executeSkill(const QString& skillId, const SkillExecutionContext& context) {
    SkillResult result;
    result.skillId = skillId;
    result.success = false;

    if (!m_skills.contains(skillId)) {
        return result;
    }

    auto skill = m_skills.value(skillId);
    if (!skill.enabled) {
        return result;
    }

    // Check dependencies
    if (!checkDependencies(skillId)) {
        return result;
    }

    // Execute skill
    result.success = true;
    result.output = QString("Executing skill %1 for task type %2").arg(skill.name, context.taskType);
    result.relevanceScore = calculateRelevanceScore(skill, context);
    result.executionTimeMs = 100;

    // Update performance
    m_performance[skillId].timesExecuted++;
    if (result.success) {
        m_performance[skillId].successfulExecutions++;
        m_performance[skillId].successRate = static_cast<float>(m_performance[skillId].successfulExecutions) / 
                                            static_cast<float>(m_performance[skillId].timesExecuted);
    }
    m_performance[skillId].averageRelevanceScore = result.relevanceScore;

    m_statistics.totalExecutions++;
    emit skillExecuted(skillId, result.success);
    emit skillResultReceived(result);

    return result;
}

QVector<SkillSystem::SkillResult> SkillSystem::executeApplicableSkills(const SkillExecutionContext& context) {
    QVector<SkillResult> results;
    auto applicableSkills = selectSkillsForTask(context.taskType);
    
    for (const auto& skill : applicableSkills) {
        if (skill.enabled) {
            results.append(executeSkill(skill.id, context));
        }
    }

    return results;
}

QVector<SkillSystem::SkillResult> SkillSystem::executeSkillsOfType(SkillType type, const SkillExecutionContext& context) {
    QVector<SkillResult> results;
    auto skills = getSkillsByType(type);
    
    for (const auto& skill : skills) {
        results.append(executeSkill(skill.id, context));
    }

    return results;
}

QVector<SkillSystem::SkillDefinition> SkillSystem::selectSkillsForTask(const QString& taskType) {
    QVector<SkillDefinition> result;
    
    for (const auto& skill : m_skills.values()) {
        if (skill.applicableTasks.contains(taskType) && skill.enabled) {
            result.append(skill);
        }
    }
    
    std::sort(result.begin(), result.end(),
        [](const SkillDefinition& a, const SkillDefinition& b) { return a.priority > b.priority; });
    
    return result;
}

QVector<SkillSystem::SkillDefinition> SkillSystem::selectSkillsForLanguage(const QString& language) {
    QVector<SkillDefinition> result;
    
    for (const auto& skill : m_skills.values()) {
        if (skill.requiredLanguages.contains(language) && skill.enabled) {
            result.append(skill);
        }
    }

    return result;
}

QVector<SkillSystem::SkillDefinition> SkillSystem::selectSkillsByTag(const QString& tag) {
    return getSkillsByTag(tag);
}

QVector<SkillSystem::SkillDefinition> SkillSystem::suggestSkillsForCode(const QString& code) {
    QVector<SkillDefinition> suggestions;
    
    // Simple heuristics for suggestions
    if (code.contains("class") || code.contains("struct")) {
        for (const auto& skill : m_skills.values()) {
            if (skill.tags.contains("design") && skill.enabled) {
                suggestions.append(skill);
            }
        }
    }
    
    return suggestions;
}

void SkillSystem::enableAutoInvocation(bool enabled) {
    m_autoInvokeEnabled = enabled;
}

void SkillSystem::setAutoInvokeThreshold(float threshold) {
    m_autoInvokeThreshold = threshold;
}

QVector<SkillSystem::SkillDefinition> SkillSystem::getAutoInvokeSkills() {
    QVector<SkillDefinition> result;
    
    for (const auto& skill : m_skills.values()) {
        if (skill.autoInvoke && skill.enabled && skill.priority >= (100 * m_autoInvokeThreshold)) {
            result.append(skill);
        }
    }

    return result;
}

void SkillSystem::enableSkill(const QString& skillId, bool enabled) {
    if (m_skills.contains(skillId)) {
        auto skill = m_skills.value(skillId);
        bool wasEnabled = skill.enabled;
        skill.enabled = enabled;
        m_skills[skillId] = skill;
        
        if (enabled && !wasEnabled) {
            m_statistics.enabledSkills++;
        } else if (!enabled && wasEnabled) {
            m_statistics.enabledSkills--;
        }
    }
}

void SkillSystem::setSkillPriority(const QString& skillId, int priority) {
    if (m_skills.contains(skillId)) {
        m_skills[skillId].priority = priority;
    }
}

void SkillSystem::configureSkillForTask(const QString& skillId, const QString& taskType) {
    if (m_skills.contains(skillId)) {
        if (!m_skills[skillId].applicableTasks.contains(taskType)) {
            m_skills[skillId].applicableTasks.append(taskType);
        }
    }
}

void SkillSystem::setSkillDependencies(const QString& skillId, const QStringList& dependencies) {
    if (m_skills.contains(skillId)) {
        m_skills[skillId].dependencies = dependencies;
    }
}

QStringList SkillSystem::resolveDependencies(const QString& skillId) {
    if (!m_skills.contains(skillId)) {
        return QStringList();
    }

    return m_skills[skillId].dependencies;
}

bool SkillSystem::checkDependencies(const QString& skillId) {
    auto deps = resolveDependencies(skillId);
    
    for (const auto& dep : deps) {
        if (!m_skills.contains(dep) || !m_skills[dep].enabled) {
            return false;
        }
    }

    return true;
}

QStringList SkillSystem::getMissingDependencies(const QString& skillId) {
    QStringList missing;
    auto deps = resolveDependencies(skillId);
    
    for (const auto& dep : deps) {
        if (!m_skills.contains(dep) || !m_skills[dep].enabled) {
            missing.append(dep);
        }
    }

    return missing;
}

SkillSystem::SkillPerformance SkillSystem::getSkillPerformance(const QString& skillId) {
    return m_performance.value(skillId, {0.0f, 0.0f, 0, 0, 0.0f});
}

QJsonObject SkillSystem::getPerformanceReport() {
    QJsonObject report;
    report["totalSkills"] = m_statistics.totalSkills;
    report["averageSuccessRate"] = m_statistics.averageSuccessRate;
    report["totalExecutions"] = m_statistics.totalExecutions;
    return report;
}

void SkillSystem::publishSkillToMarketplace(const SkillDefinition& skill) {
    qDebug() << "Publishing skill to marketplace:" << skill.name;
}

void SkillSystem::importSkillFromMarketplace(const QString& skillId) {
    qDebug() << "Importing skill from marketplace:" << skillId;
}

QVector<SkillSystem::SkillDefinition> SkillSystem::searchMarketplace(const QString& query) {
    QVector<SkillDefinition> results;
    return results;
}

QJsonArray SkillSystem::getMarketplaceSkills() {
    QJsonArray skills;
    return skills;
}

QVector<SkillSystem::SkillResult> SkillSystem::executeBatchSkills(const QStringList& skillIds, const SkillExecutionContext& context) {
    QVector<SkillResult> results;
    
    for (const auto& skillId : skillIds) {
        results.append(executeSkill(skillId, context));
    }

    return results;
}

void SkillSystem::parallelExecuteSkills(const QStringList& skillIds, const SkillExecutionContext& context) {
    // Simulate parallel execution
    executeBatchSkills(skillIds, context);
}

SkillSystem::AggregatedResults SkillSystem::aggregateResults(const QVector<SkillResult>& results) {
    AggregatedResults agg;
    agg.totalSkillsExecuted = results.size();
    agg.successfulSkills = 0;
    agg.results = results;

    for (const auto& result : results) {
        if (result.success) {
            agg.successfulSkills++;
        }
        agg.combinedSuggestions.append(result.suggestions);
    }

    agg.overallSuccessRate = agg.totalSkillsExecuted > 0 ? 
        static_cast<float>(agg.successfulSkills) / agg.totalSkillsExecuted : 0.0f;

    return agg;
}

void SkillSystem::chainSkills(const QStringList& skillIds) {
    m_skillChain = skillIds;
}

QVector<SkillSystem::SkillResult> SkillSystem::executeSkillChain(const SkillExecutionContext& context) {
    return executeBatchSkills(m_skillChain, context);
}

void SkillSystem::addTagToSkill(const QString& skillId, const QString& tag) {
    if (m_skills.contains(skillId)) {
        if (!m_skills[skillId].tags.contains(tag)) {
            m_skills[skillId].tags.append(tag);
        }
    }
}

void SkillSystem::removeTagFromSkill(const QString& skillId, const QString& tag) {
    if (m_skills.contains(skillId)) {
        m_skills[skillId].tags.removeAll(tag);
    }
}

QStringList SkillSystem::getSkillTags(const QString& skillId) {
    if (m_skills.contains(skillId)) {
        return m_skills[skillId].tags;
    }
    return QStringList();
}

QVector<SkillSystem::SkillDefinition> SkillSystem::getSkillsByTag(const QString& tag) {
    QVector<SkillDefinition> result;

    for (const auto& skill : m_skills.values()) {
        if (skill.tags.contains(tag) && skill.enabled) {
            result.append(skill);
        }
    }

    return result;
}

SkillSystem::SkillStats SkillSystem::getStatistics() const {
    return m_statistics;
}

QJsonObject SkillSystem::exportSkill(const QString& skillId) {
    if (m_skills.contains(skillId)) {
        auto skill = m_skills.value(skillId);
        QJsonObject obj;
        obj["id"] = skill.id;
        obj["name"] = skill.name;
        obj["description"] = skill.description;
        obj["type"] = static_cast<int>(skill.type);
        return obj;
    }
    return QJsonObject();
}

bool SkillSystem::importSkillFromJson(const QJsonObject& skillJson) {
    SkillDefinition skill;
    skill.id = skillJson.value("id").toString();
    skill.name = skillJson.value("name").toString();
    skill.description = skillJson.value("description").toString();
    
    registerSkill(skill);
    return true;
}

void SkillSystem::exportAllSkills(const QString& filepath) {
    qDebug() << "Exporting all skills to:" << filepath;
}

void SkillSystem::importSkillsFromFile(const QString& filepath) {
    qDebug() << "Importing skills from:" << filepath;
}

float SkillSystem::calculateRelevanceScore(const SkillDefinition& skill, const SkillExecutionContext& context) {
    float score = 0.0f;
    
    if (skill.applicableTasks.contains(context.taskType)) {
        score += 0.4f;
    }
    
    if (skill.requiredLanguages.contains(context.currentLanguage)) {
        score += 0.3f;
    }
    
    score += skill.priority / 100.0f * 0.3f;
    
    return score;
}
