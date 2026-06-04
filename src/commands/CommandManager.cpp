#include "commands/CommandManager.h"
#include <QDebug>

CommandManager* g_commandManager = nullptr;

CommandManager* CommandManager::instance()
{
    if (!g_commandManager) {
        g_commandManager = new CommandManager();
    }
    return g_commandManager;
}

CommandManager::CommandManager()
{
}

void CommandManager::registerCommand(const Command& command)
{
    if (m_commands.contains(command.id)) {
        qWarning() << "Command already registered:" << command.id;
        return;
    }
    
    m_commands[command.id] = command;
    
    // Register keyboard shortcut if present
    if (!command.shortcut.isEmpty()) {
        m_keyBindings[command.id] = command.shortcut;
        m_shortcuts[command.shortcut] = command.id;
    }
    
    emit commandRegistered(command.id);
    qInfo() << "Command registered:" << command.id;
}

void CommandManager::unregisterCommand(const QString& commandId)
{
    if (!m_commands.contains(commandId)) {
        qWarning() << "Command not found:" << commandId;
        return;
    }
    
    // Remove keyboard binding if exists
    if (m_keyBindings.contains(commandId)) {
        QString shortcut = m_keyBindings[commandId];
        m_shortcuts.remove(shortcut);
        m_keyBindings.remove(commandId);
    }
    
    m_commands.remove(commandId);
    emit commandUnregistered(commandId);
    qInfo() << "Command unregistered:" << commandId;
}

bool CommandManager::executeCommand(const QString& commandId)
{
    if (!m_commands.contains(commandId)) {
        qWarning() << "Command not found:" << commandId;
        emit commandExecuted(commandId);
        return false;
    }
    
    const Command& cmd = m_commands[commandId];
    if (cmd.handler) {
        try {
            bool result = cmd.handler();
            emit commandExecuted(commandId);
            return result;
        } catch (const std::exception& e) {
            qWarning() << "Command execution error:" << commandId << e.what();
            return false;
        }
    }
    
    return false;
}

bool CommandManager::executeCommandWithArgs(const QString& commandId, const QVariantMap& args)
{
    // 在这个简化版本中，我们忽略参数
    // 实际实现可能需要更复杂的参数传递机制
    return executeCommand(commandId);
}

Command CommandManager::getCommand(const QString& commandId) const
{
    if (m_commands.contains(commandId)) {
        return m_commands[commandId];
    }
    return Command{};
}

QList<QVariantMap> CommandManager::getAllCommands() const
{
    QList<QVariantMap> result;
    for (const auto& cmd : m_commands) {
        result.append(cmd.toMap());
    }
    return result;
}

QList<QVariantMap> CommandManager::getCommandsByCategory(const QString& category) const
{
    QList<QVariantMap> result;
    for (const auto& cmd : m_commands) {
        if (cmd.category == category) {
            result.append(cmd.toMap());
        }
    }
    return result;
}

QList<QVariantMap> CommandManager::searchCommands(const QString& query) const
{
    QList<QVariantMap> result;
    QString lowerQuery = query.toLower();
    
    for (const auto& cmd : m_commands) {
        // 在 ID、标题、分类和描述中搜索
        if (cmd.id.toLower().contains(lowerQuery) ||
            cmd.title.toLower().contains(lowerQuery) ||
            cmd.category.toLower().contains(lowerQuery) ||
            cmd.description.toLower().contains(lowerQuery)) {
            result.append(cmd.toMap());
        }
    }
    
    return result;
}

bool CommandManager::bindKeyboardShortcut(const QString& commandId, const QString& keys)
{
    if (!m_commands.contains(commandId)) {
        qWarning() << "Command not found:" << commandId;
        return false;
    }
    
    // 移除旧的快捷键绑定
    if (m_keyBindings.contains(commandId)) {
        QString oldKeys = m_keyBindings[commandId];
        m_shortcuts.remove(oldKeys);
    }
    
    // 添加新的快捷键绑定
    m_keyBindings[commandId] = keys;
    m_shortcuts[keys] = commandId;
    
    qInfo() << "Keyboard shortcut bound:" << commandId << "->" << keys;
    return true;
}

QString CommandManager::getKeyboardShortcut(const QString& commandId) const
{
    if (m_keyBindings.contains(commandId)) {
        return m_keyBindings[commandId];
    }
    return QString();
}

QString CommandManager::getCommandByKeyboardShortcut(const QString& keys) const
{
    if (m_shortcuts.contains(keys)) {
        return m_shortcuts[keys];
    }
    return QString();
}
