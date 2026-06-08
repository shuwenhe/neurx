#include "CommandRegistry.h"
#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <algorithm>

CommandRegistry::CommandRegistry(QObject *parent)
    : QObject(parent)
{
    initializeDefaultCommands();
}

CommandRegistry::~CommandRegistry()
{
}

void CommandRegistry::initializeDefaultCommands()
{
    // Agent操作命令
    registerCommand(
        "neurx.runAgent",
        "Run Agent",
        "Run the Agent with current selection",
        Agent,
        {
            {"prompt", STRING, true, "Agent prompt text", ""},
            {"context", STRING, false, "Additional context", ""}
        }
    );

    registerCommand(
        "neurx.assessRisk",
        "Assess Risk",
        "Assess security risk for current operation",
        Agent,
        {
            {"toolName", STRING, true, "Tool name to assess", ""},
            {"action", STRING, true, "Action to perform", ""}
        }
    );

    registerCommand(
        "neurx.viewApprovalHistory",
        "View Approval History",
        "Show recent approval decisions",
        Agent,
        {}
    );

    registerCommand(
        "neurx.toggleAutoApproval",
        "Toggle Auto Approval",
        "Enable/disable automatic approval for trusted tools",
        Agent,
        {}
    );

    // 文件操作命令
    registerCommand(
        "neurx.createFileFromTemplate",
        "Create File from Template",
        "Create a new file using a template",
        FileOperation,
        {
            {"templateName", STRING, true, "Template name", ""},
            {"filePath", STRING, true, "Target file path", ""}
        }
    );

    registerCommand(
        "neurx.formatSelectedFiles",
        "Format Selected Files",
        "Format selected files using Prettier/Black",
        FileOperation,
        {}
    );

    registerCommand(
        "neurx.generateDirectoryTree",
        "Generate Directory Tree",
        "Generate tree structure of current directory",
        FileOperation,
        {
            {"depth", NUMBER, false, "Maximum depth", 5},
            {"format", STRING, false, "Output format (text/json/markdown)", "text"}
        }
    );

    registerCommand(
        "neurx.batchRename",
        "Batch Rename Files",
        "Rename multiple files using pattern",
        FileOperation,
        {
            {"pattern", STRING, true, "Rename pattern", ""},
            {"replacement", STRING, true, "Replacement pattern", ""}
        }
    );

    // Git操作命令
    registerCommand(
        "neurx.generateCommitMessage",
        "Generate Commit Message",
        "Generate commit message from changes",
        GitOperation,
        {}
    );

    registerCommand(
        "neurx.createPullRequest",
        "Create Pull Request",
        "Create PR with Agent-generated description",
        GitOperation,
        {
            {"title", STRING, false, "PR title", ""},
            {"description", STRING, false, "PR description", ""}
        }
    );

    registerCommand(
        "neurx.analyzeGitHistory",
        "Analyze Git History",
        "Analyze recent git history for patterns",
        GitOperation,
        {
            {"depth", NUMBER, false, "Number of commits to analyze", 20}
        }
    );

    registerCommand(
        "neurx.detectConflicts",
        "Detect Merge Conflicts",
        "Detect potential merge conflicts",
        GitOperation,
        {}
    );

    // 导航命令
    registerCommand(
        "neurx.goToDefinition",
        "Go to Definition",
        "Navigate to symbol definition",
        Navigation,
        {
            {"symbol", STRING, true, "Symbol name", ""}
        }
    );

    registerCommand(
        "neurx.findReferences",
        "Find References",
        "Find all references to symbol",
        Navigation,
        {
            {"symbol", STRING, true, "Symbol name", ""}
        }
    );

    registerCommand(
        "neurx.searchWorkspace",
        "Search Workspace",
        "Search across entire workspace",
        Navigation,
        {
            {"query", STRING, true, "Search query", ""},
            {"type", STRING, false, "Search type (file/text/symbol)", "text"}
        }
    );

    // 调试命令
    registerCommand(
        "neurx.showDiagnostics",
        "Show Diagnostics",
        "Show code diagnostics and issues",
        Debug,
        {}
    );

    registerCommand(
        "neurx.enableDebugLogging",
        "Enable Debug Logging",
        "Enable verbose debug logging",
        Debug,
        {}
    );

    // 默认快捷键绑定
    bindKey("neurx.runAgent", "Ctrl+Shift+A", "editorFocus", "Run Agent with selection");
    bindKey("neurx.assessRisk", "Ctrl+Shift+R", "editorFocus", "Quick risk assessment");
    bindKey("neurx.formatSelectedFiles", "Ctrl+Shift+F", "editorFocus", "Format files");
    bindKey("neurx.generateCommitMessage", "Ctrl+Shift+M", "editorFocus", "Generate commit message");
}

