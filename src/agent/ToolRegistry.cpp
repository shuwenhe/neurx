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
