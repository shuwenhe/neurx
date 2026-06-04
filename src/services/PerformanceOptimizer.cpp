#include "PerformanceOptimizer.h"
#include <QStringList>
#include <QElapsedTimer>
#include <algorithm>
#include <QThreadPool>
#include <QRunnable>

PerformanceOptimizer::PerformanceOptimizer(QObject* parent)
    : QObject(parent), m_indexValid(false) {
}

PerformanceOptimizer::~PerformanceOptimizer() {
    clearSearchCache();
}

// Process large text in chunks to avoid memory spike
void PerformanceOptimizer::processInChunks(const QString& text, int chunkSize,
                                          std::function<void(const FileChunk&)> processor) {
    if (text.isEmpty() || chunkSize <= 0) return;

    QElapsedTimer timer;
    timer.start();

    int totalLines = countLines(text);
    int processedLines = 0;

    QStringList lines = text.split('\n');
    int currentLine = 0;

    for (int start = 0; start < lines.size(); start += chunkSize) {
        FileChunk chunk;
        chunk.startLine = currentLine;
        int remaining = lines.size() - start;
        int takeCount = remaining < chunkSize ? remaining : chunkSize;
        chunk.endLine = currentLine + takeCount;

        // Build chunk content
        QStringList chunkLines = lines.mid(start, takeCount);
        chunk.content = chunkLines.join('\n');
        chunk.isValid = !chunk.content.isEmpty();

        processor(chunk);

        processedLines = chunk.endLine;
        currentLine = chunk.endLine;

        // Emit progress
        if (totalLines > 0) {
            emit processingProgress(processedLines, totalLines);
        }
    }

    qint64 elapsed = timer.elapsed();
    emit performanceMetrics(elapsed, text.size());
}

// Incremental search for large texts
PerformanceOptimizer::SearchProgress PerformanceOptimizer::incrementalSearch(
    const QString& text, const QString& pattern,
    int& resumeFromLine, int maxMatchesPerBatch) {

    SearchProgress progress;
    progress.totalLines = countLines(text);

    if (text.isEmpty() || pattern.isEmpty()) {
        progress.isComplete = true;
        return progress;
    }

    // Check cache first
    auto cached = getCachedResult(pattern);
    if (!cached.isEmpty()) {
        progress.matchesFound = cached.size();
        progress.isComplete = true;
        return progress;
    }

    QRegularExpression regex(pattern);
    QStringList lines = text.split('\n');

    int matchCount = 0;
    QList<int> positions;

    for (int i = resumeFromLine; i < lines.size() && matchCount < maxMatchesPerBatch; ++i) {
        auto matches = regex.globalMatch(lines[i]);
        while (matches.hasNext() && matchCount < maxMatchesPerBatch) {
            matches.next();
            positions.append(i);
            matchCount++;
        }
        progress.currentLine = i;
    }

    progress.matchesFound = matchCount;
    progress.isComplete = (progress.currentLine >= progress.totalLines - 1);

    // Update resume point
    resumeFromLine = progress.currentLine + 1;

    // Cache the results if complete
    if (progress.isComplete) {
        cacheSearchResult(pattern, positions);
    }

    return progress;
}

// Cache search results
void PerformanceOptimizer::cacheSearchResult(const QString& pattern, const QList<int>& positions) {
    m_searchCache[pattern] = positions;
}

QList<int> PerformanceOptimizer::getCachedResult(const QString& pattern) const {
    auto it = m_searchCache.find(pattern);
    if (it != m_searchCache.end()) {
        return it.value();
    }
    return QList<int>();
}

void PerformanceOptimizer::clearSearchCache() {
    m_searchCache.clear();
}