void CommandRegistry::registerCommand(const QString &id,
                                       const QString &title,
                                       const QString &description,
                                       CommandCategory category,
                                       const QList<CommandParameter> &parameters)
{
    if (m_commands.contains(id)) {
        qWarning() << "Command already registered:" << id;
        return;
    }

    RegisteredCommand command;
    command.id = id;
    command.title = title;
    command.description = description;
    command.category = category;
    command.parameters = parameters;
    command.enabled = true;
    command.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);

    m_commands.insert(id, command);
    m_executionStats.insert(id, 0);

    emit commandRegistered(id);
    qDebug() << "[CommandRegistry] Registered command:" << id;
}

CommandRegistry::RegisteredCommand CommandRegistry::getCommand(const QString &id)
{
    return m_commands.value(id);
}

QList<CommandRegistry::RegisteredCommand> CommandRegistry::listCommands()
{
    return m_commands.values();
}

QList<CommandRegistry::RegisteredCommand> CommandRegistry::listCommandsByCategory(CommandCategory category)
{
    QList<RegisteredCommand> result;
    for (const auto &cmd : m_commands.values()) {
        if (cmd.category == category) {
            result.append(cmd);
        }
    }
    return result;
}

bool CommandRegistry::commandExists(const QString &id)
{
    return m_commands.contains(id);
}

void CommandRegistry::bindKey(const QString &commandId,
                               const QString &keyCombination,
                               const QString &when,
                               const QString &description)
{
    if (!m_commands.contains(commandId)) {
        qWarning() << "Command not found:" << commandId;
        return;
    }

    // 检查快捷键冲突
    if (isKeyConflict(keyCombination)) {
        emit keyConflictDetected(keyCombination);
        qWarning() << "Key binding conflict detected:" << keyCombination;
    }

    KeyBinding binding;
    binding.commandId = commandId;
    binding.keyCombination = keyCombination;
    binding.when = when;
    binding.description = description;
    binding.enabled = true;

    m_keyBindings.insert(commandId, binding);
    emit keyBindingAdded(commandId, keyCombination);
}

void CommandRegistry::unbindKey(const QString &commandId)
{
    if (m_keyBindings.remove(commandId) > 0) {
        emit keyBindingRemoved(commandId);
    }
}

QList<CommandRegistry::KeyBinding> CommandRegistry::getKeyBindings(const QString &commandId)
{
    QList<KeyBinding> result;

    if (commandId.isEmpty()) {
        result = m_keyBindings.values();
    } else {
        if (m_keyBindings.contains(commandId)) {
            result.append(m_keyBindings.value(commandId));
        }
    }

    return result;
}

QString CommandRegistry::getCommandFromKey(const QString &keyCombination)
{
    for (const auto &binding : m_keyBindings.values()) {
        if (binding.keyCombination == keyCombination && binding.enabled) {
            return binding.commandId;
        }
    }
    return "";
}

bool CommandRegistry::isKeyConflict(const QString &keyCombination)
{
    return !getCommandFromKey(keyCombination).isEmpty();
}

