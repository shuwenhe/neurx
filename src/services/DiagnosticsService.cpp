#include "services/DiagnosticsService.h"
#include <QDebug>

DiagnosticsService* g_diagnosticsService = nullptr;

QVariantMap DiagnosticItem::toMap() const
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

void DiagnosticsService::addDiagnostic(const DiagnosticItem& diagnostic)
{
    m_diagnostics.append(diagnostic);
    emit diagnosticsAdded(1);
    emit diagnosticsChanged();
}

void DiagnosticsService::addDiagnostics(const QList<DiagnosticItem>& diagnostics)
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
    m_diagnostics.removeIf([&](const DiagnosticItem& d) { return d.filePath == filePath; });
    emit diagnosticsChanged();
}

void DiagnosticsService::removeDiagnostic(const DiagnosticItem& diagnostic)
{
    m_diagnostics.removeIf([&](const DiagnosticItem& d) {
        return d.filePath == diagnostic.filePath && d.line == diagnostic.line;
    });
    emit diagnosticsChanged();
}

QList<DiagnosticItem> DiagnosticsService::getDiagnostics() const
{
    return m_diagnostics;
}

QList<DiagnosticItem> DiagnosticsService::getDiagnostics(const QString& filePath) const
{
    QList<DiagnosticItem> result;
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.filePath == filePath) {
            result.append(diagnostic);
        }
    }
    return result;
}

QList<DiagnosticItem> DiagnosticsService::getDiagnostics(DiagnosticItem::Severity severity) const
{
    QList<DiagnosticItem> result;
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
        if (diagnostic.severity == DiagnosticItem::Error) {
            count++;
        }
    }
    return count;
}

int DiagnosticsService::warningCount() const
{
    int count = 0;
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.severity == DiagnosticItem::Warning) {
            count++;
        }
    }
    return count;
}

DiagnosticItem DiagnosticsService::getDiagnosticAtLine(int line) const
{
    for (const auto& diagnostic : m_diagnostics) {
        if (diagnostic.line == line) {
            return diagnostic;
        }
    }
    return {};
}

DiagnosticItem DiagnosticsService::getNextDiagnostic() const
{
    if (!m_diagnostics.isEmpty()) {
        return m_diagnostics.first();
    }
    return {};
}

DiagnosticItem DiagnosticsService::getPreviousDiagnostic() const
{
    if (!m_diagnostics.isEmpty()) {
        return m_diagnostics.last();
    }
    return {};
}
