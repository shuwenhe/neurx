#include "ErrorHandlingAnalyzer.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>

const QVector<QString> ErrorHandlingAnalyzer::LOG_FUNCTIONS = {
    "qDebug", "qWarning", "qCritical", "qInfo", "console.log", "console.error", "logger.log"
};

ErrorHandlingAnalyzer::ErrorHandlingAnalyzer(QObject* parent)
    : QObject(parent)
{
}

ErrorHandlingAnalyzer::~ErrorHandlingAnalyzer()
{
}

void ErrorHandlingAnalyzer::analyzeErrorHandling(const QString& code, const QString& filePath, const AnalysisConfig& config)
{
    qInfo() << QString("[ErrorHandling] Analyzing error handling in: %1").arg(filePath);
    emit analysisStarted(filePath);

    QVector<ErrorHandlingFinding> allFindings;
    
    if (config.checkSilentFailures) {
        allFindings.append(findSilentFailures(code));
    }
    if (config.checkLogging) {
        allFindings.append(findMissingLogs(code));
    }
    if (config.checkRethrow) {
        allFindings.append(findSwallowedExceptions(code));
    }
    if (config.checkFallbacks) {
        allFindings.append(findMissingFallbacks(code));
    }

    ErrorAnalysisResult result;
    result.filePath = filePath;
    result.totalErrorBlocks = code.count("catch") + code.count("try");
    result.findings = allFindings;
    
    for (const ErrorHandlingFinding& f : allFindings) {
        if (f.issueType == SilentFailure) result.silentFailures++;
        if (f.issueType == NoLogging) result.missingLogs++;
    }

    result.properlyHandled = result.totalErrorBlocks - allFindings.size();
    result.overallScore = result.totalErrorBlocks > 0 ? static_cast<float>(result.properlyHandled) / result.totalErrorBlocks : 1.0f;
    result.recommendation = generateRecommendations(result);

    m_results[filePath] = result;
    m_totalAnalyzed++;
    m_totalIssuesFound += allFindings.size();

    for (const ErrorHandlingFinding& f : allFindings) {
        emit findingDetected(f);
    }

    emit analysisCompleted(filePath);
}

void ErrorHandlingAnalyzer::analyzeFile(const QString& filePath, const AnalysisConfig& config)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(QString("Cannot open file: %1").arg(filePath));
        return;
    }

    QTextStream in(&file);
    QString code = in.readAll();
    file.close();

    analyzeErrorHandling(code, filePath, config);
}

QVector<ErrorHandlingAnalyzer::ErrorHandlingFinding> ErrorHandlingAnalyzer::findSilentFailures(const QString& code)
{
    QVector<ErrorHandlingFinding> findings;
    
    // Look for empty catch blocks
    if (code.contains("catch") && code.contains("{}")) {
        ErrorHandlingFinding finding;
        finding.issueType = SilentFailure;
        finding.severity = 0.95f;
        finding.message = "Empty catch block - silent failure";
        finding.suggestion = "Log the exception or implement proper error handling";
        findings.append(finding);
    }

    return findings;
}

QVector<ErrorHandlingAnalyzer::ErrorHandlingFinding> ErrorHandlingAnalyzer::findMissingLogs(const QString& code)
{
    QVector<ErrorHandlingFinding> findings;

    if (code.contains("catch") && !code.contains("qDebug") && !code.contains("logger")) {
        ErrorHandlingFinding finding;
        finding.issueType = NoLogging;
        finding.severity = 0.75f;
        finding.message = "Catch block without logging";
        finding.suggestion = "Add logging to understand why exceptions occur";
        findings.append(finding);
    }

    return findings;
}

QVector<ErrorHandlingAnalyzer::ErrorHandlingFinding> ErrorHandlingAnalyzer::findSwallowedExceptions(const QString& code)
{
    QVector<ErrorHandlingFinding> findings;

    if (code.contains("catch") && code.contains("continue")) {
        ErrorHandlingFinding finding;
        finding.issueType = SwallowedException;
        finding.severity = 0.85f;
        finding.message = "Exception swallowed with continue";
        finding.suggestion = "Consider re-throwing or propagating the error";
        findings.append(finding);
    }

    return findings;
}

QVector<ErrorHandlingAnalyzer::ErrorHandlingFinding> ErrorHandlingAnalyzer::findIncompleteRecovery(const QString& code)
{
    QVector<ErrorHandlingFinding> findings;
    return findings;
}

QVector<ErrorHandlingAnalyzer::ErrorHandlingFinding> ErrorHandlingAnalyzer::findMissingFallbacks(const QString& code)
{
    QVector<ErrorHandlingFinding> findings;

    if (code.contains("throw") && !code.contains("catch")) {
        ErrorHandlingFinding finding;
        finding.issueType = NoFallback;
        finding.severity = 0.70f;
        finding.message = "Exception thrown without fallback";
        finding.suggestion = "Add fallback behavior or ensure caller handles it";
        findings.append(finding);
    }

    return findings;
}

bool ErrorHandlingAnalyzer::isSilentCatch(const QString& catchBlock)
{
    return catchBlock.contains("{}") || (catchBlock.contains("{") && catchBlock.count('}') > 0 && catchBlock.length() < 30);
}

bool ErrorHandlingAnalyzer::hasLogging(const QString& catchBlock)
{
    for (const QString& logFunc : LOG_FUNCTIONS) {
        if (catchBlock.contains(logFunc)) {
            return true;
        }
    }
    return false;
}

bool ErrorHandlingAnalyzer::hasRethrow(const QString& catchBlock)
{
    return catchBlock.contains("throw") || catchBlock.contains("rethrow");
}

bool ErrorHandlingAnalyzer::hasFallback(const QString& catchBlock)
{
    return catchBlock.contains("return") || catchBlock.contains("default") || catchBlock.contains("fallback");
}

ErrorHandlingAnalyzer::ErrorAnalysisResult ErrorHandlingAnalyzer::getAnalysisResult(const QString& filePath)
{
    if (m_results.contains(filePath)) {
        return m_results[filePath];
    }
    return ErrorAnalysisResult();
}

QJsonObject ErrorHandlingAnalyzer::getStatistics() const
{
    QJsonObject stats;
    stats["totalAnalyzed"] = m_totalAnalyzed;
    stats["totalIssuesFound"] = m_totalIssuesFound;
    return stats;
}

QString ErrorHandlingAnalyzer::generateRecommendations(const ErrorAnalysisResult& result)
{
    QString rec;
    
    if (result.overallScore < 0.70f) {
        rec += "⚠️ **Poor error handling** (Score: ";
        rec += QString::number(result.overallScore * 100, 'f', 1);
        rec += "%)\n";
        rec += "- Add logging to all catch blocks\n";
        rec += "- Implement proper recovery or re-throw\n";
    }
    
    if (result.silentFailures > 0) {
        rec += QString("🔇 **Remove %1 silent failure(s)**\n").arg(result.silentFailures);
    }
    
    if (result.missingLogs > 0) {
        rec += QString("📝 **Add logging to %1 catch block(s)**\n").arg(result.missingLogs);
    }

    return rec;
}

QString ErrorHandlingAnalyzer::suggestImprovements(const ErrorHandlingFinding& finding)
{
    return finding.suggestion;
}
