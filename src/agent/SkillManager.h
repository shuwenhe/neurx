#pragma once
#include "agent/Skill.h"
#include <QObject>
#include <QList>
#include <QDir>

class SkillManager : public QObject {
    Q_OBJECT
public:
    explicit SkillManager(QObject *parent = nullptr);

    void scanWorkspace(const QString &workspacePath);
    void loadSkill(const QString &path);

    QList<Skill> activeSkills() const;
    Skill skillById(const QString &skillId) const;
    QString skillInstructions(const QString &skillId) const;
    QString buildSystemPromptExtension() const;

    QVariantList skillsModel() const;

signals:
    void skillsChanged();

private:
    QList<Skill> m_skills;
};
