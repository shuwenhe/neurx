#ifndef EDITORCOMMANDBRIDGE_H
#define EDITORCOMMANDBRIDGE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>
#include <QVariantMap>
#include <functional>

// Forward declarations
class BracketMatcher;
class WordOperations;
class CaseConverter;
class SmartSelection;
class WordHighlight;
class InlineRename;
class GoToDefinition;
class SelectToBracket;
class LineOperations;
class CommentManager;
class FindAndReplace;

/**
 * @class EditorCommandBridge
 * @brief Bridges keybindings to editor feature implementations
 * 
 * Executes editor commands triggered by keybindings and connects them
 * to the underlying C++ feature classes
 */
class EditorCommandBridge : public QObject {
    Q_OBJECT

public:
    explicit EditorCommandBridge(QObject* parent = nullptr);

    // Set feature instances (from main.cpp)
    void setBracketMatcher(BracketMatcher* matcher) { m_bracketMatcher = matcher; }
    void setWordOperations(WordOperations* ops) { m_wordOperations = ops; }
    void setCaseConverter(CaseConverter* converter) { m_caseConverter = converter; }
    void setSmartSelection(SmartSelection* selection) { m_smartSelection = selection; }
    void setWordHighlight(WordHighlight* highlight) { m_wordHighlight = highlight; }
    void setInlineRename(InlineRename* rename) { m_inlineRename = rename; }
    void setGoToDefinition(GoToDefinition* gotodef) { m_goToDefinition = gotodef; }
    void setSelectToBracket(SelectToBracket* selectBracket) { m_selectToBracket = selectBracket; }
    void setLineOperations(LineOperations* lineOps) { m_lineOperations = lineOps; }
    void setCommentManager(CommentManager* commentManager) { m_commentManager = commentManager; }
    void setFindAndReplace(FindAndReplace* findReplace) { m_findAndReplace = findReplace; }

    /**
     * Execute editor command by command ID
     * Called when a keybinding is triggered
     */
    void executeCommand(const QString& commandId, const QString& editorText = "", 
                       int cursorLine = 0, int cursorColumn = 0);

    /**
     * Get command description for help/status bar
     */
    QString getCommandDescription(const QString& commandId) const;

signals:
    void commandExecuted(const QString& commandId);
    void commandFailed(const QString& commandId, const QString& error);
    void commandResultReady(const QString& commandId, const QVariantMap& result);

private:
    // Feature instances
    BracketMatcher* m_bracketMatcher = nullptr;
    WordOperations* m_wordOperations = nullptr;
    CaseConverter* m_caseConverter = nullptr;
    SmartSelection* m_smartSelection = nullptr;
    WordHighlight* m_wordHighlight = nullptr;
    InlineRename* m_inlineRename = nullptr;
    GoToDefinition* m_goToDefinition = nullptr;
    SelectToBracket* m_selectToBracket = nullptr;
    LineOperations* m_lineOperations = nullptr;
    CommentManager* m_commentManager = nullptr;
    FindAndReplace* m_findAndReplace = nullptr;

    // Context state
    QString m_currentEditorText;
    int m_cursorLine = 0;
    int m_cursorColumn = 0;

    // Command registry
    QMap<QString, std::function<QVariantMap()>> m_commands;
    QMap<QString, QString> m_descriptions;

    QVariantMap makeBaseResult(const QString& commandId) const;
    static QStringList splitLines(const QString& text);
    static int indexFromLineColumn(const QStringList& lines, int line, int column);
    static QVariantMap boundsToMap(int startLine, int startColumn, int endLine, int endColumn, const QString& text);

    QVariantMap onJumpToBracket();
    QVariantMap onTransformToUppercase();
    QVariantMap onTransformToLowercase();
    QVariantMap onTransformToTitleCase();
    QVariantMap onDeleteWordForward();
    QVariantMap onDeleteWordBackward();
    QVariantMap onMoveWordForward();
    QVariantMap onMoveWordBackward();
    QVariantMap onExpandSelection();
    QVariantMap onContractSelection();
    QVariantMap onToggleHighlight();
    QVariantMap onClearHighlight();
    QVariantMap onRename();
    QVariantMap onCancelRename();
    QVariantMap onGoToDefinition();
    QVariantMap onGoToPreviousDefinition();
    QVariantMap onGoToNextDefinition();
    QVariantMap onSelectToBracket();
    QVariantMap onSelectBracketPair();
    QVariantMap onDeleteLines();
    QVariantMap onMoveLineUp();
    QVariantMap onMoveLineDown();
    QVariantMap onDuplicateLines();
    QVariantMap onSortLinesAscending();
    QVariantMap onSortLinesDescending();
    QVariantMap onTrimTrailingWhitespace();
    QVariantMap onToggleLineComment();
    QVariantMap onToggleBlockComment();
    QVariantMap onFindNext();
    QVariantMap onFindPrevious();
    QVariantMap onReplaceNext();
    QVariantMap onReplaceAll();

    void initializeCommands();
};

#endif // EDITORCOMMANDBRIDGE_H
