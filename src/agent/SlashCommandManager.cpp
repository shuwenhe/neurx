#include "agent/SlashCommandManager.h"
#include <QDebug>
#include <QDateTime>
#include <QStringList>
#include <QRegularExpression>
#include <QJsonDocument>

SlashCommandManager::SlashCommandManager(QObject *parent)
    : QObject(parent)
{
    registerBuiltInCommands();
}

SlashCommandManager::~SlashCommandManager() = default;

// ── Command Registration ────────────────────────────────────────────────────

void SlashCommandManager::registerCommand(
    const SlashCommand &command,
    std::function<SlashCommandResult(const QStringList &, const QJsonObject &)> handler)
{
    if (!validateCommand(command)) {
        qWarning() << "Invalid command:" << command.name;
        return;
    }

    m_commands[command.name] = command;
    m_handlers[command.name] = handler;
    
    // Register aliases
    for (const auto &alias : command.aliases) {
        m_commands[alias] = command;
        m_handlers[alias] = handler;
    }
    
    qDebug() << "Registered command:" << command.name;
}

void SlashCommandManager::unregisterCommand(const QString &name)
{
    auto it = m_commands.find(name);
    if (it != m_commands.end()) {
        m_commands.erase(it);
        m_handlers.remove(name);
        qDebug() << "Unregistered command:" << name;
    }
}

bool SlashCommandManager::hasCommand(const QString &name) const
{
    return m_commands.contains(name);
}

// ── Command Discovery ───────────────────────────────────────────────────────

QList<SlashCommand> SlashCommandManager::allCommands() const
{
    QList<SlashCommand> result;
    QSet<QString> seen;
    
    for (const auto &cmd : m_commands) {
        if (!seen.contains(cmd.name)) {
            result.append(cmd);
            seen.insert(cmd.name);
        }
    }
    
    return result;
}

QList<SlashCommand> SlashCommandManager::commandsByCategory(const QString &category) const
{
    QList<SlashCommand> result;
    QSet<QString> seen;
    
    for (const auto &cmd : m_commands) {
        if (cmd.category == category && !seen.contains(cmd.name)) {
            result.append(cmd);
            seen.insert(cmd.name);
        }
    }
    
    return result;
}

QList<SlashCommand> SlashCommandManager::searchCommands(const QString &query) const
{
    QList<SlashCommand> result;
    QSet<QString> seen;
    QString lowerQuery = query.toLower();
    
    for (const auto &cmd : m_commands) {
        if (seen.contains(cmd.name)) continue;
        
        if (cmd.name.toLower().contains(lowerQuery) ||
            cmd.description.toLower().contains(lowerQuery)) {
            result.append(cmd);
            seen.insert(cmd.name);
        }
    }
    
    return result;
}

SlashCommand SlashCommandManager::getCommand(const QString &name) const
{
    auto it = m_commands.find(name);
    if (it != m_commands.end()) {
        return it.value();
    }
    
    // Try lowercase
    auto lowerName = name.toLower();
    for (auto it = m_commands.begin(); it != m_commands.end(); ++it) {
        if (it.key().toLower() == lowerName) {
            return it.value();
        }
    }
    
    return SlashCommand();
}

// ── Command Execution ───────────────────────────────────────────────────────

SlashCommandResult SlashCommandManager::executeCommand(const QString &commandLine, 
                                                      const QJsonObject &context)
{
    auto parts = parseCommandLine(commandLine);
    if (parts.isEmpty()) {
        SlashCommandResult result;
        result.success = false;
        result.errorMessage = "Empty command";
        return result;
    }
    
    QString commandName = parts.first();
    if (commandName.startsWith('/')) {
        commandName = commandName.mid(1);
    }
    
    QStringList args;
    if (parts.size() > 1) {
        args = parts.mid(1);
    }
    
    return executeCommand(commandName, args, context);
}

