#include "SkillDiscoveryEngine.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QCryptographicHash>
#include <QMetaType>
#include <QRegularExpression>
#include <QDirIterator>
#include <QThread>
#include <QDebug>

namespace {

static int leadingSpaces(const QString &line)
{
    int count = 0;
    while (count < line.size() && line.at(count).isSpace())
        ++count;
    return count;
}

static bool isTopLevelKeyLine(const QString &line)
{
    const QString trimmed = line.trimmed();
    return !trimmed.isEmpty() && !line.startsWith(' ') && trimmed.contains(':') && !trimmed.startsWith('-');
}

static QString unquote(const QString &value)
{
    QString out = value.trimmed();
    if ((out.startsWith('"') && out.endsWith('"'))
        || (out.startsWith('\'') && out.endsWith('\''))) {
        out = out.mid(1, out.size() - 2);
    }
    return out.trimmed();
}

static QStringList parseScalarList(const QVariant &value)
{
    QStringList out;
    if (!value.isValid())
        return out;

    if (value.typeId() == QMetaType::QStringList) {
        out = value.toStringList();
        out.removeAll({});
        return out;
    }

    if (value.canConvert<QVariantList>()) {
        for (const QVariant &item : value.toList())
            out.append(item.toString().trimmed());
        out.removeAll({});
        return out;
    }

    const QString raw = value.toString().trimmed();
    if (raw.isEmpty())
        return out;
    if (raw.startsWith('[') && raw.endsWith(']')) {
        const QString inner = raw.mid(1, raw.size() - 2);
        for (const QString &part : inner.split(',', Qt::SkipEmptyParts))
            out.append(unquote(part));
    } else if (raw.contains(',')) {
        for (const QString &part : raw.split(',', Qt::SkipEmptyParts))
            out.append(unquote(part));
    } else {
        out.append(unquote(raw));
    }
    out.removeAll({});
    return out;
}

static QVariantMap parseListItemBlock(const QStringList &lines, int &index)
{
    QVariantMap item;
    const int itemIndent = leadingSpaces(lines.at(index));
    QString currentKey;

    auto flushLine = [&](const QString &line) {
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty() || trimmed.startsWith('#'))
            return;
        const int colon = trimmed.indexOf(':');
        if (colon <= 0)
            return;
        currentKey = trimmed.left(colon).trimmed();
        item[currentKey] = unquote(trimmed.mid(colon + 1).trimmed());
    };

    flushLine(lines.at(index).mid(lines.at(index).indexOf('-') + 1));
    ++index;

    while (index < lines.size()) {
        const QString line = lines.at(index);
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty()) {
            ++index;
            continue;
        }
        if (isTopLevelKeyLine(line) || (leadingSpaces(line) <= itemIndent && trimmed.startsWith('-')))
            break;
        if (trimmed.startsWith('-') && leadingSpaces(line) >= itemIndent) {
            break;
        }

        const int colon = trimmed.indexOf(':');
        if (colon > 0 && leadingSpaces(line) > itemIndent) {
            const QString key = trimmed.left(colon).trimmed();
            const QString value = unquote(trimmed.mid(colon + 1).trimmed());
            item[key] = value;
        }
        ++index;
    }

    return item;
}

static QVector<EnvironmentVariableDef> parseEnvironmentVariableList(const QStringList &lines, int &index)
{
    QVector<EnvironmentVariableDef> vars;
    const int baseIndent = leadingSpaces(lines.at(index));
    ++index;

    while (index < lines.size()) {
        const QString line = lines.at(index);
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty()) {
            ++index;
            continue;
        }
        if (isTopLevelKeyLine(line) && leadingSpaces(line) <= baseIndent)
            break;
        if (trimmed.startsWith('-') && leadingSpaces(line) >= baseIndent) {
            QVariantMap item = parseListItemBlock(lines, index);
            EnvironmentVariableDef def;
            def.name = item.value(QStringLiteral("name")).toString();
            def.prompt = item.value(QStringLiteral("prompt")).toString();
            def.help = item.value(QStringLiteral("help")).toString();
            def.defaultValue = item.value(QStringLiteral("default")).toString();
            def.required = item.value(QStringLiteral("required"), false).toBool();
            def.secret = item.value(QStringLiteral("secret"), false).toBool();
            def.pattern = item.value(QStringLiteral("pattern")).toString();
            vars.append(def);
            continue;
        }
        if (leadingSpaces(line) <= baseIndent)
            break;
        ++index;
    }
    return vars;
}

