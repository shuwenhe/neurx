#include "DefaultMemoryManager.h"
#include <QDebug>
#include <QUuid>
#include <QDateTime>
#include <cmath>
#include <algorithm>

DefaultMemoryManager::DefaultMemoryManager(QObject *parent)
    : MemoryManager(parent)
{
}

QString DefaultMemoryManager::storeMemory(const MemoryEntry &memory,
                                          MemoryCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    // Generate ID if not present
    QString id = memory.memoryId.isEmpty() ? QUuid::createUuid().toString() : memory.memoryId;
    
    MemoryIndexEntry entry;
    entry.memory = memory;
    entry.memory.memoryId = id;
    entry.memory.createdAt = QDateTime::currentDateTime();
    entry.memory.updatedAt = QDateTime::currentDateTime();
    entry.lastAccessTime = QDateTime::currentDateTime().toMSecsSinceEpoch();
    
    // Generate embedding if not present
    if (entry.memory.embedding.isEmpty() && !entry.memory.content.isEmpty()) {
        entry.embedding = generateEmbedding(entry.memory.content);
        entry.memory.embedding = entry.embedding;
    }
    
    m_memories[id] = entry;
    m_accessCounts[id] = 0;
    
    locker.unlock();
    
    emit memoryStored(id, memory.type);
    
    if (callback) {
        callback(entry.memory);
    }
    
    return id;
}

QString DefaultMemoryManager::storeEpisodicMemory(const EpisodicMemory &memory,
                                                  MemoryCallback callback)
{
    // Cast and store as regular memory
    return storeMemory(static_cast<MemoryEntry>(memory), callback);
}

QString DefaultMemoryManager::storeSemanticMemory(const SemanticMemory &memory,
                                                  MemoryCallback callback)
{
    return storeMemory(static_cast<MemoryEntry>(memory), callback);
}

QString DefaultMemoryManager::storeWorkingMemory(const WorkingMemory &memory,
                                                 MemoryCallback callback)
{
    QString id = storeMemory(static_cast<MemoryEntry>(memory), callback);
    
    QMutexLocker locker(&m_mutex);
    m_workingMemories.append(id);
    
    return id;
}

