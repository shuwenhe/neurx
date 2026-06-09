#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QMap>
#include <QVector>
#include <memory>
#include <vector>

/**
 * @class CodeSnippetLibraryManager
 * @brief Reusable code snippet and pattern library
 */

class CodeSnippetLibraryManager : public QObject {
    Q_OBJECT

public:
    struct CodeSnippet {
        QString id;
        QString title;
        QString description;
        QString code;
        QString language;
        QStringList tags;
        QStringList relatedSnippets;
        int usageCount;
        float rating;
        QString author;
        qint64 createdAt;
    };

    struct SnippetCategory {
        QString name;
        QString description;
        QVector<QString> snippetIds;
    };

    struct BestPractice {
        QString id;
        QString title;
        QString description;
        QString codeExample;
        QString explanation;
        QStringList applicableTo;  // languages or frameworks
        QString severity;  // critical, high, medium, low
    };

    explicit CodeSnippetLibraryManager(QObject* parent = nullptr);
    ~CodeSnippetLibraryManager();

    void addSnippet(const CodeSnippet& snippet);
    void updateSnippet(const CodeSnippet& snippet);
    void deleteSnippet(const QString& snippetId);

    CodeSnippet getSnippet(const QString& snippetId);
    QVector<CodeSnippet> searchSnippets(const QString& query);
    QVector<CodeSnippet> getSnippetsByTag(const QString& tag);
    QVector<CodeSnippet> getSnippetsByLanguage(const QString& language);

    void addCategory(const SnippetCategory& category);
    QVector<SnippetCategory> getAllCategories();

    void rateSnippet(const QString& snippetId, float rating);
    void incrementUsageCount(const QString& snippetId);

    void registerBestPractice(const BestPractice& practice);
    QVector<BestPractice> getBestPractices();
    QVector<BestPractice> getBestPracticesByLanguage(const QString& language);

    struct LibraryStats {
        int totalSnippets;
        int totalCategories;
        int totalBestPractices;
        int totalTags;
        float avgRating;
    };
    LibraryStats getLibraryStatistics();

signals:
    void snippetAdded(const QString& snippetId);
    void snippetUpdated(const QString& snippetId);
    void snippetDeleted(const QString& snippetId);

private:
    QMap<QString, CodeSnippet> m_snippets;
    QVector<SnippetCategory> m_categories;
    QVector<BestPractice> m_bestPractices;
};
