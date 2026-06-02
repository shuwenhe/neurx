#pragma once

#include "MemoryManager.h"
#include <QMap>
#include <QMutex>

/**
 * @class DefaultMemoryManager
 * @brief Default memory management implementation
 * 
 * Features:
 * - Semantic and episodic memory storage
 * - Similarity-based search
 * - Memory consolidation
 * - Working memory context management
 * - Memory graph and relations
 */
class DefaultMemoryManager : public MemoryManager {
    Q_OBJECT
public:
    explicit DefaultMemoryManager(QObject *parent = nullptr);
    ~DefaultMemoryManager() = default;
    
    // Memory Storage
    QString storeMemory(const MemoryEntry &memory,
                       MemoryCallback callback = nullptr) override;
    QString storeEpisodicMemory(const EpisodicMemory &memory,
                               MemoryCallback callback = nullptr) override;
    QString storeSemanticMemory(const SemanticMemory &memory,
                               MemoryCallback callback = nullptr) override;
    QString storeWorkingMemory(const WorkingMemory &memory,
                              MemoryCallback callback = nullptr) override;
    void updateMemory(const QString &memoryId, const MemoryEntry &updates,
                     std::function<void(bool success)> callback) override;
    void deleteMemory(const QString &memoryId,
                     std::function<void(bool success)> callback) override;
    MemoryEntry getMemory(const QString &memoryId) const override;
    
    // Memory Retrieval
    void semanticSearch(const QString &queryText,
                       int maxResults = 10,
                       MemorySearchCallback callback = nullptr) override;
    void semanticSearchWithEmbedding(const Embedding &queryEmbedding,
                                    int maxResults = 10,
                                    MemorySearchCallback callback = nullptr) override;
    void keywordSearch(const QString &keyword,
                      MemorySearchCallback callback = nullptr) override;
    void searchByTags(const QStringList &tags,
                     MemorySearchCallback callback = nullptr) override;
    void searchByTimeRange(const QDateTime &from, const QDateTime &to,
                          MemorySearchCallback callback = nullptr) override;
    void searchByDomain(const QString &domain,
                       MemorySearchCallback callback = nullptr) override;
    void hybridSearch(const MemoryQuery &query,
                     MemorySearchCallback callback = nullptr) override;
    void findSimilarMemories(const QString &memoryId,
                            int maxResults = 10,
                            MemorySearchCallback callback = nullptr) override;
    QVector<MemoryEntry> getWorkingMemoryContext(int windowSize = 5) const override;
    QVector<EpisodicMemory> getRecentEpisodes(int limit = 10) const override;
    
    // Memory Relations
    void linkMemories(const QString &fromId, const QString &toId,
                     MemoryRelationType relationType,
                     float strength = 0.5f,
                     std::function<void(bool success)> callback = nullptr) override;
    QVector<MemoryRelation> getMemoryRelations(const QString &memoryId) const override;
    QVector<MemoryEntry> traverseMemoryGraph(const QString &startId,
                                            int depth = 3) const override;
    
    // Working Memory Management
    void addToWorkingMemory(const MemoryEntry &memory,
                           std::function<void(bool success)> callback = nullptr) override;
    void removeFromWorkingMemory(const QString &memoryId,
                                std::function<void(bool success)> callback = nullptr) override;
    void clearWorkingMemory(std::function<void(bool success)> callback = nullptr) override;
    int getWorkingMemorySize() const override;
    
    // Embedding Management
    Embedding generateEmbedding(const QString &text) override;
    QVector<Embedding> generateEmbeddings(const QStringList &texts) override;
    void recomputeEmbedding(const QString &memoryId,
                           std::function<void(bool success)> callback = nullptr) override;
    void batchRecomputeEmbeddings(const QStringList &memoryIds,
                                 std::function<void(int processed)> callback = nullptr) override;
    float computeSimilarity(const Embedding &emb1, const Embedding &emb2) const override;
    
    // Memory Consolidation
    void consolidateMemories(const QStringList &memoryIds,
                            std::function<void(const QString &resultId)> callback = nullptr) override;
    QString summarizeMemory(const QString &memoryId) override;
    QStringList extractKeyFacts(const QString &memoryId) override;
    void cleanupExpiredMemories(std::function<void(int removed)> callback = nullptr) override;
    
    // Memory Access Tracking
    void recordAccess(const QString &memoryId) override;
    void updateImportance(const QString &memoryId, int importance,
                         std::function<void(bool success)> callback = nullptr) override;
    QVariantMap getAccessStatistics(const QString &memoryId) const override;
    
    // Statistics & Monitoring
    MemoryStats getMemoryStats() const override;
    QVariantMap getMemoryTypeDistribution() const override;
    QVariantMap getSearchStats() const override;
    
    // Persistence
    void saveMemoryIndex(const QString &context,
                        std::function<void(bool success)> callback = nullptr) override;
    void loadMemoryIndex(const QString &context,
                        std::function<void(bool success)> callback = nullptr) override;
    void exportMemories(const QString &format,
                       std::function<void(const QByteArray &data)> callback = nullptr) override;
    void importMemories(const QByteArray &data,
                       std::function<void(int imported)> callback = nullptr) override;
    
    // Batch Operations
    void bulkStoreMemories(const QVector<MemoryEntry> &memories,
                          std::function<void(int stored)> callback = nullptr) override;
    void bulkDeleteMemories(const QStringList &memoryIds,
                           std::function<void(int deleted)> callback = nullptr) override;
    
    // Configuration
    void setEmbeddingModel(const QString &modelName) override;
    QString getEmbeddingModel() const override;
    void setRetentionPolicy(int defaultExpirationDays) override;
    int getMemoryCapacity() const override;
    void setMemoryCapacity(int maxMemories) override;

private:
    struct MemoryIndexEntry {
        MemoryEntry memory;
        Embedding embedding;
        qint64 lastAccessTime = 0;
    };
    
    QMap<QString, MemoryIndexEntry> m_memories;
    QVector<QString> m_workingMemories;
    QVector<MemoryRelation> m_relations;
    
    QMap<QString, int> m_accessCounts;
    int m_totalSearches = 0;
    qint64 m_totalSearchTime = 0;
    
    QString m_embeddingModel = "default";
    int m_embeddingDimension = 768;
    int m_maxMemories = 10000;
    int m_defaultExpirationDays = 365;
    
    mutable QMutex m_mutex;
    
    // Helper methods
    float computeCosineSimilarity(const Embedding &emb1, const Embedding &emb2) const;
    QVector<MemorySearchResult> rankSearchResults(
        const QVector<MemoryEntry> &candidates,
        float threshold = 0.5f,
        int maxResults = 10
    ) const;
    void updateMemoryStats(const QString &memoryId);
    bool isMemoryExpired(const MemoryEntry &memory) const;
};

using DefaultMemoryManagerPtr = std::shared_ptr<DefaultMemoryManager>;
