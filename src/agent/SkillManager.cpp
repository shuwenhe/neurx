#include "agent/SkillManager.h"
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStringList>
#include <algorithm>

namespace {

static QString trimMarkdownFence(const QString &text)
{
    QString value = text.trimmed();
    if ((value.startsWith('"') && value.endsWith('"'))
        || (value.startsWith('\'') && value.endsWith('\''))) {
        value = value.mid(1, value.size() - 2);
    }
    return value.trimmed();
}

static QVariant parseScalarValue(const QString &value)
{
    const QString trimmed = trimMarkdownFence(value);
    if (trimmed.compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0)
        return true;
    if (trimmed.compare(QStringLiteral("false"), Qt::CaseInsensitive) == 0)
        return false;

    bool okInt = false;
    const int intValue = trimmed.toInt(&okInt);
    if (okInt)
        return intValue;

    bool okDouble = false;
    const double doubleValue = trimmed.toDouble(&okDouble);
    if (okDouble)
        return doubleValue;

    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        QVariantList list;
        const QString inner = trimmed.mid(1, trimmed.size() - 2).trimmed();
        for (const QString &part : inner.split(',', Qt::SkipEmptyParts))
            list.append(trimMarkdownFence(part));
        return list;
    }

    return trimmed;
}

static QStringList toStringList(const QVariant &value)
{
    QStringList out;
    if (!value.isValid())
        return out;

    if (value.typeId() == QMetaType::QStringList) {
        out = value.toStringList();
        return out;
    }

    if (value.canConvert<QVariantList>()) {
        const QVariantList list = value.toList();
        for (const QVariant &item : list)
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
            out.append(trimMarkdownFence(part));
        out.removeAll({});
        return out;
    }

    if (raw.contains(',')) {
        for (const QString &part : raw.split(',', Qt::SkipEmptyParts))
            out.append(trimMarkdownFence(part));
        out.removeAll({});
        return out;
    }

    out.append(trimMarkdownFence(raw));
    return out;
}

static QString firstMarkdownHeading(const QString &body)
{
    const QStringList lines = body.split(QRegularExpression(QStringLiteral("\\r?\\n")));
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (trimmed.startsWith(QStringLiteral("# ")))
            return trimmed.mid(2).trimmed();
    }
    return {};
}

static QString firstParagraphPreview(const QString &body)
{
    const QStringList lines = body.split(QRegularExpression(QStringLiteral("\\r?\\n")));
    QStringList paragraph;
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty()) {
            if (!paragraph.isEmpty())
                break;
            continue;
        }
        if (trimmed.startsWith(QStringLiteral("# ")))
            continue;
        if (trimmed.startsWith(QStringLiteral("```")))
            continue;
        paragraph.append(trimmed);
        if (paragraph.join(' ').size() > 220)
            break;
    }
    return paragraph.join(' ').left(240).trimmed();
}

static QVariantMap parseFrontmatterBlock(const QString &content, QString *bodyOut)
{
    QVariantMap frontmatter;
    const QStringList lines = content.split(QRegularExpression(QStringLiteral("\\r?\\n")));
    if (lines.isEmpty() || lines.first().trimmed() != QStringLiteral("---")) {
        if (bodyOut)
            *bodyOut = content;
        return frontmatter;
    }

    int closingIndex = -1;
    for (int i = 1; i < lines.size(); ++i) {
        if (lines.at(i).trimmed() == QStringLiteral("---")) {
            closingIndex = i;
            break;
        }
    }

    if (closingIndex < 0) {
        if (bodyOut)
            *bodyOut = content;
        return frontmatter;
    }

    for (int i = 1; i < closingIndex; ++i) {
        const QString line = lines.at(i).trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;

        const int colon = line.indexOf(':');
        if (colon <= 0)
            continue;

        const QString key = line.left(colon).trimmed();
        const QString value = line.mid(colon + 1).trimmed();
        if (key.isEmpty())
            continue;

        frontmatter.insert(key, parseScalarValue(value));
    }

    QStringList bodyLines;
    for (int i = closingIndex + 1; i < lines.size(); ++i)
        bodyLines.append(lines.at(i));
    if (bodyOut)
        *bodyOut = bodyLines.join(QStringLiteral("\n")).trimmed();
    return frontmatter;
}

static QStringList skillRootsForWorkspace(const QString &workspacePath)
{
    QStringList roots;
    const auto addRoot = [&roots](const QString &path) {
        const QString absolute = QDir(path).absolutePath();
        if (!absolute.isEmpty() && QFileInfo::exists(absolute) && !roots.contains(absolute))
            roots.append(absolute);
    };

    if (!workspacePath.trimmed().isEmpty()) {
        const QString root = QFileInfo(workspacePath).absoluteFilePath();
        addRoot(QDir(root).filePath(QStringLiteral(".claude/skills")));
        addRoot(QDir(root).filePath(QStringLiteral(".neurx/skills")));
        addRoot(QDir(root).filePath(QStringLiteral(".agents/skills")));
        addRoot(QDir(root).filePath(QStringLiteral("skills")));
    }

    const QString home = QDir::homePath();
    addRoot(QDir(home).filePath(QStringLiteral(".claude/skills")));
    addRoot(QDir(home).filePath(QStringLiteral(".neurx/skills")));

    return roots;
}

static QString skillIdentifierForPath(const QString &skillPath)
{
    const QFileInfo info(skillPath);
    const QFileInfo parent(info.dir().absolutePath());
    const QString dirName = parent.fileName();
    if (!dirName.isEmpty())
        return dirName;
    return info.baseName();
}

} // namespace

SkillManager::SkillManager(QObject *parent) : QObject(parent) {}

