#include "ClaudeSkillManager.h"
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QDebug>
#include <QDateTime>
#include <QTimer>
#include <algorithm>

namespace {

static QStringList skillDiscoveryRoots(const QString &baseDirectory)
{
    QStringList roots;
    const auto addRoot = [&roots](const QString &path) {
        const QString absolute = QDir(path).absolutePath();
        if (!absolute.isEmpty() && QFileInfo::exists(absolute) && !roots.contains(absolute))
            roots.append(absolute);
    };

    if (!baseDirectory.trimmed().isEmpty())
        addRoot(baseDirectory);

    const QString home = QDir::homePath();
    addRoot(QDir(home).filePath(QStringLiteral(".claude/skills")));
    addRoot(QDir(home).filePath(QStringLiteral(".neurx/skills")));
    addRoot(QDir(home).filePath(QStringLiteral(".agents/skills")));
    addRoot(QStringLiteral("/Users/feifei/agent/skills/skills"));

    return roots;
}

} // namespace

ClaudeSkillManager::ClaudeSkillManager(QObject *parent)
    : QObject(parent),
      m_discoveryEngine(std::make_unique<DefaultSkillDiscoveryEngine>()),
      m_envManager(std::make_unique<DefaultSkillEnvironmentManager>())
{
}

QString ClaudeSkillManager::initialize(const QString &skillsDirectory)
{
    m_skillsDirectory = skillsDirectory;

    m_skills.clear();
    QStringList errors;
    const QStringList roots = skillDiscoveryRoots(skillsDirectory);

    for (const QString &root : roots) {
        m_discoveryEngine->discoverSkills(
            root,
            m_platform,
            true,
            [this, &errors](const QVector<ClaudeSkill> &skills, const QString &error) {
                for (const auto &skill : skills) {
                    const QString id = skill.metadata.skillId.isEmpty()
                        ? skill.filePath
                        : skill.metadata.skillId;
                    m_skills[id] = skill;
                }
                if (!error.isEmpty())
                    errors.append(error);
            }
        );
    }

    qDebug() << "Discovered" << m_skills.count() << "skills";
    emit skillsDiscovered(m_skills.count());
    if (!errors.isEmpty())
        return errors.join(QStringLiteral("\n"));

    return {};
}

void ClaudeSkillManager::setPlatform(Platform platform)
{
    m_platform = platform;
}

Platform ClaudeSkillManager::getPlatform() const
{
    return m_platform;
}

void ClaudeSkillManager::getSkillsList(ClaudeSkillsListCallback callback)
{
    QVector<SkillListingItem> items;
    
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        const auto &skill = it.value();
        
        SkillListingItem item;
        item.skillId = skill.metadata.skillId;
        item.name = skill.metadata.name;
        item.description = skill.metadata.description;
        item.tags = skill.metadata.tags;
        item.category = skill.metadata.category;
        const SkillAvailabilityCheck check = checkSkillAvailability(it.key());
        item.available = check.platformSupported && check.environmentReady && check.prerequisitesMet;
        
        items.append(item);
    }
    
    if (callback) {
        callback(items);
    }
}

void ClaudeSkillManager::searchSkills(
    const QString &query,
    const QStringList &tags,
    int maxResults,
    ClaudeSkillSearchCallback callback)
{
    SkillSearchResult result;
    result.query = query;
    result.totalCount = m_skills.count();
    
    QString lowerQuery = query.toLower();
    
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        const auto &skill = it.value();
        
        // Check if skill matches query
        bool nameMatch = skill.metadata.name.toLower().contains(lowerQuery);
        bool descMatch = skill.metadata.description.toLower().contains(lowerQuery);
        
        // Check tags
        bool tagsMatch = tags.isEmpty();
        if (!tags.isEmpty()) {
            for (const QString &tag : tags) {
                if (skill.metadata.tags.contains(tag, Qt::CaseInsensitive)) {
                    tagsMatch = true;
                    break;
                }
            }
        }
        
        if ((nameMatch || descMatch) && tagsMatch) {
            SkillListingItem item;
            item.skillId = skill.metadata.skillId;
            item.name = skill.metadata.name;
            item.description = skill.metadata.description;
            item.tags = skill.metadata.tags;
            item.category = skill.metadata.category;
            const SkillAvailabilityCheck check = checkSkillAvailability(it.key());
            item.available = check.platformSupported && check.environmentReady && check.prerequisitesMet;
            
            result.results.append(item);
            
            if (result.results.count() >= maxResults) {
                break;
            }
        }
    }
    
    result.matchedCount = result.results.count();
    
    if (callback) {
        callback(result);
    }
}

