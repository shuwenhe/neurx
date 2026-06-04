#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QMap>
#include <QVariantMap>

/**
 * @class SnippetManager
 * @brief Manages code snippets
 * 
 * Features:
 * - Snippet definition and loading
 * - Variable substitution
 * - Placeholder management
 * - Tab stop navigation
 */

struct Snippet {
    QString id;
    QString prefix;           // Trigger prefix (e.g., "main")
    QStringList body;         // Code lines
    QString description;
    QString language;
    
    QVariantMap toMap() const {
        return QVariantMap{
            {"id", id},
            {"prefix", prefix},
            {"description", description},
            {"language", language}
        };
    }
};

class SnippetManager : public QObject {
    Q_OBJECT

public:
    explicit SnippetManager(QObject* parent = nullptr);
    ~SnippetManager() override = default;
    
    // Snippet management
    void loadSnippets(const QString& language);
    void registerSnippet(const Snippet& snippet);
    void unregisterSnippet(const QString& snippetId);
    
    // Query
    QList<Snippet> getSnippets(const QString& language) const;
    Snippet getSnippet(const QString& prefix, const QString& language) const;
    QList<Snippet> findSnippets(const QString& query) const;
    
    // Snippet insertion
    void insertSnippet(const Snippet& snippet, int line, int column);
    
    // Variable handling
    QString resolveVariables(const QString& snippet);
    void selectNextPlaceholder();
    void selectPreviousPlaceholder();

signals:
    void snippetInserted(int line, int column);
    void placeholderChanged(int index);
    void snippetsLoaded(const QString& language, int count);

private:
    QMap<QString, QList<Snippet>> m_snippets;  // language -> snippets
    void initializeBuiltInSnippets();
};