static QVector<Prerequisite> parsePrerequisiteList(const QStringList &lines, int &index)
{
    QVector<Prerequisite> items;
    const int baseIndent = leadingSpaces(lines.at(index));
    ++index;

    while (index < lines.size()) {
        const QString line = lines.at(index);
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty()) {
            ++index;
            continue;
        }
        if (isTopLevelKeyLine(line) && leadingSpaces(line) <= baseIndent)
            break;
        if (trimmed.startsWith('-') && leadingSpaces(line) >= baseIndent) {
            QVariantMap item = parseListItemBlock(lines, index);
            Prerequisite prereq;
            prereq.type = item.value(QStringLiteral("type")).toString();
            prereq.name = item.value(QStringLiteral("name")).toString();
            prereq.version = item.value(QStringLiteral("version")).toString();
            prereq.installCommand = item.value(QStringLiteral("installCommand")).toString();
            prereq.checkCommand = item.value(QStringLiteral("checkCommand")).toString();
            items.append(prereq);
            continue;
        }
        if (leadingSpaces(line) <= baseIndent)
            break;
        ++index;
    }
    return items;
}

static QStringList parseStringListSection(const QStringList &lines, const QString &sectionKey)
{
    for (int i = 0; i < lines.size(); ++i) {
        const QString line = lines.at(i);
        const QString trimmed = line.trimmed();
        if (!trimmed.startsWith(sectionKey + QStringLiteral(":")))
            continue;

        const QString inlineValue = trimmed.mid(sectionKey.size() + 1).trimmed();
        if (!inlineValue.isEmpty())
            return parseScalarList(inlineValue);

        const int baseIndent = leadingSpaces(line);
        QStringList values;
        for (int j = i + 1; j < lines.size(); ++j) {
            const QString nextLine = lines.at(j);
            const QString nextTrimmed = nextLine.trimmed();
            if (nextTrimmed.isEmpty())
                continue;
            if (isTopLevelKeyLine(nextLine) && leadingSpaces(nextLine) <= baseIndent)
                break;
            if (nextTrimmed.startsWith('-')) {
                values.append(unquote(nextTrimmed.mid(1).trimmed()));
            }
        }
        return values;
    }
    return {};
}

} // namespace

DefaultSkillDiscoveryEngine::DefaultSkillDiscoveryEngine()
{
}

void DefaultSkillDiscoveryEngine::discoverSkills(
    const QString &baseDirectory,
    const Platform &currentPlatform,
    bool recursive,
    DiscoveryCallback callback)
{
    QStringList skillFiles = findSkillFiles(baseDirectory, recursive);
    QVector<ClaudeSkill> skills;
    QString error;
    
    for (const QString &filePath : skillFiles) {
        try {
            ClaudeSkill skill = loadSkill(filePath, currentPlatform);
            
            // Filter by platform
            if (isPlatformCompatible(skill, currentPlatform)) {
                skills.append(skill);
            }
        } catch (const std::exception &e) {
            qWarning() << "Failed to load skill from" << filePath << ":" << e.what();
            error += QString("Failed to load %1: %2\n").arg(filePath, e.what());
        }
    }
    
    callback(skills, error);
}

void DefaultSkillDiscoveryEngine::discoverSkillsAsync(
    const QString &baseDirectory,
    const Platform &currentPlatform,
    bool recursive,
    DiscoveryCallback callback)
{
    // Run discovery in a separate thread
    QThread *thread = QThread::create([=]() {
        discoverSkills(baseDirectory, currentPlatform, recursive, callback);
    });
    
    thread->start();
    // Thread will delete itself when finished
    QObject::connect(thread, &QThread::finished, thread, &QThread::deleteLater);
}