void ClaudeSkillManager::getSkillView(
    const QString &skillId,
    ClaudeSkillViewCallback callback)
{
    if (!m_skills.contains(skillId)) {
        return;
    }
    
    const auto &skill = m_skills[skillId];
    
    SkillViewItem view;
    
    // Basic info
    view.basicInfo.skillId = skill.metadata.skillId;
    view.basicInfo.name = skill.metadata.name;
    view.basicInfo.description = skill.metadata.description;
    view.basicInfo.tags = skill.metadata.tags;
    view.basicInfo.category = skill.metadata.category;
    const SkillAvailabilityCheck check = checkSkillAvailability(skillId);
    view.basicInfo.available = check.platformSupported && check.environmentReady && check.prerequisitesMet;
    
    // Complete metadata
    view.version = skill.metadata.version;
    view.author = skill.metadata.author;
    view.maintainer = skill.metadata.maintainer;
    view.licenseId = skill.metadata.licenseId;
    view.deprecated = skill.metadata.deprecated;
    
    // Environment variables
    view.environmentVariables = skill.requiredEnvironmentVariables;
    
    // Prerequisites
    view.prerequisites = skill.prerequisites;
    
    // Related skills
    view.relatedSkills = skill.relatedSkills;
    
    // Markdown content
    view.markdownContent = skill.markdownContent;
    
    if (callback) {
        callback(view);
    }
}

ClaudeSkill ClaudeSkillManager::getSkillWithContent(const QString &skillId)
{
    if (!m_skills.contains(skillId)) {
        return ClaudeSkill();
    }
    
    return m_skills[skillId];
}

QString ClaudeSkillManager::skillInstructions(const QString &skillId) const
{
    const auto it = m_skills.find(skillId);
    if (it == m_skills.end())
        return {};
    return it.value().markdownContent;
}

bool ClaudeSkillManager::areEnvironmentVariablesReady(const QString &skillId)
{
    if (!m_skills.contains(skillId)) {
        return false;
    }
    
    const auto &skill = m_skills[skillId];
    return m_envManager->areAllRequiredVariablesSet(skill);
}

void ClaudeSkillManager::collectEnvironmentVariables(
    const QString &skillId,
    DefaultSkillEnvironmentManager::EnvPromptCallback promptCallback,
    DefaultSkillEnvironmentManager::EnvSecretCallback secretCallback,
    DefaultSkillEnvironmentManager::EnvCollectedCallback resultCallback)
{
    if (!m_skills.contains(skillId)) {
        if (resultCallback) {
            resultCallback(false, "Skill not found");
        }
        return;
    }
    
    const auto &skill = m_skills[skillId];
    m_envManager->collectEnvironmentVariables(
        skill,
        promptCallback,
        secretCallback,
        resultCallback
    );
}

void ClaudeSkillManager::checkAllAvailability(ClaudeSkillAvailabilityCallback callback)
{
    QVector<SkillAvailabilityCheck> results;
    
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        SkillAvailabilityCheck check = checkSkillAvailability(it.key());
        results.append(check);
    }
    
    if (callback) {
        callback(results);
    }
}

SkillAvailabilityCheck ClaudeSkillManager::checkSkillAvailability(const QString &skillId)
{
    SkillAvailabilityCheck check;
    check.skillId = skillId;
    
    if (!m_skills.contains(skillId)) {
        check.platformSupported = false;
        check.platformReason = "Skill not found";
        return check;
    }
    
    const auto &skill = m_skills[skillId];
    
    // Check platform compatibility
    check.platformSupported = skill.metadata.enabled
        && m_discoveryEngine->isPlatformCompatible(skill, m_platform);
    if (!skill.metadata.enabled) {
        check.platformReason = QStringLiteral("Skill disabled");
    } else if (!check.platformSupported) {
        check.platformReason = QString("Not compatible with %1").arg(platformToString(m_platform));
    }
    
    // Check environment variables
    QStringList missing;
    QString envError;
    check.environmentReady = m_envManager->validateEnvironmentVariables(skill, missing, envError);
    check.missingEnvironmentVariables = missing;

    // Check prerequisites
    check.prerequisitesMet = true;
    for (const auto &prereq : skill.prerequisites) {
        if (prereq.type.compare(QStringLiteral("command"), Qt::CaseInsensitive) == 0
            && QStandardPaths::findExecutable(prereq.name).isEmpty()) {
            check.prerequisitesMet = false;
            check.unsatisfiedPrerequisites.append(prereq.name);
        }
    }
    if (!check.prerequisitesMet && check.platformReason.isEmpty()) {
        check.platformReason = QStringLiteral("Missing prerequisite command(s)");
    }
    
    // Cache it
    m_availabilityCache[skillId] = check;
    
    return check;
}

