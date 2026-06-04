#include "bridge/EditorCommandBridge.h"

#include "editor/BracketMatcher.h"
#include "editor/WordOperations.h"
#include "editor/CaseConverter.h"
#include "editor/SmartSelection.h"
#include "editor/WordHighlight.h"
#include "editor/InlineRename.h"
#include "editor/GoToDefinition.h"
#include "editor/SelectToBracket.h"
#include "editor/LineOperations.h"
#include "editor/CommentManager.h"
#include "editor/FindAndReplace.h"

#include <QVariantList>
#include <QDebug>

EditorCommandBridge::EditorCommandBridge(QObject *parent)
    : QObject(parent)
{
    initializeCommands();
}

QVariantMap EditorCommandBridge::makeBaseResult(const QString &commandId) const
{
    QVariantMap result;
    result.insert(QStringLiteral("commandId"), commandId);
    result.insert(QStringLiteral("editorText"), m_currentEditorText);
    result.insert(QStringLiteral("cursorLine"), m_cursorLine);
    result.insert(QStringLiteral("cursorColumn"), m_cursorColumn);
    return result;
}

QStringList EditorCommandBridge::splitLines(const QString &text)
{
    return text.split('\n');
}

int EditorCommandBridge::indexFromLineColumn(const QStringList &lines, int line, int column)
{
    if (lines.isEmpty())
        return 0;

    const int clampedLine = qBound(0, line, lines.size() - 1);
    int index = 0;
    for (int i = 0; i < clampedLine; ++i)
        index += lines.at(i).size() + 1;

    return index + qBound(0, column, lines.at(clampedLine).size());
}

QVariantMap EditorCommandBridge::boundsToMap(int startLine, int startColumn, int endLine, int endColumn, const QString &text)
{
    QVariantMap result;
    result.insert(QStringLiteral("startLine"), startLine);
    result.insert(QStringLiteral("startColumn"), startColumn);
    result.insert(QStringLiteral("endLine"), endLine);
    result.insert(QStringLiteral("endColumn"), endColumn);

    const QStringList lines = splitLines(text);
    const int startIndex = indexFromLineColumn(lines, startLine, startColumn);
    const int endIndex = indexFromLineColumn(lines, endLine, endColumn);
    result.insert(QStringLiteral("startIndex"), startIndex);
    result.insert(QStringLiteral("endIndex"), endIndex);
    return result;
}

void EditorCommandBridge::executeCommand(const QString &commandId,
                                         const QString &editorText,
                                         int cursorLine,
                                         int cursorColumn)
{
    m_currentEditorText = editorText;
    m_cursorLine = cursorLine;
    m_cursorColumn = cursorColumn;

    if (!m_commands.contains(commandId)) {
        emit commandFailed(commandId, QStringLiteral("Unknown command"));
        qWarning() << "Unknown command:" << commandId;
        return;
    }

    try {
        const QVariantMap result = m_commands.value(commandId)();
        emit commandResultReady(commandId, result);
        emit commandExecuted(commandId);
        qDebug() << "Command executed:" << commandId;
    } catch (const std::exception &e) {
        emit commandFailed(commandId, QString::fromUtf8(e.what()));
        qWarning() << "Command failed:" << commandId << e.what();
    }
}

QString EditorCommandBridge::getCommandDescription(const QString &commandId) const
{
    return m_descriptions.value(commandId);
}

