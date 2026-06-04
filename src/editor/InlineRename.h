#ifndef INLINERENAME_H
#define INLINERENAME_H

#include <QObject>
#include <QString>
#include <QList>

/**
 * Inline Rename - Quick rename for identifiers at cursor position
 * Triggered by F2, renames all occurrences of selected word
 */
class InlineRename : public QObject {
    Q_OBJECT

public:
    explicit InlineRename(QObject* parent = nullptr);

    // Rename info
    struct RenameInfo {
        QString oldName;
        QString newName;
        int occurrences = 0;
        QList<std::pair<int, int>> locations; // line, column pairs
    };

    /**
     * Start inline rename mode at cursor position
     * @param text The full text
     * @param line The line number of cursor
     * @param column The column number of cursor
     * @return Rename info if a valid identifier is found
     */
    RenameInfo startRename(const QString& text, int line, int column);

    /**
     * Apply rename and update all occurrences
     * @param text The original text
     * @param newName The new name for the identifier
     * @return Updated text with all occurrences renamed
     */
    QString applyRename(const QString& text, const QString& newName);

    /**
     * Cancel current rename operation
     */
    void cancelRename();

    /**
     * Check if rename is active
     */
    bool isRenameActive() const { return !m_currentRenameInfo.oldName.isEmpty(); }

    /**
     * Get current rename info
     */
    RenameInfo currentRenameInfo() const { return m_currentRenameInfo; }

signals:
    void renameStarted(RenameInfo info);
    void renameApplied(QString newText, int occurrences);
    void renameCancelled();

private:
    // Helper methods
    QString getWordAtPosition(const QString& text, int line, int column) const;
    bool isWordChar(const QChar& ch) const;
    bool isValidIdentifier(const QString& name) const;
    int findWordStart(const QString& line, int column) const;
    int findWordEnd(const QString& line, int column) const;
    
    // Find all occurrences for renaming
    QList<std::pair<int, int>> findRenameLocations(const QString& text, const QString& identifier);
    
    // Apply rename across text
    QString replaceAllOccurrences(const QString& text, const QString& oldName, const QString& newName);

    // State
    RenameInfo m_currentRenameInfo;
};

#endif // INLINERENAME_H
