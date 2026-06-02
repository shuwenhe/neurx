# Neurx Memory System

The Memory System manages semantic and episodic memory for sophisticated agent behavior, including knowledge storage, experience tracking, and intelligent recall.

## Overview

The memory management system provides:
- Semantic memory (knowledge and facts)
- Episodic memory (experiences and events)
- Working memory (active context)
- Vector similarity search
- Memory consolidation
- Memory graph relationships

## Core Components

### Memory Types

```cpp
enum class MemoryType {
    Semantic,    // Knowledge and facts
    Episodic,    // Experiences and events
    Working,     // Short-term active memory
    Procedural,  // Skills and procedures
    Emotional    // Emotional associations
};
```

### Embeddings

Memories are represented as vector embeddings for similarity search:

```cpp
using Embedding = QVector<float>;  // Vector representation (768-1024 dims)
using SimilarityScore = float;     // Score 0.0-1.0
```

### Memory Entry

All memories have:
```cpp
struct MemoryEntry {
    QString memoryId;              // Unique ID
    MemoryType type;               // Type of memory
    QString content;               // Main content
    Embedding embedding;           // Vector representation
    
    QString title;                 // Title
    QStringList tags;              // Tags for categorization
    int importance;                // Importance (1-10)
    int accessCount;               // Times accessed
    
    QDateTime createdAt;           // Creation time
    QDateTime updatedAt;           // Last update
    QDateTime lastAccessedAt;      // Last accessed
    int expirationDays;            // Auto-expiration
};
```

## Usage Examples

### Storing Memories

```cpp
// Store semantic memory (facts)
SemanticMemory knowledge;
knowledge.content = "Python is a programming language";
knowledge.title = "Python Programming";
knowledge.domain = "Programming Languages";
knowledge.tags = {"python", "programming", "language"};
knowledge.confidence = 9;

auto semMemId = manager->storeSemanticMemory(knowledge, [](const MemoryEntry &stored) {
    qDebug() << "Stored memory:" << stored.memoryId;
});

// Store episodic memory (experience)
EpisodicMemory experience;
experience.content = "Solved a complex bug in authentication system";
experience.title = "Bug Fix: Authentication";
experience.eventTime = QDateTime::currentDateTime();
experience.participants = {"Alice", "Bob"};
experience.importance = 8;

auto episMemId = manager->storeEpisodicMemory(experience, [](const MemoryEntry &stored) {
    qDebug() << "Stored experience:" << stored.memoryId;
});

// Store working memory (active context)
WorkingMemory active;
active.content = "Currently discussing project timeline";
active.priority = 9;
active.inActiveUse = true;

manager->storeWorkingMemory(active);
```

### Semantic Search

```cpp
// Search by similarity
manager->semanticSearch("What is Python?", 5, [](const QVector<MemorySearchResult> &results) {
    for (const auto &result : results) {
        qDebug() << "Found:" << result.memory.title
                 << "Relevance:" << result.relevanceScore;
    }
});

// Search with custom embedding
Embedding queryEmbedding = manager->generateEmbedding("Programming languages");
manager->semanticSearchWithEmbedding(queryEmbedding, 10, [](const QVector<MemorySearchResult> &results) {
    qDebug() << "Found" << results.size() << "similar memories";
});
```

### Keyword and Tag Search

```cpp
// Keyword search
manager->keywordSearch("Python", [](const QVector<MemorySearchResult> &results) {
    qDebug() << "Keyword matches:" << results.size();
});

// Tag-based search
manager->searchByTags({"python", "programming"}, [](const QVector<MemorySearchResult> &results) {
    qDebug() << "Found by tags:" << results.size();
});

// Domain search
manager->searchByDomain("Programming Languages", [](const QVector<MemorySearchResult> &results) {
    qDebug() << "Domain results:" << results.size();
});
```

### Time-Based Search

