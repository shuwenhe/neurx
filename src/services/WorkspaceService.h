#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QVariantMap>

/**
 * @class WorkspaceService
 * @brief Workspace and folder management
 * 
 * Features:
 * - Multiple workspace folders
 * - File finding within workspace
 * - Workspace configuration
 * - File exclusion patterns
 */

struct WorkspaceFolder {
    QString path;
    QString name;
    int index = 0;
};

class WorkspaceService : public QObject {
    Q_OBJECT

public:
    static WorkspaceService* instance();
    
    // Workspace management
    void addFolder(const QString& path);
    void removeFolder(const QString& path);
    void removeAll();
    
    // Query
    QList<WorkspaceFolder> getFolders() const;
    WorkspaceFolder getRootFolder() const;
    QString getWorkspaceName() const;
    int getFolderCount() const;
    
    // File operations within workspace
    QStringList findFiles(const QString& pattern, int maxResults = 1000);
    QString getRelativePath(const QString& absolutePath);
    QString getAbsolutePath(const QString& relativePath);
    
    // Exclusion patterns
    void addExclusionPattern(const QString& pattern);
    void removeExclusionPattern(const QString& pattern);
    QStringList getExclusionPatterns() const;
    bool isExcluded(const QString& path) const;
    
    // Configuration
    QVariantMap getConfiguration(const QString& section = QString());
    void setConfiguration(const QString& key, const QVariant& value);
    
    // File watching
    void watchPath(const QString& path);
    void unwatchPath(const QString& path);
    bool isPathWatched(const QString& path) const;

signals:
    void folderAdded(const WorkspaceFolder& folder);
    void folderRemoved(const WorkspaceFolder& folder);
    void fileDiscovered(const QString& path);
    void configurationChanged();
    void workspaceLoaded();

private:
    WorkspaceService();
    ~WorkspaceService() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
