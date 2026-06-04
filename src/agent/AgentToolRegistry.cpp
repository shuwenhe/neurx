#include "agent/AgentToolRegistry.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringList>

namespace {

QStringList extractSchemaPropertyNames(const QJsonObject &schema)
{
    const QJsonObject properties = schema.value(QStringLiteral("properties")).toObject();
    return properties.keys();
}

QString inferredCategoryFromTags(const QStringList &tags)
{
    if (tags.contains(QStringLiteral("shell")))
        return QStringLiteral("Execution");
    if (tags.contains(QStringLiteral("files")))
        return QStringLiteral("Workspace");
    if (tags.contains(QStringLiteral("web")))
        return QStringLiteral("Network");
    if (tags.contains(QStringLiteral("planning")))
        return QStringLiteral("Planning");
    return QStringLiteral("General");
}

} // namespace

AgentToolRegistry::AgentToolRegistry(QObject *parent) : QObject(parent) {}

QStringList AgentToolRegistry::inferredToolTags(const QString &toolName)
{
    if (toolName == QStringLiteral("file_system"))
        return {QStringLiteral("files"), QStringLiteral("workspace"), QStringLiteral("io")};
    if (toolName == QStringLiteral("smart_file_creator"))
        return {QStringLiteral("files"), QStringLiteral("workspace"), QStringLiteral("scaffold")};
    if (toolName == QStringLiteral("patch") || toolName == QStringLiteral("apply_patch"))
        return {QStringLiteral("diff"), QStringLiteral("files"), QStringLiteral("edit")};
    if (toolName == QStringLiteral("run_command") || toolName == QStringLiteral("run_docker_command"))
        return {QStringLiteral("shell"), QStringLiteral("command"), QStringLiteral("execution")};
    if (toolName == QStringLiteral("search"))
        return {QStringLiteral("search"), QStringLiteral("workspace")};
    if (toolName == QStringLiteral("web_search") || toolName == QStringLiteral("web_fetch"))
        return {QStringLiteral("web"), QStringLiteral("network")};
    if (toolName == QStringLiteral("knowledge"))
        return {QStringLiteral("knowledge"), QStringLiteral("indexing")};
    if (toolName == QStringLiteral("checkpoint"))
        return {QStringLiteral("checkpoint"), QStringLiteral("rollback")};
    if (toolName == QStringLiteral("todo") || toolName == QStringLiteral("update_plan"))
        return {QStringLiteral("planning"), QStringLiteral("tasks")};
    if (toolName == QStringLiteral("codex_agent"))
        return {QStringLiteral("agent"), QStringLiteral("delegation")};
    return {QStringLiteral("tool")};
}

QString AgentToolRegistry::inferredCategory(const QStringList &tags)
{
    return inferredCategoryFromTags(tags);
}

QStringList AgentToolRegistry::parameterNamesFromSchema(const QJsonObject &schema)
{
    return extractSchemaPropertyNames(schema);
}

ToolSchema AgentToolRegistry::buildSchemaForTool(const BaseTool *tool) const
{
    ToolSchema schema;
    if (!tool)
        return schema;

    const QString toolName = tool->name();
    const QStringList tags = inferredToolTags(toolName);
    const QJsonObject parameterSchema = tool->parametersSchema();

    schema.toolId = toolName;
    schema.name = toolName;
    schema.version = QStringLiteral("1.0.0");
    schema.description = tool->description();
    schema.author = QStringLiteral("NeurX Code");
    schema.license = QStringLiteral("Proprietary");
    schema.tags = tags;
    schema.category = inferredCategory(tags);
    schema.minPermissionLevel = PermissionLevel::Public;
    schema.requiredRoles.clear();
    schema.configuration.insert(QStringLiteral("parametersSchema"), parameterSchema.toVariantMap());
    schema.configuration.insert(QStringLiteral("summary"), tool->summary(QJsonObject{}));
    schema.environment.insert(QStringLiteral("runtime"), QStringLiteral("agent"));
    schema.environment.insert(QStringLiteral("toolName"), toolName);

    ToolCapabilityDefinition capability;
    capability.name = toolName;
    capability.description = tool->description();
    capability.inputParams = parameterNamesFromSchema(parameterSchema);
    capability.category = schema.category;
    capability.tags = tags;
    capability.isAsync = false;
    capability.isCacheable = false;
    capability.isDeterministic = false;
    capability.documentation = QStringLiteral("Generated from BaseTool parametersSchema()");
    schema.capabilities.append(capability);

    return schema;
}

