#pragma once

#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonArray>

/**
 * @class JitContext
 * @brief Utility for discovering and formatting Just-In-Time project context.
 *
 * Implements the logic from gemini-cli's jit-context.ts and memoryDiscovery.ts
 */
class JitContext {
public:
    static const QString kJitPrefix;
    static const QString kJitSuffix;

    /**
     * Discovers JIT context for an accessed path by searching upward for GEMINI.md or MEMORY.md files.
     * @param accessedPath The absolute path being accessed (file or directory).
     * @param workspaceRoot The workspace root to stop traversal.
     * @return Formatted context string with delimiters, or empty if nothing found.
     */
    static QString discoverContext(const QString &accessedPath, const QString &workspaceRoot);

    /**
     * Finds the project root by searching upward for boundary markers (e.g. .git).
     */
    static QString findProjectRoot(const QString &startPath);

    /**
     * Appends JIT context to tool output if any was found.
     */
    static QString appendJitContext(const QString &output, const QString &jitContext);

private:
    static QStringList findUpwardMemoryFiles(const QString &startPath, const QString &workspaceRoot);
    static QString readMemoryFile(const QString &filePath);
    static bool isSubpath(const QString &parent, const QString &child);
};
