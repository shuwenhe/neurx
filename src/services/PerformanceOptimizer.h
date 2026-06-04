#ifndef PERFORMANCEOPTIMIZER_H
#define PERFORMANCEOPTIMIZER_H

#include <QString>
#include <QList>
#include <QMap>
#include <QRegularExpression>
#include <QObject>
#include <QElapsedTimer>
#include <memory>
#include <functional>

/**
 * @class PerformanceOptimizer
 * @brief Performance optimization for large file operations
 * 
 * Features:
 * - Chunked file processing
 * - Incremental search
 * - Lazy evaluation
 * - Cache management
 * - Parallel processing hints
 */

class PerformanceOptimizer : public QObject {
    Q_OBJECT

public:
    explicit PerformanceOptimizer(QObject* parent = nullptr);
    ~PerformanceOptimizer();

    // Large file optimization
    struct FileChunk {
        int startLine = 0;
        int endLine = 0;
        QString content;
        bool isValid = false;
    };

    // Process large text in chunks
    void processInChunks(const QString& text, int chunkSize,
                        std::function<void(const FileChunk&)> processor);

    // Incremental search for large texts
    struct SearchProgress {
        int currentLine = 0;
        int totalLines = 0;
        int matchesFound = 0;
        bool isComplete = false;
    };

    SearchProgress incrementalSearch(const QString& text, const QString& pattern,
                                     int& resumeFromLine, int maxMatchesPerBatch = 100);

    // Cache search results for quick re-access
    void cacheSearchResult(const QString& pattern, const QList<int>& positions);
    QList<int> getCachedResult(const QString& pattern) const;
    void clearSearchCache();

    // Estimate processing time
    int estimateProcessingTime(const QString& text, const QString& operation) const;

    // Batch operation optimization
    struct BatchOperation {
        int position = 0;
        QString operation;
        QString data;
    };

    QString executeBatchOptimized(const QString& text, const QList<BatchOperation>& operations);

    // Memory stats
    struct MemoryStats {
        size_t textSize = 0;
        size_t cacheSize = 0;
        int lineCount = 0;
        int avgLineLength = 0;
    };

    MemoryStats analyzeMemoryUsage(const QString& text) const;

    // Line index for fast access
    void buildLineIndex(const QString& text);
    QString getLine(int lineNumber) const;
    int findLineNumber(int position) const;

signals:
    void processingProgress(int current, int total);
    void performanceMetrics(double timeMs, size_t bytesProcessed);

private:
    // Cache for search results
    QMap<QString, QList<int>> m_searchCache;

    // Line index for fast line access
    QList<int> m_lineOffsets;  // Offset of each line start
    QString m_indexedText;
    bool m_indexValid = false;

    // Helper methods
    QList<int> splitIntoLines(const QString& text) const;
    int countLines(const QString& text) const;
};

Q_DECLARE_METATYPE(PerformanceOptimizer::FileChunk)
Q_DECLARE_METATYPE(PerformanceOptimizer::SearchProgress)
Q_DECLARE_METATYPE(PerformanceOptimizer::MemoryStats)

#endif // PERFORMANCEOPTIMIZER_H
