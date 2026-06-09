#include "KnowledgebaseManager.h"
#include <QDebug>
#include <QDateTime>
#include <QFile>

KnowledgebaseManager::KnowledgebaseManager(QObject* parent)
    : QObject(parent) {
    m_stats = {0, 0, 0, 0, 0.0f, 0.0f, 0};
}

KnowledgebaseManager::~KnowledgebaseManager() {
}

void KnowledgebaseManager::createKnowledgebase(const QString& name, const QString& description) {
    m_kbName = name;
    qDebug() << "Created knowledge base:" << name;
}

QString KnowledgebaseManager::getKnowledgebaseName() {
    return m_kbName;
}

void KnowledgebaseManager::deleteKnowledgebase() {
    m_articles.clear();
    m_faqs.clear();
    m_tags.clear();
}

void KnowledgebaseManager::createArticle(const KnowledgeArticle& article) {
    m_articles[article.id] = article;
    m_stats.totalArticles++;
    emit articleCreated(article.id);
}

void KnowledgebaseManager::updateArticle(const KnowledgeArticle& article) {
    if (m_articles.contains(article.id)) {
        m_articles[article.id] = article;
        emit articleUpdated(article.id);
    }
}

void KnowledgebaseManager::deleteArticle(const QString& articleId) {
    if (m_articles.remove(articleId)) {
        m_stats.totalArticles--;
        emit articleDeleted(articleId);
    }
}

KnowledgebaseManager::KnowledgeArticle KnowledgebaseManager::getArticle(const QString& articleId) {
    return m_articles.value(articleId);
}

QVector<KnowledgebaseManager::KnowledgeArticle> KnowledgebaseManager::getAllArticles() {
    return QVector<KnowledgeArticle>(m_articles.values().begin(), m_articles.values().end());
}

QVector<KnowledgebaseManager::KnowledgeArticle> KnowledgebaseManager::getArticlesByCategory(ArticleCategory category) {
    QVector<KnowledgeArticle> result;
    for (const auto& article : m_articles.values()) {
        if (article.category == category) {
            result.append(article);
        }
    }
    return result;
}

QVector<KnowledgebaseManager::SearchResult> KnowledgebaseManager::search(const QString& query) {
    QVector<SearchResult> results;
    emit searchPerformed(query, results.size());
    return results;
}

QVector<KnowledgebaseManager::SearchResult> KnowledgebaseManager::semanticSearch(const QString& query) {
    QVector<SearchResult> results;
    
    for (const auto& article : m_articles.values()) {
        float relevance = calculateRelevanceScore(query, article);
        if (relevance > 0.3f) {
            SearchResult result;
            result.articleId = article.id;
            result.title = article.title;
            result.relevanceScore = relevance;
            results.append(result);
        }
    }
    
    emit searchPerformed(query, results.size());
    return results;
}

QVector<KnowledgebaseManager::SearchResult> KnowledgebaseManager::searchByTag(const QString& tag) {
    QVector<SearchResult> results;
    
    for (const auto& article : m_articles.values()) {
        if (article.tags.contains(tag)) {
            SearchResult result;
            result.articleId = article.id;
            result.title = article.title;
            result.relevanceScore = 1.0f;
            results.append(result);
        }
    }
    
    return results;
}

QStringList KnowledgebaseManager::getSearchSuggestions(const QString& query) {
    QStringList suggestions;
    for (const auto& article : m_articles.values()) {
        if (article.title.contains(query, Qt::CaseInsensitive)) {
            suggestions.append(article.title);
        }
    }
    return suggestions;
}

QStringList KnowledgebaseManager::getRelatedQueries(const QString& query) {
    return QStringList{query + " advanced", query + " troubleshooting", query + " best practices"};
}

void KnowledgebaseManager::addFAQ(const FAQEntry& entry) {
    m_faqs.append(entry);
}

QVector<KnowledgebaseManager::FAQEntry> KnowledgebaseManager::getAllFAQs() {
    return m_faqs;
}

QVector<KnowledgebaseManager::FAQEntry> KnowledgebaseManager::getFAQsByTopic(const QString& topic) {
    QVector<FAQEntry> result;
    for (const auto& faq : m_faqs) {
        if (faq.relatedTopics.contains(topic)) {
            result.append(faq);
        }
    }
    return result;
}

QString KnowledgebaseManager::generateFAQfromArticles() {
    QString faq = "# Frequently Asked Questions\n\n";
    for (const auto& article : m_articles.values()) {
        if (article.viewCount > 100) {
            faq += QString("## %1\n\n%2\n\n").arg(article.title, article.content.left(200));
        }
    }
    return faq;
}

void KnowledgebaseManager::trainFAQfromQueries() {
    qDebug() << "Training FAQ from search queries...";
}

QString KnowledgebaseManager::generateArticleOutline(const QString& topic) {
    return QString("# %1\n\n1. Introduction\n2. Core Concepts\n3. Examples\n4. Best Practices\n5. Conclusion\n").arg(topic);
}

QString KnowledgebaseManager::suggestArticleTitle(const QString& content) {
    return "Suggested Title for: " + content.left(50);
}

QString KnowledgebaseManager::generateTOC() {
    QString toc = "# Table of Contents\n\n";
    int idx = 1;
    for (const auto& article : m_articles.values()) {
        if (article.isPublished) {
            toc += QString("%1. [%2](#%3)\n").arg(idx++).arg(article.title, article.id);
        }
    }
    return toc;
}

QString KnowledgebaseManager::generateIndexPage() {
    return "# Knowledge Base Index\n\nWelcome to the knowledge base.\n";
}

