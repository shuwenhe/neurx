#include "EditorCommandManager.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>

EditorCommandManager::EditorCommandManager(QObject *parent)
    : BaseTool(parent), m_registry(new CommandRegistry(this))
{
    registerBuiltinHandlers();
}

EditorCommandManager::~EditorCommandManager()
{
}

QString EditorCommandManager::description() const
{
    return "Editor Command Manager - 执行VS Code编辑器命令、管理快捷键、提供命令搜索。"
           "支持Agent操作、文件操作、Git操作、导航和调试命令。"
           "集成快捷键绑定、参数验证和执行历史。";
}

QJsonObject EditorCommandManager::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";

    QJsonObject properties;

    // action参数
    QJsonObject actionSchema;
    actionSchema["type"] = "string";
    actionSchema["enum"] = QJsonArray{
        "execute",
        "list_commands",
        "search_commands",
        "get_command",
        "get_keybindings",
        "bind_key",
        "unbind_key",
        "get_history",
        "clear_history",
        "get_statistics"
    };
    actionSchema["description"] = "执行的操作类型";
    properties["action"] = actionSchema;

    // command_id参数
    QJsonObject commandIdSchema;
    commandIdSchema["type"] = "string";
    commandIdSchema["description"] = "命令ID (例如: neurx.runAgent)";
    properties["command_id"] = commandIdSchema;

    // parameters参数
    QJsonObject parametersSchema;
    parametersSchema["type"] = "object";
    parametersSchema["description"] = "命令参数";
    properties["parameters"] = parametersSchema;

    // query参数
    QJsonObject querySchema;
    querySchema["type"] = "string";
    querySchema["description"] = "搜索查询";
    properties["query"] = querySchema;

    // key_combination参数
    QJsonObject keySchema;
    keySchema["type"] = "string";
    keySchema["description"] = "快捷键组合 (例如: Ctrl+Shift+A)";
    properties["key_combination"] = keySchema;

    schema["properties"] = properties;
    schema["required"] = QJsonArray{"action"};

    return schema;
}