```cpp
// Find memories from specific period
QDateTime oneWeekAgo = QDateTime::currentDateTime().addDays(-7);
QDateTime now = QDateTime::currentDateTime();

manager->searchByTimeRange(oneWeekAgo, now, [](const QVector<MemorySearchResult> &results) {
    qDebug() << "Recent memories:" << results.size();
});

// Get recent episodes
auto episodes = manager->getRecentEpisodes(10);
for (const auto &episode : episodes) {
    qDebug() << "Experience:" << episode.title << "at" << episode.eventTime;
}
```

### Similarity and Relations

```cpp
// Find similar memories
manager->findSimilarMemories(memoryId, 5, [](const QVector<MemorySearchResult> &results) {
    qDebug() << "Similar memories:" << results.size();
});

// Link memories
manager->linkMemories(memoryId1, memoryId2, MemoryRelationType::Related, 0.8f);

// Get memory relations
auto relations = manager->getMemoryRelations(memoryId);
for (const auto &relation : relations) {
    qDebug() << "Related to:" << relation.toMemoryId
             << "Strength:" << relation.strength;
}

// Traverse memory graph
auto connected = manager->traverseMemoryGraph(memoryId, 3);
qDebug() << "Connected memories:" << connected.size();
```

### Working Memory Context

```cpp
// Get current working memory
auto context = manager->getWorkingMemoryContext(5);
qDebug() << "Active context size:" << context.size();

// Add to working memory
WorkingMemory active;
active.content = "Current discussion topic";
manager->addToWorkingMemory(active);

// Remove from working memory
manager->removeFromWorkingMemory(memoryId);

// Clear all working memory
manager->clearWorkingMemory([](bool success) {
    qDebug() << "Working memory cleared";
});

// Get size
int size = manager->getWorkingMemorySize();
```

### Memory Updates and Maintenance

```cpp
// Update memory
MemoryEntry updates;
updates.content = "Updated content";
updates.importance = 7;
manager->updateMemory(memoryId, updates, [](bool success) {
    qDebug() << "Memory updated:" << success;
});

// Delete memory
manager->deleteMemory(memoryId, [](bool success) {
    qDebug() << "Memory deleted:" << success;
});

// Update importance
manager->updateImportance(memoryId, 8, [](bool success) {
    qDebug() << "Importance updated";
});

// Record access
manager->recordAccess(memoryId);

// Clean up expired memories
manager->cleanupExpiredMemories([](int removed) {
    qDebug() << "Removed" << removed << "expired memories";
});
```

### Memory Consolidation

```cpp
// Consolidate similar memories
manager->consolidateMemories({memoryId1, memoryId2, memoryId3}, 
    [](const QString &resultId) {
        qDebug() << "Consolidated into:" << resultId;
    });

// Summarize memory
QString summary = manager->summarizeMemory(memoryId);

// Extract key facts
auto facts = manager->extractKeyFacts(memoryId);
for (const auto &fact : facts) {
    qDebug() << "Fact:" << fact;
}
```

### Embeddings

```cpp
// Generate embedding for text
Embedding emb = manager->generateEmbedding("Sample text");

// Generate multiple embeddings
auto embeddings = manager->generateEmbeddings({"text1", "text2", "text3"});

// Compute similarity
float similarity = manager->computeSimilarity(emb1, emb2);

// Recompute embedding (e.g., with new model)
manager->recomputeEmbedding(memoryId, [](bool success) {
    qDebug() << "Embedding recomputed";
});

// Batch recompute
manager->batchRecomputeEmbeddings({id1, id2, id3}, [](int processed) {
    qDebug() << "Processed" << processed << "memories";
});
```

### Statistics and Monitoring