void KnowledgebaseManager::addTag(const QString& tag) {
    if (!m_tags.contains(tag)) {
        m_tags.append(tag);
    }
}

QStringList KnowledgebaseManager::getAllTags() {
    return m_tags;
}

QStringList KnowledgebaseManager::suggestTags(const QString& content) {
    QStringList suggestions;
    if (content.contains("error", Qt::CaseInsensitive)) {
        suggestions.append("troubleshooting");
    }
    if (content.contains("how", Qt::CaseInsensitive)) {
        suggestions.append("howto");
    }
    return suggestions;
}

void KnowledgebaseManager::reorganizeByTags() {
    qDebug() << "Reorganizing knowledge base by tags...";
}

void KnowledgebaseManager::saveVersion(const ArticleVersion& version) {
    qDebug() << "Saving version" << version.version << "for article" << version.articleId;
}

QVector<KnowledgebaseManager::ArticleVersion> KnowledgebaseManager::getVersionHistory(const QString& articleId) {
    QVector<ArticleVersion> history;
    return history;
}

void KnowledgebaseManager::revertToVersion(const QString& articleId, const QString& version) {
    qDebug() << "Reverting article" << articleId << "to version" << version;
}

float KnowledgebaseManager::calculateArticleQuality(const QString& articleId) {
    auto article = getArticle(articleId);
    float quality = 0.5f;
    quality += (article.viewCount > 50) ? 0.2f : 0.0f;
    quality += (article.helpfulness > 0.7f) ? 0.2f : 0.0f;
    quality += (article.tags.size() > 3) ? 0.1f : 0.0f;
    return qMin(1.0f, quality);
}

QStringList KnowledgebaseManager::getArticlesNeedingUpdate() {
    QStringList articles;
    for (const auto& article : m_articles.values()) {
        auto days = article.updatedAt.daysTo(QDateTime::currentDateTime());
        if (days > 180) {
            articles.append(article.id);
        }
    }
    return articles;
}

QStringList KnowledgebaseManager::getPopularArticles() {
    QStringList popular;
    for (const auto& article : m_articles.values()) {
        if (article.viewCount > 100) {
            popular.append(article.id);
        }
    }
    return popular;
}

QStringList KnowledgebaseManager::getLowRatingArticles() {
    QStringList lowRating;
    for (const auto& article : m_articles.values()) {
        if (article.helpfulness < 0.5f) {
            lowRating.append(article.id);
        }
    }
    return lowRating;
}

QString KnowledgebaseManager::exportToMarkdown(const QString& articleId) {
    auto article = getArticle(articleId);
    return QString("# %1\n\n%2\n").arg(article.title, article.content);
}

QString KnowledgebaseManager::exportAllToHTML() {
    QString html = "<html><body>\n";
    for (const auto& article : m_articles.values()) {
        html += QString("<h1>%1</h1><p>%2</p>\n").arg(article.title, article.content);
    }
    html += "</body></html>\n";
    return html;
}

bool KnowledgebaseManager::importFromMarkdown(const QString& filePath) {
    QFile file(filePath);
    if (file.open(QIODevice::ReadOnly)) {
        file.close();
        return true;
    }
    return false;
}

QString KnowledgebaseManager::exportAsJSON() {
    QJsonObject json;
    json["name"] = m_kbName;
    json["articleCount"] = m_articles.size();
    return QString::fromUtf8(QJsonDocument(json).toJson());
}

KnowledgebaseManager::KnowledgebaseStats KnowledgebaseManager::getStatistics() {
    return m_stats;
}

void KnowledgebaseManager::trackArticleView(const QString& articleId) {
    if (m_articles.contains(articleId)) {
        m_articles[articleId].viewCount++;
        m_stats.viewsThisMonth++;
        emit articleViewIncremented(articleId);
    }
}

void KnowledgebaseManager::trackSearch(const QString& query, bool found) {
    m_searchQueries[query]++;
    m_stats.searchQueriesThisMonth++;
}

void KnowledgebaseManager::trackHelpfulness(const QString& articleId, float rating) {
    if (m_articles.contains(articleId)) {
        m_articles[articleId].helpfulness = rating;
    }
}

QString KnowledgebaseManager::suggestArticleContent(const QString& topic) {
    return QString("# %1\n\n## Introduction\n\n## Key Points\n\n## Conclusion\n").arg(topic);
}

QString KnowledgebaseManager::improveArticle(const QString& articleId) {
    auto article = getArticle(articleId);
    return "Improved version of: " + article.title;
}

QStringList KnowledgebaseManager::identifyKnowledgeGaps() {
    return QStringList{"Missing error handling guide", "No advanced configuration docs", "Limited examples"};
}

QString KnowledgebaseManager::generateSummary(const QString& articleId) {
    auto article = getArticle(articleId);
    return article.content.left(300) + "...";
}

void KnowledgebaseManager::addContributor(const Contributor& contributor) {
    qDebug() << "Added contributor:" << contributor.name;
}

QVector<KnowledgebaseManager::Contributor> KnowledgebaseManager::getContributors() {
    QVector<Contributor> contributors;
    return contributors;
}

float KnowledgebaseManager::calculateRelevanceScore(const QString& query, const KnowledgeArticle& article) {
    float score = 0.0f;
    if (article.title.contains(query, Qt::CaseInsensitive)) {
        score += 0.5f;
    }
    if (article.content.contains(query, Qt::CaseInsensitive)) {
        score += 0.3f;
    }
    if (article.tags.contains(query, Qt::CaseInsensitive)) {
        score += 0.2f;
    }
    return qMin(1.0f, score);
}