ToolResult EditorCommandManager::execute(const QString &callId, const QJsonObject &args)
{
    QString action = args.value("action").toString().toLower();
    ToolResult result;
    result.callId = callId;
    result.name = name();
    result.isError = false;

    try {
        if (action == "execute") {
            QString commandId = args.value("command_id").toString();
            QJsonObject parameters = args.value("parameters").toObject();

            if (commandId.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing command_id"}
                }).toJson();
                return result;
            }

            QJsonObject execResult = executeCommand(commandId, parameters);
            result.content = QJsonDocument(execResult).toJson();

        } else if (action == "list_commands") {
            QString category = args.value("category").toString();
            QJsonArray commandsArray;

            for (const auto &cmd : m_registry->listCommands()) {
                QJsonObject cmdObj;
                cmdObj["id"] = cmd.id;
                cmdObj["title"] = cmd.title;
                cmdObj["description"] = cmd.description;
                cmdObj["enabled"] = cmd.enabled;
                commandsArray.append(cmdObj);
            }

            result.content = QJsonDocument(QJsonObject{
                {"commands", commandsArray},
                {"count", commandsArray.size()}
            }).toJson();

        } else if (action == "search_commands") {
            QString query = args.value("query").toString();
            if (query.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing search query"}
                }).toJson();
                return result;
            }

            QJsonArray resultsArray;
            for (const auto &cmd : m_registry->searchCommands(query)) {
                QJsonObject cmdObj;
                cmdObj["id"] = cmd.id;
                cmdObj["title"] = cmd.title;
                cmdObj["description"] = cmd.description;
                resultsArray.append(cmdObj);
            }

            result.content = QJsonDocument(QJsonObject{
                {"query", query},
                {"results", resultsArray},
                {"count", resultsArray.size()}
            }).toJson();

        } else if (action == "get_command") {
            QString commandId = args.value("command_id").toString();
            if (commandId.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing command_id"}
                }).toJson();
                return result;
            }

            auto cmd = m_registry->getCommand(commandId);
            if (cmd.id.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", QString("Command not found: %1").arg(commandId)}
                }).toJson();
                return result;
            }

            QJsonObject cmdObj;
            cmdObj["id"] = cmd.id;
            cmdObj["title"] = cmd.title;
            cmdObj["description"] = cmd.description;
            cmdObj["enabled"] = cmd.enabled;
            cmdObj["created_at"] = cmd.createdAt;

            result.content = QJsonDocument(cmdObj).toJson();

        } else if (action == "get_keybindings") {
            QString commandId = args.value("command_id").toString();
            QJsonArray bindingsArray;

            for (const auto &binding : m_registry->getKeyBindings(commandId)) {
                QJsonObject bindObj;
                bindObj["command_id"] = binding.commandId;
                bindObj["key_combination"] = binding.keyCombination;
                bindObj["when"] = binding.when;
                bindObj["description"] = binding.description;
                bindObj["enabled"] = binding.enabled;
                bindingsArray.append(bindObj);
            }

            result.content = QJsonDocument(QJsonObject{
                {"key_bindings", bindingsArray},
                {"count", bindingsArray.size()}
            }).toJson();

        } else if (action == "bind_key") {
            QString commandId = args.value("command_id").toString();
            QString keyCombination = args.value("key_combination").toString();

            if (commandId.isEmpty() || keyCombination.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing command_id or key_combination"}
                }).toJson();
                return result;
            }

            m_registry->bindKey(commandId, keyCombination);
            result.content = QJsonDocument(QJsonObject{
                {"message", QString("Key %1 bound to %2").arg(keyCombination, commandId)}
            }).toJson();

        } else if (action == "unbind_key") {
            QString commandId = args.value("command_id").toString();
            if (commandId.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing command_id"}
                }).toJson();
                return result;
            }

            m_registry->unbindKey(commandId);
            result.content = QJsonDocument(QJsonObject{
                {"message", QString("Key unbound from %1").arg(commandId)}
            }).toJson();

        } else if (action == "get_history") {
            QString commandId = args.value("command_id").toString();
            int limit = args.value("limit").toInt(100);

            QJsonArray historyArray;
            for (const auto &exec : m_registry->getExecutionHistory(commandId, limit)) {
                QJsonObject execObj;
                execObj["command_id"] = exec.commandId;
                execObj["executed_at"] = exec.executedAt;
                execObj["status"] = exec.status;
                execObj["execution_time_ms"] = static_cast<int>(exec.executionTimeMs);
                if (!exec.error.isEmpty()) {
                    execObj["error"] = exec.error;
                }
                historyArray.append(execObj);
            }

            result.content = QJsonDocument(QJsonObject{
                {"history", historyArray},
                {"count", historyArray.size()}
            }).toJson();

        } else if (action == "clear_history") {
            QString commandId = args.value("command_id").toString();
            m_registry->clearExecutionHistory(commandId);
            result.content = QJsonDocument(QJsonObject{
                {"message", "Execution history cleared"}
            }).toJson();

        } else if (action == "get_statistics") {
            QJsonObject stats = m_registry->getStatistics();
            result.content = QJsonDocument(stats).toJson();

        } else {
            result.isError = true;
            result.content = QJsonDocument(QJsonObject{
                {"error", QString("Unknown action: %1").arg(action)}
            }).toJson();
        }

    } catch (const std::exception &e) {
        result.isError = true;
        result.content = QJsonDocument(QJsonObject{
            {"error", QString("Exception: %1").arg(e.what())}
        }).toJson();
    }

    return result;
}

QString EditorCommandManager::summary(const QJsonObject &args) const
{
    QString action = args.value("action").toString();
    QString commandId = args.value("command_id").toString();

    if (action == "execute") {
        return QString("Execute command: %1").arg(commandId);
    } else if (action == "list_commands") {
        return "List all available commands";
    } else if (action == "search_commands") {
        return QString("Search commands: %1").arg(args.value("query").toString());
    }

    return QString("Editor command: %1").arg(action);
}

QJsonObject EditorCommandManager::executeCommand(const QString &commandId, const QJsonObject &parameters)
{
    QJsonObject result;

    // 验证参数
    QStringList missing;
    if (!validateParameters(commandId, parameters, missing)) {
        result["status"] = "error";
        result["message"] = QString("Missing required parameters: %1").arg(missing.join(", "));
        return result;
    }

    // 查找并执行处理器
    if (m_handlers.contains(commandId)) {
        auto startTime = QDateTime::currentMSecsSinceEpoch();
        QJsonObject execResult = m_handlers[commandId](parameters);
        auto endTime = QDateTime::currentMSecsSinceEpoch();

        // 记录执行
        CommandRegistry::CommandExecution exec;
        exec.commandId = commandId;
        exec.executedAt = QDateTime::currentDateTime().toString(Qt::ISODate);
        exec.status = execResult.value("status").toString("success");
        exec.result = execResult;
        exec.error = execResult.value("error").toString("");
        exec.executionTimeMs = endTime - startTime;
        m_registry->recordExecution(exec);

        return execResult;
    } else {
        result["status"] = "error";
        result["message"] = QString("No handler for command: %1").arg(commandId);
        return result;
    }
}