void DefaultMemoryManager::updateMemory(const QString &memoryId, const MemoryEntry &updates,
                                       std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        // Update fields
        if (!updates.content.isEmpty()) it->memory.content = updates.content;
        if (!updates.title.isEmpty()) it->memory.title = updates.title;
        if (updates.importance > 0) it->memory.importance = updates.importance;
        if (!updates.tags.isEmpty()) it->memory.tags = updates.tags;
        
        it->memory.updatedAt = QDateTime::currentDateTime();
        
        // Regenerate embedding if content changed
        if (!updates.content.isEmpty()) {
            it->embedding = generateEmbedding(updates.content);
            it->memory.embedding = it->embedding;
        }
        
        locker.unlock();
        emit memoryUpdated(memoryId);
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultMemoryManager::deleteMemory(const QString &memoryId,
                                       std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_memories.remove(memoryId) > 0) {
        m_workingMemories.removeAll(memoryId);
        m_accessCounts.remove(memoryId);
        
        locker.unlock();
        emit memoryDeleted(memoryId);
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

MemoryEntry DefaultMemoryManager::getMemory(const QString &memoryId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        return it->memory;
    }
    
    return MemoryEntry();
}

void DefaultMemoryManager::semanticSearch(const QString &queryText,
                                         int maxResults,
                                         MemorySearchCallback callback)
{
    Embedding queryEmbedding = generateEmbedding(queryText);
    semanticSearchWithEmbedding(queryEmbedding, maxResults, callback);
}

void DefaultMemoryManager::semanticSearchWithEmbedding(const Embedding &queryEmbedding,
                                                      int maxResults,
                                                      MemorySearchCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemorySearchResult> results;
    
    for (auto it = m_memories.begin(); it != m_memories.end(); ++it) {
        if (it->embedding.isEmpty()) continue;
        
        float similarity = computeCosineSimilarity(queryEmbedding, it->embedding);
        
        if (similarity >= 0.5f) {
            MemorySearchResult result;
            result.memory = it->memory;
            result.similarityScore = similarity;
            result.relevanceScore = similarity * (it->memory.importance / 10.0f);
            result.rank = results.size() + 1;
            
            results.append(result);
        }
    }
    
    // Sort by relevance
    std::sort(results.begin(), results.end(),
        [](const MemorySearchResult &a, const MemorySearchResult &b) {
            return a.relevanceScore > b.relevanceScore;
        });
    
    // Limit results
    if (results.size() > maxResults) {
        results.resize(maxResults);
    }
    
    locker.unlock();
    
    emit searchCompleted(results);
    if (callback) callback(results);
}

void DefaultMemoryManager::keywordSearch(const QString &keyword,
                                        MemorySearchCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemorySearchResult> results;
    
    for (auto it = m_memories.begin(); it != m_memories.end(); ++it) {
        if (it->memory.content.contains(keyword, Qt::CaseInsensitive) ||
            it->memory.title.contains(keyword, Qt::CaseInsensitive) ||
            it->memory.tags.contains(keyword, Qt::CaseInsensitive)) {
            
            MemorySearchResult result;
            result.memory = it->memory;
            result.similarityScore = 1.0f;
            result.relevanceScore = 1.0f;
            result.rank = results.size() + 1;
            
            results.append(result);
        }
    }
    
    locker.unlock();
    
    if (callback) callback(results);
}

void DefaultMemoryManager::searchByTags(const QStringList &tags,
                                       MemorySearchCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemorySearchResult> results;
    
    for (auto it = m_memories.begin(); it != m_memories.end(); ++it) {
        for (const auto &tag : tags) {
            if (it->memory.tags.contains(tag)) {
                MemorySearchResult result;
                result.memory = it->memory;
                result.similarityScore = 1.0f;
                result.relevanceScore = 1.0f;
                result.rank = results.size() + 1;
                
                results.append(result);
                break;
            }
        }
    }
    
    locker.unlock();
    
    if (callback) callback(results);
}

void DefaultMemoryManager::searchByTimeRange(const QDateTime &from, const QDateTime &to,
                                            MemorySearchCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemorySearchResult> results;
    
    for (auto it = m_memories.begin(); it != m_memories.end(); ++it) {
        if (it->memory.createdAt >= from && it->memory.createdAt <= to) {
            MemorySearchResult result;
            result.memory = it->memory;
            result.similarityScore = 1.0f;
            result.relevanceScore = 1.0f;
            result.rank = results.size() + 1;
            
            results.append(result);
        }
    }
    
    locker.unlock();
    
    if (callback) callback(results);
}

void DefaultMemoryManager::searchByDomain(const QString &domain,
                                         MemorySearchCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemorySearchResult> results;
    
    for (auto it = m_memories.begin(); it != m_memories.end(); ++it) {
        if (it->memory.type == MemoryType::Semantic) {
            SemanticMemory semMem = static_cast<SemanticMemory>(it->memory);
            if (semMem.domain == domain) {
                MemorySearchResult result;
                result.memory = it->memory;
                result.similarityScore = 1.0f;
                result.relevanceScore = 1.0f;
                result.rank = results.size() + 1;
                
                results.append(result);
            }
        }
    }
    
    locker.unlock();
    
    if (callback) callback(results);
}

void DefaultMemoryManager::hybridSearch(const MemoryQuery &query,
                                       MemorySearchCallback callback)
{
    QVector<MemorySearchResult> results;
    
    if (query.type == MemoryQueryType::Semantic && !query.queryText.isEmpty()) {
        semanticSearch(query.queryText, query.maxResults, callback);
    } else if (query.type == MemoryQueryType::Keyword) {
        keywordSearch(query.queryText, callback);
    } else if (query.type == MemoryQueryType::Tag) {
        searchByTags(query.tags, callback);
    } else if (query.type == MemoryQueryType::TimeRange) {
        searchByTimeRange(query.fromTime, query.toTime, callback);
    } else if (query.type == MemoryQueryType::Hybrid) {
        // Combine multiple search strategies
        if (!query.queryText.isEmpty()) {
            semanticSearch(query.queryText, query.maxResults / 2, callback);
        }
        if (!query.tags.isEmpty()) {
            searchByTags(query.tags, callback);
        }
    }
}

void DefaultMemoryManager::findSimilarMemories(const QString &memoryId,
                                              int maxResults,
                                              MemorySearchCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_memories.find(memoryId);
    if (it == m_memories.end() || it->embedding.isEmpty()) {
        locker.unlock();
        if (callback) callback(QVector<MemorySearchResult>());
        return;
    }
    
    Embedding queryEmbedding = it->embedding;
    locker.unlock();
    
    semanticSearchWithEmbedding(queryEmbedding, maxResults, callback);
}

QVector<MemoryEntry> DefaultMemoryManager::getWorkingMemoryContext(int windowSize) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemoryEntry> context;
    
    int start = std::max(0, static_cast<int>(m_workingMemories.size()) - windowSize);
    for (int i = start; i < m_workingMemories.size(); ++i) {
        auto it = m_memories.find(m_workingMemories[i]);
        if (it != m_memories.end()) {
            context.append(it->memory);
        }
    }
    
    return context;
}

