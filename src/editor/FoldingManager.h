#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QMap>

/**
 * @class FoldingManager
 * @brief Manages code folding regions
 * 
 * Features:
 * - Detect foldable regions
 * - Fold/unfold code blocks
 * - Fold all/unfold all
 * - Cache fold ranges
 */

struct FoldRange {
    int startLine;
    int endLine;
    int indent;
    QString type;  // "function", "class", "comment", "region", "import"
};

class FoldingManager : public QObject {
    Q_OBJECT

public:
    explicit FoldingManager(QObject* parent = nullptr);
    ~FoldingManager() override = default;
    
    // Fold range computation
    QList<FoldRange> computeFoldRanges(const QString& text, const QString& language);
    
    // Fold operations
    void toggleFold(int line);
    void fold(int line);
    void unfold(int line);
    void foldAll();
    void unfoldAll();
    void foldLevel(int level);
    void unfoldLevel(int level);
    
    // Query
    bool isFolded(int line) const;
    FoldRange getFoldRange(int line) const;
    QList<FoldRange> getFoldRanges() const { return m_foldRanges; }
    
    // Configuration
    void setMinimumFoldSize(int lines) { m_minFoldSize = lines; }
    int minimumFoldSize() const { return m_minFoldSize; }

signals:
    void foldsChanged(const QList<FoldRange>& ranges);
    void foldToggled(int line, bool folded);

private:
    QList<FoldRange> m_foldRanges;
    QMap<int, bool> m_foldStates;  // line -> isFolded
    int m_minFoldSize = 2;
    
    FoldRange detectFunctionRange(const QString& text, int startLine);
    FoldRange detectClassRange(const QString& text, int startLine);
    FoldRange detectCommentRange(const QString& text, int startLine);
};