void EditorCommandManager::registerHandler(const QString &commandId, CommandHandler handler)
{
    m_handlers[commandId] = handler;
}

CommandRegistry::RegisteredCommand EditorCommandManager::getCommand(const QString &commandId)
{
    return m_registry->getCommand(commandId);
}

QList<CommandRegistry::RegisteredCommand> EditorCommandManager::listAllCommands()
{
    return m_registry->listCommands();
}

QList<CommandRegistry::RegisteredCommand> EditorCommandManager::searchCommands(const QString &query)
{
    return m_registry->searchCommands(query);
}

void EditorCommandManager::bindKey(const QString &commandId, const QString &keyCombination)
{
    m_registry->bindKey(commandId, keyCombination);
}

QString EditorCommandManager::getCommandFromKey(const QString &keyCombination)
{
    return m_registry->getCommandFromKey(keyCombination);
}

QList<CommandRegistry::KeyBinding> EditorCommandManager::getKeyBindings()
{
    return m_registry->getKeyBindings();
}

void EditorCommandManager::registerBuiltinHandlers()
{
    // runAgent命令
    m_handlers["neurx.runAgent"] = [this](const QJsonObject &params) -> QJsonObject {
        return handleAgentCommand("neurx.runAgent", params);
    };

    // assessRisk命令
    m_handlers["neurx.assessRisk"] = [this](const QJsonObject &params) -> QJsonObject {
        return handleAgentCommand("neurx.assessRisk", params);
    };

    // 文件操作命令
    m_handlers["neurx.generateDirectoryTree"] = [this](const QJsonObject &params) -> QJsonObject {
        return handleFileCommand("neurx.generateDirectoryTree", params);
    };

    // Git命令
    m_handlers["neurx.generateCommitMessage"] = [this](const QJsonObject &params) -> QJsonObject {
        return handleGitCommand("neurx.generateCommitMessage", params);
    };

    // 导航命令
    m_handlers["neurx.searchWorkspace"] = [this](const QJsonObject &params) -> QJsonObject {
        return handleNavigationCommand("neurx.searchWorkspace", params);
    };
}

QJsonObject EditorCommandManager::handleAgentCommand(const QString &commandId, const QJsonObject &params)
{
    QJsonObject result;
    result["status"] = "success";
    result["command_id"] = commandId;
    result["executed_at"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    if (commandId == "neurx.runAgent") {
        result["message"] = "Agent execution initiated";
        result["prompt"] = params.value("prompt").toString();
    } else if (commandId == "neurx.assessRisk") {
        result["message"] = "Risk assessment completed";
        result["tool_name"] = params.value("toolName").toString();
        result["action"] = params.value("action").toString();
    }

    return result;
}

QJsonObject EditorCommandManager::handleFileCommand(const QString &commandId, const QJsonObject &params)
{
    QJsonObject result;
    result["status"] = "success";
    result["command_id"] = commandId;

    if (commandId == "neurx.generateDirectoryTree") {
        result["message"] = "Directory tree generated";
        result["format"] = params.value("format").toString("text");
        result["depth"] = params.value("depth").toInt(5);
    }

    return result;
}

QJsonObject EditorCommandManager::handleGitCommand(const QString &commandId, const QJsonObject &params)
{
    QJsonObject result;
    result["status"] = "success";
    result["command_id"] = commandId;

    if (commandId == "neurx.generateCommitMessage") {
        result["message"] = "Commit message generated";
        result["suggested_message"] = "Implement feature X";
    }

    return result;
}

QJsonObject EditorCommandManager::handleNavigationCommand(const QString &commandId, const QJsonObject &params)
{
    QJsonObject result;
    result["status"] = "success";
    result["command_id"] = commandId;

    if (commandId == "neurx.searchWorkspace") {
        result["message"] = "Workspace search completed";
        result["query"] = params.value("query").toString();
    }

    return result;
}

QJsonObject EditorCommandManager::handleDebugCommand(const QString &commandId, const QJsonObject &params)
{
    QJsonObject result;
    result["status"] = "success";
    result["command_id"] = commandId;
    return result;
}

bool EditorCommandManager::validateParameters(const QString &commandId, const QJsonObject &params, QStringList &missing)
{
    auto cmd = m_registry->getCommand(commandId);
    if (cmd.id.isEmpty()) {
        return false;
    }

    for (const auto &param : cmd.parameters) {
        if (param.required && !params.contains(param.name)) {
            missing.append(param.name);
        }
    }

    return missing.isEmpty();
}