QVector<EpisodicMemory> DefaultMemoryManager::getRecentEpisodes(int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<EpisodicMemory> episodes;
    
    for (auto it = m_memories.begin(); it != m_memories.end(); ++it) {
        if (it->memory.type == MemoryType::Episodic) {
            episodes.append(static_cast<EpisodicMemory>(it->memory));
        }
    }
    
    std::sort(episodes.begin(), episodes.end(),
        [](const EpisodicMemory &a, const EpisodicMemory &b) {
            return a.createdAt > b.createdAt;
        });
    
    if (episodes.size() > limit) {
        episodes.resize(limit);
    }
    
    return episodes;
}

void DefaultMemoryManager::linkMemories(const QString &fromId, const QString &toId,
                                       MemoryRelationType relationType,
                                       float strength,
                                       std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_memories.contains(fromId) && m_memories.contains(toId)) {
        MemoryRelation relation;
        relation.relationId = QUuid::createUuid().toString();
        relation.fromMemoryId = fromId;
        relation.toMemoryId = toId;
        relation.type = relationType;
        relation.strength = strength;
        relation.createdAt = QDateTime::currentDateTime();
        
        m_relations.append(relation);
        
        locker.unlock();
        emit memoriesLinked(fromId, toId);
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

QVector<MemoryRelation> DefaultMemoryManager::getMemoryRelations(const QString &memoryId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemoryRelation> relations;
    
    for (const auto &relation : m_relations) {
        if (relation.fromMemoryId == memoryId || relation.toMemoryId == memoryId) {
            relations.append(relation);
        }
    }
    
    return relations;
}

QVector<MemoryEntry> DefaultMemoryManager::traverseMemoryGraph(const QString &startId,
                                                              int depth) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<MemoryEntry> traversed;
    QStringList visited;
    
    std::function<void(const QString &, int)> traverse;
    traverse = [&](const QString &currentId, int currentDepth) {
        if (currentDepth <= 0 || visited.contains(currentId)) return;
        
        visited.append(currentId);
        
        auto it = m_memories.find(currentId);
        if (it != m_memories.end()) {
            traversed.append(it->memory);
        }
        
        for (const auto &relation : m_relations) {
            if (relation.fromMemoryId == currentId) {
                traverse(relation.toMemoryId, currentDepth - 1);
            } else if (relation.toMemoryId == currentId) {
                traverse(relation.fromMemoryId, currentDepth - 1);
            }
        }
    };
    
    traverse(startId, depth);
    
    return traversed;
}

void DefaultMemoryManager::addToWorkingMemory(const MemoryEntry &memory,
                                             std::function<void(bool success)> callback)
{
    QString id = storeWorkingMemory(static_cast<WorkingMemory>(memory));
    if (!id.isEmpty()) {
        if (callback) callback(true);
    } else {
        if (callback) callback(false);
    }
}

void DefaultMemoryManager::removeFromWorkingMemory(const QString &memoryId,
                                                  std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_workingMemories.removeAll(memoryId) > 0) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultMemoryManager::clearWorkingMemory(std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    m_workingMemories.clear();
    locker.unlock();
    
    if (callback) callback(true);
}

int DefaultMemoryManager::getWorkingMemorySize() const
{
    QMutexLocker locker(&m_mutex);
    return m_workingMemories.size();
}

Embedding DefaultMemoryManager::generateEmbedding(const QString &text)
{
    // Simple stub: generate a random embedding
    // In production, would use actual embedding model (OpenAI, Hugging Face, etc.)
    Embedding embedding(m_embeddingDimension);
    for (int i = 0; i < m_embeddingDimension; ++i) {
        embedding[i] = (static_cast<float>(qHash(text) + i) / 1000.0f);
    }
    
    // Normalize to unit vector
    float magnitude = 0.0f;
    for (float val : embedding) {
        magnitude += val * val;
    }
    magnitude = std::sqrt(magnitude);
    
    if (magnitude > 0.0f) {
        for (auto &val : embedding) {
            val /= magnitude;
        }
    }
    
    return embedding;
}