// Estimate processing time based on text size and operation type
int PerformanceOptimizer::estimateProcessingTime(const QString& text, const QString& operation) const {
    // Rough estimates in milliseconds
    double sizeInMB = text.size() / (1024.0 * 1024.0);

    if (operation == "search") {
        return static_cast<int>(sizeInMB * 50);  // ~50ms per MB
    } else if (operation == "replace") {
        return static_cast<int>(sizeInMB * 100);  // ~100ms per MB
    } else if (operation == "format") {
        return static_cast<int>(sizeInMB * 200);  // ~200ms per MB
    }

    return static_cast<int>(sizeInMB * 75);  // Default: 75ms per MB
}

// Execute batch operations optimally
QString PerformanceOptimizer::executeBatchOptimized(const QString& text,
                                                     const QList<BatchOperation>& operations) {
    if (operations.isEmpty()) return text;

    // Sort operations by position (reverse order to preserve indices)
    QList<BatchOperation> sortedOps = operations;
    std::sort(sortedOps.begin(), sortedOps.end(),
              [](const BatchOperation& a, const BatchOperation& b) {
                  return a.position > b.position;  // Reverse sort
              });

    QString result = text;

    for (const auto& op : sortedOps) {
        if (op.position < 0 || op.position > result.length()) continue;

        if (op.operation == "insert") {
            result.insert(op.position, op.data);
        } else if (op.operation == "delete") {
            int deleteCount = op.data.toInt();
            if (op.position + deleteCount <= result.length()) {
                result.remove(op.position, deleteCount);
            }
        } else if (op.operation == "replace") {
            // Find word boundary and replace
            int endPos = result.indexOf(' ', op.position);
            if (endPos == -1) endPos = result.length();
            int length = endPos - op.position;

            if (op.position + length <= result.length()) {
                result.replace(op.position, length, op.data);
            }
        }
    }

    return result;
}

// Analyze memory usage
PerformanceOptimizer::MemoryStats PerformanceOptimizer::analyzeMemoryUsage(const QString& text) const {
    MemoryStats stats;
    stats.textSize = text.size();
    stats.lineCount = countLines(text);

    if (stats.lineCount > 0) {
        stats.avgLineLength = text.size() / stats.lineCount;
    }

    // Estimate cache size
    for (const auto& positions : m_searchCache) {
        stats.cacheSize += positions.size() * static_cast<int>(sizeof(int));
    }

    return stats;
}

// Build line index for fast line access
void PerformanceOptimizer::buildLineIndex(const QString& text) {
    if (m_indexedText == text && m_indexValid) return;

    m_lineOffsets.clear();
    m_lineOffsets.append(0);

    for (int i = 0; i < text.length(); ++i) {
        if (text[i] == '\n') {
            m_lineOffsets.append(i + 1);
        }
    }

    m_indexedText = text;
    m_indexValid = true;
}

// Get line by number
QString PerformanceOptimizer::getLine(int lineNumber) const {
    if (!m_indexValid || lineNumber < 0 || lineNumber >= m_lineOffsets.size()) {
        return QString();
    }

    int start = m_lineOffsets[lineNumber];
    int end = (lineNumber + 1 < m_lineOffsets.size()) ? m_lineOffsets[lineNumber + 1] : m_indexedText.length();

    if (end > 0 && m_indexedText[end - 1] == '\n') end--;

    return m_indexedText.mid(start, end - start);
}

// Find line number for a position
int PerformanceOptimizer::findLineNumber(int position) const {
    if (!m_indexValid) return -1;

    auto it = std::upper_bound(m_lineOffsets.begin(), m_lineOffsets.end(), position);
    if (it != m_lineOffsets.begin()) {
        --it;
        return it - m_lineOffsets.begin();
    }

    return -1;
}

// Count lines in text
int PerformanceOptimizer::countLines(const QString& text) const {
    if (text.isEmpty()) return 0;
    return text.count('\n') + 1;
}

// Split text into lines
QList<int> PerformanceOptimizer::splitIntoLines(const QString& text) const {
    QList<int> lineStarts;
    lineStarts.append(0);

    for (int i = 0; i < text.length(); ++i) {
        if (text[i] == '\n') {
            lineStarts.append(i + 1);
        }
    }

    return lineStarts;
}
