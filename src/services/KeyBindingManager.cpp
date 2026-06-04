#include "services/KeyBindingManager.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>

KeyBindingManager* g_keyBindingManager = nullptr;

KeyBindingManager* KeyBindingManager::instance()
{
    if (!g_keyBindingManager) {
        g_keyBindingManager = new KeyBindingManager();
    }
    return g_keyBindingManager;
}

KeyBindingManager::KeyBindingManager()
{
    initializeDefaultKeyBindings();
}

void KeyBindingManager::initializeDefaultKeyBindings()
{
    // Editor commands - Phase 1 (Core)
    registerKeyBinding({"editor.action.undo", "Ctrl+Z", "", "Undo"});
    registerKeyBinding({"editor.action.redo", "Ctrl+Y", "", "Redo"});
    registerKeyBinding({"editor.action.delete", "Ctrl+Shift+K", "", "Delete line"});
    registerKeyBinding({"editor.action.duplicate", "Ctrl+Shift+D", "", "Duplicate line"});
    registerKeyBinding({"editor.action.moveUp", "Alt+Up", "", "Move line up"});
    registerKeyBinding({"editor.action.moveDown", "Alt+Down", "", "Move line down"});
    registerKeyBinding({"editor.action.comment", "Ctrl+/", "", "Toggle line comment"});
    registerKeyBinding({"editor.action.blockComment", "Ctrl+Shift+/", "", "Toggle block comment"});
    registerKeyBinding({"editor.action.fold", "Ctrl+Shift+[", "", "Fold code"});
    registerKeyBinding({"editor.action.unfold", "Ctrl+Shift+]", "", "Unfold code"});
    
    // Search commands
    registerKeyBinding({"editor.action.find", "Ctrl+F", "", "Find"});
    registerKeyBinding({"editor.action.replace", "Ctrl+H", "", "Replace"});
    registerKeyBinding({"editor.action.selectAll", "Ctrl+A", "", "Select all"});
    
    // Workbench commands
    registerKeyBinding({"workbench.action.showCommands", "Ctrl+Shift+P", "", "Show command palette"});
    registerKeyBinding({"workbench.action.findInFiles", "Ctrl+Shift+F", "", "Find in files"});
    registerKeyBinding({"workbench.action.openSettings", "Ctrl+,", "", "Open settings"});
    registerKeyBinding({"workbench.action.quickOpen", "Ctrl+P", "", "Quick open"});
    
    // View commands
    registerKeyBinding({"workbench.action.toggleSidebar", "Ctrl+B", "", "Toggle sidebar"});
    registerKeyBinding({"workbench.action.togglePanel", "Ctrl+J", "", "Toggle panel"});
    
    // Phase 2 - Enhancement commands
    // Bracket Matching
    registerKeyBinding({"editor.action.jumpToBracket", "Ctrl+Shift+\\", "", "Jump to matching bracket"});
    
    // Word Operations
    registerKeyBinding({"editor.action.transformToUppercase", "Ctrl+Shift+U", "", "Convert to uppercase"});
    registerKeyBinding({"editor.action.transformToLowercase", "Ctrl+Shift+L", "", "Convert to lowercase"});
    registerKeyBinding({"editor.action.transformToTitleCase", "Ctrl+Shift+T", "", "Convert to title case"});
    registerKeyBinding({"editor.action.deleteWordForward", "Ctrl+Alt+Delete", "", "Delete word forward"});
    registerKeyBinding({"editor.action.deleteWordBackward", "Ctrl+Alt+Backspace", "", "Delete word backward"});
    registerKeyBinding({"editor.action.moveWordForward", "Ctrl+Right", "", "Move cursor forward by word"});
    registerKeyBinding({"editor.action.moveWordBackward", "Ctrl+Left", "", "Move cursor backward by word"});
    
    // Phase 3 - Advanced commands
    // Smart Selection
    registerKeyBinding({"editor.action.expandSelection", "Ctrl+Shift+Right", "", "Expand selection (Word→Line→Paragraph→All)"});
    registerKeyBinding({"editor.action.contractSelection", "Ctrl+Shift+Left", "", "Contract selection"});
    
    // Word Highlight
    registerKeyBinding({"editor.action.toggleHighlight", "Ctrl+Shift+H", "", "Highlight all occurrences of word"});
    registerKeyBinding({"editor.action.clearHighlight", "Escape", "", "Clear word highlights"});
    
    // Inline Rename
    registerKeyBinding({"editor.action.rename", "F2", "", "Rename symbol (inline)"});
    registerKeyBinding({"editor.action.cancelRename", "Escape", "", "Cancel rename"});
    
    // Go to Definition
    registerKeyBinding({"editor.action.goToDefinition", "F12", "", "Go to definition"});
    registerKeyBinding({"editor.action.goToPreviousDefinition", "Alt+Left", "", "Go to previous definition location"});
    registerKeyBinding({"editor.action.goToNextDefinition", "Alt+Right", "", "Go to next definition location"});
    registerKeyBinding({"editor.action.goToDefinitionAlt", "Ctrl+Click", "", "Go to definition (Alt: click)"});
    
    // Select to Bracket
    registerKeyBinding({"editor.action.selectToBracket", "Ctrl+Shift+.", "", "Select to matching bracket"});
    registerKeyBinding({"editor.action.selectBracketPair", "Ctrl+Shift+,", "", "Select matching bracket pair"});
}