void SkillManager::scanWorkspace(const QString &workspacePath)
{
    m_skills.clear();

    QSet<QString> seenPaths;
    const QStringList roots = skillRootsForWorkspace(workspacePath);
    for (const QString &root : roots) {
        QDirIterator it(root, QStringList{QStringLiteral("SKILL.md")}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString skillPath = QFileInfo(it.next()).absoluteFilePath();
            if (skillPath.isEmpty() || seenPaths.contains(skillPath))
                continue;
            seenPaths.insert(skillPath);
            loadSkill(skillPath);
        }
    }

    std::sort(m_skills.begin(), m_skills.end(), [](const Skill &a, const Skill &b) {
        const QString aKey = !a.title.isEmpty() ? a.title.toLower() : a.id.toLower();
        const QString bKey = !b.title.isEmpty() ? b.title.toLower() : b.id.toLower();
        if (aKey == bKey)
            return a.id.toLower() < b.id.toLower();
        return aKey < bKey;
    });

    emit skillsChanged();
}

void SkillManager::loadSkill(const QString &skillPath)
{
    QFile file(skillPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning().noquote() << "[SkillManager] Failed to open skill:" << skillPath;
        return;
    }

    const QString content = QString::fromUtf8(file.readAll());
    QString body;
    const QVariantMap frontmatter = parseFrontmatterBlock(content, &body);

    Skill skill;
    skill.sourcePath = QFileInfo(skillPath).absoluteFilePath();
    skill.sourceDirectory = QFileInfo(skillPath).dir().absolutePath();
    skill.id = frontmatter.value(QStringLiteral("id")).toString().trimmed();
    if (skill.id.isEmpty())
        skill.id = skillIdentifierForPath(skillPath);

    skill.title = frontmatter.value(QStringLiteral("name")).toString().trimmed();
    if (skill.title.isEmpty())
        skill.title = frontmatter.value(QStringLiteral("title")).toString().trimmed();
    if (skill.title.isEmpty())
        skill.title = firstMarkdownHeading(body);
    if (skill.title.isEmpty())
        skill.title = skill.id;

    skill.description = frontmatter.value(QStringLiteral("description")).toString().trimmed();
    if (skill.description.isEmpty())
        skill.description = firstParagraphPreview(body);

    skill.systemInstructions = body.trimmed();

    skill.requiredTools = toStringList(frontmatter.value(QStringLiteral("tools")));
    if (skill.requiredTools.isEmpty())
        skill.requiredTools = toStringList(frontmatter.value(QStringLiteral("required_tools")));

    skill.tags = toStringList(frontmatter.value(QStringLiteral("tags")));
    skill.aliases = toStringList(frontmatter.value(QStringLiteral("aliases")));

    skill.active = true;
    if (frontmatter.contains(QStringLiteral("active")))
        skill.active = frontmatter.value(QStringLiteral("active")).toBool();
    if (frontmatter.contains(QStringLiteral("enabled")))
        skill.active = skill.active && frontmatter.value(QStringLiteral("enabled")).toBool();

    const bool disabledForModel = frontmatter.value(QStringLiteral("disable-model-invocation")).toBool()
        || frontmatter.value(QStringLiteral("disable_model_invocation")).toBool();
    skill.active = skill.active && !disabledForModel;

    skill.metadata = frontmatter;

    if (skill.systemInstructions.isEmpty()) {
        skill.systemInstructions = QStringLiteral("No instructions were provided in SKILL.md.");
    }

    m_skills.append(skill);
    qInfo().noquote() << "[SkillManager] Loaded skill:"
                      << skill.title << "(" << skill.id << ") from" << skill.sourcePath;
}

QList<Skill> SkillManager::activeSkills() const
{
    QList<Skill> active;
    for (const Skill &skill : m_skills) {
        if (skill.active)
            active.append(skill);
    }
    return active;
}

Skill SkillManager::skillById(const QString &skillId) const
{
    for (const Skill &skill : m_skills) {
        if (skill.id.compare(skillId, Qt::CaseInsensitive) == 0)
            return skill;
        if (skill.title.compare(skillId, Qt::CaseInsensitive) == 0)
            return skill;
        if (skill.aliases.contains(skillId, Qt::CaseInsensitive))
            return skill;
    }
    return {};
}

QString SkillManager::skillInstructions(const QString &skillId) const
{
    const Skill skill = skillById(skillId);
    return skill.id.isEmpty() ? QString{} : skill.systemInstructions;
}

QString SkillManager::buildSystemPromptExtension() const
{
    const QList<Skill> skills = activeSkills();
    if (skills.isEmpty())
        return {};

    QString prompt = QStringLiteral(
        "\n\n=== AVAILABLE SKILLS ===\n"
        "These are workspace or user-installed Claude-style skills.\n"
        "Use a skill when the task clearly matches its purpose.\n"
        "If a skill is relevant, follow its SKILL.md instructions before acting.\n");

    for (const Skill &skill : skills) {
        QString line = QStringLiteral("- %1 (%2)").arg(skill.title, skill.id);
        if (!skill.description.isEmpty())
            line += QStringLiteral(": %1").arg(skill.description);
        if (!skill.requiredTools.isEmpty())
            line += QStringLiteral(" [tools: %1]").arg(skill.requiredTools.join(QStringLiteral(", ")));
        prompt += line + QStringLiteral("\n");
    }

    prompt += QStringLiteral(
        "\nWhen a skill is clearly the right fit, mention it explicitly in your plan and use its instructions.\n");
    return prompt;
}

QVariantList SkillManager::skillsModel() const
{
    QVariantList list;
    for (const Skill &skill : m_skills)
        list.append(skill.toMap());
    return list;
}