ClaudeSkill DefaultSkillDiscoveryEngine::loadSkill(const QString &filePath, const Platform &platform)
{
    // Check cache first
    if (m_skillCache.contains(filePath)) {
        ClaudeSkill cached = m_skillCache[filePath];
        // Check if file was modified
        QFileInfo info(filePath);
        if (info.exists() && m_fileModificationTimes.contains(filePath)) {
            QDateTime lastMod = m_fileModificationTimes[filePath];
            if (lastMod == info.lastModified()) {
                return cached; // Cache is still valid
            }
        }
    }
    
    // Load from file
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        throw std::runtime_error(QString("Cannot open file: %1").arg(filePath).toStdString());
    }
    
    QString fileContent = QString::fromUtf8(file.readAll());
    file.close();
    
    // Extract and parse YAML frontmatter
    QString yamlContent, bodyContent;
    if (!extractYamlFrontmatter(fileContent, yamlContent, bodyContent)) {
        throw std::runtime_error(QString("Invalid frontmatter in %1").arg(filePath).toStdString());
    }
    
    // Parse YAML
    ClaudeSkillMetadata metadata = parseYamlFrontmatter(yamlContent);
    
    // Validate metadata
    QStringList validationErrors = validateSkillMetadata(metadata);
    if (!validationErrors.isEmpty()) {
        throw std::runtime_error(QString("Metadata validation failed: %1").arg(validationErrors.join(", ")).toStdString());
    }
    
    // Build skill object
    ClaudeSkill skill;
    skill.metadata = metadata;
    skill.markdownContent = bodyContent;
    skill.metadata.documentation = bodyContent;
    skill.filePath = filePath;
    skill.discoveredAt = QDateTime::currentDateTime();

    const QStringList yamlLines = yamlContent.split(QRegularExpression(QStringLiteral("\\r?\\n")));
    for (int i = 0; i < yamlLines.size(); ++i) {
        const QString trimmed = yamlLines.at(i).trimmed();
        if (trimmed.startsWith(QStringLiteral("required_environment_variables:"))) {
            skill.requiredEnvironmentVariables = parseEnvironmentVariableList(yamlLines, i);
            continue;
        }
        if (trimmed.startsWith(QStringLiteral("prerequisites:"))) {
            skill.prerequisites = parsePrerequisiteList(yamlLines, i);
            continue;
        }
    }

    skill.relatedSkills = parseStringListSection(yamlLines, QStringLiteral("related_skills"));
    skill.linkedTools = parseStringListSection(yamlLines, QStringLiteral("linked_tools"));
    if (skill.linkedTools.isEmpty())
        skill.linkedTools = parseStringListSection(yamlLines, QStringLiteral("tools"));

    skill.capability.skillId = skill.metadata.skillId;
    skill.capability.name = skill.metadata.name;
    skill.capability.description = skill.metadata.description;
    
    // Parse markdown body for additional information
    QFileInfo fileInfo(filePath);
    skill.modifiedAt = fileInfo.lastModified();
    
    // Calculate checksum
    skill.checksum = calculateChecksum(filePath);
    
    // Cache it
    m_skillCache[filePath] = skill;
    m_fileModificationTimes[filePath] = skill.modifiedAt;
    
    return skill;
}

void DefaultSkillDiscoveryEngine::reloadSkillIfModified(ClaudeSkill &skill, const Platform &platform)
{
    QFileInfo info(skill.filePath);
    if (!info.exists()) {
        return;
    }
    
    if (info.lastModified() != skill.modifiedAt) {
        skill = loadSkill(skill.filePath, platform);
        skill.isModified = true;
    }
}