void EditorCommandBridge::initializeCommands()
{
    m_commands.insert(QStringLiteral("editor.action.jumpToBracket"), [this]() { return onJumpToBracket(); });
    m_commands.insert(QStringLiteral("editor.action.transformToUppercase"), [this]() { return onTransformToUppercase(); });
    m_commands.insert(QStringLiteral("editor.action.transformToLowercase"), [this]() { return onTransformToLowercase(); });
    m_commands.insert(QStringLiteral("editor.action.transformToTitleCase"), [this]() { return onTransformToTitleCase(); });
    m_commands.insert(QStringLiteral("editor.action.deleteWordForward"), [this]() { return onDeleteWordForward(); });
    m_commands.insert(QStringLiteral("editor.action.deleteWordBackward"), [this]() { return onDeleteWordBackward(); });
    m_commands.insert(QStringLiteral("editor.action.moveWordForward"), [this]() { return onMoveWordForward(); });
    m_commands.insert(QStringLiteral("editor.action.moveWordBackward"), [this]() { return onMoveWordBackward(); });
    m_commands.insert(QStringLiteral("editor.action.expandSelection"), [this]() { return onExpandSelection(); });
    m_commands.insert(QStringLiteral("editor.action.contractSelection"), [this]() { return onContractSelection(); });
    m_commands.insert(QStringLiteral("editor.action.toggleHighlight"), [this]() { return onToggleHighlight(); });
    m_commands.insert(QStringLiteral("editor.action.clearHighlight"), [this]() { return onClearHighlight(); });
    m_commands.insert(QStringLiteral("editor.action.rename"), [this]() { return onRename(); });
    m_commands.insert(QStringLiteral("editor.action.cancelRename"), [this]() { return onCancelRename(); });
    m_commands.insert(QStringLiteral("editor.action.goToDefinition"), [this]() { return onGoToDefinition(); });
    m_commands.insert(QStringLiteral("editor.action.goToPreviousDefinition"), [this]() { return onGoToPreviousDefinition(); });
    m_commands.insert(QStringLiteral("editor.action.goToNextDefinition"), [this]() { return onGoToNextDefinition(); });
    m_commands.insert(QStringLiteral("editor.action.selectToBracket"), [this]() { return onSelectToBracket(); });
    m_commands.insert(QStringLiteral("editor.action.selectBracketPair"), [this]() { return onSelectBracketPair(); });
    m_commands.insert(QStringLiteral("editor.action.deleteLines"), [this]() { return onDeleteLines(); });
    m_commands.insert(QStringLiteral("editor.action.moveLinesUpAction"), [this]() { return onMoveLineUp(); });
    m_commands.insert(QStringLiteral("editor.action.moveLinesDownAction"), [this]() { return onMoveLineDown(); });
    m_commands.insert(QStringLiteral("editor.action.duplicateSelection"), [this]() { return onDuplicateLines(); });
    m_commands.insert(QStringLiteral("editor.action.sortLinesAscending"), [this]() { return onSortLinesAscending(); });
    m_commands.insert(QStringLiteral("editor.action.sortLinesDescending"), [this]() { return onSortLinesDescending(); });
    m_commands.insert(QStringLiteral("editor.action.trimTrailingWhitespace"), [this]() { return onTrimTrailingWhitespace(); });
    m_commands.insert(QStringLiteral("editor.action.commentLine"), [this]() { return onToggleLineComment(); });
    m_commands.insert(QStringLiteral("editor.action.blockComment"), [this]() { return onToggleBlockComment(); });
    m_commands.insert(QStringLiteral("editor.action.nextMatchFindAction"), [this]() { return onFindNext(); });
    m_commands.insert(QStringLiteral("editor.action.previousMatchFindAction"), [this]() { return onFindPrevious(); });
    m_commands.insert(QStringLiteral("editor.action.replaceNextAction"), [this]() { return onReplaceNext(); });
    m_commands.insert(QStringLiteral("editor.action.replaceAllAction"), [this]() { return onReplaceAll(); });

    m_descriptions.insert(QStringLiteral("editor.action.jumpToBracket"), QStringLiteral("Jump to matching bracket"));
    m_descriptions.insert(QStringLiteral("editor.action.transformToUppercase"), QStringLiteral("Transform to UPPERCASE"));
    m_descriptions.insert(QStringLiteral("editor.action.transformToLowercase"), QStringLiteral("Transform to lowercase"));
    m_descriptions.insert(QStringLiteral("editor.action.transformToTitleCase"), QStringLiteral("Transform to Title Case"));
    m_descriptions.insert(QStringLiteral("editor.action.deleteWordForward"), QStringLiteral("Delete word forward"));
    m_descriptions.insert(QStringLiteral("editor.action.deleteWordBackward"), QStringLiteral("Delete word backward"));
    m_descriptions.insert(QStringLiteral("editor.action.moveWordForward"), QStringLiteral("Move cursor forward by word"));
    m_descriptions.insert(QStringLiteral("editor.action.moveWordBackward"), QStringLiteral("Move cursor backward by word"));
    m_descriptions.insert(QStringLiteral("editor.action.expandSelection"), QStringLiteral("Expand selection"));
    m_descriptions.insert(QStringLiteral("editor.action.contractSelection"), QStringLiteral("Contract selection"));
    m_descriptions.insert(QStringLiteral("editor.action.toggleHighlight"), QStringLiteral("Highlight word occurrences"));
    m_descriptions.insert(QStringLiteral("editor.action.clearHighlight"), QStringLiteral("Clear word highlights"));
    m_descriptions.insert(QStringLiteral("editor.action.rename"), QStringLiteral("Rename symbol (F2)"));
    m_descriptions.insert(QStringLiteral("editor.action.cancelRename"), QStringLiteral("Cancel rename"));
    m_descriptions.insert(QStringLiteral("editor.action.goToDefinition"), QStringLiteral("Go to definition (F12)"));
    m_descriptions.insert(QStringLiteral("editor.action.goToPreviousDefinition"), QStringLiteral("Go to previous definition location"));
    m_descriptions.insert(QStringLiteral("editor.action.goToNextDefinition"), QStringLiteral("Go to next definition location"));
    m_descriptions.insert(QStringLiteral("editor.action.selectToBracket"), QStringLiteral("Select to matching bracket"));
    m_descriptions.insert(QStringLiteral("editor.action.selectBracketPair"), QStringLiteral("Select matching bracket pair"));
    m_descriptions.insert(QStringLiteral("editor.action.deleteLines"), QStringLiteral("Delete Line"));
    m_descriptions.insert(QStringLiteral("editor.action.moveLinesUpAction"), QStringLiteral("Move Line Up"));
    m_descriptions.insert(QStringLiteral("editor.action.moveLinesDownAction"), QStringLiteral("Move Line Down"));
    m_descriptions.insert(QStringLiteral("editor.action.duplicateSelection"), QStringLiteral("Duplicate Selection"));
    m_descriptions.insert(QStringLiteral("editor.action.sortLinesAscending"), QStringLiteral("Sort Lines Ascending"));
    m_descriptions.insert(QStringLiteral("editor.action.sortLinesDescending"), QStringLiteral("Sort Lines Descending"));
    m_descriptions.insert(QStringLiteral("editor.action.trimTrailingWhitespace"), QStringLiteral("Trim Trailing Whitespace"));
    m_descriptions.insert(QStringLiteral("editor.action.commentLine"), QStringLiteral("Toggle Line Comment"));
    m_descriptions.insert(QStringLiteral("editor.action.blockComment"), QStringLiteral("Toggle Block Comment"));
    m_descriptions.insert(QStringLiteral("editor.action.nextMatchFindAction"), QStringLiteral("Find Next"));
    m_descriptions.insert(QStringLiteral("editor.action.previousMatchFindAction"), QStringLiteral("Find Previous"));
}

