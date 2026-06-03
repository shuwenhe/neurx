#pragma once

#include "MemoryTypes.h"
#include <QObject>
#include <memory>

/**
 * @class MemoryManager
 * @brief Agent semantic and episodic memory management
 * 
 * Handles:
 * - Semantic memory (knowledge and facts)
 * - Episodic memory (experiences and events)
 * - Working memory (active context)
 * - Memory search and retrieval
 * - Memory consolidation
 */
class MemoryManager : public QObject {
    Q_OBJECT
public:
    virtual ~MemoryManager() = default;

protected:
    explicit MemoryManager(QObject *parent = nullptr) : QObject(parent) {}
    
    // ── Memory Storage ────────────────────────────────────
    
    /// Store a new memory
    virtual QString storeMemory(const MemoryEntry &memory,
                               MemoryCallback callback = nullptr) = 0;
    
    /// Store episodic memory
    virtual QString storeEpisodicMemory(const EpisodicMemory &memory,
                                       MemoryCallback callback = nullptr) = 0;
    
    /// Store semantic memory
    virtual QString storeSemanticMemory(const SemanticMemory &memory,
                                       MemoryCallback callback = nullptr) = 0;
    
    /// Store working memory
    virtual QString storeWorkingMemory(const WorkingMemory &memory,
                                      MemoryCallback callback = nullptr) = 0;
    
    /// Update existing memory
    virtual void updateMemory(const QString &memoryId, const MemoryEntry &updates,
                             std::function<void(bool success)> callback) = 0;
    
    /// Delete memory
    virtual void deleteMemory(const QString &memoryId,
                             std::function<void(bool success)> callback) = 0;
    
    /// Get memory by ID
    virtual MemoryEntry getMemory(const QString &memoryId) const = 0;
    
    // ── Memory Retrieval ──────────────────────────────────
    
    /// Semantic search (similarity-based)
    virtual void semanticSearch(const QString &queryText,
                               int maxResults = 10,
                               MemorySearchCallback callback = nullptr) = 0;
    
    /// Semantic search with embedding
    virtual void semanticSearchWithEmbedding(const Embedding &queryEmbedding,
                                            int maxResults = 10,
                                            MemorySearchCallback callback = nullptr) = 0;
    
    /// Keyword search
    virtual void keywordSearch(const QString &keyword,
                              MemorySearchCallback callback = nullptr) = 0;
    
    /// Tag-based search
    virtual void searchByTags(const QStringList &tags,
                             MemorySearchCallback callback = nullptr) = 0;
    
    /// Time-based search
    virtual void searchByTimeRange(const QDateTime &from, const QDateTime &to,
                                  MemorySearchCallback callback = nullptr) = 0;
    
    /// Domain-specific search (semantic memories)
    virtual void searchByDomain(const QString &domain,
                               MemorySearchCallback callback = nullptr) = 0;
    
    /// Hybrid search combining multiple criteria
    virtual void hybridSearch(const MemoryQuery &query,
                             MemorySearchCallback callback = nullptr) = 0;
    
    /// Get similar memories
    virtual void findSimilarMemories(const QString &memoryId,
                                    int maxResults = 10,
                                    MemorySearchCallback callback = nullptr) = 0;
    
    /// Retrieve working memory context
    virtual QVector<MemoryEntry> getWorkingMemoryContext(int windowSize = 5) const = 0;
    
    /// Get recent episodic memories
    virtual QVector<EpisodicMemory> getRecentEpisodes(int limit = 10) const = 0;
    
    // ── Memory Relations ──────────────────────────────────
    
