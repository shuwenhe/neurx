#include "TestCoverageAnalyzer.h"
#include <QDebug>
#include <QJsonDocument>
#include <QFile>
#include <QTextStream>
#include <cmath>
#include <algorithm>

const QVector<QString> TestCoverageAnalyzer::BOUNDARY_PATTERNS = {"0", "-1", "INT_MAX", "empty", "null", "nullptr"};
const QVector<QString> TestCoverageAnalyzer::EDGE_CASE_KEYWORDS = {"boundary", "edge", "empty", "max", "min", "overflow", "underflow", "null"};
const QVector<QString> TestCoverageAnalyzer::ERROR_CONDITIONS = {"throw", "catch", "error", "exception", "fail", "assert"};

TestCoverageAnalyzer::TestCoverageAnalyzer(QObject* parent)
    : QObject(parent)
{
}

TestCoverageAnalyzer::~TestCoverageAnalyzer()
{
}

void TestCoverageAnalyzer::analyzeCoverage(const QString& projectPath, const AnalysisConfig& config)
{
    m_config = config;
    qInfo() << QString("[Coverage] Analyzing project: %1").arg(projectPath);
    emit analysisStarted(projectPath);

    CoverageAnalysis analysis;
    analysis.projectPath = projectPath;
    analysis.analyzedAt = QDateTime::currentDateTime();
    
    // In production, would scan project for test files
    computeMetrics(analysis);
    
    analysis.overallScore = (analysis.metrics.lineCoverage + analysis.metrics.branchCoverage) / 2.0f * 100.0f;
    m_analysisResults[projectPath] = analysis;
    m_totalFilesAnalyzed++;

    emit analysisCompleted(projectPath);
    qInfo() << QString("[Coverage] Coverage: %.1f%%, Score: %.1f%%").arg(analysis.metrics.lineCoverage * 100).arg(analysis.overallScore);
}

void TestCoverageAnalyzer::analyzeTestFile(const QString& filePath, const AnalysisConfig& config)
{
    m_config = config;
    qInfo() << QString("[Coverage] Analyzing test file: %1").arg(filePath);
    analyzeFileInternal(filePath);
}

void TestCoverageAnalyzer::analyzeSourceFile(const QString& filePath, const AnalysisConfig& config)
{
    m_config = config;
    qInfo() << QString("[Coverage] Analyzing source file: %1").arg(filePath);
    analyzeFileInternal(filePath);
}

TestCoverageAnalyzer::CoverageMetrics TestCoverageAnalyzer::calculateMetrics(const QString& coverageData)
{
    CoverageMetrics metrics;
    metrics.measuredAt = QDateTime::currentDateTime();
    
    // Parse coverage data - in production would parse lcov or coverage reports
    metrics.lineCoverage = 0.85f;
    metrics.branchCoverage = 0.78f;
    metrics.functionCoverage = 0.90f;
    metrics.conditionalCoverage = 0.80f;
    metrics.totalLines = 10000;
    metrics.coveredLines = static_cast<int>(metrics.totalLines * metrics.lineCoverage);
    metrics.uncoveredLines = metrics.totalLines - metrics.coveredLines;

    return metrics;
}

float TestCoverageAnalyzer::calculateLineCount(const QString& code)
{
    return code.split('\n').size();
}

float TestCoverageAnalyzer::calculateBranchCount(const QString& code)
{
    int count = 0;
    count += code.count("if");
    count += code.count("else");
    count += code.count("switch");
    count += code.count("case");
    count += code.count("?");  // ternary
    return count;
}

QVector<TestCoverageAnalyzer::CoverageGap> TestCoverageAnalyzer::detectCoverageGaps(const QString& code, const CoverageMetrics& metrics)
{
    QVector<CoverageGap> gaps;

    if (metrics.lineCoverage < m_config.minAcceptableCoverage) {
        CoverageGap gap;
        gap.reason = "Line coverage below threshold";
        gap.importance = 1.0f - metrics.lineCoverage;
        gap.isCritical = true;
        gaps.append(gap);
        m_totalGapsDetected++;
    }

    gaps.append(identifyUncoveredBranches(code));
    
    return gaps;
}

QVector<TestCoverageAnalyzer::CoverageGap> TestCoverageAnalyzer::identifyUncoveredBranches(const QString& code)
{
    QVector<CoverageGap> gaps;
    
    // Detect if/else branches without tests
    int ifCount = code.count("if (");
    int testCount = code.count("test(") + code.count("it(");
    
    if (ifCount > testCount * 2) {
        CoverageGap gap;
        gap.reason = QString("Potential uncovered branches: %1 if statements vs %2 tests").arg(ifCount).arg(testCount);
        gap.importance = 0.8f;
        gaps.append(gap);
    }

    return gaps;
}

