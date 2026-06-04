#pragma once

#include "CommandSystem.h"
#include <QMap>
#include <QMutex>

namespace neurx {

/**
 * @class DefaultCommandSystem
 * @brief Default implementation of the command system
 */
class DefaultCommandSystem : public CommandSystem {
    Q_OBJECT
    
public:
    explicit DefaultCommandSystem(QObject* parent = nullptr);
    ~DefaultCommandSystem() override = default;
    
    // CommandSystem interface
    bool registerCommand(const CommandDefinition& definition,
                        CommandHandler handler) override;
    bool unregisterCommand(const QString& commandName) override;
    bool hasCommand(const QString& commandName) const override;
    
    QList<CommandDefinition> getAllCommands() const override;
    QList<CommandDefinition> getCommandsByScope(CommandScope scope) const override;
    QList<CommandDefinition> getCommandsByCategory(const QString& category) const override;
    QList<CommandDefinition> searchCommands(const QString& query) const override;
    CommandDefinition getCommandDefinition(const QString& commandName) const override;
    
    CommandResult executeCommand(const QString& input,
                                const CommandContext& context) override;
    QPair<QString, QVariantMap> parseCommand(const QString& input) const override;
    QString validateArguments(const QString& commandName,
                            const QVariantMap& args) const override;
    
    QString getCommandHelp(const QString& commandName) const override;
    QString getAllCommandsHelp() const override;
    QStringList getCommandExamples(const QString& commandName) const override;
    
    // Built-in commands
    void registerBuiltInCommands();
    
private:
    struct CommandEntry {
        CommandDefinition definition;
        CommandHandler handler;
    };
    
    // Command storage
    QMap<QString, CommandEntry> m_commands;
    QMap<QString, QString> m_aliases; // alias -> command name
    mutable QMutex m_mutex;
    
    // Helper methods
    QString resolveCommandName(const QString& input) const;
    bool checkRequirements(const CommandDefinition& def,
                          const CommandContext& context,
                          QString& error) const;
    QVariantMap extractArguments(const CommandDefinition& def,
                                const QStringList& rawArgs) const;
    
    // Built-in command handlers
    CommandResult handleHelpCommand(const CommandContext& context);
    CommandResult handleCommitCommand(const CommandContext& context);
    CommandResult handleCommitPushPRCommand(const CommandContext& context);
    CommandResult handleCodeReviewCommand(const CommandContext& context);
    CommandResult handleFeatureDevCommand(const CommandContext& context);
    CommandResult handlePluginCommand(const CommandContext& context);
};

} // namespace neurx