ClaudeSkillMetadata DefaultSkillDiscoveryEngine::parseYamlFrontmatter(const QString &fileContent)
{
    QString yamlContent, bodyContent;
    if (!extractYamlFrontmatter(fileContent, yamlContent, bodyContent)) {
        return ClaudeSkillMetadata();
    }
    
    QMap<QString, QVariant> yamlMap = parseYamlMap(yamlContent);
    const QStringList lines = yamlContent.split(QRegularExpression(QStringLiteral("\\r?\\n")));
    
    ClaudeSkillMetadata metadata;
    
    // Parse core fields
    metadata.skillId = yamlMap.value("name", "").toString();
    metadata.name = yamlMap.value("name", "").toString();
    metadata.description = yamlMap.value("description", "").toString();
    metadata.version = yamlMap.value("version", "1.0.0").toString();
    metadata.author = yamlMap.value("author", "").toString();
    metadata.maintainer = yamlMap.value("maintainer", "").toString();
    metadata.category = yamlMap.value("category", "").toString();
    metadata.licenseId = yamlMap.value("license", "").toString();
    metadata.enabled = yamlMap.value("enabled", true).toBool();
    metadata.deprecated = yamlMap.value("deprecated", false).toBool();
    metadata.deprecationMessage = yamlMap.value("deprecation_message", "").toString();
    
    // Parse platforms
    metadata.platforms = parseStringListSection(lines, QStringLiteral("platforms"));
    if (metadata.platforms.isEmpty())
        metadata.platforms = parseScalarList(yamlMap.value(QStringLiteral("platforms")));
    
    // Parse tags and keywords
    metadata.tags = parseStringListSection(lines, QStringLiteral("tags"));
    if (metadata.tags.isEmpty())
        metadata.tags = parseScalarList(yamlMap.value(QStringLiteral("tags")));
    
    metadata.keywords = parseStringListSection(lines, QStringLiteral("keywords"));
    if (metadata.keywords.isEmpty())
        metadata.keywords = parseScalarList(yamlMap.value(QStringLiteral("keywords")));

    // Parse nested sections that describe the actual skill requirements.
    for (int i = 0; i < lines.size(); ++i) {
        const QString trimmed = lines.at(i).trimmed();
    }
    
    return metadata;
}

QString DefaultSkillDiscoveryEngine::parseMarkdownBody(const QString &fileContent)
{
    QString yamlContent, bodyContent;
    if (extractYamlFrontmatter(fileContent, yamlContent, bodyContent)) {
        return bodyContent;
    }
    return fileContent; // Return as-is if no frontmatter
}

bool DefaultSkillDiscoveryEngine::isPlatformCompatible(const ClaudeSkill &skill, const Platform &platform)
{
    if (skill.metadata.platforms.isEmpty()) {
        return true; // No platform restriction
    }
    
    QString platformStr = platformToString(platform);
    
    for (const QString &supported : skill.metadata.platforms) {
        if (supported.toLower() == platformStr.toLower() || supported.toLower() == "any") {
            return true;
        }
    }
    
    return false;
}

QStringList DefaultSkillDiscoveryEngine::validateSkillMetadata(const ClaudeSkillMetadata &metadata)
{
    QStringList errors;
    
    // Required fields
    if (metadata.skillId.isEmpty()) {
        errors << "Missing required field: name (skill ID)";
    }
    
    if (metadata.description.isEmpty()) {
        errors << "Missing required field: description";
    }
    
    if (metadata.skillId.length() > 64) {
        errors << "Skill ID exceeds maximum length (64 characters)";
    }
    
    if (metadata.description.length() > 1024) {
        errors << "Description exceeds maximum length (1024 characters)";
    }
    
    // Version format
    QRegularExpression versionRegex("^(\\d+)\\.(\\d+)\\.(\\d+)");
    if (!versionRegex.match(metadata.version).hasMatch()) {
        errors << "Invalid version format (must be semantic: X.Y.Z)";
    }
    
    return errors;
}

void DefaultSkillDiscoveryEngine::clearCache()
{
    m_skillCache.clear();
    m_fileModificationTimes.clear();
}

QVariantMap DefaultSkillDiscoveryEngine::getCacheStats() const
{
    QVariantMap stats;
    stats["cachedSkills"] = m_skillCache.count();
    return stats;
}

QStringList DefaultSkillDiscoveryEngine::findSkillFiles(const QString &baseDirectory, bool recursive) const
{
    QStringList skillFiles;
    QDir dir(baseDirectory);
    
    if (!dir.exists()) {
        qWarning() << "Skills directory does not exist:" << baseDirectory;
        return skillFiles;
    }
    
    if (recursive) {
        QDirIterator it(baseDirectory, QStringList() << "SKILL.md", QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            skillFiles << it.next();
        }
    } else {
        QStringList filters;
        filters << "SKILL.md";
        QStringList files = dir.entryList(filters, QDir::Files);
        
        for (const QString &file : files) {
            skillFiles << dir.absoluteFilePath(file);
        }
    }
    
    return skillFiles;
}