QVariantMap EditorCommandBridge::onJumpToBracket()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.jumpToBracket"));
    if (!m_bracketMatcher)
        return result;

    const int line0 = qMax(0, m_cursorLine - 1);
    const int column0 = qMax(0, m_cursorColumn - 1);
    const QVariantMap match = m_bracketMatcher->matchingBracketAt(m_currentEditorText, line0, column0);
    result.insert(QStringLiteral("match"), match);
    result.insert(QStringLiteral("hasMatch"), match.value(QStringLiteral("hasMatch")).toBool());
    return result;
}

QVariantMap EditorCommandBridge::onTransformToUppercase()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.transformToUppercase"));
    if (!m_caseConverter)
        return result;

    const QString converted = CaseConverter::convert(m_currentEditorText, CaseConverter::UpperCase);
    result.insert(QStringLiteral("changedText"), converted);
    return result;
}

QVariantMap EditorCommandBridge::onTransformToLowercase()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.transformToLowercase"));
    if (!m_caseConverter)
        return result;

    const QString converted = CaseConverter::convert(m_currentEditorText, CaseConverter::LowerCase);
    result.insert(QStringLiteral("changedText"), converted);
    return result;
}

QVariantMap EditorCommandBridge::onTransformToTitleCase()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.transformToTitleCase"));
    if (!m_caseConverter)
        return result;

    const QString converted = CaseConverter::convert(m_currentEditorText, CaseConverter::TitleCase);
    result.insert(QStringLiteral("changedText"), converted);
    return result;
}

QVariantMap EditorCommandBridge::onDeleteWordForward()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.deleteWordForward"));
    if (!m_wordOperations)
        return result;

    const int line0 = qMax(0, m_cursorLine - 1);
    const int column0 = qMax(0, m_cursorColumn - 1);
    const QString nextText = m_wordOperations->deleteWordForward(m_currentEditorText, line0, column0);
    result.insert(QStringLiteral("changedText"), nextText);
    return result;
}