SlashCommandResult SlashCommandManager::executeCommand(const QString &name, 
                                                      const QStringList &args,
                                                      const QJsonObject &context)
{
    auto handler = m_handlers.find(name);
    if (handler == m_handlers.end()) {
        SlashCommandResult result;
        result.success = false;
        result.errorMessage = QString("Command not found: /%1").arg(name);
        return result;
    }
    
    emit commandExecuting(name, args);
    
    try {
        auto result = (*handler)(args, context);
        
        // Add to history
        m_history.append(QString("/%1 %2").arg(name, args.join(" ")));
        if (m_history.size() > 100) {
            m_history.removeFirst();
        }
        
        emit commandCompleted(name, result);
        return result;
    } catch (const std::exception &e) {
        SlashCommandResult result;
        result.success = false;
        result.errorMessage = QString("Exception: %1").arg(e.what());
        emit commandFailed(name, result.errorMessage);
        return result;
    }
}

// ── Help and Documentation ───────────────────────────────────────────────────

QString SlashCommandManager::getCommandHelp(const QString &name) const
{
    auto cmd = getCommand(name);
    if (cmd.name.isEmpty()) {
        return QString("Command not found: /%1").arg(name);
    }
    
    QString help;
    help += QString("## /%1\n\n").arg(cmd.name);
    help += cmd.description + "\n\n";
    
    if (!cmd.args.isEmpty()) {
        help += "**Arguments:**\n";
        for (const auto &arg : cmd.args) {
            help += QString("- `%1`: %2\n").arg(arg.first, arg.second);
        }
        help += "\n";
    }
    
    if (!cmd.aliases.isEmpty()) {
        help += "**Aliases:** ";
        help += cmd.aliases.join(", ") + "\n\n";
    }
    
    if (!cmd.allowedTools.isEmpty()) {
        help += "**Allowed Tools:** ";
        help += cmd.allowedTools.join(", ") + "\n";
    }
    
    return help;
}

QString SlashCommandManager::getAllCommandsHelp() const
{
    QString help = "# Available Commands\n\n";
    
    QMap<QString, QList<SlashCommand>> byCategory;
    QSet<QString> seen;
    
    for (const auto &cmd : m_commands) {
        if (seen.contains(cmd.name)) continue;
        byCategory[cmd.category].append(cmd);
        seen.insert(cmd.name);
    }
    
    for (auto it = byCategory.begin(); it != byCategory.end(); ++it) {
        help += QString("## %1\n\n").arg(it.key());
        for (const auto &cmd : it.value()) {
            help += QString("- **/%1**: %2\n").arg(cmd.name, cmd.description);
        }
        help += "\n";
    }
    
    return help;
}

QStringList SlashCommandManager::getCompletions(const QString &partial) const
{
    QStringList completions;
    QSet<QString> seen;
    
    for (const auto &cmd : m_commands) {
        if (seen.contains(cmd.name)) continue;
        
        if (cmd.name.startsWith(partial, Qt::CaseInsensitive)) {
            completions.append(QString("/%1").arg(cmd.name));
            seen.insert(cmd.name);
        }
    }
    
    completions.sort();
    return completions;
}

// ── Built-in Commands ───────────────────────────────────────────────────────

void SlashCommandManager::registerBuiltInCommands()
{
    // /code-review command
    {
        SlashCommand cmd;
        cmd.id = "code-review";
        cmd.name = "code-review";
        cmd.description = "Automated code review with multiple specialized agents";
        cmd.category = "development";
        cmd.aliases = {"review"};
        cmd.requiresContext = true;
        cmd.allowedTools = {"read_file", "analyze_code"};
        cmd.args = {{"file", "File to review"}, {"aspect", "Review aspect (optional)"}};
        
        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdCodeReview(args, ctx);
        });
    }
    
    // /new-sdk-app command
    {
        SlashCommand cmd;
        cmd.id = "new-sdk-app";
        cmd.name = "new-sdk-app";
        cmd.description = "Create a new Claude Agent SDK application";
        cmd.category = "development";
        cmd.args = {{"name", "Project name"}, {"language", "TypeScript or Python"}};
        
        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdNewSdkApp(args, ctx);
        });
    }
    
    // /feature-dev command
    {
        SlashCommand cmd;
        cmd.id = "feature-dev";
        cmd.name = "feature-dev";
        cmd.description = "Guided feature development workflow";
        cmd.category = "development";
        cmd.requiresContext = true;
        
        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdFeatureDev(args, ctx);
        });
    }
    
    // /plugin-create command
    {
        SlashCommand cmd;
        cmd.id = "plugin-create";
        cmd.name = "plugin-create";
        cmd.description = "Create a new plugin";
        cmd.category = "plugins";
        cmd.args = {{"name", "Plugin name"}, {"description", "Plugin description"}};
        
        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdPluginCreate(args, ctx);
        });
    }
    
    // /help command
    {
        SlashCommand cmd;
        cmd.id = "help";
        cmd.name = "help";
        cmd.description = "Show help for commands";
        cmd.category = "utilities";
        cmd.args = {{"command", "Command name (optional)"}};
        
        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdHelp(args, ctx);
        });
    }
    
    // /commit command
    {
        SlashCommand cmd;
        cmd.id = "commit";
        cmd.name = "commit";
        cmd.description = "Create a git commit with AI-generated message";
        cmd.category = "git";
        cmd.aliases = {"git-commit"};
        cmd.allowedTools = {"shell_tool"};
        
        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdCommit(args, ctx);
        });
    }
}

