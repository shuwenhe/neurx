#include "agent/AgentToolRegistry.h"
#include <QJsonObject>
#include <QJsonArray>

AgentToolRegistry::AgentToolRegistry(QObject *parent) : QObject(parent) {}

void AgentToolRegistry::registerTool(BaseTool *tool)
{
    if (!tool)
        return;

    const QString name = tool->name();
    BaseTool *previous = m_tools.value(name, nullptr);
    qDebug() << "[AgentToolRegistry] Registering tool:" << name;

    // Allow re-registration during workspace rebuilds without leaving the
    // registry temporarily empty. If a tool with the same name already exists,
    // replace it in-place and retire the old instance afterwards.
    m_tools.insert(name, tool);
    if (tool->parent() == nullptr) tool->setParent(this);

    if (previous && previous != tool)
        previous->deleteLater();
}

void AgentToolRegistry::unregisterTool(const QString &name)
{
    m_tools.remove(name);
}

BaseTool *AgentToolRegistry::tool(const QString &name) const
{
    return m_tools.value(name, nullptr);
}

QList<BaseTool *> AgentToolRegistry::allTools() const
{
    return m_tools.values();
}

QJsonArray AgentToolRegistry::toAnthropicSchema() const
{
    QJsonArray arr;
    qDebug() << "[AgentToolRegistry] Building Anthropic schema for" << m_tools.size() << "tools";
    for (const auto *t : m_tools) {
        qDebug() << "  - Tool:" << t->name();
        QJsonObject tool;
        tool["name"]         = t->name();
        tool["description"]  = t->description();
        tool["input_schema"] = t->parametersSchema();
        arr.append(tool);
    }
    return arr;
}

QJsonArray AgentToolRegistry::toOpenAISchema() const
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

QJsonArray AgentToolRegistry::toGeminiSchema() const
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