QVariantMap EditorCommandBridge::onDeleteWordBackward()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.deleteWordBackward"));
    if (!m_wordOperations)
        return result;

    const int line0 = qMax(0, m_cursorLine - 1);
    const int column0 = qMax(0, m_cursorColumn - 1);
    const QString nextText = m_wordOperations->deleteWordBackward(m_currentEditorText, line0, column0);
    result.insert(QStringLiteral("changedText"), nextText);
    return result;
}

QVariantMap EditorCommandBridge::onMoveWordForward()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.moveWordForward"));
    if (!m_wordOperations)
        return result;

    int line0 = qMax(0, m_cursorLine - 1);
    int column0 = qMax(0, m_cursorColumn - 1);
    m_wordOperations->moveWordForward(m_currentEditorText, line0, column0);
    result.insert(QStringLiteral("cursorLine"), line0 + 1);
    result.insert(QStringLiteral("cursorColumn"), column0 + 1);
    result.insert(QStringLiteral("cursorLine0"), line0);
    result.insert(QStringLiteral("cursorColumn0"), column0);
    return result;
}

QVariantMap EditorCommandBridge::onMoveWordBackward()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.moveWordBackward"));
    if (!m_wordOperations)
        return result;

    int line0 = qMax(0, m_cursorLine - 1);
    int column0 = qMax(0, m_cursorColumn - 1);
    m_wordOperations->moveWordBackward(m_currentEditorText, line0, column0);
    result.insert(QStringLiteral("cursorLine"), line0 + 1);
    result.insert(QStringLiteral("cursorColumn"), column0 + 1);
    result.insert(QStringLiteral("cursorLine0"), line0);
    result.insert(QStringLiteral("cursorColumn0"), column0);
    return result;
}

QVariantMap EditorCommandBridge::onExpandSelection()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.expandSelection"));
    if (!m_smartSelection)
        return result;

    const auto bounds = m_smartSelection->expandSelection(m_currentEditorText, qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn - 1));
    result.insert(QStringLiteral("selection"), boundsToMap(bounds.startLine, bounds.startColumn, bounds.endLine, bounds.endColumn, m_currentEditorText));
    result.insert(QStringLiteral("selectedText"), bounds.selectedText);
    result.insert(QStringLiteral("mode"), static_cast<int>(m_smartSelection->currentMode()));
    return result;
}

QVariantMap EditorCommandBridge::onContractSelection()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.contractSelection"));
    if (!m_smartSelection)
        return result;

    const auto bounds = m_smartSelection->contractSelection();
    result.insert(QStringLiteral("selection"), boundsToMap(bounds.startLine, bounds.startColumn, bounds.endLine, bounds.endColumn, m_currentEditorText));
    result.insert(QStringLiteral("selectedText"), bounds.selectedText);
    result.insert(QStringLiteral("mode"), static_cast<int>(m_smartSelection->currentMode()));
    return result;
}

QVariantMap EditorCommandBridge::onToggleHighlight()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.toggleHighlight"));
    if (!m_wordHighlight)
        return result;

    const auto highlights = m_wordHighlight->highlightAtPosition(m_currentEditorText, qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn - 1));
    QVariantList items;
    for (const auto &highlight : highlights) {
        QVariantMap item;
        item.insert(QStringLiteral("line"), highlight.line);
        item.insert(QStringLiteral("column"), highlight.column);
        item.insert(QStringLiteral("length"), highlight.length);
        item.insert(QStringLiteral("caseSensitive"), highlight.isCaseSensitive);
        items.append(item);
    }
    result.insert(QStringLiteral("highlights"), items);
    result.insert(QStringLiteral("count"), items.size());
    return result;
}

QVariantMap EditorCommandBridge::onClearHighlight()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.clearHighlight"));
    if (m_wordHighlight)
        m_wordHighlight->clearHighlights();
    result.insert(QStringLiteral("cleared"), true);
    return result;
}

