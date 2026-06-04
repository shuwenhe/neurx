#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QKeySequence>
#include <functional>

/**
 * @class KeyBindingManager
 * @brief Manages keyboard shortcuts
 * 
 * Features:
 * - Keybinding registration
 * - Conflict detection
 * - Custom keybinding support
 * - Keybinding persistence
 */

struct KeyBinding {
    QString commandId;
    QString keys;
    QString when;        // Context condition
    QString description;
};

class KeyBindingManager : public QObject {
    Q_OBJECT

public:
    static KeyBindingManager* instance();
    
    // Keybinding management
    void registerKeyBinding(const KeyBinding& binding);
    void registerKeyBinding(const QString& commandId, const QString& keys);
    void unregisterKeyBinding(const QString& commandId);
    
    // Query
    KeyBinding getKeyBinding(const QString& commandId) const;
    QString getCommand(const QString& keys) const;
    QList<KeyBinding> getAllKeyBindings() const;
    QList<KeyBinding> findConflicts(const QString& keys) const;
    
    // Persistence
    void loadKeyBindings(const QString& filePath);
    void saveKeyBindings(const QString& filePath);
    void resetToDefaults();
    
    // Check for conflicts
    bool hasConflict(const QString& keys) const;

signals:
    void keyBindingRegistered(const KeyBinding& binding);
    void keyBindingChanged(const QString& commandId, const QString& oldKeys, const QString& newKeys);
    void conflictDetected(const QList<KeyBinding>& conflicts);

private:
    KeyBindingManager();
    ~KeyBindingManager() override = default;
    
    Q_DISABLE_COPY_MOVE(KeyBindingManager)
    
    QMap<QString, KeyBinding> m_keyBindings;  // keys -> binding
    QMap<QString, QString> m_commandToKeys;   // commandId -> keys
    
    void initializeDefaultKeyBindings();
};