// ── Command History ─────────────────────────────────────────────────────────

QList<QString> SlashCommandManager::commandHistory(int maxItems) const
{
    int start = qMax(0, m_history.size() - maxItems);
    return m_history.mid(start);
}

void SlashCommandManager::clearHistory()
{
    m_history.clear();
}

// ── Built-in command implementations ────────────────────────────────────

SlashCommandResult SlashCommandManager::cmdCodeReview(const QStringList &args, 
                                                     const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.output = "Starting code review...";
    result.metadata["command"] = "code-review";
    
    if (!args.isEmpty()) {
        result.metadata["target"] = args.first();
    }
    
    emit commandStatusUpdated("code-review", "Analyzing code structure...");
    return result;
}

SlashCommandResult SlashCommandManager::cmdNewSdkApp(const QStringList &args, 
                                                    const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.output = "Creating new Agent SDK application...";
    result.metadata["command"] = "new-sdk-app";
    
    if (!args.isEmpty()) {
        result.metadata["projectName"] = args.first();
        result.metadata["language"] = args.size() > 1 ? args[1] : "TypeScript";
    }
    
    emit commandStatusUpdated("new-sdk-app", "Setting up project structure...");
    return result;
}

SlashCommandResult SlashCommandManager::cmdFeatureDev(const QStringList &args, 
                                                     const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.output = "Starting feature development workflow...";
    result.metadata["command"] = "feature-dev";
    
    emit commandStatusUpdated("feature-dev", "Analyzing requirements...");
    return result;
}

SlashCommandResult SlashCommandManager::cmdPluginCreate(const QStringList &args, 
                                                       const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.output = "Creating new plugin...";
    result.metadata["command"] = "plugin-create";
    
    if (!args.isEmpty()) {
        result.metadata["pluginName"] = args.first();
        result.metadata["description"] = args.size() > 1 ? args.join(" ").mid(args.first().length()) : "";
    }
    
    emit commandStatusUpdated("plugin-create", "Setting up plugin structure...");
    return result;
}

SlashCommandResult SlashCommandManager::cmdHelp(const QStringList &args, 
                                               const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    
    if (args.isEmpty()) {
        result.output = getAllCommandsHelp();
    } else {
        result.output = getCommandHelp(args.first());
    }
    
    return result;
}

SlashCommandResult SlashCommandManager::cmdCommit(const QStringList &args, 
                                                 const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.output = "Generating commit message...";
    result.metadata["command"] = "commit";
    
    emit commandStatusUpdated("commit", "Analyzing changes...");
    return result;
}

// ── Helper methods ───────────────────────────────────────────────────────────

QStringList SlashCommandManager::parseCommandLine(const QString &line) const
{
    return line.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
}

bool SlashCommandManager::validateCommand(const SlashCommand &cmd) const
{
    return !cmd.name.isEmpty() && !cmd.description.isEmpty();
}

QString SlashCommandManager::expandContext(const QString &text, const QJsonObject &context) const
{
    QString result = text;
    
    // Replace simple placeholders
    for (auto it = context.begin(); it != context.end(); ++it) {
        QString placeholder = QString("${%1}").arg(it.key());
        if (it.value().isString()) {
            result.replace(placeholder, it.value().toString());
        }
    }
    
    return result;
}