QVariantMap EditorCommandBridge::onRename()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.rename"));
    if (!m_inlineRename)
        return result;

    const auto info = m_inlineRename->startRename(m_currentEditorText, qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn - 1));
    QVariantMap renameInfo;
    renameInfo.insert(QStringLiteral("oldName"), info.oldName);
    renameInfo.insert(QStringLiteral("newName"), info.newName);
    renameInfo.insert(QStringLiteral("occurrences"), info.occurrences);
    QVariantList locations;
    for (const auto &location : info.locations) {
        QVariantMap loc;
        loc.insert(QStringLiteral("line"), location.first);
        loc.insert(QStringLiteral("column"), location.second);
        locations.append(loc);
    }
    renameInfo.insert(QStringLiteral("locations"), locations);
    result.insert(QStringLiteral("rename"), renameInfo);
    return result;
}

QVariantMap EditorCommandBridge::onCancelRename()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.cancelRename"));
    if (m_inlineRename)
        m_inlineRename->cancelRename();
    result.insert(QStringLiteral("cancelled"), true);
    return result;
}

QVariantMap EditorCommandBridge::onGoToDefinition()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.goToDefinition"));
    if (!m_goToDefinition)
        return result;

    const auto def = m_goToDefinition->findDefinition(m_currentEditorText, qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn - 1));
    QVariantMap defMap;
    defMap.insert(QStringLiteral("line"), def.line);
    defMap.insert(QStringLiteral("column"), def.column);
    defMap.insert(QStringLiteral("symbol"), def.symbol);
    defMap.insert(QStringLiteral("type"), def.type);
    defMap.insert(QStringLiteral("found"), def.found);
    defMap.insert(QStringLiteral("preview"), def.preview);
    result.insert(QStringLiteral("definition"), defMap);
    return result;
}

QVariantMap EditorCommandBridge::onGoToPreviousDefinition()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.goToPreviousDefinition"));
    if (!m_goToDefinition || !m_goToDefinition->canNavigateBack())
        return result;

    const auto def = m_goToDefinition->navigateBack();
    result.insert(QStringLiteral("definitionLine"), def.line);
    result.insert(QStringLiteral("definitionColumn"), def.column);
    result.insert(QStringLiteral("symbol"), def.symbol);
    return result;
}

QVariantMap EditorCommandBridge::onGoToNextDefinition()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.goToNextDefinition"));
    if (!m_goToDefinition || !m_goToDefinition->canNavigateForward())
        return result;

    const auto def = m_goToDefinition->navigateForward();
    result.insert(QStringLiteral("definitionLine"), def.line);
    result.insert(QStringLiteral("definitionColumn"), def.column);
    result.insert(QStringLiteral("symbol"), def.symbol);
    return result;
}

QVariantMap EditorCommandBridge::onSelectToBracket()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.selectToBracket"));
    if (!m_selectToBracket)
        return result;

    const auto bounds = m_selectToBracket->selectToBracket(m_currentEditorText, qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn - 1));
    QVariantMap selection = boundsToMap(bounds.startLine, bounds.startColumn, bounds.endLine, bounds.endColumn, m_currentEditorText);
    selection.insert(QStringLiteral("found"), bounds.found);
    result.insert(QStringLiteral("selection"), selection);
    result.insert(QStringLiteral("selectedText"), bounds.selectedText);
    return result;
}

QVariantMap EditorCommandBridge::onSelectBracketPair()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.selectBracketPair"));
    if (!m_selectToBracket)
        return result;

    const auto bounds = m_selectToBracket->selectBracketPair(m_currentEditorText, qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn - 1));
    QVariantMap selection = boundsToMap(bounds.startLine, bounds.startColumn, bounds.endLine, bounds.endColumn, m_currentEditorText);
    selection.insert(QStringLiteral("found"), bounds.found);
    result.insert(QStringLiteral("selection"), selection);
    result.insert(QStringLiteral("selectedText"), bounds.selectedText);
    return result;
}

QVariantMap EditorCommandBridge::onDeleteLines()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.deleteLines"));
    QStringList lines = splitLines(m_currentEditorText);
    int line0 = qMax(0, m_cursorLine - 1);

    QStringList nextLines = LineOperations::deleteLines(lines, {line0});
    result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
    return result;
}

QVariantMap EditorCommandBridge::onMoveLineUp()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.moveLinesUpAction"));
    QStringList lines = splitLines(m_currentEditorText);
    int line0 = qMax(0, m_cursorLine - 1);

    if (line0 > 0) {
        QStringList nextLines = LineOperations::moveLinesUp(lines, line0, line0);
        result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
        result.insert(QStringLiteral("cursorLine"), m_cursorLine - 1);
    }
    return result;
}

