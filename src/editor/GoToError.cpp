#include "GoToError.h"
#include <QDebug>
#include <algorithm>

GoToError::GoToError(QObject* parent)
    : QObject(parent)
{
}

void GoToError::setDiagnostics(const QString& filePath, const QList<Diagnostic>& diagnostics)
{
    if (!filePath.isEmpty()) {
        auto& entry = m_diagnosticsByFile[filePath];
        entry.diagnostics = diagnostics;
        entry.currentIndex = 0;
        
        // Sort diagnostics by line and column
        std::sort(entry.diagnostics.begin(), entry.diagnostics.end(),
                  [](const Diagnostic& a, const Diagnostic& b) {
                      if (a.line != b.line) return a.line < b.line;
                      return a.column < b.column;
                  });
        
        auto counts = getDiagnosticCounts();
        emit diagnosticsChanged(filePath, counts.first, counts.second);
    }
}

QList<GoToError::Diagnostic> GoToError::getDiagnostics(const QString& filePath) const
{
    auto it = m_diagnosticsByFile.find(filePath);
    if (it != m_diagnosticsByFile.end()) {
        return it->diagnostics;
    }
    return {};
}

GoToError::NavigationResult GoToError::goToNextError(int currentLine, int currentColumn, bool includeWarnings)
{
    NavigationResult result;
    if (m_currentFile.isEmpty()) {
        return result;
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return result;
    }

    auto filtered = filterBySeverity(it->diagnostics, true, includeWarnings, false, false);
    if (filtered.isEmpty()) {
        return result;
    }

    // Find next diagnostic after current position
    int nextIndex = -1;
    for (int i = 0; i < filtered.size(); ++i) {
        const auto& diag = filtered[i];
        if (diag.line > currentLine || 
            (diag.line == currentLine && diag.column > currentColumn)) {
            nextIndex = i;
            break;
        }
    }

    // If not found, wrap around to first
    if (nextIndex == -1) {
        nextIndex = 0;
    }

    if (nextIndex >= 0 && nextIndex < filtered.size()) {
        result.found = true;
        result.diagnostic = filtered[nextIndex];
        result.index = nextIndex;
        result.totalCount = filtered.size();
        emit navigatedToDiagnostic(result.diagnostic);
        return result;
    }

    return result;
}

GoToError::NavigationResult GoToError::goToPreviousError(int currentLine, int currentColumn, bool includeWarnings)
{
    NavigationResult result;
    if (m_currentFile.isEmpty()) {
        return result;
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return result;
    }

    auto filtered = filterBySeverity(it->diagnostics, true, includeWarnings, false, false);
    if (filtered.isEmpty()) {
        return result;
    }

    // Find previous diagnostic before current position
    int prevIndex = -1;
    for (int i = filtered.size() - 1; i >= 0; --i) {
        const auto& diag = filtered[i];
        if (diag.line < currentLine || 
            (diag.line == currentLine && diag.column < currentColumn)) {
            prevIndex = i;
            break;
        }
    }

    // If not found, wrap around to last
    if (prevIndex == -1) {
        prevIndex = filtered.size() - 1;
    }

    if (prevIndex >= 0 && prevIndex < filtered.size()) {
        result.found = true;
        result.diagnostic = filtered[prevIndex];
        result.index = prevIndex;
        result.totalCount = filtered.size();
        emit navigatedToDiagnostic(result.diagnostic);
        return result;
    }

    return result;
}

GoToError::NavigationResult GoToError::goToDiagnostic(int index)
{
    NavigationResult result;
    if (m_currentFile.isEmpty()) {
        return result;
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end() || index < 0 || index >= it->diagnostics.size()) {
        return result;
    }

    result.found = true;
    result.diagnostic = it->diagnostics[index];
    result.index = index;
    result.totalCount = it->diagnostics.size();
    emit navigatedToDiagnostic(result.diagnostic);
    return result;
}

QList<GoToError::Diagnostic> GoToError::getErrors() const
{
    if (m_currentFile.isEmpty()) {
        return {};
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return {};
    }

    return filterBySeverity(it->diagnostics, true, false, false, false);
}