QList<CommandRegistry::KeyBinding> CommandRegistry::getConflictingBindings(const QString &keyCombination)
{
    QList<KeyBinding> result;
    for (const auto &binding : m_keyBindings.values()) {
        if (binding.keyCombination == keyCombination) {
            result.append(binding);
        }
    }
    return result;
}

void CommandRegistry::recordExecution(const CommandExecution &execution)
{
    m_executionHistory.append(execution);

    if (m_executionStats.contains(execution.commandId)) {
        m_executionStats[execution.commandId]++;
    }

    // 保持历史记录在合理大小
    if (m_executionHistory.size() > 10000) {
        m_executionHistory = m_executionHistory.mid(m_executionHistory.size() - 5000);
    }

    if (execution.status == "success") {
        emit commandExecuted(execution.commandId, execution.result);
    } else {
        emit commandFailed(execution.commandId, execution.error);
    }
}

QList<CommandRegistry::CommandExecution> CommandRegistry::getExecutionHistory(const QString &commandId, int limit)
{
    QList<CommandExecution> result;

    for (int i = m_executionHistory.size() - 1; i >= 0 && result.size() < limit; --i) {
        const auto &exec = m_executionHistory[i];
        if (commandId.isEmpty() || exec.commandId == commandId) {
            result.append(exec);
        }
    }

    return result;
}

void CommandRegistry::clearExecutionHistory(const QString &commandId)
{
    if (commandId.isEmpty()) {
        m_executionHistory.clear();
    } else {
        QList<CommandExecution> filtered;
        for (const auto &exec : m_executionHistory) {
            if (exec.commandId != commandId) {
                filtered.append(exec);
            }
        }
        m_executionHistory = filtered;
    }
}

QList<CommandRegistry::RegisteredCommand> CommandRegistry::searchCommands(const QString &query)
{
    QList<RegisteredCommand> result;

    for (const auto &cmd : m_commands.values()) {
        if (cmd.title.contains(query, Qt::CaseInsensitive) ||
            cmd.description.contains(query, Qt::CaseInsensitive) ||
            cmd.id.contains(query, Qt::CaseInsensitive)) {
            result.append(cmd);
        }
    }

    return result;
}

QList<CommandRegistry::RegisteredCommand> CommandRegistry::filterByCategory(CommandCategory category)
{
    return listCommandsByCategory(category);
}

QList<CommandRegistry::RegisteredCommand> CommandRegistry::getRecentCommands(int count)
{
    QList<RegisteredCommand> result;
    QMap<QString, int> commandFrequency;

    for (const auto &exec : m_executionHistory) {
        commandFrequency[exec.commandId]++;
    }

    // 按执行次数排序
    QList<QString> sorted = commandFrequency.keys();
    std::sort(sorted.begin(), sorted.end(),
        [&commandFrequency](const QString &a, const QString &b) {
            return commandFrequency[a] > commandFrequency[b];
        });

    for (int i = 0; i < qMin(count, sorted.size()); ++i) {
        if (m_commands.contains(sorted[i])) {
            result.append(m_commands[sorted[i]]);
        }
    }

    return result;
}