QVector<SkillCapability> ClaudeSkillManager::getAvailableSkills()
{
    QVector<SkillCapability> available;
    
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        SkillAvailabilityCheck check = checkSkillAvailability(it.key());
        
        if (check.platformSupported && check.environmentReady && check.prerequisitesMet) {
            available.append(it.value().capability);
        }
    }
    
    return available;
}

void ClaudeSkillManager::generateSkillContextForLLM(
    int tier,
    int maxSkills,
    const QVariantMap &currentContext,
    ClaudeSkillContextCallback callback)
{
    SkillContextForLLM context;
    
    // Collect available skills
    QVector<ClaudeSkill> availableSkills;
    for (auto it = m_skills.begin(); it != m_skills.end() && availableSkills.count() < maxSkills; ++it) {
        SkillAvailabilityCheck check = checkSkillAvailability(it.key());
        if (check.platformSupported && check.environmentReady) {
            availableSkills.append(it.value());
        }
    }
    
    // Generate appropriate tier context
    switch(tier) {
        case 1:
            context.tier1Context = formatTier1Context(
                [&availableSkills]() {
                    QVector<SkillListingItem> items;
                    for (const auto &skill : availableSkills) {
                        SkillListingItem item;
                        item.skillId = skill.metadata.skillId;
                        item.name = skill.metadata.name;
                        item.description = skill.metadata.description;
                        item.tags = skill.metadata.tags;
                        item.category = skill.metadata.category;
                        items.append(item);
                    }
                    return items;
                }()
            );
            context.contextMarkdown = context.tier1Context;
            context.totalTokens = 50;
            break;
            
        case 2: {
            // Collect Tier 2 data
            QVector<SkillViewItem> viewItems;
            for (const auto &skill : availableSkills) {
                SkillViewItem view;
                view.basicInfo.skillId = skill.metadata.skillId;
                view.basicInfo.name = skill.metadata.name;
                view.basicInfo.description = skill.metadata.description;
                view.basicInfo.tags = skill.metadata.tags;
                view.version = skill.metadata.version;
                view.author = skill.metadata.author;
                viewItems.append(view);
            }
            context.tier2Context = formatTier2Context(viewItems);
            context.contextMarkdown = context.tier2Context;
            context.totalTokens = 500;
            break;
        }
        
        case 3:
        default:
            context.tier3Context = formatTier3Context(availableSkills);
            context.contextMarkdown = context.tier3Context;
            context.totalTokens = 1500;
            break;
    }
    
    if (callback) {
        callback(context);
    }
}

QString ClaudeSkillManager::getSkillsContextMarkdown(int tier, int maxSkills)
{
    QString result;
    
    SkillContextForLLM context;
    generateSkillContextForLLM(tier, maxSkills, QVariantMap(),
        [&context](const SkillContextForLLM &ctx) { context = ctx; });
    
    return context.contextMarkdown;
}

void ClaudeSkillManager::executeSkill(
    const SkillExecutionRequest &request,
    ClaudeSkillExecutionCallback callback)
{
    // This would execute the skill - for now, return placeholder
    SkillExecutionResult result;
    result.skillId = request.skillId;
    result.executionId = request.executionId;
    result.success = false;
    result.errorMessage = "Skill execution not yet implemented";
    
    if (callback) {
        callback(result);
    }
}