QVector<Embedding> DefaultMemoryManager::generateEmbeddings(const QStringList &texts)
{
    QVector<Embedding> embeddings;
    for (const auto &text : texts) {
        embeddings.append(generateEmbedding(text));
    }
    return embeddings;
}

void DefaultMemoryManager::recomputeEmbedding(const QString &memoryId,
                                             std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        it->embedding = generateEmbedding(it->memory.content);
        it->memory.embedding = it->embedding;
        
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultMemoryManager::batchRecomputeEmbeddings(const QStringList &memoryIds,
                                                   std::function<void(int processed)> callback)
{
    int processed = 0;
    
    for (const auto &id : memoryIds) {
        recomputeEmbedding(id, nullptr);
        processed++;
    }
    
    if (callback) callback(processed);
}

float DefaultMemoryManager::computeSimilarity(const Embedding &emb1, const Embedding &emb2) const
{
    return computeCosineSimilarity(emb1, emb2);
}

void DefaultMemoryManager::consolidateMemories(const QStringList &memoryIds,
                                              std::function<void(const QString &resultId)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    // Merge memories
    MemoryEntry consolidated;
    consolidated.memoryId = QUuid::createUuid().toString();
    consolidated.title = "Consolidated Memory";
    
    for (const auto &id : memoryIds) {
        auto it = m_memories.find(id);
        if (it != m_memories.end()) {
            consolidated.content += it->memory.content + "\n";
            consolidated.tags.append(it->memory.tags);
        }
    }
    
    locker.unlock();
    
    QString resultId = storeMemory(consolidated);
    
    if (callback) callback(resultId);
}

QString DefaultMemoryManager::summarizeMemory(const QString &memoryId)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        // Simple summarization: return first 100 chars
        return it->memory.content.left(100) + "...";
    }
    
    return "";
}

QStringList DefaultMemoryManager::extractKeyFacts(const QString &memoryId)
{
    QMutexLocker locker(&m_mutex);
    
    QStringList facts;
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        // Simple fact extraction: split by periods
        facts = it->memory.content.split(".");
    }
    
    return facts;
}

void DefaultMemoryManager::cleanupExpiredMemories(std::function<void(int removed)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    int removed = 0;
    
    for (auto it = m_memories.begin(); it != m_memories.end(); ) {
        if (isMemoryExpired(it->memory)) {
            it = m_memories.erase(it);
            removed++;
        } else {
            ++it;
        }
    }
    
    locker.unlock();
    
    if (callback) callback(removed);
}

void DefaultMemoryManager::recordAccess(const QString &memoryId)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        it->memory.accessCount++;
        it->memory.lastAccessedAt = QDateTime::currentDateTime();
        it->lastAccessTime = QDateTime::currentDateTime().toMSecsSinceEpoch();
        
        m_accessCounts[memoryId]++;
    }
}

void DefaultMemoryManager::updateImportance(const QString &memoryId, int importance,
                                           std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        it->memory.importance = qBound(1, importance, 10);
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

QVariantMap DefaultMemoryManager::getAccessStatistics(const QString &memoryId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    
    auto it = m_memories.find(memoryId);
    if (it != m_memories.end()) {
        stats["accessCount"] = it->memory.accessCount;
        stats["lastAccessedAt"] = it->memory.lastAccessedAt.toString();
        stats["createdAt"] = it->memory.createdAt.toString();
        stats["updatedAt"] = it->memory.updatedAt.toString();
        stats["importance"] = it->memory.importance;
    }
    
    return stats;
}

MemoryStats DefaultMemoryManager::getMemoryStats() const
{
    QMutexLocker locker(&m_mutex);
    
    MemoryStats stats;
    stats.totalMemories = m_memories.size();
    stats.totalSearches = m_totalSearches;
    
    for (const auto &entry : m_memories) {
        switch (entry.memory.type) {
            case MemoryType::Semantic:
                stats.semanticMemories++;
                break;
            case MemoryType::Episodic:
                stats.episodicMemories++;
                break;
            case MemoryType::Working:
                stats.workingMemories++;
                break;
            case MemoryType::Procedural:
                stats.proceduralMemories++;
                break;
            case MemoryType::Emotional:
                stats.emotionalMemories++;
                break;
        }
    }
    
    return stats;
}

QVariantMap DefaultMemoryManager::getMemoryTypeDistribution() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap distribution;
    distribution["semantic"] = 0;
    distribution["episodic"] = 0;
    distribution["working"] = 0;
    distribution["procedural"] = 0;
    distribution["emotional"] = 0;
    
    for (const auto &entry : m_memories) {
        switch (entry.memory.type) {
            case MemoryType::Semantic:
                distribution["semantic"] = distribution["semantic"].toInt() + 1;
                break;
            case MemoryType::Episodic:
                distribution["episodic"] = distribution["episodic"].toInt() + 1;
                break;
            case MemoryType::Working:
                distribution["working"] = distribution["working"].toInt() + 1;
                break;
            case MemoryType::Procedural:
                distribution["procedural"] = distribution["procedural"].toInt() + 1;
                break;
            case MemoryType::Emotional:
                distribution["emotional"] = distribution["emotional"].toInt() + 1;
                break;
        }
    }
    
    return distribution;
}

