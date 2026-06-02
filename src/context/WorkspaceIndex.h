#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QHash>

// ── WorkspaceIndex ───────────────────────────────────────────────────────────
//  Lightweight workspace index for file inventory and summary generation.

class WorkspaceIndex : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString rootPath READ rootPath WRITE setRootPath NOTIFY rootPathChanged)
    Q_PROPERTY(int fileCount READ fileCount NOTIFY indexChanged)
    Q_PROPERTY(QStringList topExtensions READ topExtensions NOTIFY indexChanged)

public:
    explicit WorkspaceIndex(QObject *parent = nullptr);

    QString rootPath() const { return m_rootPath; }
    int fileCount() const { return m_fileCount; }
    QStringList topExtensions() const { return m_topExtensions; }
    Q_INVOKABLE QStringList searchPaths(const QString &needle) const;

    void setRootPath(const QString &path);
    void refresh();
    void recordFileAccess(const QString &filePath);

    QString buildContextSummary() const;

signals:
    void rootPathChanged();
    void indexChanged();

private:
    static bool shouldSkipPath(const QString &path);
    static QString normalizeExtension(const QString &filePath);

    QString m_rootPath;
    int m_fileCount{0};
    QHash<QString, int> m_extensionCounts;
    QStringList m_topExtensions;
    QStringList m_recentFiles;
    QStringList m_filePaths;
};
