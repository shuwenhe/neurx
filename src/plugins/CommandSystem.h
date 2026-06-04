#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <functional>
#include <memory>

/**
 * @file CommandSystem.h
 * @brief Slash command system inspired by Claude Code
 * 
 * Implements:
 * - Command registration and discovery
 * - Command execution with context
 * - Command aliases and shortcuts
 * - Command help and documentation
 * - Scope-based availability
 */

namespace neurx {

/**
 * @enum CommandScope
 * @brief Where a command can be executed
 */
enum class CommandScope {
    Global,       // Available everywhere
    Workspace,    // Only when workspace is open
    Chat,         // Only in chat context
    Editor,       // Only when editor is active
    Terminal      // Only in terminal context
};

/**
 * @enum CommandPriority
 * @brief Display priority for commands
 */
enum class CommandPriority {
    Low = 0,
    Normal = 50,
    High = 100,
    Critical = 200
};

/**
 * @struct CommandParameter
 * @brief Definition of a command parameter
 */
struct CommandParameter {
    QString name;                   // Parameter name
    QString description;            // Parameter description
    QString type;                   // Type: string, number, boolean, file, etc.
    bool required;                  // Is required?
    QVariant defaultValue;          // Default value
    QStringList choices;            // Valid choices (if any)
    QString pattern;                // Regex pattern for validation
};

/**
 * @struct CommandDefinition
 * @brief Complete command definition
 */
struct CommandDefinition {
    QString name;                   // Command name (without /)
    QString description;            // Short description
    QString longDescription;        // Detailed description
    QStringList aliases;            // Alternative names
    CommandScope scope;             // Execution scope
    CommandPriority priority;       // Display priority
    
    // Parameters
    QList<CommandParameter> parameters;
    bool allowExtraArgs;            // Allow additional arguments
    
    // Requirements
    bool requiresWorkspace;         // Needs workspace context
    bool requiresInternet;          // Needs internet connection
    bool requiresGit;               // Needs git repository
    QStringList requiredPermissions; // Required permissions
    
    // UI
    QString icon;                   // Icon identifier
    QString category;               // Category for grouping
    QStringList tags;               // Tags for search
    
    // Execution
    QString agentId;                // Agent to invoke
    QString skillId;                // Skill to use
    QString promptTemplate;         // Prompt template
    QVariantMap metadata;           // Additional metadata
    
    // Examples
    QStringList examples;           // Usage examples
    
    QJsonObject toJson() const;
    static CommandDefinition fromJson(const QJsonObject& json);
};

/**
 * @struct CommandContext
 * @brief Context provided to command handlers
 */
struct CommandContext {
    // User input
    QString input;                  // Raw input
    QString command;                // Command name
    QVariantMap args;               // Parsed arguments
    QStringList rawArgs;            // Raw arguments
    
    // Workspace
    QString workspacePath;          // Current workspace
    QString activeFile;             // Active file path
    QString activeEditor;           // Active editor ID
    QStringList selectedFiles;      // Selected files
    
    // Session
    QString sessionId;              // Current session ID
    QString userId;                 // User ID
    QVariantMap sessionData;        // Session data
    
    // Agent state
    QStringList conversationHistory; // Recent conversation
    QVariantMap agentState;         // Agent state
    
    // Settings
    QVariantMap settings;           // Command settings
    
    QJsonObject toJson() const;
    static CommandContext fromJson(const QJsonObject& json);
};

/**
 * @struct CommandResult
 * @brief Result from command execution
 */
struct CommandResult {
    bool success;                   // Was successful?
    QString message;                // Result message
    QString output;                 // Command output
    QString error;                  // Error message
    QVariantMap data;               // Result data
    bool showInChat;                // Display in chat?
    
    CommandResult() : success(false), showInChat(true) {}
    explicit CommandResult(bool ok) : success(ok), showInChat(true) {}
    