QVariantMap DefaultMemoryManager::getSearchStats() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalSearches"] = m_totalSearches;
    stats["averageSearchTime"] = m_totalSearches > 0 ? m_totalSearchTime / m_totalSearches : 0;
    
    return stats;
}

void DefaultMemoryManager::saveMemoryIndex(const QString &context,
                                          std::function<void(bool success)> callback)
{
    // Would save to persistent storage
    if (callback) callback(true);
}

void DefaultMemoryManager::loadMemoryIndex(const QString &context,
                                          std::function<void(bool success)> callback)
{
    // Would load from persistent storage
    if (callback) callback(true);
}

void DefaultMemoryManager::exportMemories(const QString &format,
                                         std::function<void(const QByteArray &data)> callback)
{
    // Would export to JSON, CSV, etc.
    if (callback) callback(QByteArray());
}

void DefaultMemoryManager::importMemories(const QByteArray &data,
                                         std::function<void(int imported)> callback)
{
    // Would import from various formats
    if (callback) callback(0);
}

void DefaultMemoryManager::bulkStoreMemories(const QVector<MemoryEntry> &memories,
                                            std::function<void(int stored)> callback)
{
    int stored = 0;
    
    for (const auto &memory : memories) {
        storeMemory(memory);
        stored++;
    }
    
    if (callback) callback(stored);
}

void DefaultMemoryManager::bulkDeleteMemories(const QStringList &memoryIds,
                                             std::function<void(int deleted)> callback)
{
    int deleted = 0;
    
    for (const auto &id : memoryIds) {
        deleteMemory(id, nullptr);
        deleted++;
    }
    
    if (callback) callback(deleted);
}

void DefaultMemoryManager::setEmbeddingModel(const QString &modelName)
{
    QMutexLocker locker(&m_mutex);
    m_embeddingModel = modelName;
}

QString DefaultMemoryManager::getEmbeddingModel() const
{
    QMutexLocker locker(&m_mutex);
    return m_embeddingModel;
}

void DefaultMemoryManager::setRetentionPolicy(int defaultExpirationDays)
{
    QMutexLocker locker(&m_mutex);
    m_defaultExpirationDays = defaultExpirationDays;
}

int DefaultMemoryManager::getMemoryCapacity() const
{
    QMutexLocker locker(&m_mutex);
    return m_maxMemories;
}

void DefaultMemoryManager::setMemoryCapacity(int maxMemories)
{
    QMutexLocker locker(&m_mutex);
    m_maxMemories = maxMemories;
}

float DefaultMemoryManager::computeCosineSimilarity(const Embedding &emb1, const Embedding &emb2) const
{
    if (emb1.isEmpty() || emb2.isEmpty()) return 0.0f;
    if (emb1.size() != emb2.size()) return 0.0f;
    
    float dotProduct = 0.0f;
    float mag1 = 0.0f;
    float mag2 = 0.0f;
    
    for (int i = 0; i < emb1.size(); ++i) {
        dotProduct += emb1[i] * emb2[i];
        mag1 += emb1[i] * emb1[i];
        mag2 += emb2[i] * emb2[i];
    }
    
    mag1 = std::sqrt(mag1);
    mag2 = std::sqrt(mag2);
    
    if (mag1 > 0.0f && mag2 > 0.0f) {
        return dotProduct / (mag1 * mag2);
    }
    
    return 0.0f;
}

bool DefaultMemoryManager::isMemoryExpired(const MemoryEntry &memory) const
{
    if (memory.expirationDays <= 0) return false;
    
    QDateTime expiryDate = memory.createdAt.addDays(memory.expirationDays);
    return expiryDate < QDateTime::currentDateTime();
}

#include "moc_DefaultMemoryManager.cpp"
