#include "agent/ToolRegistry.h"
#include <QJsonObject>
#include <QJsonArray>

ToolRegistry::ToolRegistry(QObject *parent) : QObject(parent) {}

void ToolRegistry::registerTool(BaseTool *tool)
{
    m_tools.insert(tool->name(), tool);
    if (tool->parent() == nullptr) tool->setParent(this);
}

void ToolRegistry::unregisterTool(const QString &name)
{
    m_tools.remove(name);
}

BaseTool *ToolRegistry::tool(const QString &name) const
{
    return m_tools.value(name, nullptr);
}

QList<BaseTool *> ToolRegistry::allTools() const
{
    return m_tools.values();
}

QJsonArray ToolRegistry::toAnthropicSchema() const
{
    QJsonArray arr;
    for (const auto *t : m_tools) {
        QJsonObject tool;
        tool["name"]         = t->name();
        tool["description"]  = t->description();
        tool["input_schema"] = t->parametersSchema();
        arr.append(tool);
    }
    return arr;
}

QJsonArray ToolRegistry::toOpenAISchema() const
{
    QJsonArray arr;
    for (const auto *t : m_tools) {
        QJsonObject func;
        func["name"]        = t->name();
        func["description"] = t->description();
        func["parameters"]  = t->parametersSchema();

        QJsonObject tool;
        tool["type"]     = "function";
        tool["function"] = func;
        arr.append(tool);
    }
    return arr;
}

QJsonArray ToolRegistry::toGeminiSchema() const
{
    QJsonArray declarations;
    for (const auto *t : m_tools) {
        // Special case for Gemini's built-in grounding
        if (t->name() == "google_search") continue;

        QJsonObject dec;
        dec["name"]        = t->name();
        dec["description"] = t->description();
        dec["parameters"]  = t->parametersSchema();
        declarations.append(dec);
    }

    QJsonArray toolsArr;
    if (!declarations.isEmpty()) {
        QJsonObject fnDeclarations;
        fnDeclarations["function_declarations"] = declarations;
        toolsArr.append(fnDeclarations);
    }

    // Add native grounding if tool exists
    if (m_tools.contains("google_search")) {
        QJsonObject searchTool;
        searchTool["google_search_retrieval"] = QJsonObject();
        toolsArr.append(searchTool);
    }

    return toolsArr;
}