void ClaudeSkillManager::refresh(std::function<void(int count, const QString &error)> callback)
{
    m_discoveryEngine->clearCache();

    m_skills.clear();
    QStringList errors;
    const QStringList roots = skillDiscoveryRoots(m_skillsDirectory);
    for (const QString &root : roots) {
        m_discoveryEngine->discoverSkills(
            root,
            m_platform,
            true,
            [this, &errors](const QVector<ClaudeSkill> &skills, const QString &error) {
                for (const auto &skill : skills) {
                    const QString id = skill.metadata.skillId.isEmpty()
                        ? skill.filePath
                        : skill.metadata.skillId;
                    m_skills[id] = skill;
                }
                if (!error.isEmpty())
                    errors.append(error);
            }
        );
    }

    qDebug() << "Refreshed: discovered" << m_skills.count() << "skills";
    emit skillsDiscovered(m_skills.count());
    if (callback) {
        callback(m_skills.count(), errors.join(QStringLiteral("\n")));
    }
}

void ClaudeSkillManager::checkForModifications()
{
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        auto &skill = it.value();
        m_discoveryEngine->reloadSkillIfModified(skill, m_platform);
        
        if (skill.isModified) {
            emit skillModified(skill.metadata.skillId);
            skill.isModified = false;
        }
    }
}

ClaudeSkill ClaudeSkillManager::getSkill(const QString &skillId) const
{
    if (m_skills.contains(skillId)) {
        return m_skills[skillId];
    }
    return ClaudeSkill();
}

QVector<ClaudeSkill> ClaudeSkillManager::getAllSkills() const
{
    return m_skills.values().toVector();
}

int ClaudeSkillManager::getSkillCount() const
{
    return m_skills.count();
}

QVector<ClaudeSkill> ClaudeSkillManager::getSkillsByCategory(const QString &category) const
{
    QVector<ClaudeSkill> result;
    
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        if (it.value().metadata.category == category) {
            result.append(it.value());
        }
    }
    
    return result;
}

QVector<ClaudeSkill> ClaudeSkillManager::getSkillsByTag(const QString &tag) const
{
    QVector<ClaudeSkill> result;
    
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        if (it.value().metadata.tags.contains(tag, Qt::CaseInsensitive)) {
            result.append(it.value());
        }
    }
    
    return result;
}

QVariantMap ClaudeSkillManager::getStatistics() const
{
    QVariantMap stats;
    stats["totalSkills"] = m_skills.count();
    stats["platform"] = platformToString(m_platform);
    
    int available = 0;
    for (auto it = m_skills.begin(); it != m_skills.end(); ++it) {
        if (m_availabilityCache.contains(it.key())) {
            const auto &check = m_availabilityCache[it.key()];
            if (check.platformSupported && check.environmentReady) {
                available++;
            }
        }
    }
    stats["availableSkills"] = available;
    
    return stats;
}

QString ClaudeSkillManager::formatTier1Context(const QVector<SkillListingItem> &skills) const
{
    QString result = "# Available Skills\n\n";
    
    for (const auto &skill : skills) {
        result += QString("- **%1**: %2\n").arg(skill.name, skill.description);
    }
    
    return result;
}

QString ClaudeSkillManager::formatTier2Context(const QVector<SkillViewItem> &skills) const
{
    QString result = "# Skills Reference\n\n";
    
    for (const auto &skill : skills) {
        result += QString("## %1\n\n").arg(skill.basicInfo.name);
        result += QString("**Description**: %1\n\n").arg(skill.basicInfo.description);
        
        if (!skill.version.isEmpty()) {
            result += QString("**Version**: %1\n\n").arg(skill.version);
        }
        
        if (!skill.author.isEmpty()) {
            result += QString("**Author**: %1\n\n").arg(skill.author);
        }
        
        if (!skill.environmentVariables.isEmpty()) {
            result += "**Environment Variables**:\n";
            for (const auto &env : skill.environmentVariables) {
                result += QString("- `%1`: %2\n").arg(env.name, env.help);
            }
            result += "\n";
        }
    }
    
    return result;
}

QString ClaudeSkillManager::formatTier3Context(const QVector<ClaudeSkill> &skills) const
{
    QString result = "# Skills - Complete Reference\n\n";
    
    for (const auto &skill : skills) {
        result += QString("## %1\n\n").arg(skill.metadata.name);
        result += QString("%1\n\n").arg(skill.metadata.description);
        
        if (!skill.markdownContent.isEmpty()) {
            result += skill.markdownContent;
        }
        
        result += "\n---\n\n";
    }
    
    return result;
}