```cpp
// Get memory statistics
auto stats = manager->getMemoryStats();
qDebug() << "Total memories:" << stats.totalMemories;
qDebug() << "Semantic:" << stats.semanticMemories;
qDebug() << "Episodic:" << stats.episodicMemories;
qDebug() << "Working:" << stats.workingMemories;

// Get type distribution
auto dist = manager->getMemoryTypeDistribution();
qDebug() << "Distribution:" << dist;

// Get search performance
auto searchStats = manager->getSearchStats();

// Get access statistics
auto accStats = manager->getAccessStatistics(memoryId);
qDebug() << "Access count:" << accStats["accessCount"];
qDebug() << "Last accessed:" << accStats["lastAccessedAt"];
```

### Configuration

```cpp
// Set embedding model
manager->setEmbeddingModel("sentence-transformers/all-MiniLM-L6-v2");
auto model = manager->getEmbeddingModel();

// Memory capacity
manager->setMemoryCapacity(10000);
int capacity = manager->getMemoryCapacity();

// Retention policy
manager->setRetentionPolicy(365);  // 1 year default expiration
```

### Persistence

```cpp
// Save memory index
manager->saveMemoryIndex("checkpoint-1", [](bool success) {
    qDebug() << "Memory index saved";
});

// Load memory index
manager->loadMemoryIndex("checkpoint-1", [](bool success) {
    qDebug() << "Memory index loaded";
});

// Bulk operations
QVector<MemoryEntry> memories;
// ... populate memories
manager->bulkStoreMemories(memories, [](int stored) {
    qDebug() << "Stored" << stored << "memories";
});

// Delete multiple
manager->bulkDeleteMemories({id1, id2, id3}, [](int deleted) {
    qDebug() << "Deleted" << deleted << "memories";
});
```

## Signals and Events

```cpp
connect(manager.get(), &MemoryManager::memoryStored,
    [](const QString &id, MemoryType type) {
        qDebug() << "Memory stored:" << id;
    });

connect(manager.get(), &MemoryManager::memoryUpdated,
    [](const QString &id) {
        qDebug() << "Memory updated:" << id;
    });

connect(manager.get(), &MemoryManager::memoryDeleted,
    [](const QString &id) {
        qDebug() << "Memory deleted:" << id;
    });

connect(manager.get(), &MemoryManager::memoriesLinked,
    [](const QString &fromId, const QString &toId) {
        qDebug() << "Memories linked";
    });

connect(manager.get(), &MemoryManager::memoryConsolidated,
    [](const QString &resultId) {
        qDebug() << "Memory consolidated:" << resultId;
    });
```

## Memory Query Examples

```cpp
// Hybrid search combining multiple criteria
MemoryQuery query;
query.queryText = "Programming";
query.tags = {"python", "coding"};
query.type = MemoryQueryType::Hybrid;
query.maxResults = 20;
query.similarityThreshold = 0.6f;

manager->hybridSearch(query, [](const QVector<MemorySearchResult> &results) {
    for (const auto &result : results) {
        qDebug() << "Result:" << result.memory.title
                 << "Score:" << result.relevanceScore;
    }
});
```

## Best Practices

1. **Use appropriate memory types** - Choose semantic, episodic, or working memory based on data
2. **Tag memories appropriately** - Use consistent tags for easy retrieval
3. **Set importance levels** - Higher importance affects relevance scoring
4. **Monitor memory capacity** - Implement cleanup policies to prevent unbounded growth
5. **Consolidate similar memories** - Periodically merge related memories
6. **Use embeddings for semantic search** - Vector similarity finds conceptually related items
7. **Track memory access** - Monitor which memories are frequently used
8. **Set expiration policies** - Old, irrelevant memories should be pruned
9. **Build memory graphs** - Link related memories to enable traversal
10. **Test embedding models** - Different models produce different quality results

## Architecture

The memory system uses:
- **Vector embeddings** - Semantic representation of content
- **Cosine similarity** - Fast similarity comparison
- **Memory indices** - QMap-based in-memory storage
- **Relation graph** - Connect related memories
- **Type system** - Distinguish memory types
- **Working memory** - Active context window
- **Mutex protection** - Thread-safe operations
- **Signal/slot events** - Observer pattern
- **Expiration tracking** - Auto-cleanup old memories
