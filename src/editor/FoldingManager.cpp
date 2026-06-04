#include "editor/FoldingManager.h"
#include <QDebug>
#include <QRegularExpression>

FoldingManager::FoldingManager(QObject* parent)
    : QObject(parent)
{
}

QList<FoldRange> FoldingManager::computeFoldRanges(const QString& text, const QString& language)
{
    m_foldRanges.clear();
    auto lines = text.split('\n');
    
    for (int i = 0; i < lines.size(); ++i) {
        const QString& line = lines[i];
        
        // 检测函数定义
        if (language == "cpp" || language == "c" || language == "java") {
            if (line.contains("(") && (line.contains("{") || (i + 1 < lines.size() && lines[i+1].contains("{")))) {
                FoldRange range = detectFunctionRange(text, i);
                if (range.endLine - range.startLine >= m_minFoldSize) {
                    m_foldRanges.append(range);
                }
            }
        }
        
        // 检测类定义
        if (line.trimmed().startsWith("class ") || line.trimmed().startsWith("struct ")) {
            FoldRange range = detectClassRange(text, i);
            if (range.endLine - range.startLine >= m_minFoldSize) {
                m_foldRanges.append(range);
            }
        }
        
        // 检测注释块
        if (line.contains("/*")) {
            FoldRange range = detectCommentRange(text, i);
            if (range.endLine - range.startLine >= m_minFoldSize) {
                m_foldRanges.append(range);
            }
        }
    }
    
    emit foldsChanged(m_foldRanges);
    return m_foldRanges;
}

FoldRange FoldingManager::detectFunctionRange(const QString& text, int startLine)
{
    auto lines = text.split('\n');
    int braceCount = 0;
    int endLine = startLine;
    
    for (int i = startLine; i < lines.size(); ++i) {
        braceCount += lines[i].count('{') - lines[i].count('}');
        if (braceCount == 0 && i > startLine && lines[i].contains('}')) {
            endLine = i;
            break;
        }
    }
    
    return {startLine, endLine, 0, "function"};
}

FoldRange FoldingManager::detectClassRange(const QString& text, int startLine)
{
    auto lines = text.split('\n');
    int braceCount = 0;
    int endLine = startLine;
    
    for (int i = startLine; i < lines.size(); ++i) {
        braceCount += lines[i].count('{') - lines[i].count('}');
        if (braceCount == 0 && i > startLine && lines[i].contains('}')) {
            endLine = i;
            break;
        }
    }
    
    return {startLine, endLine, 0, "class"};
}

FoldRange FoldingManager::detectCommentRange(const QString& text, int startLine)
{
    auto lines = text.split('\n');
    int endLine = startLine;
    
    for (int i = startLine + 1; i < lines.size(); ++i) {
        if (lines[i].contains("*/")) {
            endLine = i;
            break;
        }
    }
    
    return {startLine, endLine, 0, "comment"};
}

void FoldingManager::toggleFold(int line)
{
    bool isFolded = m_foldStates.value(line, false);
    m_foldStates[line] = !isFolded;
    emit foldToggled(line, !isFolded);
}

void FoldingManager::fold(int line)
{
    m_foldStates[line] = true;
    emit foldToggled(line, true);
}

void FoldingManager::unfold(int line)
{
    m_foldStates[line] = false;
    emit foldToggled(line, false);
}

void FoldingManager::foldAll()
{
    for (const auto& range : m_foldRanges) {
        m_foldStates[range.startLine] = true;
    }
    qDebug() << "Fold all";
}

void FoldingManager::unfoldAll()
{
    m_foldStates.clear();
    qDebug() << "Unfold all";
}

void FoldingManager::foldLevel(int level)
{
    for (const auto& range : m_foldRanges) {
        if (range.indent >= level) {
            m_foldStates[range.startLine] = true;
        }
    }
}

void FoldingManager::unfoldLevel(int level)
{
    for (const auto& range : m_foldRanges) {
        if (range.indent >= level) {
            m_foldStates[range.startLine] = false;
        }
    }
}

bool FoldingManager::isFolded(int line) const
{
    return m_foldStates.value(line, false);
}

FoldRange FoldingManager::getFoldRange(int line) const
{
    for (const auto& range : m_foldRanges) {
        if (range.startLine <= line && line <= range.endLine) {
            return range;
        }
    }
    return {-1, -1, 0, ""};
}