    /// Link two memories
    virtual void linkMemories(const QString &fromId, const QString &toId,
                             MemoryRelationType relationType,
                             float strength = 0.5f,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get memory relations
    virtual QVector<MemoryRelation> getMemoryRelations(const QString &memoryId) const = 0;
    
    /// Traverse memory graph
    virtual QVector<MemoryEntry> traverseMemoryGraph(const QString &startId,
                                                    int depth = 3) const = 0;
    
    // ── Working Memory Management ──────────────────────
    
    /// Add to working memory
    virtual void addToWorkingMemory(const MemoryEntry &memory,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Remove from working memory
    virtual void removeFromWorkingMemory(const QString &memoryId,
                                        std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Clear working memory
    virtual void clearWorkingMemory(std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get working memory size
    virtual int getWorkingMemorySize() const = 0;
    
    // ── Embedding Management ───────────────────────────
    
    /// Generate embedding for text
    virtual Embedding generateEmbedding(const QString &text) = 0;
    
    /// Generate embeddings for texts
    virtual QVector<Embedding> generateEmbeddings(const QStringList &texts) = 0;
    
    /// Recompute embedding for memory
    virtual void recomputeEmbedding(const QString &memoryId,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Batch recompute embeddings
    virtual void batchRecomputeEmbeddings(const QStringList &memoryIds,
                                         std::function<void(int processed)> callback = nullptr) = 0;
    
    /// Compute similarity between two embeddings
    virtual float computeSimilarity(const Embedding &emb1, const Embedding &emb2) const = 0;
    
    // ── Memory Consolidation ───────────────────────────
    
    /// Consolidate memories (merge similar)
    virtual void consolidateMemories(const QStringList &memoryIds,
                                    std::function<void(const QString &resultId)> callback = nullptr) = 0;
    
    /// Summarize memory
    virtual QString summarizeMemory(const QString &memoryId) = 0;
    
    /// Extract key facts from memory
    virtual QStringList extractKeyFacts(const QString &memoryId) = 0;
    
    /// Cleanup expired memories
    virtual void cleanupExpiredMemories(std::function<void(int removed)> callback = nullptr) = 0;
    
    // ── Memory Access Tracking ────────────────────────
    
    /// Record memory access
    virtual void recordAccess(const QString &memoryId) = 0;
    
    /// Update memory importance
    virtual void updateImportance(const QString &memoryId, int importance,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get access statistics
    virtual QVariantMap getAccessStatistics(const QString &memoryId) const = 0;
    
    // ── Statistics & Monitoring ────────────────────────
    
    /// Get memory statistics
    virtual MemoryStats getMemoryStats() const = 0;
    
    /// Get memory type distribution
    virtual QVariantMap getMemoryTypeDistribution() const = 0;
    
    /// Get search performance stats
    virtual QVariantMap getSearchStats() const = 0;
    
    // ── Persistence ───────────────────────────────────
    
    /// Save memory index
    virtual void saveMemoryIndex(const QString &context,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Load memory index
    virtual void loadMemoryIndex(const QString &context,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Export memories
    virtual void exportMemories(const QString &format,
                               std::function<void(const QByteArray &data)> callback = nullptr) = 0;
    
    /// Import memories
    virtual void importMemories(const QByteArray &data,
                               std::function<void(int imported)> callback = nullptr) = 0;
    
    // ── Batch Operations ───────────────────────────────
    
    /// Bulk store memories
    virtual void bulkStoreMemories(const QVector<MemoryEntry> &memories,
                                  std::function<void(int stored)> callback = nullptr) = 0;
    
    /// Bulk delete memories
    virtual void bulkDeleteMemories(const QStringList &memoryIds,
                                   std::function<void(int deleted)> callback = nullptr) = 0;
    
    // ── Configuration ──────────────────────────────────
    
    /// Set embedding model
    virtual void setEmbeddingModel(const QString &modelName) = 0;
    
    /// Get embedding model
    virtual QString getEmbeddingModel() const = 0;
    
    /// Set memory retention policy
    virtual void setRetentionPolicy(int defaultExpirationDays) = 0;
    
    /// Get memory capacity
    virtual int getMemoryCapacity() const = 0;
    
    /// Set memory capacity
    virtual void setMemoryCapacity(int maxMemories) = 0;

signals:
    /// Memory stored signal
    void memoryStored(const QString &memoryId, MemoryType type);
    
    /// Memory updated signal
    void memoryUpdated(const QString &memoryId);
    
    /// Memory deleted signal
    void memoryDeleted(const QString &memoryId);
    
    /// Search completed signal
    void searchCompleted(const QVector<MemorySearchResult> &results);
    
    /// Memory linked signal
    void memoriesLinked(const QString &fromId, const QString &toId);
    
    /// Memory consolidation signal
    void memoryConsolidated(const QString &resultId);
    
    /// Expired memory cleanup signal
    void expiredMemoriesCleanedUp(int count);
};

using MemoryManagerPtr = std::shared_ptr<MemoryManager>;
