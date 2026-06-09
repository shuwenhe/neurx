#include "agent/ContextManager.h"
#include <QDebug>
#include <QUuid>
#include <QDateTime>
#include <QJsonObject>

ContextManager::ContextManager(QObject *parent)
    : QObject(parent)
{
}

ContextManager::~ContextManager() = default;

// ── Context Addition ────────────────────────────────────────────────────

QString ContextManager::addFileContext(const QString &filePath, int startLine, int endLine,
                                      bool transient)
{
    ContextItem item;
    item.id = generateItemId();
    item.type = "file";
    item.source = filePath;
    item.content = filePath;
    item.timestamp = QDateTime::currentDateTime();
    item.transient = transient;
    item.priority = 50;  // Default priority
    
    if (startLine >= 0 || endLine >= 0) {
        item.metadata["startLine"] = startLine;
        item.metadata["endLine"] = endLine;
    }
    
    return addContextItem(item);
}

QString ContextManager::addSelectionContext(const QString &content, const QString &source,
                                           bool transient)
{
    ContextItem item;
    item.id = generateItemId();
    item.type = "selection";
    item.source = source;
    item.content = content;
    item.timestamp = QDateTime::currentDateTime();
    item.transient = transient;
    item.priority = 60;  // Higher priority than files
    
    return addContextItem(item);
}

QString ContextManager::addNote(const QString &content, bool transient)
{
    ContextItem item;
    item.id = generateItemId();
    item.type = "note";
    item.source = "user";
    item.content = content;
    item.timestamp = QDateTime::currentDateTime();
    item.transient = transient;
    item.priority = 70;  // Higher priority
    
    return addContextItem(item);
}

QString ContextManager::addContextItem(const ContextItem &item)
{
    ContextItem newItem = item;
    if (newItem.id.isEmpty()) {
        newItem.id = generateItemId();
    }
    if (newItem.timestamp.isNull()) {
        newItem.timestamp = QDateTime::currentDateTime();
    }
    
    m_contextItems[newItem.id] = newItem;
    emit contextItemAdded(newItem);
    
    // Check if context size exceeds limit
    if (getContextSize() > m_maxContextSize) {
        emit contextSizeExceeded(getContextSize(), m_maxContextSize);
        trimContext();
    }
    
    qDebug() << "Added context item:" << newItem.id << "type:" << newItem.type;
    return newItem.id;
}

// ── Context Access ──────────────────────────────────────────────────────

QList<ContextItem> ContextManager::allContextItems() const
{
    return m_contextItems.values();
}

QList<ContextItem> ContextManager::getContextByType(const QString &type) const
{
    QList<ContextItem> result;
    for (const auto &item : m_contextItems.values()) {
        if (item.type == type) {
            result.append(item);
        }
    }
    return result;
}

ContextItem ContextManager::getContextItem(const QString &itemId) const
{
    auto it = m_contextItems.find(itemId);
    if (it != m_contextItems.end()) {
        return *it;
    }
    return ContextItem();
}

QJsonArray ContextManager::getContextAsJSON() const
{
    QJsonArray array;
    
    // Sort by priority
    auto items = getContextByPriority();
    
    for (const auto &item : items) {
        QJsonObject obj;
        obj["id"] = item.id;
        obj["type"] = item.type;
        obj["source"] = item.source;
        obj["content"] = item.content;
        obj["priority"] = item.priority;
        obj["timestamp"] = item.timestamp.toString(Qt::ISODate);
        
        if (!item.metadata.isEmpty()) {
            obj["metadata"] = item.metadata;
        }
        
        array.append(obj);
    }
    
    return array;
}

QString ContextManager::getContextAsText() const
{
    QString text;
    
    auto items = getContextByPriority();
    
    for (const auto &item : items) {
        text += QString("=== [%1] %2 ===\n").arg(item.type, item.source);
        text += item.content;
        text += "\n\n";
    }
    
    return text;
}

// ── Context Manipulation ────────────────────────────────────────────────

bool ContextManager::removeContextItem(const QString &itemId)
{
    bool removed = m_contextItems.remove(itemId) > 0;
    if (removed) {
        emit contextItemRemoved(itemId);
    }
    return removed;
}

int ContextManager::removeContextByType(const QString &type)
{
    QStringList idsToRemove;
    for (const auto &item : m_contextItems.values()) {
        if (item.type == type) {
            idsToRemove.append(item.id);
        }
    }
    
    int count = 0;
    for (const auto &id : idsToRemove) {
        if (removeContextItem(id)) {
            count++;
        }
    }
    
    return count;
}

