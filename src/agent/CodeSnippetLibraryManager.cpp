#include "CodeSnippetLibraryManager.h"
#include <QDebug>

CodeSnippetLibraryManager::CodeSnippetLibraryManager(QObject* parent)
    : QObject(parent) {
}

CodeSnippetLibraryManager::~CodeSnippetLibraryManager() {
}

void CodeSnippetLibraryManager::addSnippet(const CodeSnippet& snippet) {
    m_snippets[snippet.id] = snippet;
    emit snippetAdded(snippet.id);
}

void CodeSnippetLibraryManager::updateSnippet(const CodeSnippet& snippet) {
    if (m_snippets.contains(snippet.id)) {
        m_snippets[snippet.id] = snippet;
        emit snippetUpdated(snippet.id);
    }
}

void CodeSnippetLibraryManager::deleteSnippet(const QString& snippetId) {
    m_snippets.remove(snippetId);
    emit snippetDeleted(snippetId);
}

CodeSnippetLibraryManager::CodeSnippet CodeSnippetLibraryManager::getSnippet(const QString& snippetId) {
    return m_snippets.value(snippetId);
}

QVector<CodeSnippetLibraryManager::CodeSnippet> CodeSnippetLibraryManager::searchSnippets(const QString& query) {
    QVector<CodeSnippet> results;
    for (const auto& snippet : m_snippets.values()) {
        if (snippet.title.contains(query, Qt::CaseInsensitive) || 
            snippet.description.contains(query, Qt::CaseInsensitive)) {
            results.append(snippet);
        }
    }
    return results;
}

QVector<CodeSnippetLibraryManager::CodeSnippet> CodeSnippetLibraryManager::getSnippetsByTag(const QString& tag) {
    QVector<CodeSnippet> results;
    for (const auto& snippet : m_snippets.values()) {
        if (snippet.tags.contains(tag)) {
            results.append(snippet);
        }
    }
    return results;
}

QVector<CodeSnippetLibraryManager::CodeSnippet> CodeSnippetLibraryManager::getSnippetsByLanguage(const QString& language) {
    QVector<CodeSnippet> results;
    for (const auto& snippet : m_snippets.values()) {
        if (snippet.language == language) {
            results.append(snippet);
        }
    }
    return results;
}

void CodeSnippetLibraryManager::addCategory(const SnippetCategory& category) {
    m_categories.append(category);
}

QVector<CodeSnippetLibraryManager::SnippetCategory> CodeSnippetLibraryManager::getAllCategories() {
    return m_categories;
}

void CodeSnippetLibraryManager::rateSnippet(const QString& snippetId, float rating) {
    if (m_snippets.contains(snippetId)) {
        m_snippets[snippetId].rating = rating;
    }
}

void CodeSnippetLibraryManager::incrementUsageCount(const QString& snippetId) {
    if (m_snippets.contains(snippetId)) {
        m_snippets[snippetId].usageCount++;
    }
}

void CodeSnippetLibraryManager::registerBestPractice(const BestPractice& practice) {
    m_bestPractices.append(practice);
}

QVector<CodeSnippetLibraryManager::BestPractice> CodeSnippetLibraryManager::getBestPractices() {
    return m_bestPractices;
}

QVector<CodeSnippetLibraryManager::BestPractice> CodeSnippetLibraryManager::getBestPracticesByLanguage(const QString& language) {
    QVector<BestPractice> results;
    for (const auto& practice : m_bestPractices) {
        if (practice.applicableTo.contains(language)) {
            results.append(practice);
        }
    }
    return results;
}

CodeSnippetLibraryManager::LibraryStats CodeSnippetLibraryManager::getLibraryStatistics() {
    LibraryStats stats;
    stats.totalSnippets = m_snippets.size();
    stats.totalCategories = m_categories.size();
    stats.totalBestPractices = m_bestPractices.size();
    stats.totalTags = 0;
    stats.avgRating = 0.0f;

    QSet<QString> uniqueTags;
    float totalRating = 0.0f;
    for (const auto& snippet : m_snippets.values()) {
        for (const auto& tag : snippet.tags) {
            uniqueTags.insert(tag);
        }
        totalRating += snippet.rating;
    }

    stats.totalTags = uniqueTags.size();
    if (stats.totalSnippets > 0) {
        stats.avgRating = totalRating / stats.totalSnippets;
    }

    return stats;
}
