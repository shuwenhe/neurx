#include "tools/NeurxSkillCreatorTool.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QJsonDocument>
#include <QDebug>

NeurxSkillCreatorTool::NeurxSkillCreatorTool(ClaudeSkillManager *manager, const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_manager(manager)
    , m_workspaceRoot(workspaceRoot)
{
}

QJsonObject NeurxSkillCreatorTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "skill_name": {
                "type": "string",
                "description": "Name of the skill in kebab-case (e.g., 'python-expert')"
            },
            "path": {
                "type": "string",
                "description": "Base path where the skill should be created (relative to workspace root, default: 'skills')"
            }
        },
        "required": ["skill_name"]
    })JSON").object();
}

ToolResult NeurxSkillCreatorTool::execute(const QString &callId, const QJsonObject &args)
{
    QString skillName = args.value("skill_name").toString();
    QString relPath = args.value("path").toString("skills");

    if (skillName.isEmpty()) {
        return {callId, name(), true, "Error: skill_name is required"};
    }

    // Prevent path traversal in skill name
    if (skillName.contains('/') || skillName.contains('\\') || skillName.contains("..")) {
        return {callId, name(), true, "Error: Invalid skill name (cannot contain path separators)"};
    }

    QDir root(m_workspaceRoot);
    QString skillDirPath = QDir::cleanPath(root.absoluteFilePath(relPath + "/" + skillName));

    if (!skillDirPath.startsWith(QDir::cleanPath(m_workspaceRoot))) {
        return {callId, name(), true, "Error: Target path must be within the workspace root"};
    }

    QDir skillDir(skillDirPath);
    if (skillDir.exists()) {
        return {callId, name(), true, "Error: Skill directory already exists: " + skillDirPath};
    }

    // Template strings (ported from init_skill.cjs)
    const QString skillTitle = titleCase(skillName);

    QString skillTemplate = QString(R"---(---
name: %1
description: TODO: Complete and informative explanation of what the skill does and when to use it. Include WHEN to use this skill - specific scenarios, file types, or tasks that trigger it.
---

# %2

## Overview

[TODO: 1-2 sentences explaining what this skill enables]

## Guidelines

[TODO: Add engineering patterns, coding standards, or requirements here]

## Resources

### scripts/
Executable code for automation.

### references/
Detailed documentation for context.

### assets/
Boilerplate or template files.
)---").arg(skillName, skillTitle);

    QString exampleScript = QString(R"---(#!/usr/bin/env node
/**
 * Example helper script for %1
 */
async function main() {
  try {
    process.stdout.write("Success: Processed the task.\n");
  } catch (err) {
    process.stderr.write(`Failure: ${err.message}\n`);
    process.exit(1);
  }
}
main();
)---").arg(skillName);

    // Create directories
    if (!ensureDirectoryExists(skillDirPath) ||
        !ensureDirectoryExists(skillDirPath + "/scripts") ||
        !ensureDirectoryExists(skillDirPath + "/references") ||
        !ensureDirectoryExists(skillDirPath + "/assets")) {
        return {callId, name(), true, "Error: Failed to create skill directory structure"};
    }

    // Write files
    if (!writeToFile(skillDirPath + "/SKILL.md", skillTemplate) ||
        !writeToFile(skillDirPath + "/scripts/example_script.cjs", exampleScript) ||
        !writeToFile(skillDirPath + "/references/example_reference.md", "# Reference for " + skillTitle) ||
        !writeToFile(skillDirPath + "/assets/example_asset.txt", "Placeholder for assets.")) {
        return {callId, name(), true, "Error: Failed to write skill files"};
    }

    QString message = QString("✅ Skill '%1' initialized at %2").arg(skillName, relPath + "/" + skillName);
    return {callId, name(), false, message};
}

bool NeurxSkillCreatorTool::ensureDirectoryExists(const QString &dirPath)
{
    QDir dir(dirPath);
    if (dir.exists()) return true;
    return dir.mkpath(".");
}

bool NeurxSkillCreatorTool::writeToFile(const QString &filePath, const QString &content)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
    QTextStream out(&file);
    out << content;
    return true;
}

QString NeurxSkillCreatorTool::titleCase(const QString &name)
{
    QStringList parts = name.split('-');
    for (int i = 0; i < parts.size(); ++i) {
        if (!parts[i].isEmpty()) {
            parts[i][0] = parts[i][0].toUpper();
        }
    }
    return parts.join(' ');
}

