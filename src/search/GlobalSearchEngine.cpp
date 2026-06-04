#include "search/GlobalSearchEngine.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QDebug>

GlobalSearchEngine::GlobalSearchEngine(QObject* parent)
    : QObject(parent)
{
}

GlobalSearchEngine::~GlobalSearchEngine() = default;

void GlobalSearchEngine::search(const QString& pattern, const QString& rootPath,
                                bool useRegex, bool caseSensitive)
{
    if (pattern.isEmpty()) {
        emit error("Search pattern is empty");
        return;
    }
    
    m_isSearching = true;
    m_shouldCancel = false;
    m_results.clear();
    m_filesSearched = 0;
    
    emit searchStarted();
    
    try {
        searchDirectory(rootPath, pattern, useRegex, caseSensitive);
        
        if (!m_shouldCancel) {
            QList<QVariantMap> variantResults;
            for (const auto& result : m_results) {
                variantResults.append(result.toMap());
            }
            emit resultsFound(variantResults);
            emit searchFinished();
        } else {
            emit searchCancelled();
        }
    } catch (const std::exception& e) {
        emit error(QString("Search error: %1").arg(e.what()));
    }
    
    m_isSearching = false;
}

void GlobalSearchEngine::searchDirectory(const QString& dirPath, const QString& pattern,
                                         bool useRegex, bool caseSensitive)
{
    QDir dir(dirPath);
    
    // 遍历所有文件和目录
    const auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
    
    for (const auto& entry : entries) {
        if (m_shouldCancel) {
            return;
        }
        
        if (entry.isDir()) {
            // 跳过常见的排除目录
            const QString dirName = entry.fileName();
            if (dirName != ".git" && dirName != "node_modules" && 
                dirName != ".vscode" && dirName != "build" && 
                dirName != ".neurx") {
                searchDirectory(entry.filePath(), pattern, useRegex, caseSensitive);
            }
        } else {
            // 搜索文件
            searchInFile(entry.filePath(), pattern, useRegex, caseSensitive);
            m_filesSearched++;
            emit progressUpdated(m_filesSearched);
        }
    }
}

void GlobalSearchEngine::searchInFile(const QString& filePath, const QString& pattern,
                                      bool useRegex, bool caseSensitive)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }
    
    QTextStream stream(&file);
    int lineNumber = 0;
    
    while (!stream.atEnd()) {
        if (m_shouldCancel) {
            break;
        }
        
        QString line = stream.readLine();
        lineNumber++;
        
        if (useRegex) {
            // 正则表达式搜索
            QRegularExpression regex(pattern);
            if (!caseSensitive) {
                regex.setPatternOptions(QRegularExpression::CaseInsensitiveOption);
            }
            
            auto match = regex.match(line);
            if (match.hasMatch()) {
                SearchResult result;
                result.filePath = filePath;
                result.lineNumber = lineNumber;
                result.columnNumber = match.capturedStart() + 1;
                result.lineContent = line;
                result.matchStart = match.capturedStart();
                result.matchLength = match.capturedLength();
                
                m_results.append(result);
                emit resultAdded(result.toMap());
            }
        } else {
            // 简单文本搜索
            Qt::CaseSensitivity cs = caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive;
            int index = line.indexOf(pattern, 0, cs);
            
            while (index >= 0) {
                SearchResult result;
                result.filePath = filePath;
                result.lineNumber = lineNumber;
                result.columnNumber = index + 1;
                result.lineContent = line;
                result.matchStart = index;
                result.matchLength = pattern.length();
                
                m_results.append(result);
                emit resultAdded(result.toMap());
                
                index = line.indexOf(pattern, index + 1, cs);
            }
        }
    }
    
    file.close();
}

void GlobalSearchEngine::replace(const QString& pattern, const QString& replacement,
                                 const QString& rootPath, bool useRegex)
{
    if (pattern.isEmpty()) {
        emit error("Pattern is empty");
        return;
    }
    
    m_isSearching = true;
    m_shouldCancel = false;
    m_filesSearched = 0;
    
    emit searchStarted();
    
    try {
        QDir dir(rootPath);
        const auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        
        int filesModified = 0;
        
        for (const auto& entry : entries) {
            if (m_shouldCancel) {
                break;
            }
            
            if (entry.isDir()) {
                const QString dirName = entry.fileName();
                if (dirName != ".git" && dirName != "node_modules" && 
                    dirName != ".vscode" && dirName != "build") {
                    replace(pattern, replacement, entry.filePath(), useRegex);
                }
            } else if (entry.isFile()) {
                // 读取文件
                QFile file(entry.filePath());
                if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                    QString content = QTextStream(&file).readAll();
                    file.close();
                    
                    QString newContent = content;
                    bool modified = false;
                    
                    if (useRegex) {
                        QRegularExpression regex(pattern);
                        if (content.contains(regex)) {
                            newContent = content.replace(regex, replacement);
                            modified = true;
                        }
                    } else {
                        if (content.contains(pattern)) {
                            newContent = content.replace(pattern, replacement);
                            modified = true;
                        }
                    }
                    
                    // 写回文件
                    if (modified) {
                        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                            QTextStream out(&file);
                            out << newContent;
                            file.close();
                            filesModified++;
                        }
                    }
                }
                m_filesSearched++;
                emit progressUpdated(m_filesSearched);
            }
        }
        
        emit searchFinished();
        qInfo() << "Replace finished. Files modified:" << filesModified;
        
    } catch (const std::exception& e) {
        emit error(QString("Replace error: %1").arg(e.what()));
    }
    
    m_isSearching = false;
}

void GlobalSearchEngine::cancelSearch()
{
    m_shouldCancel = true;
}
