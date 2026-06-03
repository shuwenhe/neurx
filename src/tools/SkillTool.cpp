#include "tools/SkillTool.h"
#include <QJsonDocument>
#include <QJsonObject>

SkillTool::SkillTool(ClaudeSkillManager *manager, QObject *parent)
    : BaseTool(parent), m_manager(manager)
{}

QJsonObject SkillTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "skill_id": {
                "type": "string",
                "description": "The ID or name of the skill to consult."
            }
        },
        "required": ["skill_id"]
    })").object();
}

ToolResult SkillTool::execute(const QString &callId, const QJsonObject &args)
{
    if (!m_manager) return {callId, name(), true, "Skill manager not available."};

    const QString skillId = args["skill_id"].toString();
    const QString instructions = m_manager->skillInstructions(skillId);

    if (instructions.isEmpty()) {
        return {callId, name(), true, "Skill not found: " + skillId};
    }

    return {callId, name(), false, "SKILL INSTRUCTIONS (" + skillId + "):\n\n" + instructions};
}
