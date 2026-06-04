#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QVariantMap>

/**
 * @class DiagnosticsService
 * @brief Manages error and warning diagnostics
 * 
 * Features:
 * - Collect diagnostics from multiple sources
 * - Display errors and warnings
 * - Navigate to problem location
 * - Filter by severity
 */

struct Diagnostic {
    enum Severity { Error, Warning, Information, Hint };
    
    QString filePath;
    int line;
    int column;
    int endLine;
    int endColumn;
    Severity severity;
    QString message;
    QString source;  // e.g., "clang", "eslint"
    QString code;    // Error/warning code
    
    QVariantMap toMap() const;
};

class DiagnosticsService : public QObject {
    Q_OBJECT

public:
    static DiagnosticsService* instance();
    
    // Diagnostic management
    void addDiagnostic(const Diagnostic& diagnostic);
    void addDiagnostics(const QList<Diagnostic>& diagnostics);
    void clearDiagnostics();
    void clearDiagnostics(const QString& filePath);
    void removeDiagnostic(const Diagnostic& diagnostic);
    
    // Query
    QList<Diagnostic> getDiagnostics() const;
    QList<Diagnostic> getDiagnostics(const QString& filePath) const;
    QList<Diagnostic> getDiagnostics(Diagnostic::Severity severity) const;
    int errorCount() const;
    int warningCount() const;
    
    // Navigation
    Diagnostic getDiagnosticAtLine(int line) const;
    Diagnostic getNextDiagnostic() const;
    Diagnostic getPreviousDiagnostic() const;

signals:
    void diagnosticsChanged();
    void diagnosticsAdded(int count);
    void diagnosticsCleared();
    void diagnosticNavigated(int line, int column);

private:
    DiagnosticsService();
    ~DiagnosticsService() override = default;
    
    Q_DISABLE_COPY_MOVE(DiagnosticsService)
    
    QList<Diagnostic> m_diagnostics;
};
