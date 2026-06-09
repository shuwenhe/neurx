#include "agent/SlashCommandManager.h"
#include "agent/AutoCommentGenerator.h"
#include "agent/IssueActivityMonitor.h"
#include "agent/IssueLifecycleRulesEngine.h"
#include <QDebug>
#include <QDateTime>
#include <QStringList>
#include <QRegularExpression>
#include <QJsonDocument>

namespace {

IssueLifecycleRulesEngine::LifecycleLabel labelFromText(const QString &text)
{
    const QString normalized = text.trimmed().toLower();
    if (normalized == QStringLiteral("needs-repro") || normalized == QStringLiteral("needs_repro")) {
        return IssueLifecycleRulesEngine::NeedsRepro;
    }
    if (normalized == QStringLiteral("needs-info") || normalized == QStringLiteral("needs_info")) {
        return IssueLifecycleRulesEngine::NeedsInfo;
    }
    if (normalized == QStringLiteral("stale")) {
        return IssueLifecycleRulesEngine::Stale;
    }
    if (normalized == QStringLiteral("autoclose") || normalized == QStringLiteral("auto-close")) {
        return IssueLifecycleRulesEngine::Autoclose;
    }
    if (normalized == QStringLiteral("invalid")) {
        return IssueLifecycleRulesEngine::Invalid;
    }
    return IssueLifecycleRulesEngine::Invalid;
}

QString lifecycleLabelToText(IssueLifecycleRulesEngine::LifecycleLabel label)
{
    switch (label) {
        case IssueLifecycleRulesEngine::Invalid: return QStringLiteral("invalid");
        case IssueLifecycleRulesEngine::NeedsRepro: return QStringLiteral("needs-repro");
        case IssueLifecycleRulesEngine::NeedsInfo: return QStringLiteral("needs-info");
        case IssueLifecycleRulesEngine::Stale: return QStringLiteral("stale");
        case IssueLifecycleRulesEngine::Autoclose: return QStringLiteral("autoclose");
    }
    return QStringLiteral("invalid");
}

AutoCommentGenerator::CommentType commentTypeForLifecycle(IssueLifecycleRulesEngine::LifecycleLabel label)
{
    switch (label) {
        case IssueLifecycleRulesEngine::NeedsInfo: return AutoCommentGenerator::NeedsInfoRequest;
        case IssueLifecycleRulesEngine::NeedsRepro: return AutoCommentGenerator::NeedsReproRequest;
        case IssueLifecycleRulesEngine::Stale: return AutoCommentGenerator::StaleWarning;
        case IssueLifecycleRulesEngine::Autoclose: return AutoCommentGenerator::AutoCloseWarning;
        case IssueLifecycleRulesEngine::Invalid: return AutoCommentGenerator::Custom;
    }
    return AutoCommentGenerator::Custom;
}

QStringList splitCsv(const QString &value)
{
    QStringList out;
    for (const QString &part : value.split(',', Qt::SkipEmptyParts)) {
        const QString trimmed = part.trimmed();
        if (!trimmed.isEmpty()) {
            out.append(trimmed);
        }
    }
    return out;
}

}

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
        cmd.allowedTools = {"shell_tool", "git_workflow_agent"};

        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdCommit(args, ctx);
        });
    }

    // /commit-push-pr command
    {
        SlashCommand cmd;
        cmd.id = "commit-push-pr";
        cmd.name = "commit-push-pr";
        cmd.description = "Commit, push, and create a pull request";
        cmd.category = "git";
        cmd.aliases = {"pr"};
        cmd.allowedTools = {"shell_tool", "git_workflow_agent"};

        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdCommitPushPR(args, ctx);
        });
    }

    // /clean_gone command
    {
        SlashCommand cmd;
        cmd.id = "clean_gone";
        cmd.name = "clean_gone";
        cmd.description = "Clean up local branches that have been deleted on the remote";
        cmd.category = "git";
        cmd.allowedTools = {"shell_tool", "git_workflow_agent"};

        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdCleanGone(args, ctx);
        });
    }

    // /workspace command
    {
        SlashCommand cmd;
        cmd.id = "workspace";
        cmd.name = "workspace";
        cmd.description = "Show current workspace and conversation context status";
        cmd.category = "utilities";
        cmd.aliases = {"workspace-status"};

        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdWorkspaceStatus(args, ctx);
        });
    }

    // /context command
    {
        SlashCommand cmd;
        cmd.id = "context";
        cmd.name = "context";
        cmd.description = "Show the currently injected context items";
        cmd.category = "utilities";
        cmd.aliases = {"context-status"};

        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdContext(args, ctx);
        });
    }

    // /issue-lifecycle command
    {
        SlashCommand cmd;
        cmd.id = "issue-lifecycle";
        cmd.name = "issue-lifecycle";
        cmd.description = "Analyze a GitHub issue and generate a lifecycle comment draft";
        cmd.category = "issues";
        cmd.aliases = {"issue-comment", "issue-auto"};
        cmd.args = {
            {"issue_number", "Issue number"},
            {"labels", "Comma-separated labels"},
            {"days", "Days inactive"},
            {"upvotes", "Upvote count"},
            {"state", "Issue state"},
            {"reason", "State reason or closure reason"},
            {"missing_info", "Comma-separated missing info hints"},
            {"duplicate_of", "Duplicate issue number"}
        };

        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdIssueLifecycle(args, ctx);
        });
    }

    // /issue-activity command
    {
        SlashCommand cmd;
        cmd.id = "issue-activity";
        cmd.name = "issue-activity";
        cmd.description = "Evaluate issue activity and generate stale/close recommendations";
        cmd.category = "issues";
        cmd.aliases = {"issue-monitor", "stale-check"};
        cmd.args = {
            {"issue_number", "Issue number"},
            {"title", "Issue title"},
            {"state", "Issue state"},
            {"days", "Days inactive"},
            {"upvotes", "Upvote count"},
            {"assignees", "Assignee count"},
            {"labels", "Comma-separated labels"},
            {"process_assigned", "Process assigned issues (true/false)"}
        };

        registerCommand(cmd, [this](const QStringList &args, const QJsonObject &ctx) {
            return cmdIssueActivity(args, ctx);
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
    result.output = "Generating commit message and creating commit...";
    result.metadata["command"] = "commit";
    result.metadata["agent"] = "git-workflow-agent";

    emit commandStatusUpdated("commit", "Analyzing changes and generating message...");
    return result;
}

SlashCommandResult SlashCommandManager::cmdCommitPushPR(const QStringList &args,
                                                       const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.output = "Starting commit-push-PR workflow...";
    result.metadata["command"] = "commit-push-pr";
    result.metadata["agent"] = "git-workflow-agent";

    emit commandStatusUpdated("commit-push-pr", "Initializing git workflow...");
    return result;
}

SlashCommandResult SlashCommandManager::cmdCleanGone(const QStringList &args,
                                                  const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.output = "Cleaning up gone branches...";
    result.metadata["command"] = "clean_gone";
    result.metadata["agent"] = "git-workflow-agent";

    emit commandStatusUpdated("clean_gone", "Identifying merged branches...");
    return result;
}

SlashCommandResult SlashCommandManager::cmdWorkspaceStatus(const QStringList &args,
                                                          const QJsonObject &context)
{
    Q_UNUSED(args);
    SlashCommandResult result;
    result.success = true;
    result.metadata["command"] = "workspace";
    result.metadata["workspaceRoot"] = context.value("workspaceRoot").toString();
    result.metadata["activeModel"] = context.value("activeModel").toString();
    result.metadata["historySize"] = context.value("historySize").toInt();
    result.metadata["contextSize"] = context.value("contextSize").toInt();
    result.metadata["contextCount"] = context.value("contextCount").toInt();

    result.output = QStringLiteral(
        "Workspace: %1\nModel: %2\nHistory messages: %3\nContext items: %4\nContext size: %5"
    ).arg(
        result.metadata["workspaceRoot"].toString(),
        result.metadata["activeModel"].toString(),
        QString::number(result.metadata["historySize"].toInt()),
        QString::number(result.metadata["contextCount"].toInt()),
        QString::number(result.metadata["contextSize"].toInt())
    );
    return result;
}

SlashCommandResult SlashCommandManager::cmdContext(const QStringList &args,
                                                  const QJsonObject &context)
{
    SlashCommandResult result;
    result.success = true;
    result.metadata["command"] = "context";
    result.metadata["contextCount"] = context.value("contextCount").toInt();
    result.metadata["contextSize"] = context.value("contextSize").toInt();

    const bool showJson = args.contains(QStringLiteral("--json"))
        || args.contains(QStringLiteral("json"))
        || args.contains(QStringLiteral("raw"));

    const QJsonArray items = context.value("contextItems").toArray();
    if (items.isEmpty()) {
        result.output = QStringLiteral("No injected context items are currently available.");
        return result;
    }

    if (showJson) {
        result.output = QString::fromUtf8(
            QJsonDocument(items).toJson(QJsonDocument::Indented)
        );
        return result;
    }

    QString output;
    output += QStringLiteral("Context items: %1\n").arg(items.size());
    output += QStringLiteral("Context size: %1 tokens (estimated)\n\n")
                  .arg(result.metadata["contextSize"].toInt());

    for (int i = 0; i < items.size(); ++i) {
        const QJsonObject item = items.at(i).toObject();
        const QString id = item.value("id").toString();
        const QString type = item.value("type").toString();
        const QString source = item.value("source").toString();
        const int priority = item.value("priority").toInt();
        const QString timestamp = item.value("timestamp").toString();
        const QString content = item.value("content").toString().simplified();
        const QString preview = content.size() > 160 ? content.left(160) + QStringLiteral("...") : content;

        output += QStringLiteral("%1. [%2] %3\n").arg(i + 1).arg(type, source);
        output += QStringLiteral("   id: %1 | priority: %2 | timestamp: %3\n")
                      .arg(id, QString::number(priority), timestamp);
        if (!preview.isEmpty()) {
            output += QStringLiteral("   content: %1\n").arg(preview);
        }

        const QJsonObject metadata = item.value("metadata").toObject();
        if (!metadata.isEmpty()) {
            output += QStringLiteral("   metadata: ");
            QStringList metaPairs;
            for (auto it = metadata.begin(); it != metadata.end(); ++it) {
                metaPairs.append(QStringLiteral("%1=%2").arg(it.key(), it.value().toVariant().toString()));
            }
            output += metaPairs.join(QStringLiteral(", ")) + QStringLiteral("\n");
        }

        output += QStringLiteral("\n");
    }

    result.output = output.trimmed();
    return result;
}

SlashCommandResult SlashCommandManager::cmdIssueLifecycle(const QStringList &args,
                                                         const QJsonObject &context)
{
    const QMap<QString, QString> kv = parseKeyValueArgs(args);

    auto readString = [&](const QString &key, const QString &fallback = QString()) -> QString {
        if (kv.contains(key)) {
            return kv.value(key);
        }

        QString ctxKey = key;
        if (!ctxKey.contains('_')) {
            ctxKey.replace('-', '_');
        }

        const QJsonValue value = context.value(ctxKey);
        if (value.isString()) {
            return value.toString();
        }
        if (value.isDouble()) {
            return QString::number(value.toDouble());
        }
        if (value.isBool()) {
            return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
        }
        return fallback;
    };

    auto readLabels = [&]() -> QStringList {
        if (kv.contains(QStringLiteral("labels"))) {
            return splitCsv(kv.value(QStringLiteral("labels")));
        }

        const QJsonValue value = context.value(QStringLiteral("labels"));
        if (value.isArray()) {
            QStringList labels;
            for (const auto &item : value.toArray()) {
                const QString label = item.isObject()
                    ? item.toObject().value(QStringLiteral("name")).toString()
                    : item.toString();
                if (!label.trimmed().isEmpty()) {
                    labels.append(label.trimmed());
                }
            }
            return labels;
        }

        return splitCsv(value.toString());
    };

    const bool showJson = args.contains(QStringLiteral("--json"))
        || args.contains(QStringLiteral("json"))
        || args.contains(QStringLiteral("raw"));

    const int issueNumber = readString(QStringLiteral("issue_number"),
                                       readString(QStringLiteral("issue"),
                                                  readString(QStringLiteral("number"), QStringLiteral("0")))).toInt();
    const int effectiveIssueNumber = issueNumber > 0 ? issueNumber : 1;
    const QString title = readString(QStringLiteral("title"), context.value(QStringLiteral("title")).toString());
    const QString body = readString(QStringLiteral("body"), context.value(QStringLiteral("body")).toString());
    const QString state = readString(QStringLiteral("state"), QStringLiteral("open")).toLower();
    const QString stateReason = readString(QStringLiteral("reason"),
                                          readString(QStringLiteral("state_reason"))).toLower();
    const QString style = readString(QStringLiteral("style"), QStringLiteral("friendly"));
    const int daysInactive = readString(QStringLiteral("days"), QStringLiteral("0")).toInt();
    const int upvotes = readString(QStringLiteral("upvotes"), QStringLiteral("0")).toInt();
    const int duplicateOf = readString(QStringLiteral("duplicate_of"), QStringLiteral("0")).toInt();
    const QString reason = readString(QStringLiteral("reason_text"), readString(QStringLiteral("reason")));
    const QStringList labels = readLabels();
    const QStringList missingInfo = splitCsv(readString(QStringLiteral("missing_info")));

    QJsonObject issueSnapshot;
    issueSnapshot["number"] = effectiveIssueNumber;
    issueSnapshot["title"] = title;
    issueSnapshot["body"] = body;
    issueSnapshot["state"] = state;
    issueSnapshot["state_reason"] = stateReason;
    issueSnapshot["upvotes"] = upvotes;
    issueSnapshot["updated_at"] = QDateTime::currentDateTimeUtc().addDays(-qMax(0, daysInactive)).toString(Qt::ISODate);
    issueSnapshot["created_at"] = QDateTime::currentDateTimeUtc().addDays(-qMax(0, daysInactive + 3)).toString(Qt::ISODate);

    QJsonArray labelsArray;
    for (const QString &label : labels) {
        labelsArray.append(QJsonObject{{QStringLiteral("name"), label}});
    }
    issueSnapshot["labels"] = labelsArray;

    IssueLifecycleRulesEngine engine;
    engine.ingestIssueSnapshot(effectiveIssueNumber, issueSnapshot);
    engine.setIssueUpvotes(effectiveIssueNumber, upvotes);
    engine.setMaxInactivityDays(qMax(1, daysInactive > 0 ? daysInactive : 30));
    engine.setAutoTransitionEnabled(false);

    const auto currentLabel = labelFromText(stateReason.isEmpty() && !labels.isEmpty()
        ? labels.first()
        : stateReason);
    const auto recommendedLabel = engine.evaluatePolicy(effectiveIssueNumber);

    AutoCommentGenerator generator;
    generator.setCommentStyle(style);

    QString comment;
    if (duplicateOf > 0) {
        comment = generator.generateDuplicateComment(duplicateOf);
    } else {
        switch (commentTypeForLifecycle(recommendedLabel)) {
            case AutoCommentGenerator::NeedsInfoRequest:
                comment = generator.generateNeedsInfoComment(missingInfo.isEmpty()
                    ? QStringList{QStringLiteral("environment"), QStringLiteral("steps to reproduce")}
                    : missingInfo);
                break;
            case AutoCommentGenerator::NeedsReproRequest:
                comment = generator.generateNeedsReproComment();
                break;
            case AutoCommentGenerator::StaleWarning:
                comment = generator.generateStaleWarningComment(qMax(1, daysInactive));
                break;
            case AutoCommentGenerator::AutoCloseWarning:
                comment = generator.generateAutoCloseComment(reason.isEmpty()
                    ? QStringLiteral("inactive for too long")
                    : reason);
                break;
            case AutoCommentGenerator::Custom:
            default:
                comment = generator.generateLifecycleComment(effectiveIssueNumber,
                    lifecycleLabelToText(recommendedLabel), qMax(0, daysInactive));
                break;
        }
    }

    QJsonObject payload;
    payload["command"] = "issue-lifecycle";
    payload["issueNumber"] = issueNumber;
    payload["title"] = title;
    payload["currentLabel"] = lifecycleLabelToText(currentLabel);
    payload["recommendedLabel"] = lifecycleLabelToText(recommendedLabel);
    payload["daysInactive"] = daysInactive;
    payload["upvotes"] = upvotes;
    payload["duplicateOf"] = duplicateOf;
    payload["state"] = state;
    payload["stateReason"] = stateReason;
    payload["comment"] = comment;
    payload["issueSnapshot"] = issueSnapshot;

    SlashCommandResult result;
    result.success = true;
    result.metadata = payload;

    if (showJson) {
        result.output = QString::fromUtf8(QJsonDocument(payload).toJson(QJsonDocument::Indented));
    } else {
        result.output = QStringLiteral(
            "Issue #%1 lifecycle\n"
            "Title: %2\n"
            "Current: %3\n"
            "Recommended: %4\n"
            "Days inactive: %5\n"
            "Upvotes: %6\n\n"
            "Comment draft:\n%7"
        ).arg(
            QString::number(issueNumber),
            title.isEmpty() ? QStringLiteral("(untitled)") : title,
            payload["currentLabel"].toString(),
            payload["recommendedLabel"].toString(),
            QString::number(daysInactive),
            QString::number(upvotes),
            comment
        );
    }

    return result;
}

SlashCommandResult SlashCommandManager::cmdIssueActivity(const QStringList &args,
                                                        const QJsonObject &context)
{
    const QMap<QString, QString> kv = parseKeyValueArgs(args);

    auto readString = [&](const QString &key, const QString &fallback = QString()) -> QString {
        if (kv.contains(key)) {
            return kv.value(key);
        }

        QString ctxKey = key;
        if (!ctxKey.contains('_')) {
            ctxKey.replace('-', '_');
        }

        const QJsonValue value = context.value(ctxKey);
        if (value.isString()) return value.toString();
        if (value.isDouble()) return QString::number(value.toDouble());
        if (value.isBool()) return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
        return fallback;
    };

    auto readBool = [&](const QString &key, bool fallback = false) -> bool {
        if (kv.contains(key)) {
            const QString value = kv.value(key).toLower();
            return value == QStringLiteral("1")
                || value == QStringLiteral("true")
                || value == QStringLiteral("yes")
                || value == QStringLiteral("on");
        }
        QString ctxKey = key;
        if (!ctxKey.contains('_')) {
            ctxKey.replace('-', '_');
        }
        return context.value(ctxKey).toBool(fallback);
    };

    const bool showJson = args.contains(QStringLiteral("--json"))
        || args.contains(QStringLiteral("json"))
        || args.contains(QStringLiteral("raw"));

    const int issueNumber = readString(QStringLiteral("issue_number"),
                                       readString(QStringLiteral("issue"),
                                                  readString(QStringLiteral("number"), QStringLiteral("0")))).toInt();
    const int effectiveIssueNumber = issueNumber > 0 ? issueNumber : 1;
    const QString title = readString(QStringLiteral("title"));
    const QString state = readString(QStringLiteral("state"), QStringLiteral("open")).toLower();
    const QString stateReason = readString(QStringLiteral("reason"),
                                          readString(QStringLiteral("state_reason"))).toLower();
    const int daysInactive = readString(QStringLiteral("days"), QStringLiteral("0")).toInt();
    const int upvotes = readString(QStringLiteral("upvotes"), QStringLiteral("0")).toInt();
    const int assignees = readString(QStringLiteral("assignees"), QStringLiteral("0")).toInt();
    const int staleDays = readString(QStringLiteral("stale_days"), QStringLiteral("14")).toInt();
    const int closeDays = readString(QStringLiteral("close_days"), QStringLiteral("7")).toInt();
    const int preserveThreshold = readString(QStringLiteral("upvote_threshold"), QStringLiteral("10")).toInt();
    const bool processAssigned = readBool(QStringLiteral("process_assigned"), false);
    const QStringList labels = splitCsv(readString(QStringLiteral("labels")));

    IssueActivityMonitor::IssueState issueState;
    issueState.number = effectiveIssueNumber;
    issueState.title = title;
    issueState.state = state;
    issueState.stateReason = stateReason;
    issueState.createdAt = QDateTime::currentDateTime().addDays(-qMax(0, daysInactive + 3));
    issueState.updatedAt = QDateTime::currentDateTime().addDays(-qMax(0, daysInactive));
    issueState.lastActivityAt = issueState.updatedAt;
    issueState.assigneeCount = assignees;
    issueState.reactionCount = upvotes;
    issueState.upvoteCount = upvotes;
    for (const QString &label : labels) {
        issueState.labels.insert(label.trimmed());
    }

    IssueActivityMonitor::MonitorConfig config;
    config.staleDays = qMax(1, staleDays);
    config.closeExpirationDays = qMax(1, closeDays);
    config.upvoteThresholdForPreservation = qMax(0, preserveThreshold);
    config.processAssignedIssues = processAssigned;

    IssueActivityMonitor monitor;
    monitor.updateIssueState(issueState);

    const bool stale = monitor.isStaleIssue(issueState, config);
    const bool preserve = monitor.shouldPreserveIssue(issueState, config);
    const bool expired = (issueState.labels.contains(QStringLiteral("stale"))
        || issueState.labels.contains(QStringLiteral("autoclose")))
        && daysInactive >= (config.staleDays + config.closeExpirationDays);

    QString recommendation;
    QString action;
    QString comment;

    AutoCommentGenerator generator;
    if (stale && !preserve) {
        action = QStringLiteral("mark-stale");
        recommendation = QStringLiteral("Issue should be marked stale.");
        comment = generator.generateStaleWarningComment(daysInactive);
    } else if (expired && !preserve) {
        action = QStringLiteral("close");
        recommendation = QStringLiteral("Issue can be closed due to inactivity.");
        comment = generator.generateAutoCloseComment(QStringLiteral("inactive for %1 days").arg(daysInactive));
    } else if (preserve) {
        action = QStringLiteral("preserve");
        recommendation = QStringLiteral("Issue should be preserved.");
        comment = QStringLiteral("Preserve due to high engagement or assignment.");
    } else {
        action = QStringLiteral("no-action");
        recommendation = QStringLiteral("No lifecycle action needed.");
        comment = generator.generateLifecycleComment(effectiveIssueNumber, QStringLiteral("stale"), daysInactive);
    }

    QJsonObject payload;
    payload["command"] = "issue-activity";
    payload["issueNumber"] = issueNumber;
    payload["title"] = title;
    payload["state"] = state;
    payload["daysInactive"] = daysInactive;
    payload["upvotes"] = upvotes;
    payload["assignees"] = assignees;
    payload["stale"] = stale;
    payload["preserve"] = preserve;
    payload["expired"] = expired;
    payload["action"] = action;
    payload["recommendation"] = recommendation;
    payload["comment"] = comment;
    payload["monitorStats"] = monitor.getMonitoringStatistics();

    SlashCommandResult result;
    result.success = true;
    result.metadata = payload;

    if (showJson) {
        result.output = QString::fromUtf8(QJsonDocument(payload).toJson(QJsonDocument::Indented));
    } else {
        result.output = QStringLiteral(
            "Issue #%1 activity\n"
            "Title: %2\n"
            "State: %3\n"
            "Inactive days: %4\n"
            "Upvotes: %5\n"
            "Assignees: %6\n"
            "Action: %7\n\n"
            "%8\n\n"
            "Comment draft:\n%9"
        ).arg(
            QString::number(issueNumber),
            title.isEmpty() ? QStringLiteral("(untitled)") : title,
            state,
            QString::number(daysInactive),
            QString::number(upvotes),
            QString::number(assignees),
            action,
            recommendation,
            comment
        );
    }

    return result;
}

// ── Helper methods ───────────────────────────────────────────────────────────

QStringList SlashCommandManager::parseCommandLine(const QString &line) const
{
    return line.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
}

QMap<QString, QString> SlashCommandManager::parseKeyValueArgs(const QStringList &args) const
{
    QMap<QString, QString> map;
    for (const QString &arg : args) {
        const int eq = arg.indexOf('=');
        if (eq <= 0) {
            continue;
        }
        const QString key = arg.left(eq).trimmed();
        const QString value = arg.mid(eq + 1).trimmed();
        if (!key.isEmpty()) {
            map[key] = value;
        }
    }
    return map;
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