void AgentToolRegistry::registerTool(BaseTool *tool)
{
    if (!tool)
        return;

    const QString name = tool->name();
    BaseTool *previous = m_tools.value(name, nullptr);
    m_toolSchemas.insert(name, buildSchemaForTool(tool));
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
    m_toolSchemas.remove(name);
}

BaseTool *AgentToolRegistry::tool(const QString &name) const
{
    return m_tools.value(name, nullptr);
}

QList<BaseTool *> AgentToolRegistry::allTools() const
{
    return m_tools.values();
}

ToolSchema AgentToolRegistry::toolSchema(const QString &name) const
{
    return m_toolSchemas.value(name, ToolSchema());
}

QVector<ToolSchema> AgentToolRegistry::allToolSchemas() const
{
    return QVector<ToolSchema>(m_toolSchemas.values().begin(), m_toolSchemas.values().end());
}

QJsonObject AgentToolRegistry::toolSchemaJson(const QString &name) const
{
    const ToolSchema schema = toolSchema(name);
    if (schema.toolId.isEmpty())
        return {};

    QJsonObject obj;
    obj[QStringLiteral("toolId")] = schema.toolId;
    obj[QStringLiteral("name")] = schema.name;
    obj[QStringLiteral("version")] = schema.version;
    obj[QStringLiteral("description")] = schema.description;
    obj[QStringLiteral("author")] = schema.author;
    obj[QStringLiteral("license")] = schema.license;
    obj[QStringLiteral("category")] = schema.category;
    obj[QStringLiteral("tags")] = QJsonArray::fromStringList(schema.tags);
    obj[QStringLiteral("minPermissionLevel")] = int(schema.minPermissionLevel);
    // Capabilities is a QVector, convert to QVariantList
    QVariantList capsList;
    for (const auto &cap : schema.capabilities) {
        QVariantMap capMap;
        capMap["name"] = cap.name;
        capMap["description"] = cap.description;
        capsList.append(capMap);
    }
    obj[QStringLiteral("capabilities")] = QJsonArray::fromVariantList(capsList);
    obj[QStringLiteral("configuration")] = QJsonObject::fromVariantMap(schema.configuration);
    // environment is already a QMap<QString, QVariant>, convert directly
    QVariantMap envMap;
    for (auto it = schema.environment.begin(); it != schema.environment.end(); ++it) {
        envMap[it.key()] = it.value();
    }
    obj[QStringLiteral("environment")] = QJsonObject::fromVariantMap(envMap);
    return obj;
}

QJsonArray AgentToolRegistry::allToolSchemasJson() const
{
    QJsonArray arr;
    for (const auto &schema : m_toolSchemas) {
        QJsonObject obj;
        obj[QStringLiteral("toolId")] = schema.toolId;
        obj[QStringLiteral("name")] = schema.name;
        obj[QStringLiteral("version")] = schema.version;
        obj[QStringLiteral("description")] = schema.description;
        obj[QStringLiteral("author")] = schema.author;
        obj[QStringLiteral("license")] = schema.license;
        obj[QStringLiteral("category")] = schema.category;
        obj[QStringLiteral("tags")] = QJsonArray::fromStringList(schema.tags);
        obj[QStringLiteral("minPermissionLevel")] = int(schema.minPermissionLevel);
        obj[QStringLiteral("configuration")] = QJsonObject::fromVariantMap(schema.configuration);
        QVariantMap envMap;
        for (auto it = schema.environment.begin(); it != schema.environment.end(); ++it) {
            envMap[it.key()] = it.value();
        }
        obj[QStringLiteral("environment")] = QJsonObject::fromVariantMap(envMap);
        arr.append(obj);
    }
    return arr;
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
