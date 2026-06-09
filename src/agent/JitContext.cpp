#include "agent/JitContext.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QDebug>

const QString JitContext::kJitPrefix = QStringLiteral("\n\n--- Newly Discovered Project Context ---\n");
const QString JitContext::kJitSuffix = QStringLiteral("\n--- End Project Context ---");

QString JitContext::discoverContext(const QString &accessedPath, const QString &workspaceRoot)
{
    if (accessedPath.isEmpty()) {
        return QString();
    }

    QString actualWorkspaceRoot = workspaceRoot;
    if (actualWorkspaceRoot.isEmpty()) {
        actualWorkspaceRoot = findProjectRoot(accessedPath);
    }

    if (actualWorkspaceRoot.isEmpty()) {
        return QString();
    }

    QStringList memoryFiles = findUpwardMemoryFiles(accessedPath, actualWorkspaceRoot);
    if (memoryFiles.isEmpty()) {
        return QString();
    }

    QString concatenated;
    for (const QString &filePath : memoryFiles) {
        QString content = readMemoryFile(filePath);
        if (content.isEmpty()) continue;

        if (!concatenated.isEmpty()) concatenated += QStringLiteral("\n\n");
        concatenated += QStringLiteral("--- Context from: %1 ---\n").arg(filePath);
        concatenated += content.trimmed();
        concatenated += QStringLiteral("\n--- End of Context from: %1 ---").arg(filePath);
    }

    return concatenated;
}

QString JitContext::appendJitContext(const QString &output, const QString &jitContext)
{
    if (jitContext.isEmpty()) {
        return output;
    }
    return output + kJitPrefix + jitContext + kJitSuffix;
}

QStringList JitContext::findUpwardMemoryFiles(const QString &startPath, const QString &workspaceRoot)
{
    QStringList found;
    QFileInfo info(startPath);
    QString currentDir = info.isDir() ? info.absoluteFilePath() : info.absolutePath();

    QString absWorkspaceRoot = QDir(workspaceRoot).absolutePath();
    QStringList memoryFilenames = { QStringLiteral("GEMINI.md"), QStringLiteral("MEMORY.md") };

    // Traverse upward
    while (true) {
        for (const QString &filename : memoryFilenames) {
            QString path = QDir(currentDir).filePath(filename);
            if (QFileInfo::exists(path) && QFileInfo(path).isFile()) {
                found.prepend(path); // Prepend so root files come first
            }
        }

        if (currentDir == absWorkspaceRoot || currentDir == QStringLiteral("/")) {
            break;
        }

        QString parentDir = QDir(currentDir).filePath(QStringLiteral(".."));
        currentDir = QDir(parentDir).absolutePath();

        // Safety check to avoid infinite loop
        if (currentDir.isEmpty() || currentDir == QStringLiteral(".")) break;
    }

    // Deduplicate while preserving order (root to leaf)
    QStringList uniqueFound;
    for (const QString &path : found) {
        if (!uniqueFound.contains(path)) {
            uniqueFound.append(path);
        }
    }

    return uniqueFound;
}

QString JitContext::readMemoryFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }
    QTextStream in(&file);
    return in.readAll();
}

QString JitContext::findProjectRoot(const QString &startPath)
{
    QFileInfo info(startPath);
    QString currentDir = info.isDir() ? info.absoluteFilePath() : info.absolutePath();

    QStringList boundaryMarkers = { QStringLiteral(".git"), QStringLiteral("package.json") };

    while (true) {
        for (const QString &marker : boundaryMarkers) {
            QString path = QDir(currentDir).filePath(marker);
            if (QFileInfo::exists(path)) {
                return currentDir;
            }
        }

        QString parentDir = QDir(currentDir).filePath(QStringLiteral(".."));
        QString absoluteParent = QDir(parentDir).absolutePath();

        if (absoluteParent == currentDir || absoluteParent == QStringLiteral("/") || absoluteParent.isEmpty()) {
            break;
        }
        currentDir = absoluteParent;
    }

    return QString();
}

bool JitContext::isSubpath(const QString &parent, const QString &child)
{
    QString p = QDir(parent).absolutePath();
    QString c = QDir(child).absolutePath();
    if (p == c) return true;
    if (!p.endsWith(QDir::separator())) p += QDir::separator();
    return c.startsWith(p);
}
