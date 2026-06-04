#include "services/DiagnosticsService.h"
#include <QDebug>

DiagnosticsService* g_diagnosticsService = nullptr;

QVariantMap Diagnostic::toMap() const
{
    return QVariantMap{
        {"filePath", filePath},
        {"line", line},
        {"column", column},
        {"endLine", endLine},
        {"endColumn", endColumn},
        {"severity", severity},
        {"message", message},
        {"source", source},
        {"code", code}
    };
}

DiagnosticsService* DiagnosticsService::instance()
{
    if (!g_diagnosticsService) {
        g_diagnosticsService = new DiagnosticsService();
    }
    return g_diagnosticsService;
}

DiagnosticsService::DiagnosticsService()
{
}

void DiagnosticsService::addDiagnostic(const Diagnostic& diagnostic)
{
    m_diagnostics.append(diagnostic);
    emit diagnosticsAdded(1);
    emit diagnosticsChanged();
}

void DiagnosticsService::addDiagnostics(const QList<Diagnostic>& diagnostics)
{
    m_diagnostics.append(diagnostics);
    emit diagnosticsAdded(diagnostics.size());
    emit diagnosticsChanged();
}

void DiagnosticsService::clearDiagnostics()
{
    m_diagnostics.clear();
    emit diagnosticsCleared();
    emit diagnosticsChanged();
}

void DiagnosticsService::clearDiagnostics(const QString& filePath)
{
    m_diagnostics.removeIf([&](const Diagnostic& d) { return d.filePath == filePath; });
    emit diagnosticsChanged();
}

void DiagnosticsService::removeDiagnostic(const Diagnostic& diagnostic)
{
    m_diagnostics.removeIf([&](const Diagnostic& d) {
        return d.filePath == diagnostic.filePath && d.line == diagnostic.line;
    });
    emit diagnosticsChanged();
}

QList<Diagnostic> DiagnosticsService::getDiagnostics() const
{
    return m_diagnostics;
}

QList<Diagnostic> DiagnosticsService::getDiagnostics(const QString& filePath) const
{
    QList<Diagnostic> result;
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.filePath == filePath) {
            result.append(diagnostic);
        }
    }
    return result;
}

QList<Diagnostic> DiagnosticsService::getDiagnostics(Diagnostic::Severity severity) const
{
    QList<Diagnostic> result;
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.severity == severity) {
            result.append(diagnostic);
        }
    }
    return result;
}

int DiagnosticsService::errorCount() const
{
    int count = 0;
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.severity == Diagnostic::Error) {
            count++;
        }
    }
    return count;
}

int DiagnosticsService::warningCount() const
{
    int count = 0;
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.severity == Diagnostic::Warning) {
            count++;
        }
    }
    return count;
}

Diagnostic DiagnosticsService::getDiagnosticAtLine(int line) const
{
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.line == line) {
            return diagnostic;
        }
    }
    return {};
}

Diagnostic DiagnosticsService::getNextDiagnostic() const
{
    if (!m_diagnostics.isEmpty()) {
        return m_diagnostics.first();
    }
    return {};
}

Diagnostic DiagnosticsService::getPreviousDiagnostic() const
{
    if (!m_diagnostics.isEmpty()) {
        return m_diagnostics.last();
    }
    return {};
}
