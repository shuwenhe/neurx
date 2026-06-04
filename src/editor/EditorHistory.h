#pragma once

#include <QObject>
#include <QStack>
#include <QString>

/**
 * @class EditorHistory
 * @brief Manages undo/redo functionality for text editors
 * 
 * Maintains two stacks:
 * - undoStack: stores previous states
 * - redoStack: stores undone states
 */

struct EditorState {
    QString content;
    int cursorPosition = 0;
    int selectionStart = 0;
    int selectionEnd = 0;
    
    bool operator==(const EditorState& other) const {
        return content == other.content && 
               cursorPosition == other.cursorPosition &&
               selectionStart == other.selectionStart &&
               selectionEnd == other.selectionEnd;
    }
};

class EditorHistory : public QObject {
    Q_OBJECT

public:
    explicit EditorHistory(QObject* parent = nullptr);
    ~EditorHistory() override = default;
    
    // State management
    void pushState(const EditorState& state);
    void clear();
    
    // Undo/Redo operations
    bool canUndo() const { return !m_undoStack.isEmpty(); }
    bool canRedo() const { return !m_redoStack.isEmpty(); }
    
    EditorState undo();
    EditorState redo();
    
    // Configuration
    void setMaxHistorySize(int size) { m_maxSize = size; }
    int maxHistorySize() const { return m_maxSize; }
    int undoStackSize() const { return m_undoStack.size(); }
    int redoStackSize() const { return m_redoStack.size(); }

signals:
    void canUndoChanged(bool canUndo);
    void canRedoChanged(bool canRedo);
    void stateChanged();

private:
    QStack<EditorState> m_undoStack;
    QStack<EditorState> m_redoStack;
    int m_maxSize = 100;
};
