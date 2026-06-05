#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QJsonObject>

/**
 * @class GoToError
 * @brief Navigate to diagnostic errors and warnings in the editor
 * 
 * Ported from VS Code: /src/vs/editor/contrib/gotoError/
 * 
 * Features:
 * - Jump to next error/warning
 * - Jump to previous error/warning
 * - Show error details
 * - Quick navigation through diagnostics
 */

class GoToError : public QObject {
    Q_OBJECT

public:
    explicit GoToError(QObject* parent = nullptr);
    ~GoToError() override = default;

    // Diagnostic severity levels (matching LSP)
    enum class Severity {
        Error = 1,      // Red - compilation errors
        Warning = 2,    // Yellow - warnings
        Information = 3, // Blue - informational
        Hint = 4        // Dim - hints
    };
    Q_ENUM(Severity)

    // Diagnostic entry
    struct Diagnostic {
        QString file;
        int line{0};
        int column{0};
        int endLine{0};
        int endColumn{0};
        
        Severity severity{Severity::Error};
        QString code;
        QString message;
        QString source;
        
        // Additional context
        QJsonObject relatedInfo;
        bool isSuppressed{false};
    };

    // Navigation result
    struct NavigationResult {
        bool found{false};
        Diagnostic diagnostic;
        int index{0};           // Current position in diagnostics list
        int totalCount{0};      // Total number of diagnostics
    };

    /**
     * @brief Set diagnostics for the current document
     * @param filePath File path
     * @param diagnostics List of diagnostics
     */
    void setDiagnostics(const QString& filePath, const QList<Diagnostic>& diagnostics);

    /**
     * @brief Get diagnostics for a file
     * @param filePath File path
     * @return List of diagnostics
     */
    QList<Diagnostic> getDiagnostics(const QString& filePath) const;

    /**
     * @brief Go to next error or warning
     * @param currentLine Current line position
     * @param currentColumn Current column position
     * @param includeWarnings Include warnings in navigation
     * @return Navigation result
     */
    NavigationResult goToNextError(int currentLine, int currentColumn, bool includeWarnings = true);

    /**
     * @brief Go to previous error or warning
     * @param currentLine Current line position
     * @param currentColumn Current column position
     * @param includeWarnings Include warnings in navigation
     * @return Navigation result
     */
    NavigationResult goToPreviousError(int currentLine, int currentColumn, bool includeWarnings = true);

    /**
     * @brief Go to specific diagnostic by index
     * @param index Index in diagnostics list
     * @return Navigation result
     */
    NavigationResult goToDiagnostic(int index);

    /**
     * @brief Get all errors for current document
     * @return List of error diagnostics
     */
    QList<Diagnostic> getErrors() const;

    /**
     * @brief Get all warnings for current document
     * @return List of warning diagnostics
     */
    QList<Diagnostic> getWarnings() const;

    /**
     * @brief Get diagnostics at specific position
     * @param line Line number
     * @param column Column number
     * @return Diagnostics at position
     */
    QList<Diagnostic> getDiagnosticsAtPosition(int line, int column) const;

    /**
     * @brief Check if line has errors
     * @param line Line number
     * @return True if line has errors
     */
    bool lineHasErrors(int line) const;

    /**
     * @brief Check if line has warnings
     * @param line Line number
     * @return True if line has warnings
     */
    bool lineHasWarnings(int line) const;

    /**
     * @brief Get error/warning icon for line
     * @param line Line number
     * @return Icon type ("error", "warning", "info", "hint", "")
     */
    QString getLineIndicator(int line) const;

    /**
     * @brief Get count of errors and warnings
     * @return Pair of (error count, warning count)
     */
    QPair<int, int> getDiagnosticCounts() const;

    /**
     * @brief Clear all diagnostics for a file
     * @param filePath File path
     */
    void clearDiagnostics(const QString& filePath);

    /**
     * @brief Set current file context
     * @param filePath File path
     */
    void setCurrentFile(const QString& filePath);

signals:
    /**
     * @brief Emitted when navigation to error/warning
     */
    void navigatedToDiagnostic(const Diagnostic& diagnostic);

    /**
     * @brief Emitted when diagnostics changed
     */
    void diagnosticsChanged(const QString& filePath, int errorCount, int warningCount);

    /**
     * @brief Emitted when diagnostic details requested
     */
    void showDiagnosticDetails(const Diagnostic& diagnostic);

private:
    struct FileEntry {
        QList<Diagnostic> diagnostics;
        int currentIndex{0};
    };

    // Filter diagnostics based on severity
    QList<Diagnostic> filterBySeverity(const QList<Diagnostic>& diagnostics, 
                                       bool includeErrors = true,
                                       bool includeWarnings = true,
                                       bool includeInfo = false,
                                       bool includeHints = false) const;

    // Find nearest diagnostic
    int findNearestDiagnostic(int line, int column, bool forward = true) const;

    QString m_currentFile;
    QHash<QString, FileEntry> m_diagnosticsByFile;
};
