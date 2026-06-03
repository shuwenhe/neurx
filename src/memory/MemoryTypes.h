#pragma once

#include <QString>
#include <QVector>
#include <QDateTime>
#include <QVariantMap>
#include <functional>

/**
 * Memory types for semantic and episodic memory management
 */

// ── Memory Types ────────────────────────────────────────

enum class MemoryType {
    Semantic,    // Knowledge and facts
    Episodic,    // Experiences and events
    Working,     // Short-term active memory
    Procedural,  // Skills and procedures
    Emotional    // Emotional associations
};

// ── Embedding Types ─────────────────────────────────────

/// Vector embedding (typically 768, 1024, or higher dimensions)
using Embedding = QVector<float>;

/// Similarity score (0.0 to 1.0)
using SimilarityScore = float;

/// Embedding metadata
struct EmbeddingMetadata {
    QString embeddingModel;          // e.g., "sentence-transformers/all-MiniLM-L6-v2"
    int dimension = 0;               // Embedding dimension
    qint64 generatedAt = 0;          // Timestamp when generated
    QString sourceText;              // Original text used for embedding
};

// ── Memory Entry Types ──────────────────────────────────

/// Base memory entry
struct MemoryEntry {
    QString memoryId;                // Unique ID
    MemoryType type;                 // Type of memory
    QString content;                 // Main content
    Embedding embedding;             // Vector representation
    EmbeddingMetadata embeddingMeta; // Embedding metadata
    
    QString title;                   // Title or summary
    QString description;             // Detailed description
    QStringList tags;                // Tags for categorization
    QVariantMap metadata;            // Additional metadata
    
    int importance = 5;              // Importance score (1-10)
    int accessCount = 0;             // Times accessed
    float relevanceScore = 0.0f;     // Current relevance
    
    QDateTime createdAt;             // Creation timestamp
    QDateTime updatedAt;             // Last update timestamp
    QDateTime lastAccessedAt;        // Last accessed timestamp
    int expirationDays = 0;          // 0 = no expiration
    
    bool isPublic = true;            // Accessible to other agents
    QString source;                  // Source of memory (user input, LLM, etc.)
    QString relatedMemoryIds;        // Comma-separated related memory IDs
    
    // Quick checks
    bool isExpired() const;
    bool needsRefresh() const;
};

/// Episodic memory (experiences)
struct EpisodicMemory : public MemoryEntry {
    QString eventId;                 // Associated event
    QDateTime eventTime;             // When it happened
    QString location;                // Where it happened
    QStringList participants;        // Who was involved
    QVariantMap context;             // Context information
};

/// Semantic memory (knowledge)
struct SemanticMemory : public MemoryEntry {
    QString domain;                  // Knowledge domain
    QStringList concepts;            // Related concepts
    int confidence = 8;              // Confidence level (1-10)
    QString source_url;              // Source URL if applicable
};

/// Working memory (active context)
struct WorkingMemory : public MemoryEntry {
    int priority = 5;                // Priority in working set
    bool inActiveUse = false;        // Currently being used
    int windowSize = 5;              // Number of related memories in context window
};

// ── Memory Query Types ──────────────────────────────────

enum class MemoryQueryType {
    Semantic,           // Similarity search
    Keyword,            // Keyword search
    Tag,                // Tag-based search
    TimeRange,          // Time-based search
    Hybrid,             // Combined search
    GraphTraversal      // Relationship traversal
};

struct MemoryQuery {
    QString queryId;
    MemoryQueryType type;
    QString queryText;              // Query text or keyword
    Embedding queryEmbedding;       // Embedding of query
    
    QStringList tags;               // Tags to filter
    QStringList domains;            // Domains to search (semantic)
    
    QDateTime fromTime;             // Time range start
    QDateTime toTime;               // Time range end
    
    QVector<MemoryType> memoryTypes; // Types to search
    
    int maxResults = 10;            // Max results to return
    float similarityThreshold = 0.5f; // Min similarity score
    int limit = 100;                // Result limit
    
    bool includeExpired = false;    // Include expired entries
    bool sortByRelevance = true;    // Sort by relevance or time
    bool sortByRecency = false;     // Sort by recency
};

// ── Memory Search Results ───────────────────────────────

struct MemorySearchResult {
    MemoryEntry memory;
    SimilarityScore similarityScore;
    float relevanceScore;
    QString matchContext;           // Surrounding context
    int rank;                       // Rank in result set
};

// ── Memory Statistics ───────────────────────────────────

struct MemoryStats {
    int totalMemories = 0;
    int semanticMemories = 0;
    int episodicMemories = 0;
    int workingMemories = 0;
    int proceduralMemories = 0;
    int emotionalMemories = 0;
    
    int totalSearches = 0;
    int averageSearchTime = 0;     // milliseconds
    
    float averageImportance = 0.0f;
    float averageRelevance = 0.0f;
    
    int expiredMemories = 0;
    int memoriesDueRefresh = 0;
    
    qint64 totalStorageSize = 0;   // bytes
    qint64 embeddingStorageSize = 0; // bytes
    
    QDateTime createdAt;
    QDateTime lastUpdatedAt;
};

// ── Memory Index ────────────────────────────────────────

struct MemoryIndex {
    QString indexId;
    QString name;
    MemoryType type;
    QStringList tags;
    
    int entryCount = 0;
    QDateTime createdAt;
    QDateTime lastCompactedAt;
};

// ── Memory Graph/Relations ──────────────────────────────

enum class MemoryRelationType {
    Related,        // Generally related
    Caused,         // A caused B
    PartOf,         // A is part of B
    Specializes,    // A specializes B
    Contradicts,    // A contradicts B
    Supports,       // A supports B
    References,     // A references B
    Previous,       // A is previous to B
    Next            // A is next to B
};

struct MemoryRelation {
    QString relationId;
    QString fromMemoryId;
    QString toMemoryId;
    MemoryRelationType type;
    float strength = 0.5f;          // Relationship strength (0-1)
    QString reason;                 // Why related
    QDateTime createdAt;
};

// ── Memory Consolidation ────────────────────────────────

struct MemoryConsolidation {
    QString consolidationId;
    QStringList sourceMemoryIds;
    QString resultMemoryId;
    QString action;                 // merge, summarize, extract, cluster
    QDateTime performedAt;
    QString summary;
};

// ── Callbacks ───────────────────────────────────────────

using MemoryCallback = std::function<void(const MemoryEntry &)>;
using MemoryListCallback = std::function<void(const QVector<MemoryEntry> &)>;
using MemorySearchCallback = std::function<void(const QVector<MemorySearchResult> &)>;
using MemoryStatCallback = std::function<void(const MemoryStats &)>;
using MemoryErrorCallback = std::function<void(const QString &error)>;
