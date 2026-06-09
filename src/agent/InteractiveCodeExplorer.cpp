#include "InteractiveCodeExplorer.h"
#include <QDebug>

InteractiveCodeExplorer::InteractiveCodeExplorer(QObject* parent)
    : QObject(parent) {
}

InteractiveCodeExplorer::~InteractiveCodeExplorer() {
}

void InteractiveCodeExplorer::indexCodebase(const QStringList& filePaths) {
    qDebug() << "Indexing" << filePaths.size() << "files";
    emit codebaseIndexed(filePaths.size());
}

QVector<InteractiveCodeExplorer::CodeLocation> InteractiveCodeExplorer::findDefinition(const QString& symbol) {
    return m_symbolIndex.value(symbol);
}

QVector<InteractiveCodeExplorer::CodeLocation> InteractiveCodeExplorer::findReferences(const QString& symbol) {
    QVector<CodeLocation> refs;
    for (const auto& loc : m_symbolIndex.value(symbol)) {
        refs.append(loc);
    }
    return refs;
}

QVector<InteractiveCodeExplorer::CodeLocation> InteractiveCodeExplorer::findImplementations(const QString& interface) {
    return QVector<CodeLocation>();
}

QString InteractiveCodeExplorer::getContextAroundLocation(const CodeLocation& location, int contextLines) {
    return QString("Context around line %1 in %2").arg(location.line).arg(location.filePath);
}

QString InteractiveCodeExplorer::getCodeSnippet(const CodeLocation& startLoc, const CodeLocation& endLoc) {
    return QString("Code from %1:%2 to %3:%4").arg(startLoc.filePath).arg(startLoc.line).arg(endLoc.filePath).arg(endLoc.line);
}

QVector<InteractiveCodeExplorer::CodeLocation> InteractiveCodeExplorer::navigateToSymbol(const QString& symbol) {
    return findDefinition(symbol);
}

void InteractiveCodeExplorer::startExploration(const QString& purpose) {
    ExplorationPath path;
    path.purpose = purpose;
    m_explorationHistory.append(path);
    emit navigationStarted(purpose);
}

void InteractiveCodeExplorer::addLocationToPath(const CodeLocation& location) {
    if (!m_explorationHistory.isEmpty()) {
        m_explorationHistory.last().visitedLocations.append(location);
        emit locationVisited(location);
    }
}

InteractiveCodeExplorer::NavigationStats InteractiveCodeExplorer::getNavigationStatistics() {
    NavigationStats stats;
    stats.totalLocationsVisited = 0;
    for (const auto& path : m_explorationHistory) {
        stats.totalLocationsVisited += path.visitedLocations.size();
    }
    stats.explorationHistory = m_explorationHistory;
    return stats;
}