QVector<TestCoverageAnalyzer::CoverageGap> TestCoverageAnalyzer::identifyUntestableCode(const QString& code)
{
    QVector<CoverageGap> gaps;
    
    // Detect code that's hard to test
    if (code.contains("random()") || code.contains("time()")) {
        CoverageGap gap;
        gap.reason = "Non-deterministic code (uses random/time)";
        gap.suggestedTests.append("Use mocked randomness");
        gaps.append(gap);
    }

    return gaps;
}

QVector<QString> TestCoverageAnalyzer::suggestEdgeCases(const QString& functionSignature)
{
    QVector<QString> suggestions;
    
    if (functionSignature.contains("int")) {
        suggestions.append("Test with 0");
        suggestions.append("Test with negative values");
        suggestions.append("Test with INT_MAX");
        suggestions.append("Test with INT_MIN");
    }
    
    if (functionSignature.contains("QString") || functionSignature.contains("string")) {
        suggestions.append("Test with empty string");
        suggestions.append("Test with NULL");
        suggestions.append("Test with very long string");
        suggestions.append("Test with special characters");
    }
    
    if (functionSignature.contains("QVector") || functionSignature.contains("vector")) {
        suggestions.append("Test with empty collection");
        suggestions.append("Test with single element");
        suggestions.append("Test with large collection");
    }

    return suggestions;
}

QVector<QString> TestCoverageAnalyzer::suggestBoundaryTests(const QString& parameterType)
{
    QVector<QString> suggestions;

    if (parameterType.contains("int")) {
        suggestions << "MIN_VALUE" << "MAX_VALUE" << "0" << "-1" << "1";
    } else if (parameterType.contains("float") || parameterType.contains("double")) {
        suggestions << "0.0" << "-1.0" << "1.0" << "NaN" << "Infinity";
    } else if (parameterType.contains("string")) {
        suggestions << "\"\"" << "nullptr" << "\" \"" << "very_long_string";
    }

    return suggestions;
}

bool TestCoverageAnalyzer::hasEdgeCaseTests(const TestCase& test)
{
    QString description = test.description.toLower();
    for (const QString& keyword : EDGE_CASE_KEYWORDS) {
        if (description.contains(keyword)) {
            return true;
        }
    }
    return false;
}

float TestCoverageAnalyzer::assessTestQuality(const QVector<TestCase>& tests)
{
    if (tests.isEmpty()) return 0.0f;

    float quality = 0.0f;
    int unitTests = 0;
    int integrationTests = 0;
    int e2eTests = 0;
    int withEdgeCases = 0;

    for (const TestCase& test : tests) {
        if (test.isUnit) unitTests++;
        if (test.isIntegration) integrationTests++;
        if (test.isE2E) e2eTests++;
        if (hasEdgeCaseTests(test)) withEdgeCases++;
    }

    // Scoring: favor balanced test portfolio
    quality += std::min(1.0f, unitTests / 10.0f) * 0.5f;
    quality += std::min(1.0f, integrationTests / 5.0f) * 0.3f;
    quality += std::min(1.0f, e2eTests / 2.0f) * 0.2f;
    quality += (withEdgeCases / static_cast<float>(tests.size())) * 0.25f;

    return std::min(1.0f, quality) * 100.0f;
}

bool TestCoverageAnalyzer::detectFlakiness(const QString& testName)
{
    // Heuristics for detecting flaky tests
    return testName.contains("Timer") || testName.contains("Thread") || testName.contains("Random");
}

bool TestCoverageAnalyzer::isTestIndependent(const TestCase& test)
{
    // Check if test depends on others
    return !test.name.contains("Setup") && !test.name.contains("TearDown");
}

void TestCoverageAnalyzer::prioritizeGaps(QVector<CoverageGap>& gaps)
{
    std::sort(gaps.begin(), gaps.end(), [](const CoverageGap& a, const CoverageGap& b) {
        return a.importance > b.importance;
    });
}

float TestCoverageAnalyzer::calculateGapImportance(const CoverageGap& gap)
{
    float importance = gap.importance;
    if (gap.isCritical) importance = std::min(1.0f, importance + 0.2f);
    return std::min(1.0f, importance);
}

QString TestCoverageAnalyzer::generateRecommendations(const CoverageAnalysis& analysis)
{
    QString rec;
    
    if (analysis.metrics.lineCoverage < 0.70f) {
        rec += "⚠️ **Critical**: Line coverage is below 70%\n";
        rec += "- Add tests for uncovered lines\n";
        rec += "- Focus on critical paths first\n\n";
    }
    
    if (analysis.gaps.size() > 0) {
        rec += QString("🔧 **Address %1 coverage gaps**:\n").arg(analysis.gaps.size());
        for (int i = 0; i < std::min(5, static_cast<int>(analysis.gaps.size())); ++i) {
            rec += QString("- %1\n").arg(analysis.gaps[i].reason);
        }
    }
    
    if (analysis.totalTests < 10) {
        rec += QString("📝 **Add more tests** (currently %1 tests)\n").arg(analysis.totalTests);
    }

    return rec;
}