QList<GoToError::Diagnostic> GoToError::getWarnings() const
{
    if (m_currentFile.isEmpty()) {
        return {};
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return {};
    }

    return filterBySeverity(it->diagnostics, false, true, false, false);
}

QList<GoToError::Diagnostic> GoToError::getDiagnosticsAtPosition(int line, int column) const
{
    if (m_currentFile.isEmpty()) {
        return {};
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return {};
    }

    QList<Diagnostic> result;
    for (const auto& diag : it->diagnostics) {
        if (diag.line == line && diag.column <= column && column <= diag.endColumn) {
            result.append(diag);
        }
    }
    return result;
}

bool GoToError::lineHasErrors(int line) const
{
    if (m_currentFile.isEmpty()) {
        return false;
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return false;
    }

    for (const auto& diag : it->diagnostics) {
        if (diag.line == line && diag.severity == Severity::Error) {
            return true;
        }
    }
    return false;
}

bool GoToError::lineHasWarnings(int line) const
{
    if (m_currentFile.isEmpty()) {
        return false;
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return false;
    }

    for (const auto& diag : it->diagnostics) {
        if (diag.line == line && diag.severity == Severity::Warning) {
            return true;
        }
    }
    return false;
}

QString GoToError::getLineIndicator(int line) const
{
    if (lineHasErrors(line)) {
        return "error";
    }
    if (lineHasWarnings(line)) {
        return "warning";
    }

    // Check for info or hints
    if (m_currentFile.isEmpty()) {
        return "";
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return "";
    }

    for (const auto& diag : it->diagnostics) {
        if (diag.line == line) {
            if (diag.severity == Severity::Information) {
                return "info";
            } else if (diag.severity == Severity::Hint) {
                return "hint";
            }
        }
    }

    return "";
}

QPair<int, int> GoToError::getDiagnosticCounts() const
{
    if (m_currentFile.isEmpty()) {
        return {0, 0};
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return {0, 0};
    }

    int errorCount = 0;
    int warningCount = 0;

    for (const auto& diag : it->diagnostics) {
        if (diag.severity == Severity::Error) {
            errorCount++;
        } else if (diag.severity == Severity::Warning) {
            warningCount++;
        }
    }

    return {errorCount, warningCount};
}

void GoToError::clearDiagnostics(const QString& filePath)
{
    m_diagnosticsByFile.remove(filePath);
    emit diagnosticsChanged(filePath, 0, 0);
}

void GoToError::setCurrentFile(const QString& filePath)
{
    m_currentFile = filePath;
}

QList<GoToError::Diagnostic> GoToError::filterBySeverity(const QList<Diagnostic>& diagnostics,
                                                         bool includeErrors,
                                                         bool includeWarnings,
                                                         bool includeInfo,
                                                         bool includeHints) const
{
    QList<Diagnostic> result;
    for (const auto& diag : diagnostics) {
        bool include = false;
        switch (diag.severity) {
            case Severity::Error:
                include = includeErrors;
                break;
            case Severity::Warning:
                include = includeWarnings;
                break;
            case Severity::Information:
                include = includeInfo;
                break;
            case Severity::Hint:
                include = includeHints;
                break;
        }
        if (include) {
            result.append(diag);
        }
    }
    return result;
}

int GoToError::findNearestDiagnostic(int line, int column, bool forward) const
{
    if (m_currentFile.isEmpty()) {
        return -1;
    }

    auto it = m_diagnosticsByFile.find(m_currentFile);
    if (it == m_diagnosticsByFile.end()) {
        return -1;
    }

    if (forward) {
        for (int i = 0; i < it->diagnostics.size(); ++i) {
            const auto& diag = it->diagnostics[i];
            if (diag.line > line || (diag.line == line && diag.column > column)) {
                return i;
            }
        }
        return 0;
    } else {
        for (int i = it->diagnostics.size() - 1; i >= 0; --i) {
            const auto& diag = it->diagnostics[i];
            if (diag.line < line || (diag.line == line && diag.column < column)) {
                return i;
            }
        }
        return it->diagnostics.size() - 1;
    }
}
