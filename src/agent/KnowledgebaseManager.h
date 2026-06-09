#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class KnowledgebaseManager
 * @brief Intelligent knowledge base and documentation system
 * 
 * Features:
 * - Knowledge base creation and management
 * - Document indexing and search
 * - Semantic similarity search
 * - FAQ management
 * - Knowledge article creation
 * - Category and tagging system
 * - Version history
 * - Analytics and insights
 */

class KnowledgebaseManager : public QObject {
    Q_OBJECT

public:
    enum ArticleCategory {
        Troubleshooting,
        HowTo,
        Reference,
        Conceptual,
        API,
        Tutorial,
        FAQ,
        Best_Practices
    };

    struct KnowledgeArticle {
        QString id;
        QString title;
        QString content;
        ArticleCategory category;
        QStringList tags;
        QDateTime createdAt;
        QDateTime updatedAt;
        QString author;
        int viewCount;
        float helpfulness;  // 0-1.0
        bool isPublished;
        QStringList relatedArticles;
    };

    struct SearchResult {
        QString articleId;
        QString title;
        QString snippet;
        float relevanceScore;  // 0-1.0
        QString category;
    };

    struct FAQEntry {
        QString question;
        QString answer;
        int frequency;
        float rating;  // 0-5
        QStringList relatedTopics;
    };

    struct KnowledgebaseStats {
        int totalArticles;
        int categorizedArticles;
        int taggedArticles;
        int viewsThisMonth;
        float avgArticleLength;
        float avgHelpfulness;
        int searchQueriesThisMonth;
    };

    explicit KnowledgebaseManager(QObject* parent = nullptr);
    ~KnowledgebaseManager();

    // Knowledge base management
    void createKnowledgebase(const QString& name, const QString& description);
    QString getKnowledgebaseName();
    void deleteKnowledgebase();

    // Article management
    void createArticle(const KnowledgeArticle& article);
    void updateArticle(const KnowledgeArticle& article);
    void deleteArticle(const QString& articleId);
    KnowledgeArticle getArticle(const QString& articleId);
    QVector<KnowledgeArticle> getAllArticles();
    QVector<KnowledgeArticle> getArticlesByCategory(ArticleCategory category);

    // Search functionality
    QVector<SearchResult> search(const QString& query);
    QVector<SearchResult> semanticSearch(const QString& query);
    QVector<SearchResult> searchByTag(const QString& tag);
    QStringList getSearchSuggestions(const QString& query);
    QStringList getRelatedQueries(const QString& query);

    // FAQ management
    void addFAQ(const FAQEntry& entry);
    QVector<FAQEntry> getAllFAQs();
    QVector<FAQEntry> getFAQsByTopic(const QString& topic);
    QString generateFAQfromArticles();
    void trainFAQfromQueries();

    // Content generation
    QString generateArticleOutline(const QString& topic);
    QString suggestArticleTitle(const QString& content);
    QString generateTOC();
    QString generateIndexPage();

    // Tagging and organization
    void addTag(const QString& tag);
    QStringList getAllTags();
    QStringList suggestTags(const QString& content);
    void reorganizeByTags();

    // Version history
    struct ArticleVersion {
        QString articleId;
        QString version;
        QString content;
        QDateTime timestamp;
        QString author;
        QString changeDescription;
    };
    void saveVersion(const ArticleVersion& version);
    QVector<ArticleVersion> getVersionHistory(const QString& articleId);
    void revertToVersion(const QString& articleId, const QString& version);

    // Quality metrics
    float calculateArticleQuality(const QString& articleId);
    QStringList getArticlesNeedingUpdate();
    QStringList getPopularArticles();
    QStringList getLowRatingArticles();

    // Export and import
    QString exportToMarkdown(const QString& articleId);
    QString exportAllToHTML();
    bool importFromMarkdown(const QString& filePath);
    QString exportAsJSON();

    // Analytics
    KnowledgebaseStats getStatistics();
    void trackArticleView(const QString& articleId);
    void trackSearch(const QString& query, bool found);
    void trackHelpfulness(const QString& articleId, float rating);

    // AI-assisted features
    QString suggestArticleContent(const QString& topic);
    QString improveArticle(const QString& articleId);
    QStringList identifyKnowledgeGaps();
    QString generateSummary(const QString& articleId);

    // Collaboration
    struct Contributor {
        QString name;
        QString email;
        int articlesContributed;
        float avgQualityScore;
    };
    void addContributor(const Contributor& contributor);
    QVector<Contributor> getContributors();

signals:
    void articleCreated(const QString& articleId);
    void articleUpdated(const QString& articleId);
    void articleDeleted(const QString& articleId);
    void searchPerformed(const QString& query, int resultsCount);
    void articleViewIncremented(const QString& articleId);
    void contentGenerated(const QString& type);

private:
    QString m_kbName;
    QMap<QString, KnowledgeArticle> m_articles;
    QVector<FAQEntry> m_faqs;
    QMap<QString, int> m_searchQueries;
    KnowledgebaseStats m_stats;
    QStringList m_tags;

    float calculateRelevanceScore(const QString& query, const KnowledgeArticle& article);
};
