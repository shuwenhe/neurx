#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QJsonObject>

/**
 * @class StorageService
 * @brief Persistent storage for application state
 * 
 * Features:
 * - Key-value storage
 * - JSON serialization
 * - Session and global storage
 * - Automatic persistence
 */

class StorageService : public QObject {
    Q_OBJECT

public:
    enum StorageScope {
        Global,      // Persisted across sessions
        Workspace,   // Per-workspace storage
        Session,     // Current session only
        Temporary    // Not persisted
    };

    static StorageService* instance();
    
    // Storage operations
    QVariant get(const QString& key, const QVariant& defaultValue = QVariant(),
                 StorageScope scope = Global);
    void set(const QString& key, const QVariant& value,
             StorageScope scope = Global);
    bool has(const QString& key, StorageScope scope = Global) const;
    void remove(const QString& key, StorageScope scope = Global);
    void clear(StorageScope scope = Global);
    
    // Batch operations
    QJsonObject getAll(StorageScope scope = Global) const;
    void loadFromJson(const QJsonObject& obj, StorageScope scope = Global);
    
    // File operations
    bool loadFromFile(const QString& filePath, StorageScope scope = Global);
    bool saveToFile(const QString& filePath, StorageScope scope = Global);
    
    // Storage paths
    QString globalStoragePath() const;
    QString workspaceStoragePath(const QString& workspacePath) const;
    QString sessionStoragePath() const;
    
    // Statistics
    int storageSize(StorageScope scope = Global) const;
    QStringList keys(StorageScope scope = Global) const;

signals:
    void storageChanged(const QString& key, const QVariant& value, StorageScope scope);
    void storageCleared(StorageScope scope);

private:
    StorageService();
    ~StorageService() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