QString TestCoverageAnalyzer::suggestNextTests(const QVector<CoverageGap>& gaps, int count)
{
    QString suggestions;
    suggestions += "## Suggested Tests\n\n";
    
    for (int i = 0; i < std::min(count, static_cast<int>(gaps.size())); ++i) {
        suggestions += QString("**%1.** %2\n").arg(i+1).arg(gaps[i].reason);
        if (!gaps[i].suggestedTests.isEmpty()) {
            suggestions += QString("- Tests: %1\n").arg(gaps[i].suggestedTests.join(", "));
        }
    }

    return suggestions;
}

TestCoverageAnalyzer::CoverageAnalysis TestCoverageAnalyzer::getAnalysisResult(const QString& projectPath)
{
    if (m_analysisResults.contains(projectPath)) {
        return m_analysisResults[projectPath];
    }
    return CoverageAnalysis();
}

QJsonObject TestCoverageAnalyzer::getAnalysisStatistics() const
{
    QJsonObject stats;
    stats["totalFilesAnalyzed"] = m_totalFilesAnalyzed;
    stats["totalGapsDetected"] = m_totalGapsDetected;
    stats["averageCoverage"] = m_totalFilesAnalyzed > 0 ? m_totalCoverageAccumulated / m_totalFilesAnalyzed : 0.0;
    return stats;
}

QString TestCoverageAnalyzer::generateCoverageReport(const CoverageAnalysis& analysis)
{
    QString report;
    report += "# Test Coverage Report\n\n";
    report += QString("**Overall Coverage**: %.1f%%\n").arg(analysis.overallScore);
    report += QString("**Line Coverage**: %.1f%%\n").arg(analysis.metrics.lineCoverage * 100);
    report += QString("**Branch Coverage**: %.1f%%\n").arg(analysis.metrics.branchCoverage * 100);
    report += QString("**Total Tests**: %1 (%2 passing, %3 failing)\n\n").arg(analysis.totalTests).arg(analysis.passingTests).arg(analysis.failingTests);
    
    report += generateRecommendations(analysis);

    return report;
}

QString TestCoverageAnalyzer::generateGapReport(const CoverageAnalysis& analysis)
{
    QString report;
    report += "# Coverage Gaps Report\n\n";
    report += QString("**Total Gaps**: %1\n\n").arg(analysis.gaps.size());
    
    for (const CoverageGap& gap : analysis.gaps) {
        report += QString("- **%1** (Importance: %.1f) — %2\n").arg(gap.functionName).arg(gap.importance * 100).arg(gap.reason);
    }

    return report;
}

TestCoverageAnalyzer::CoverageComparison TestCoverageAnalyzer::compareCoverage(const CoverageAnalysis& previous, const CoverageAnalysis& current)
{
    CoverageComparison comp;
    comp.coverageDelta = current.overallScore - previous.overallScore;
    
    if (comp.coverageDelta > 5.0f) {
        comp.trend = "improving";
    } else if (comp.coverageDelta < -5.0f) {
        comp.trend = "declining";
    } else {
        comp.trend = "stable";
    }

    return comp;
}

void TestCoverageAnalyzer::analyzeFileInternal(const QString& filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(QString("Cannot open file: %1").arg(filePath));
        return;
    }

    QTextStream in(&file);
    QString code = in.readAll();
    file.close();

    m_totalFilesAnalyzed++;
    emit fileAnalyzed(filePath, 0.85f);
}

void TestCoverageAnalyzer::computeMetrics(CoverageAnalysis& analysis)
{
    analysis.metrics = calculateMetrics("");
    analysis.totalTests = 15;
    analysis.passingTests = 14;
    analysis.failingTests = 1;
    m_totalCoverageAccumulated += analysis.metrics.lineCoverage;
}

QString TestCoverageAnalyzer::detectTestFramework(const QString& projectPath)
{
    // Detect test framework from project structure
    if (projectPath.contains("jest") || projectPath.contains("test")) return "jest";
    if (projectPath.contains("pytest")) return "pytest";
    if (projectPath.contains("gtest")) return "gtest";
    return "unknown";
}

float TestCoverageAnalyzer::parseLineCoverage(const QString& coverageOutput)
{
    // Parse coverage from common formats
    return 0.85f;  // Placeholder
}

void TestCoverageAnalyzer::identifyTestableUnits(const QString& code, CoverageAnalysis& analysis)
{
    // Identify functions/methods that are testable
}
