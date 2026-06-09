#pragma once

#include <QString>
#include <QMap>
#include <QList>
#include <QJsonObject>
#include <QJsonArray>
#include <QObject>
#include <functional>

/**
 * @class SlashCommand
 * @brief Represents a slash command (e.g., /code-review, /new-sdk-app)
 */
struct SlashCommand {
    QString id;                          ///< Unique command ID
    QString name;                        ///< Command name (without leading /)
    QString description;                 ///< Human-readable description
    QString category;                    ///< Category (e.g., "development", "utilities")
    QList<QString> aliases;             ///< Alternative command names
    
    // Command metadata
    bool requiresContext{false};         ///< Requires file/workspace context
    QStringList allowedTools;            ///< Tools this command can use
    QList<QPair<QString, QString>> args; ///< Arguments (name, description) pairs
    
    // Execution
    QString workingDirectory;            ///< Working directory for execution
    int timeoutMs{30000};               ///< Execution timeout
    
    // Visibility and access control
    bool visible{true};                 ///< Show in command palette
    QString requiredCapability;         ///< Required agent capability
};

/**
 * @class SlashCommandResult
 * @brief Result of command execution
 */
struct SlashCommandResult {
    bool success;
    QString output;
    QString errorMessage;
    int exitCode{0};
    QJsonObject metadata;
    QList<QString> logs;
};

/**
 * @class SlashCommandManager
 * @brief Manages slash commands in the agent system
 * 
 * Implements Claude Code-style slash commands:
 * - /code-review, /new-sdk-app, /feature-dev, etc.
 * - Extensible command registration
 * - Command discovery and help
 * - Execution with context injection
 * - Command history and completion
 */
class SlashCommandManager : public QObject {
    Q_OBJECT

public:
    explicit SlashCommandManager(QObject *parent = nullptr);
    ~SlashCommandManager();

    // ── Command Registration ────────────────────────────────────────────────
    
    /**
     * @brief Register a slash command
     * @param command The command to register
     * @param handler Function to execute when command is invoked
     */
    void registerCommand(const SlashCommand &command,
                        std::function<SlashCommandResult(const QStringList &args, const QJsonObject &context)> handler);
    
    /**
     * @brief Unregister a slash command
     */
    void unregisterCommand(const QString &name);
    
    /**
     * @brief Check if a command exists
     */
    bool hasCommand(const QString &name) const;

    // ── Command Discovery ────────────────────────────────────────────────────
    
    /**
     * @brief Get all registered commands
     */
    QList<SlashCommand> allCommands() const;
    
    /**
     * @brief Get commands by category
     */
    QList<SlashCommand> commandsByCategory(const QString &category) const;
    
    /**
     * @brief Search commands by name or description
     */
    QList<SlashCommand> searchCommands(const QString &query) const;
    
    /**
     * @brief Get command by name or alias
     */
    SlashCommand getCommand(const QString &name) const;

    // ── Command Execution ───────────────────────────────────────────────────
    
    /**
     * @brief Execute a slash command
     * @param commandLine Full command line (e.g., "/code-review file.ts")
     * @param context Context data (file content, selection, etc.)
     * @return Execution result
     */
    SlashCommandResult executeCommand(const QString &commandLine, const QJsonObject &context);
    
    /**
     * @brief Execute a command by name with arguments
     */
    SlashCommandResult executeCommand(const QString &name, const QStringList &args, 
                                     const QJsonObject &context);

    // ── Help and Documentation ───────────────────────────────────────────────
    
    /**
     * @brief Get help text for a command
     */
    QString getCommandHelp(const QString &name) const;
    
    /**
     * @brief Get formatted list of all commands
     */
    QString getAllCommandsHelp() const;
    
    /**
     * @brief Get command completion suggestions
     */
    QStringList getCompletions(const QString &partial) const;

    // ── Built-in Commands ───────────────────────────────────────────────────
    
    /**
     * @brief Register all built-in commands
     */
    void registerBuiltInCommands();

    // ── Command History ─────────────────────────────────────────────────────
    
    /**
     * @brief Get command history
     */
    QList<QString> commandHistory(int maxItems = 50) const;
    
    /**
     * @brief Clear command history
     */
    void clearHistory();

signals:
    /**
     * @brief Emitted before command execution
     */
    void commandExecuting(const QString &name, const QStringList &args);
    
    /**
     * @brief Emitted after command completes
     */
    void commandCompleted(const QString &name, const SlashCommandResult &result);
    
    /**
     * @brief Emitted when command fails
     */
    void commandFailed(const QString &name, const QString &error);
    
    /**
     * @brief Emitted for status/progress updates
     */
    void commandStatusUpdated(const QString &name, const QString &status);

private:
    // ── Built-in command implementations ────────────────────────────────────
    SlashCommandResult cmdCodeReview(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdNewSdkApp(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdFeatureDev(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdPluginCreate(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdHelp(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdCommit(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdCommitPushPR(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdCleanGone(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdWorkspaceStatus(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdContext(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdIssueLifecycle(const QStringList &args, const QJsonObject &context);
    SlashCommandResult cmdIssueActivity(const QStringList &args, const QJsonObject &context);
    
    // ── Helper methods ───────────────────────────────────────────────────────
    QStringList parseCommandLine(const QString &line) const;
    bool validateCommand(const SlashCommand &cmd) const;
    QString expandContext(const QString &text, const QJsonObject &context) const;
    QMap<QString, QString> parseKeyValueArgs(const QStringList &args) const;

    // ── Data members ─────────────────────────────────────────────────────────
    QMap<QString, SlashCommand> m_commands;
    QMap<QString, std::function<SlashCommandResult(const QStringList &, const QJsonObject &)>> m_handlers;
    QList<QString> m_history;
};