    QJsonObject toJson() const;
    static CommandResult fromJson(const QJsonObject& json);
};

/**
 * @typedef CommandHandler
 * @brief Function signature for command handlers
 */
using CommandHandler = std::function<CommandResult(const CommandContext&)>;

/**
 * @class CommandSystem
 * @brief Manages slash commands
 */
class CommandSystem : public QObject {
    Q_OBJECT
    
public:
    explicit CommandSystem(QObject* parent = nullptr);
    virtual ~CommandSystem() = default;
    
    // ── Registration ────────────────────────────────────────────
    
    /**
     * @brief Register a command
     * @param definition Command definition
     * @param handler Command handler function
     * @return true if registered successfully
     */
    virtual bool registerCommand(const CommandDefinition& definition,
                                CommandHandler handler) = 0;
    
    /**
     * @brief Unregister a command
     * @param commandName Command name
     * @return true if unregistered successfully
     */
    virtual bool unregisterCommand(const QString& commandName) = 0;
    
    /**
     * @brief Check if command is registered
     * @param commandName Command name
     * @return true if registered
     */
    virtual bool hasCommand(const QString& commandName) const = 0;
    
    // ── Discovery ───────────────────────────────────────────────
    
    /**
     * @brief Get all registered commands
     * @return List of command definitions
     */
    virtual QList<CommandDefinition> getAllCommands() const = 0;
    
    /**
     * @brief Get commands by scope
     * @param scope Command scope
     * @return List of matching commands
     */
    virtual QList<CommandDefinition> getCommandsByScope(CommandScope scope) const = 0;
    
    /**
     * @brief Get commands by category
     * @param category Category name
     * @return List of matching commands
     */
    virtual QList<CommandDefinition> getCommandsByCategory(const QString& category) const = 0;
    
    /**
     * @brief Search commands
     * @param query Search query
     * @return List of matching commands
     */
    virtual QList<CommandDefinition> searchCommands(const QString& query) const = 0;
    
    /**
     * @brief Get command definition
     * @param commandName Command name or alias
     * @return Command definition (empty if not found)
     */
    virtual CommandDefinition getCommandDefinition(const QString& commandName) const = 0;
    
    // ── Execution ───────────────────────────────────────────────
    
    /**
     * @brief Execute a command
     * @param input Command input (e.g., "/commit -m 'message'")
     * @param context Execution context
     * @return Command result
     */
    virtual CommandResult executeCommand(const QString& input,
                                        const CommandContext& context) = 0;
    
    /**
     * @brief Parse command input
     * @param input Command input
     * @return Parsed command name and arguments
     */
    virtual QPair<QString, QVariantMap> parseCommand(const QString& input) const = 0;
    
    /**
     * @brief Validate command arguments
     * @param commandName Command name
     * @param args Arguments to validate
     * @return Error message (empty if valid)
     */
    virtual QString validateArguments(const QString& commandName,
                                     const QVariantMap& args) const = 0;
    
    // ── Help ────────────────────────────────────────────────────
    
    /**
     * @brief Get command help text
     * @param commandName Command name
     * @return Help text
     */
    virtual QString getCommandHelp(const QString& commandName) const = 0;
    
    /**
     * @brief Get all command help
     * @return Complete help text
     */
    virtual QString getAllCommandsHelp() const = 0;
    
    /**
     * @brief Get command examples
     * @param commandName Command name
     * @return List of examples
     */
    virtual QStringList getCommandExamples(const QString& commandName) const = 0;
    
signals:
    /**
     * @brief Emitted when command is executed
     * @param commandName Command name
     * @param success Whether execution was successful
     */
    void commandExecuted(const QString& commandName, bool success);
    
    /**
     * @brief Emitted when command is registered
     * @param commandName Command name
     */
    void commandRegistered(const QString& commandName);
    
    /**
     * @brief Emitted when command is unregistered
     * @param commandName Command name
     */
    void commandUnregistered(const QString& commandName);
};

// Utility functions
QString commandScopeToString(CommandScope scope);
CommandScope stringToCommandScope(const QString& str);
QString commandPriorityToString(CommandPriority priority);
CommandPriority stringToCommandPriority(const QString& str);

} // namespace neurx