void ContextManager::clearAllContext()
{
    m_contextItems.clear();
    emit contextCleared();
}

void ContextManager::clearTransientContext()
{
    QStringList idsToRemove;
    for (const auto &item : m_contextItems.values()) {
        if (item.transient) {
            idsToRemove.append(item.id);
        }
    }
    
    for (const auto &id : idsToRemove) {
        removeContextItem(id);
    }
}

// ── Context Priority ────────────────────────────────────────────────────

void ContextManager::setItemPriority(const QString &itemId, int priority)
{
    auto it = m_contextItems.find(itemId);
    if (it != m_contextItems.end()) {
        it->priority = priority;
    }
}

QList<ContextItem> ContextManager::getContextByPriority() const
{
    auto items = m_contextItems.values();
    
    std::sort(items.begin(), items.end(),
              [](const ContextItem &a, const ContextItem &b) {
                  return a.priority > b.priority;
              });
    
    return items;
}

// ── Context Size Management ─────────────────────────────────────────────

int ContextManager::getContextSize() const
{
    int size = 0;
    for (const auto &item : m_contextItems.values()) {
        size += estimateTokenCount(item.content);
    }
    return size;
}

void ContextManager::setMaxContextSize(int size)
{
    m_maxContextSize = size;
}

void ContextManager::trimContext()
{
    int currentSize = getContextSize();
    if (currentSize <= m_maxContextSize) {
        return;
    }
    
    removeLowestPriorityItems(m_maxContextSize);
}

// ── Context History and Snapshots ───────────────────────────────────────

QString ContextManager::createSnapshot()
{
    QString snapshotId = generateItemId();
    m_snapshots[snapshotId] = m_contextItems.values();
    qDebug() << "Created snapshot:" << snapshotId << "with" << m_contextItems.size() << "items";
    return snapshotId;
}

bool ContextManager::restoreSnapshot(const QString &snapshotId)
{
    auto it = m_snapshots.find(snapshotId);
    if (it != m_snapshots.end()) {
        m_contextItems.clear();
        for (const auto &item : it.value()) {
            m_contextItems[item.id] = item;
        }
        qDebug() << "Restored snapshot:" << snapshotId;
        return true;
    }
    return false;
}

QList<QString> ContextManager::getSnapshots() const
{
    return m_snapshots.keys();
}

void ContextManager::clearSnapshots()
{
    m_snapshots.clear();
}

// ── Context Analysis ────────────────────────────────────────────────────

QJsonObject ContextManager::getStatistics() const
{
    QJsonObject stats;
    stats["totalItems"] = m_contextItems.size();
    stats["contextSize"] = getContextSize();
    stats["maxSize"] = m_maxContextSize;
    
    QJsonObject byType;
    for (const auto &item : m_contextItems.values()) {
        byType[item.type] = byType[item.type].toInt(0) + 1;
    }
    stats["byType"] = byType;
    
    stats["snapshotCount"] = m_snapshots.size();
    
    return stats;
}

QList<ContextItem> ContextManager::findRelated(const QString &query) const
{
    QList<ContextItem> result;
    QString lowerQuery = query.toLower();
    
    for (const auto &item : m_contextItems.values()) {
        if (item.content.toLower().contains(lowerQuery) ||
            item.source.toLower().contains(lowerQuery)) {
            result.append(item);
        }
    }
    
    return result;
}

// ── Private helper methods ───────────────────────────────────────────────

QString ContextManager::generateItemId()
{
    return QString("ctx_%1_%2").arg(++m_itemCounter).arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
}

int ContextManager::estimateTokenCount(const QString &text) const
{
    // Rough estimation: 1 token ≈ 4 characters
    return text.length() / 4 + 1;
}

void ContextManager::removeLowestPriorityItems(int targetSize)
{
    // Get items sorted by priority (lowest first)
    auto items = m_contextItems.values();
    std::sort(items.begin(), items.end(),
              [](const ContextItem &a, const ContextItem &b) {
                  return a.priority < b.priority;
              });
    
    // Remove items until we reach target size
    int currentSize = getContextSize();
    for (const auto &item : items) {
        if (currentSize <= targetSize) {
            break;
        }
        
        removeContextItem(item.id);
        currentSize -= estimateTokenCount(item.content);
    }
}
