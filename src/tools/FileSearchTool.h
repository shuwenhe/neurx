#pragma once

#include "agent/AgentToolRegistry.h"
#include <QDir>
#include <QRegularExpression>
#include <memory>

/**
 * @class FileSearchTool
 * @brief Advanced file search with regex, glob patterns, and result aggregation
 * 
 * Migrated from claude-code/hermes-agent:
 * - Regular expression search (ECMAScript regex)
 * - Glob pattern file matching
 * - Context lines around matches
 * - Result truncation for large result sets
 * - Performance optimization (search limits)
 * - Binary file exclusion
 */

class FileSearchTool : public BaseTool {
    Q_OBJECT

public:
    explicit FileSearchTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "file_search"; }
    QString description() const override {
        return "Search for text patterns in files using regex, with glob pattern matching, "
               "context extraction, and result aggregation.";
    }

    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct SearchMatch {
        QString filepath;
        int lineNumber;
        int columnNumber;
        QString lineContent;
        QString beforeContext;  // Lines before match
        QString afterContext;   // Lines after match
    };

    struct SearchResult {
        QList<SearchMatch> matches;
        QStringList matchedFiles;
        int totalMatches{0};
        int filesSearched{0};
        bool truncated{false};
        QString error;
    };

    // Search operations
    SearchResult searchRegex(
        const QString &pattern,
        const QString &glob,
        int contextLines = 0,
        int maxResults = 1000,
        bool caseSensitive = false,
        bool wholeWord = false
    );

    SearchResult searchLiteral(
        const QString &text,
        const QString &glob,
        int contextLines = 0,
        int maxResults = 1000,
        bool caseSensitive = false
    );

    // Helper methods
    bool matchesGlobPattern(const QString &filepath, const QString &pattern) const;
    bool isBinaryFile(const QString &filepath) const;
    QString safePath(const QString &relOrAbsPath) const;
    QStringList getContextLines(const QString &filepath, int lineNumber, int beforeCount, int afterCount) const;
    int getLineNumber(const QString &filepath, qint64 byteOffset) const;

    // File enumeration
    QStringList enumerateFiles(const QString &baseDir, const QString &glob) const;

    QDir m_root;
    static constexpr int DEFAULT_MAX_RESULTS = 1000;
    static constexpr int DEFAULT_MAX_FILES = 10000;
    static constexpr int DEFAULT_CONTEXT_LINES = 2;
    static constexpr int MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024;  // 10 MB
};
