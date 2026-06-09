#include "tools/GeminiGetInternalDocsTool.h"
#include <QDirIterator>
#include <QFile>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <QCoreApplication>

GeminiGetInternalDocsTool::GeminiGetInternalDocsTool(QObject* parent)
    : BaseTool(parent)
{
}

QString GeminiGetInternalDocsTool::description() const
{
    return "Provides access to internal documentation. If no path is provided, it returns a list of all available documentation files. If a path is provided, it returns the content of that specific file.";
}

QJsonObject GeminiGetInternalDocsTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"JSON({
        "type": "object",
        "properties": {
            "path": {
                "type": "string",
                "description": "The relative path to a specific documentation file (e.g., 'CLAUDE_STANDARD_TOOLS.md'). If omitted, lists all files."
            }
        }
    })JSON").object();
}

ToolResult GeminiGetInternalDocsTool::execute(const QString& callId, const QJsonObject& args)
{
    QString relativePath = args.value("path").toString();
    QString docsRoot = getDocsRoot();

    if (docsRoot.isEmpty()) {
        return {callId, name(), true, "Error: Could not find documentation directory."};
    }

    if (relativePath.isEmpty()) {
        // List all .md and .mdx files
        QStringList files;
        QDirIterator it(docsRoot, QStringList() << "*.md" << "*.mdx", QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            files << QDir(docsRoot).relativeFilePath(it.filePath());
        }
        files.sort();

        QString fileList = "Available internal documentation files:\n\n";
        for (const QString& f : files) {
            fileList += "- " + f + "\n";
        }

        return {callId, name(), false, fileList};
    }

    // Read specific file
    QString absPath = QDir(docsRoot).absoluteFilePath(relativePath);
    if (!isPathInsideDocs(absPath, docsRoot)) {
        return {callId, name(), true, "Error: Access denied. Requested path is outside the documentation directory."};
    }

    QFile file(absPath);
    if (!file.exists()) {
        return {callId, name(), true, "Error: Documentation file not found: " + relativePath};
    }

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true, "Error: Cannot open documentation file: " + file.errorString()};
    }

    QTextStream in(&file);
    QString content = in.readAll();
    file.close();

    return {callId, name(), false, content};
}

QString GeminiGetInternalDocsTool::summary(const QJsonObject& args) const
{
    QString path = args.value("path").toString();
    if (path.isEmpty()) {
        return "Listing internal documentation";
    }
    return QString("Reading internal documentation: %1").arg(path);
}

QString GeminiGetInternalDocsTool::getDocsRoot() const
{
    // Try current directory / docs
    QString currentPath = QDir::currentPath();
    QDir dir(currentPath);

    // Search upwards for 'docs' directory
    while (true) {
        if (dir.exists("docs")) {
            return dir.absoluteFilePath("docs");
        }

        if (!dir.cdUp()) {
            break;
        }
    }

    // Fallback to application dir / docs
    QDir appDir(QCoreApplication::applicationDirPath());
    if (appDir.exists("docs")) {
        return appDir.absoluteFilePath("docs");
    }

    return QString();
}

bool GeminiGetInternalDocsTool::isPathInsideDocs(const QString& path, const QString& docsRoot) const
{
    QString cleanPath = QDir::cleanPath(path);
    QString cleanRoot = QDir::cleanPath(docsRoot);
    return cleanPath.startsWith(cleanRoot);
}