bool DefaultSkillDiscoveryEngine::extractYamlFrontmatter(const QString &fileContent,
                                                        QString &yamlContent,
                                                        QString &bodyContent) const
{
    QStringList lines = fileContent.split("\n");
    
    if (lines.isEmpty() || !lines[0].startsWith("---")) {
        return false; // No frontmatter
    }
    
    int frontmatterEnd = -1;
    for (int i = 1; i < lines.count(); ++i) {
        if (lines[i].trimmed() == "---") {
            frontmatterEnd = i;
            break;
        }
    }
    
    if (frontmatterEnd == -1) {
        return false; // Frontmatter not closed
    }
    
    // Extract YAML content (skip first and closing ---)
    yamlContent = lines.mid(1, frontmatterEnd - 1).join("\n");
    
    // Extract body content (after closing ---)
    bodyContent = lines.mid(frontmatterEnd + 1).join("\n").trimmed();
    
    return true;
}

QMap<QString, QVariant> DefaultSkillDiscoveryEngine::parseYamlMap(const QString &yamlContent) const
{
    QMap<QString, QVariant> result;
    QStringList lines = yamlContent.split("\n");
    
    for (const QString &line : lines) {
        if (line.trimmed().isEmpty() || line.trimmed().startsWith("#")) {
            continue;
        }
        
        int colonPos = line.indexOf(":");
        if (colonPos > 0) {
            QString key = line.left(colonPos).trimmed();
            QString value = line.mid(colonPos + 1).trimmed();
            
            // Remove quotes if present
            if ((value.startsWith("\"") && value.endsWith("\"")) ||
                (value.startsWith("'") && value.endsWith("'"))) {
                value = value.mid(1, value.length() - 2);
            }
            
            // Handle special values
            if (value == "true") {
                result[key] = true;
            } else if (value == "false") {
                result[key] = false;
            } else {
                result[key] = value;
            }
        }
    }
    
    return result;
}

QVector<EnvironmentVariableDef> DefaultSkillDiscoveryEngine::parseEnvironmentVariables(const QVariant &yamlVar) const
{
    QVector<EnvironmentVariableDef> result;
    if (!yamlVar.isValid())
        return result;

    const QVariantList list = yamlVar.toList();
    for (const QVariant &item : list) {
        const QVariantMap map = item.toMap();
        EnvironmentVariableDef def;
        def.name = map.value(QStringLiteral("name")).toString();
        def.prompt = map.value(QStringLiteral("prompt")).toString();
        def.help = map.value(QStringLiteral("help")).toString();
        def.defaultValue = map.value(QStringLiteral("default")).toString();
        def.required = map.value(QStringLiteral("required"), false).toBool();
        def.secret = map.value(QStringLiteral("secret"), false).toBool();
        def.pattern = map.value(QStringLiteral("pattern")).toString();
        if (!def.name.isEmpty())
            result.append(def);
    }

    return result;
}

QVector<Prerequisite> DefaultSkillDiscoveryEngine::parsePrerequisites(const QVariant &yamlVar) const
{
    QVector<Prerequisite> result;
    if (!yamlVar.isValid())
        return result;

    const QVariantList list = yamlVar.toList();
    for (const QVariant &item : list) {
        const QVariantMap map = item.toMap();
        Prerequisite prereq;
        prereq.type = map.value(QStringLiteral("type")).toString();
        prereq.name = map.value(QStringLiteral("name")).toString();
        prereq.version = map.value(QStringLiteral("version")).toString();
        prereq.installCommand = map.value(QStringLiteral("installCommand")).toString();
        prereq.checkCommand = map.value(QStringLiteral("checkCommand")).toString();
        if (!prereq.name.isEmpty() || !prereq.type.isEmpty())
            result.append(prereq);
    }

    return result;
}

QString DefaultSkillDiscoveryEngine::calculateChecksum(const QString &filePath) const
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return "";
    }
    
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(&file);
    file.close();
    
    return hash.result().toHex();
}