QVariantMap EditorCommandBridge::onMoveLineDown()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.moveLinesDownAction"));
    QStringList lines = splitLines(m_currentEditorText);
    int line0 = qMax(0, m_cursorLine - 1);

    if (line0 < lines.size() - 1) {
        QStringList nextLines = LineOperations::moveLinesDown(lines, line0, line0);
        result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
        result.insert(QStringLiteral("cursorLine"), m_cursorLine + 1);
    }
    return result;
}

QVariantMap EditorCommandBridge::onDuplicateLines()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.duplicateSelection"));
    QStringList lines = splitLines(m_currentEditorText);
    int line0 = qMax(0, m_cursorLine - 1);

    QStringList nextLines = LineOperations::duplicateLines(lines, line0, line0);
    result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
    return result;
}

QVariantMap EditorCommandBridge::onSortLinesAscending()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.sortLinesAscending"));
    QStringList lines = splitLines(m_currentEditorText);
    // Ideally we'd have a selection range, but for now we'll just sort all lines if no selection is provided
    // In a real editor, this would operate on the selection.
    QStringList nextLines = LineOperations::sortLines(lines, 0, lines.size() - 1, true);
    result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
    return result;
}

QVariantMap EditorCommandBridge::onSortLinesDescending()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.sortLinesDescending"));
    QStringList lines = splitLines(m_currentEditorText);
    QStringList nextLines = LineOperations::sortLines(lines, 0, lines.size() - 1, false);
    result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
    return result;
}

QVariantMap EditorCommandBridge::onTrimTrailingWhitespace()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.trimTrailingWhitespace"));
    QStringList lines = splitLines(m_currentEditorText);
    QStringList nextLines = LineOperations::trimWhitespace(lines, 0, lines.size() - 1, false, true);
    result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
    return result;
}

QVariantMap EditorCommandBridge::onToggleLineComment()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.commentLine"));
    if (!m_commentManager) return result;

    QStringList lines = splitLines(m_currentEditorText);
    int line0 = qMax(0, m_cursorLine - 1);

    // We should probably pass the actual language here, but for now we'll use "cpp"
    CommentSyntax syntax = m_commentManager->getSyntax("cpp");
    QStringList nextLines = CommentManager::toggleLineComment(lines, line0, line0, syntax);
    result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
    return result;
}

QVariantMap EditorCommandBridge::onToggleBlockComment()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.blockComment"));
    if (!m_commentManager) return result;

    QStringList lines = splitLines(m_currentEditorText);
    int line0 = qMax(0, m_cursorLine - 1);

    CommentSyntax syntax = m_commentManager->getSyntax("cpp");
    QStringList nextLines = CommentManager::toggleBlockComment(lines, line0, line0, syntax);
    result.insert(QStringLiteral("changedText"), nextLines.join('\n'));
    return result;
}

QVariantMap EditorCommandBridge::onFindNext()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.nextMatchFindAction"));
    if (!m_findAndReplace) return result;

    // We'll assume the search text is passed in a more complex command call or stored somewhere
    // For now we'll just demonstrate the connection.
    // Usually Find next uses the current search state.
    auto found = m_findAndReplace->findNext(m_currentEditorText, m_findAndReplace->currentSearchText(),
                                           qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn));
    if (found.found) {
        result.insert(QStringLiteral("cursorLine"), found.line + 1);
        result.insert(QStringLiteral("cursorColumn"), found.column + 1);
        result.insert(QStringLiteral("matchLength"), found.length);
    }
    return result;
}

QVariantMap EditorCommandBridge::onFindPrevious()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.previousMatchFindAction"));
    if (!m_findAndReplace) return result;

    auto found = m_findAndReplace->findPrevious(m_currentEditorText, m_findAndReplace->currentSearchText(),
                                               qMax(0, m_cursorLine - 1), qMax(0, m_cursorColumn - 2));
    if (found.found) {
        result.insert(QStringLiteral("cursorLine"), found.line + 1);
        result.insert(QStringLiteral("cursorColumn"), found.column + 1);
        result.insert(QStringLiteral("matchLength"), found.length);
    }
    return result;
}

QVariantMap EditorCommandBridge::onReplaceNext()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.replaceNextAction"));
    // Implement if replace text is available
    return result;
}

QVariantMap EditorCommandBridge::onReplaceAll()
{
    QVariantMap result = makeBaseResult(QStringLiteral("editor.action.replaceAllAction"));
    // Implement if replace text is available
    return result;
}

