#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QMap>
#include <QVector>
#include <memory>
#include <vector>

/**
 * @class InteractiveCodeExplorer
 * @brief Interactive code exploration and navigation
 */

class InteractiveCodeExplorer : public QObject {
    Q_OBJECT

public:
    struct CodeLocation {
        QString filePath;
        int line;
        int column;
        QString context;
    };

    struct ExplorationPath {
        QString startLocation;
        QVector<CodeLocation> visitedLocations;
        QString purpose;
    };

    explicit InteractiveCodeExplorer(QObject* parent = nullptr);
    ~InteractiveCodeExplorer();

    void indexCodebase(const QStringList& filePaths);
    QVector<CodeLocation> findDefinition(const QString& symbol);
    QVector<CodeLocation> findReferences(const QString& symbol);
    QVector<CodeLocation> findImplementations(const QString& interface);

    QString getContextAroundLocation(const CodeLocation& location, int contextLines = 5);
    QString getCodeSnippet(const CodeLocation& startLoc, const CodeLocation& endLoc);

    QVector<CodeLocation> navigateToSymbol(const QString& symbol);
    void startExploration(const QString& purpose);
    void addLocationToPath(const CodeLocation& location);

    struct NavigationStats {
        int totalLocationsVisited;
        QVector<QString> exploreSymbols;
        QVector<ExplorationPath> explorationHistory;
    };
    NavigationStats getNavigationStatistics();

signals:
    void codebaseIndexed(int totalFiles);
    void navigationStarted(const QString& purpose);
    void locationVisited(const CodeLocation& location);

private:
    QMap<QString, QVector<CodeLocation>> m_symbolIndex;
    QVector<ExplorationPath> m_explorationHistory;
};