QJsonObject CommandRegistry::exportCommands()
{
    QJsonObject export_obj;
    QJsonArray commandsArray;

    for (const auto &cmd : m_commands.values()) {
        QJsonObject cmdObj;
        cmdObj["id"] = cmd.id;
        cmdObj["title"] = cmd.title;
        cmdObj["description"] = cmd.description;
        cmdObj["category"] = static_cast<int>(cmd.category);
        cmdObj["enabled"] = cmd.enabled;

        QJsonArray paramsArray;
        for (const auto &param : cmd.parameters) {
            QJsonObject paramObj;
            paramObj["name"] = param.name;
            paramObj["type"] = static_cast<int>(param.type);
            paramObj["required"] = param.required;
            paramObj["description"] = param.description;
            paramsArray.append(paramObj);
        }
        cmdObj["parameters"] = paramsArray;

        commandsArray.append(cmdObj);
    }

    export_obj["commands"] = commandsArray;
    export_obj["exportedAt"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    return export_obj;
}

QJsonObject CommandRegistry::exportKeyBindings()
{
    QJsonObject export_obj;
    QJsonArray bindingsArray;

    for (const auto &binding : m_keyBindings.values()) {
        QJsonObject bindObj;
        bindObj["commandId"] = binding.commandId;
        bindObj["keyCombination"] = binding.keyCombination;
        bindObj["when"] = binding.when;
        bindObj["description"] = binding.description;
        bindObj["enabled"] = binding.enabled;
        bindingsArray.append(bindObj);
    }

    export_obj["keyBindings"] = bindingsArray;
    export_obj["exportedAt"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    return export_obj;
}

void CommandRegistry::importCommands(const QJsonObject &data)
{
    if (!data.contains("commands")) {
        return;
    }

    QJsonArray commandsArray = data.value("commands").toArray();
    for (const auto &item : commandsArray) {
        QJsonObject cmdObj = item.toObject();
        QString id = cmdObj.value("id").toString();
        QString title = cmdObj.value("title").toString();
        QString description = cmdObj.value("description").toString();
        CommandCategory category = static_cast<CommandCategory>(cmdObj.value("category").toInt());

        QList<CommandParameter> parameters;
        QJsonArray paramsArray = cmdObj.value("parameters").toArray();
        for (const auto &paramItem : paramsArray) {
            QJsonObject paramObj = paramItem.toObject();
            CommandParameter param;
            param.name = paramObj.value("name").toString();
            param.type = static_cast<ParameterType>(paramObj.value("type").toInt());
            param.required = paramObj.value("required").toBool();
            param.description = paramObj.value("description").toString();
            parameters.append(param);
        }

        registerCommand(id, title, description, category, parameters);
    }
}

void CommandRegistry::importKeyBindings(const QJsonObject &data)
{
    if (!data.contains("keyBindings")) {
        return;
    }

    QJsonArray bindingsArray = data.value("keyBindings").toArray();
    for (const auto &item : bindingsArray) {
        QJsonObject bindObj = item.toObject();
        QString commandId = bindObj.value("commandId").toString();
        QString keyCombination = bindObj.value("keyCombination").toString();
        QString when = bindObj.value("when").toString();
        QString description = bindObj.value("description").toString();

        bindKey(commandId, keyCombination, when, description);
    }
}

QJsonObject CommandRegistry::getStatistics()
{
    QJsonObject stats;
    stats["totalCommands"] = getTotalCommandCount();
    stats["totalExecutions"] = m_executionHistory.size();
    stats["uniqueCommandsExecuted"] = m_executionStats.size();

    QJsonObject categoryCount;
    for (int i = 0; i <= Custom; ++i) {
        CommandCategory cat = static_cast<CommandCategory>(i);
        int count = listCommandsByCategory(cat).size();
        QString catName;
        switch (cat) {
        case Agent: catName = "Agent"; break;
        case FileOperation: catName = "FileOperation"; break;
        case GitOperation: catName = "GitOperation"; break;
        case Navigation: catName = "Navigation"; break;
        case Debug: catName = "Debug"; break;
        case Custom: catName = "Custom"; break;
        }
        categoryCount[catName] = count;
    }
    stats["commandsByCategory"] = categoryCount;

    return stats;
}

int CommandRegistry::getTotalCommandCount()
{
    return m_commands.size();
}

int CommandRegistry::getExecutionCount(const QString &commandId)
{
    return m_executionStats.value(commandId, 0);
}

void CommandRegistry::resetToDefaults()
{
    m_commands.clear();
    m_keyBindings.clear();
    m_executionHistory.clear();
    m_executionStats.clear();
    initializeDefaultCommands();
}
