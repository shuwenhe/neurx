#include "editor/EditorHistory.h"

EditorHistory::EditorHistory(QObject* parent)
    : QObject(parent)
{
}

void EditorHistory::pushState(const EditorState& state)
{
    // 新操作后清空 redo 栈
    if (!m_redoStack.isEmpty()) {
        m_redoStack.clear();
        emit canRedoChanged(false);
    }
    
    // 控制栈大小
    if (m_undoStack.size() >= m_maxSize) {
        m_undoStack.removeFirst();
    }
    
    m_undoStack.push(state);
    
    // 通知 UI 更新
    emit canUndoChanged(true);
    emit stateChanged();
}

EditorState EditorHistory::undo()
{
    if (!canUndo()) {
        return EditorState();
    }
    
    EditorState state = m_undoStack.pop();
    m_redoStack.push(state);
    
    emit canUndoChanged(canUndo());
    emit canRedoChanged(true);
    emit stateChanged();
    
    return state;
}

EditorState EditorHistory::redo()
{
    if (!canRedo()) {
        return EditorState();
    }
    
    EditorState state = m_redoStack.pop();
    m_undoStack.push(state);
    
    emit canRedoChanged(canRedo());
    emit canUndoChanged(true);
    emit stateChanged();
    
    return state;
}

void EditorHistory::clear()
{
    m_undoStack.clear();
    m_redoStack.clear();
    
    emit canUndoChanged(false);
    emit canRedoChanged(false);
    emit stateChanged();
}
