#pragma once

#include <QString>
#include <QMap>
#include <QList>
#include <QJsonObject>
#include <QJsonArray>
#include <QObject>
#include <QDateTime>

/**
 * @class ContextItem
 * @brief A single context item
 */
struct ContextItem {
    QString id;                      ///< Unique item ID
    QString type;                    ///< Item type (file, selection, note, etc.)
    QString source;                  ///< Source/origin
    QString content;                 ///< Item content
    QJsonObject metadata;            ///< Additional metadata
    QDateTime timestamp;             ///< When added
    bool transient{false};          ///< Temporary context (cleared after use)
    int priority{0};                ///< Priority (higher = more important)
};

/**
 * @class ContextManager
 * @brief Manages agent context (files, selections, notes, etc.)
 * 
 * Features:
 * - Multi-source context injection
 * - Context persistence
 * - Priority-based ordering
 * - Automatic context cleanup
 * - Context versioning/history
 */
class ContextManager : public QObject {
    Q_OBJECT

public:
    explicit ContextManager(QObject *parent = nullptr);
    ~ContextManager();

    // ── Context Addition ────────────────────────────────────────────────────
    
    /**
     * @brief Add a file to context
     */
    QString addFileContext(const QString &filePath, int startLine = -1, int endLine = -1,
                          bool transient = false);
    
    /**
     * @brief Add selected code to context
     */
    QString addSelectionContext(const QString &content, const QString &source = "editor",
                               bool transient = false);
    
    /**
     * @brief Add a note to context
     */
    QString addNote(const QString &content, bool transient = false);
    
    /**
     * @brief Add custom context item
     */
    QString addContextItem(const ContextItem &item);

    // ── Context Access ──────────────────────────────────────────────────────
    
    /**
     * @brief Get all context items
     */
    QList<ContextItem> allContextItems() const;
    
    /**
     * @brief Get context by type
     */
    QList<ContextItem> getContextByType(const QString &type) const;
    
    /**
     * @brief Get context item
     */
    ContextItem getContextItem(const QString &itemId) const;
    
    /**
     * @brief Get context as JSON (for sending to LLM)
     */
    QJsonArray getContextAsJSON() const;
    
    /**
     * @brief Get context as plain text (for sending to LLM)
     */
    QString getContextAsText() const;

    // ── Context Manipulation ────────────────────────────────────────────────
    
    /**
     * @brief Remove context item
     */
    bool removeContextItem(const QString &itemId);
    
    /**
     * @brief Remove context by type
     */
    int removeContextByType(const QString &type);
    
    /**
     * @brief Clear all context
     */
    void clearAllContext();
    
    /**
     * @brief Clear transient context
     */
    void clearTransientContext();

    // ── Context Priority ────────────────────────────────────────────────────
    
    /**
     * @brief Set item priority
     */
    void setItemPriority(const QString &itemId, int priority);
    
    /**
     * @brief Get items sorted by priority
     */
    QList<ContextItem> getContextByPriority() const;

    // ── Context Size Management ─────────────────────────────────────────────
    
    /**
     * @brief Get total context size (approximate tokens)
     */
    int getContextSize() const;
    
    /**
     * @brief Set maximum context size
     */
    void setMaxContextSize(int size);
    
    /**
     * @brief Trim context to fit within size limit
     */
    void trimContext();

    // ── Context History and Snapshots ───────────────────────────────────────
    
    /**
     * @brief Create context snapshot
     */
    QString createSnapshot();
    
    /**
     * @brief Restore context from snapshot
     */
    bool restoreSnapshot(const QString &snapshotId);
    
    /**
     * @brief Get available snapshots
     */
    QList<QString> getSnapshots() const;
    
    /**
     * @brief Clear snapshots
     */
    void clearSnapshots();

    // ── Context Analysis ────────────────────────────────────────────────────
    
    /**
     * @brief Get context statistics
     */
    QJsonObject getStatistics() const;
    
    /**
     * @brief Find related context items
     */
    QList<ContextItem> findRelated(const QString &query) const;

signals:
    /**
     * @brief Emitted when context item is added
     */
    void contextItemAdded(const ContextItem &item);
    
    /**
     * @brief Emitted when context item is removed
     */
    void contextItemRemoved(const QString &itemId);
    
    /**
     * @brief Emitted when context is cleared
     */
    void contextCleared();
    
    /**
     * @brief Emitted when context size exceeds limit
     */
    void contextSizeExceeded(int currentSize, int maxSize);

private:
    /**
     * @brief Generate unique item ID
     */
    QString generateItemId();
    
    /**
     * @brief Estimate token count for text
     */
    int estimateTokenCount(const QString &text) const;
    
    /**
     * @brief Remove lowest priority items to fit size
     */
    void removeLowestPriorityItems(int targetSize);

    // ── Data members ────────────────────────────────────────────────────────
    QMap<QString, ContextItem> m_contextItems;
    QMap<QString, QList<ContextItem>> m_snapshots;  // snapshotId -> items
    int m_maxContextSize{4000};  // Approximate token count
    int m_itemCounter{0};
};