void KeyBindingManager::registerKeyBinding(const KeyBinding& binding)
{
    if (hasConflict(binding.keys)) {
        auto conflicts = findConflicts(binding.keys);
        emit conflictDetected(conflicts);
        qWarning() << "Keybinding conflict detected:" << binding.keys;
    }
    
    m_keyBindings[binding.keys] = binding;
    m_commandToKeys[binding.commandId] = binding.keys;
    emit keyBindingRegistered(binding);
}

void KeyBindingManager::registerKeyBinding(const QString& commandId, const QString& keys)
{
    registerKeyBinding({commandId, keys, "", ""});
}

void KeyBindingManager::unregisterKeyBinding(const QString& commandId)
{
    if (m_commandToKeys.contains(commandId)) {
        QString keys = m_commandToKeys[commandId];
        m_keyBindings.remove(keys);
        m_commandToKeys.remove(commandId);
        qDebug() << "Keybinding unregistered:" << commandId;
    }
}

KeyBinding KeyBindingManager::getKeyBinding(const QString& commandId) const
{
    if (m_commandToKeys.contains(commandId)) {
        QString keys = m_commandToKeys[commandId];
        return m_keyBindings[keys];
    }
    return {};
}

QString KeyBindingManager::getCommand(const QString& keys) const
{
    if (m_keyBindings.contains(keys)) {
        return m_keyBindings[keys].commandId;
    }
    return "";
}

QList<KeyBinding> KeyBindingManager::getAllKeyBindings() const
{
    QList<KeyBinding> result;
    for (const auto& binding : m_keyBindings) {
        result.append(binding);
    }
    return result;
}

QList<KeyBinding> KeyBindingManager::findConflicts(const QString& keys) const
{
    QList<KeyBinding> conflicts;
    
    if (m_keyBindings.contains(keys)) {
        conflicts.append(m_keyBindings[keys]);
    }
    
    return conflicts;
}

void KeyBindingManager::loadKeyBindings(const QString& filePath)
{
    QFile file(filePath);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        file.close();
        
        if (doc.isArray()) {
            QJsonArray arr = doc.array();
            for (const auto& item : arr) {
                QJsonObject obj = item.toObject();
                KeyBinding binding;
                binding.commandId = obj["command"].toString();
                binding.keys = obj["key"].toString();
                binding.when = obj["when"].toString();
                registerKeyBinding(binding);
            }
            qDebug() << "Keybindings loaded from:" << filePath;
        }
    } else {
        qWarning() << "Failed to load keybindings from:" << filePath;
    }
}

void KeyBindingManager::saveKeyBindings(const QString& filePath)
{
    QJsonArray arr;
    for (auto it = m_keyBindings.begin(); it != m_keyBindings.end(); ++it) {
        QJsonObject obj;
        obj["command"] = it.value().commandId;
        obj["key"] = it.key();
        obj["when"] = it.value().when;
        arr.append(obj);
    }
    
    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(arr).toJson());
        file.close();
        qDebug() << "Keybindings saved to:" << filePath;
    } else {
        qWarning() << "Failed to save keybindings to:" << filePath;
    }
}

void KeyBindingManager::resetToDefaults()
{
    m_keyBindings.clear();
    m_commandToKeys.clear();
    initializeDefaultKeyBindings();
    qDebug() << "Keybindings reset to defaults";
}

bool KeyBindingManager::hasConflict(const QString& keys) const
{
    return m_keyBindings.contains(keys);
}
