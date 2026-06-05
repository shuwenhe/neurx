#include "PeekView.h"
#include <QDebug>
#include <QFile>
#include <QFileInfo>

PeekView::PeekView(QObject* parent)
    : QObject(parent)
{
}

PeekView::PeekResult PeekView::peekDefinition(const QString& filePath, int line, int column, const QString& symbol)
{
    PeekResult result;
    result.mode = PeekMode::Definition;
    result.symbol = symbol.isEmpty() ? "unknown" : symbol;
    result.startLine = line;
    result.endLine = line;
    
    // Mock: In real implementation, would query LSP for definition
    Location loc;
    loc.file = filePath;
    loc.line = line;
    loc.column = column;
    loc.name = symbol;
    loc.kind = "function";
    
    result.locations.append(loc);
    result.currentIndex = 0;
    result.previewContent = getFileContext(filePath, line, 10);
    
    m_activePeek = result;
    m_peekState = PeekState{result, filePath, line, column};
    
    emit peekOpened(result);
    return result;
}

PeekView::PeekResult PeekView::peekReferences(const QString& filePath, int line, int column, const QString& symbol)
{
    PeekResult result;
    result.mode = PeekMode::References;
    result.symbol = symbol.isEmpty() ? "unknown" : symbol;
    result.startLine = line;
    result.endLine = line;
    
    // Mock: In real implementation, would query LSP for references
    Location loc1;
    loc1.file = filePath;
    loc1.line = line;
    loc1.column = column;
    loc1.name = symbol;
    loc1.kind = "reference";
    
    result.locations.append(loc1);
    result.currentIndex = 0;
    result.previewContent = getFileContext(filePath, line, 10);
    
    m_activePeek = result;
    m_peekState = PeekState{result, filePath, line, column};
    
    emit peekOpened(result);
    return result;
}

PeekView::PeekResult PeekView::peekImplementations(const QString& filePath, int line, int column, const QString& symbol)
{
    PeekResult result;
    result.mode = PeekMode::Implementations;
    result.symbol = symbol.isEmpty() ? "unknown" : symbol;
    result.startLine = line;
    result.endLine = line;
    
    // Mock: In real implementation, would query LSP for implementations
    Location loc;
    loc.file = filePath;
    loc.line = line;
    loc.column = column;
    loc.name = symbol;
    loc.kind = "method";
    
    result.locations.append(loc);
    result.currentIndex = 0;
    result.previewContent = getFileContext(filePath, line, 10);
    
    m_activePeek = result;
    m_peekState = PeekState{result, filePath, line, column};
    
    emit peekOpened(result);
    return result;
}

PeekView::PeekResult PeekView::peekTypeDefinition(const QString& filePath, int line, int column, const QString& symbol)
{
    PeekResult result;
    result.mode = PeekMode::TypeDefinition;
    result.symbol = symbol.isEmpty() ? "unknown" : symbol;
    result.startLine = line;
    result.endLine = line;
    
    // Mock: In real implementation, would query LSP for type definition
    Location loc;
    loc.file = filePath;
    loc.line = line;
    loc.column = column;
    loc.name = symbol;
    loc.kind = "class";
    
    result.locations.append(loc);
    result.currentIndex = 0;
    result.previewContent = getFileContext(filePath, line, 10);
    
    m_activePeek = result;
    m_peekState = PeekState{result, filePath, line, column};
    
    emit peekOpened(result);
    return result;
}

PeekView::PeekResult PeekView::nextPeekLocation()
{
    if (!m_activePeek.has_value() || m_activePeek->locations.isEmpty()) {
        return PeekResult{};
    }

    auto& peek = m_activePeek.value();
    peek.currentIndex = (peek.currentIndex + 1) % peek.locations.size();
    
    const auto& currentLoc = peek.locations[peek.currentIndex];
    peek.previewContent = getFileContext(currentLoc.file, currentLoc.line, 10);
    peek.startLine = currentLoc.line;
    peek.endLine = currentLoc.line;
    
    emit peekLocationChanged(peek);
    return peek;
}

PeekView::PeekResult PeekView::previousPeekLocation()
{
    if (!m_activePeek.has_value() || m_activePeek->locations.isEmpty()) {
        return PeekResult{};
    }

    auto& peek = m_activePeek.value();
    peek.currentIndex = (peek.currentIndex - 1 + peek.locations.size()) % peek.locations.size();
    
    const auto& currentLoc = peek.locations[peek.currentIndex];
    peek.previewContent = getFileContext(currentLoc.file, currentLoc.line, 10);
    peek.startLine = currentLoc.line;
    peek.endLine = currentLoc.line;
    
    emit peekLocationChanged(peek);
    return peek;
}

PeekView::PeekResult PeekView::gotoLocationIndex(int index)
{
    if (!m_activePeek.has_value() || index < 0 || index >= m_activePeek->locations.size()) {
        return PeekResult{};
    }

    auto& peek = m_activePeek.value();
    peek.currentIndex = index;
    
    const auto& currentLoc = peek.locations[peek.currentIndex];
    peek.previewContent = getFileContext(currentLoc.file, currentLoc.line, 10);
    peek.startLine = currentLoc.line;
    peek.endLine = currentLoc.line;
    
    emit locationSelected(currentLoc);
    emit peekLocationChanged(peek);
    return peek;
}

void PeekView::closePeek()
{
    if (m_activePeek.has_value()) {
        m_activePeek.reset();
        m_peekState.reset();
        m_previewCache.clear();
        emit peekClosed();
    }
}

void PeekView::addPeekLocation(const Location& location)
{
    if (m_activePeek.has_value()) {
        m_activePeek->locations.append(location);
    }
}

QString PeekView::getFileContext(const QString& filePath, int line, int contextLines)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString("Cannot read file: %1").arg(filePath);
    }

    QStringList lines;
    QString content;
    int currentLine = 0;

    while (!file.atEnd()) {
        content = QString::fromUtf8(file.readLine());
        currentLine++;

        // Include context lines around the target line
        if (currentLine >= line - contextLines && currentLine <= line + contextLines) {
            lines.append(content.trimmed());
        }

        if (currentLine > line + contextLines) {
            break;
        }
    }

    file.close();
    
    QString result;
    int startLine = std::max(1, line - contextLines);
    for (int i = 0; i < lines.size(); ++i) {
        result += QString::number(startLine + i) + ": " + lines[i] + "\n";
    }

    return result;
}

QString PeekView::getLineContent(const QString& filePath, int line)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }

    int currentLine = 0;
    QString result;

    while (!file.atEnd()) {
        QString content = QString::fromUtf8(file.readLine());
        currentLine++;

        if (currentLine == line) {
            result = content.trimmed();
            break;
        }
    }

    file.close();
    return result;
}

QString PeekView::loadPreviewContent(const Location& location)
{
    auto it = m_previewCache.find(location.file);
    if (it != m_previewCache.end()) {
        return it.value();
    }

    QString content = getFileContext(location.file, location.line, 10);
    m_previewCache[location.file] = content;
    return content;
}

QString PeekView::formatLocation(const Location& location) const
{
    return QString("%1 (%2:%3)")
        .arg(location.file)
        .arg(location.line)
        .arg(location.column);
}
