#pragma once

#include <QObject>
#include <QMap>
#include <QList>
#include <QString>
#include <QVariantMap>
#include <functional>

/**
 * @class CommandManager
 * @brief Manages all commands in the editor
 * 
 * Features:
 * - Command registration and execution
 * - Keyboard shortcut management
 * - Command palette filtering
 */

struct Command {
    QString id;           // Unique command ID (e.g., "editor.action.undo")
    QString title;        // Display title (e.g., "Undo")
    QString category;     // Category (e.g., "Editor", "File", "View")
    QString shortcut;     // Keyboard shortcut (e.g., "Ctrl+Z")
    QString description;  // Help text
    std::function<bool()> handler;  // Command execution function
    
    QVariantMap toMap() const {
        return QVariantMap{
            {"id", id},
            {"title", title},
            {"category", category},
            {"shortcut", shortcut},
            {"description", description}
        };
    }
};

class CommandManager : public QObject {
    Q_OBJECT

public:
    static CommandManager* instance();
    
    // Command management
    void registerCommand(const Command& command);
    void unregisterCommand(const QString& commandId);
    
    // Command execution
    bool executeCommand(const QString& commandId);
    bool executeCommandWithArgs(const QString& commandId, const QVariantMap& args);
    
    // Query commands
    Command getCommand(const QString& commandId) const;
    QList<QVariantMap> getAllCommands() const;
    QList<QVariantMap> getCommandsByCategory(const QString& category) const;
    QList<QVariantMap> searchCommands(const QString& query) const;
    
    // Keyboard management
    bool bindKeyboardShortcut(const QString& commandId, const QString& keys);
    QString getKeyboardShortcut(const QString& commandId) const;
    QString getCommandByKeyboardShortcut(const QString& keys) const;

signals:
    void commandExecuted(const QString& commandId);
    void commandRegistered(const QString& commandId);
    void commandUnregistered(const QString& commandId);

private:
    CommandManager();
    ~CommandManager() override = default;
    
    Q_DISABLE_COPY_MOVE(CommandManager)
    
    QMap<QString, Command> m_commands;
    QMap<QString, QString> m_shortcuts;  // shortcut -> commandId
    QMap<QString, QString> m_keyBindings; // commandId -> shortcut
};
