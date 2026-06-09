#include "WorkspaceHealthAnalyzer.h"
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QRegularExpression>
#include <algorithm>

namespace {

QString metricName(WorkspaceHealthAnalyzer::HealthMetric metric)
{
    switch (metric) {
        case WorkspaceHealthAnalyzer::CodeQuality: return QStringLiteral("Code Quality");
        case WorkspaceHealthAnalyzer::TestCoverage: return QStringLiteral("Test Coverage");
        case WorkspaceHealthAnalyzer::Documentation: return QStringLiteral("Documentation");
        case WorkspaceHealthAnalyzer::Dependencies: return QStringLiteral("Dependencies");
        case WorkspaceHealthAnalyzer::Performance: return QStringLiteral("Performance");
        case WorkspaceHealthAnalyzer::Security: return QStringLiteral("Security");
        case WorkspaceHealthAnalyzer::Maintainability: return QStringLiteral("Maintainability");
    }
    return QStringLiteral("Unknown");
}

QString healthName(WorkspaceHealthAnalyzer::HealthScore score)
{
    switch (score) {
        case WorkspaceHealthAnalyzer::Critical: return QStringLiteral("Critical");
        case WorkspaceHealthAnalyzer::Poor: return QStringLiteral("Poor");
        case WorkspaceHealthAnalyzer::Fair: return QStringLiteral("Fair");
        case WorkspaceHealthAnalyzer::Good: return QStringLiteral("Good");
        case WorkspaceHealthAnalyzer::Excellent: return QStringLiteral("Excellent");
    }
    return QStringLiteral("Unknown");
}

QStringList sourceFilePatterns()
{
    return {"*.cpp", "*.cxx", "*.cc", "*.h", "*.hpp", "*.qml", "*.js", "*.ts"};
}

QStringList testFilePatterns()
{
    return {"*test*.cpp", "*test*.h", "*tests*.cpp", "*tests*.h", "*spec*.cpp", "*spec*.h", "*test*.qml", "*spec*.qml"};
}

bool looksLikeFunctionStart(const QString &line)
{
    static const QRegularExpression re(
        QStringLiteral(R"(^\s*(?:[A-Za-z_][\w:<>,\s\*&]*\s+)?[A-Za-z_][\w:]*\s*\([^;]*\)\s*(?:const\s*)?(?:override\s*)?(?:final\s*)?\{?\s*$)")
    );
    return re.match(line).hasMatch();
}

}

WorkspaceHealthAnalyzer::WorkspaceHealthAnalyzer(QObject* parent)
    : QObject(parent), m_detailedAnalysis(false)
{
    // Initialize default thresholds
    m_qualityThresholds[CodeQuality] = 80;
    m_qualityThresholds[TestCoverage] = 75;
    m_qualityThresholds[Documentation] = 70;
    m_qualityThresholds[Dependencies] = 85;
    m_qualityThresholds[Performance] = 80;
    m_qualityThresholds[Security] = 90;
    m_qualityThresholds[Maintainability] = 75;
}

WorkspaceHealthAnalyzer::~WorkspaceHealthAnalyzer()
{
}

WorkspaceHealthAnalyzer::HealthReport WorkspaceHealthAnalyzer::analyzeWorkspace(const QString& workspacePath)
{
    emit analysisStarted(workspacePath);
    
    HealthReport report;
    
    // Analyze each metric
    int codeQualityScore = calculateCodeQualityScore(workspacePath);
    int testCoverageScore = calculateTestCoverageScore(workspacePath);
    int docScore = calculateDocumentationScore(workspacePath);
    int maintainScore = calculateMaintainabilityScore(workspacePath);
    int dependencyScore = 85;
    int performanceScore = qMax(0, 100 - detectPerformanceIssues(workspacePath).size() * 5);
    int securityScore = qMax(0, 100 - detectSecurityIssues(workspacePath).size() * 8);
    
    report.scores[CodeQuality] = codeQualityScore;
    report.scores[TestCoverage] = testCoverageScore;
    report.scores[Documentation] = docScore;
    report.scores[Dependencies] = dependencyScore;
    report.scores[Performance] = performanceScore;
    report.scores[Security] = securityScore;
    report.scores[Maintainability] = maintainScore;
    
    emit metricAnalyzed(CodeQuality, codeQualityScore);
    emit metricAnalyzed(TestCoverage, testCoverageScore);
    emit metricAnalyzed(Documentation, docScore);
    emit metricAnalyzed(Dependencies, dependencyScore);
    emit metricAnalyzed(Performance, performanceScore);
    emit metricAnalyzed(Security, securityScore);
    emit metricAnalyzed(Maintainability, maintainScore);
    
    // Detect issues
    report.issues = detectCodeSmells(workspacePath);
    report.issues += detectDocumentationGaps(workspacePath);
    report.issues += detectSecurityIssues(workspacePath);
    report.issues += detectPerformanceIssues(workspacePath);
    
    for (const QString& issue : report.issues) {
        emit issueDetected(issue, "warning");
    }
    
    // Calculate overall score
    int totalScore = (codeQualityScore + testCoverageScore + docScore + dependencyScore
        + performanceScore + securityScore + maintainScore) / 7;
    report.overallScore = totalScore;
    
    if (totalScore >= 90) {
        report.overallHealth = Excellent;
    } else if (totalScore >= 80) {
        report.overallHealth = Good;
    } else if (totalScore >= 70) {
        report.overallHealth = Fair;
    } else if (totalScore >= 50) {
        report.overallHealth = Poor;
    } else {
        report.overallHealth = Critical;
    }
    
    // Generate recommendations
    report.improvements = generateRecommendations(report);
    
    emit analysisFinished(report);
    return report;
}

WorkspaceHealthAnalyzer::HealthReport WorkspaceHealthAnalyzer::analyzeProject(const QString& projectPath)
{
    return analyzeWorkspace(projectPath);
}

void WorkspaceHealthAnalyzer::analyzeCodeQuality(const QString& sourcePath)
{
    int score = calculateCodeQualityScore(sourcePath);
    emit metricAnalyzed(CodeQuality, score);
}

void WorkspaceHealthAnalyzer::analyzeTestCoverage(const QString& projectPath)
{
    int score = calculateTestCoverageScore(projectPath);
    emit metricAnalyzed(TestCoverage, score);
}

void WorkspaceHealthAnalyzer::analyzeDocumentation(const QString& projectPath)
{
    int score = calculateDocumentationScore(projectPath);
    emit metricAnalyzed(Documentation, score);
}

void WorkspaceHealthAnalyzer::analyzeDependencies(const QString& projectPath)
{
    const QStringList dependencyMarkers = {
        QStringLiteral("package.json"),
        QStringLiteral("requirements.txt"),
        QStringLiteral("pyproject.toml"),
        QStringLiteral("Cargo.toml"),
        QStringLiteral("go.mod"),
        QStringLiteral("CMakeLists.txt")
    };

    int found = 0;
    for (const QString &marker : dependencyMarkers) {
        if (QFile::exists(projectPath + QLatin1Char('/') + marker)) {
            found++;
        }
    }

    int score = qMin(100, 60 + found * 8);
    emit metricAnalyzed(Dependencies, score);
}

int WorkspaceHealthAnalyzer::calculateCodeQualityScore(const QString& sourcePath)
{
    CodeQualityMetrics metrics = analyzeCodeMetrics(sourcePath);
    
    int score = 100;
    
    // Penalize for high complexity
    if (metrics.cyclomaticComplexity > 10) {
        score -= (metrics.cyclomaticComplexity - 10) * 2;
    }
    
    // Penalize for long functions
    if (metrics.linesPerFunction > 100) {
        score -= (metrics.linesPerFunction - 100) / 10;
    }
    
    // Penalize for duplicates
    score -= qMin(20, metrics.duplicateLines / 100);
    
    // Reward for good comments
    if (metrics.commentRatio > 20) {
        score += qMin(10, metrics.commentRatio - 20);
    }
    
    // Penalize for warnings
    score -= qMin(20, metrics.warningCount * 2);
    
    return qMax(0, qMin(100, score));
}

int WorkspaceHealthAnalyzer::calculateTestCoverageScore(const QString& projectPath)
{
    TestMetrics metrics = analyzeTests(projectPath);
    
    if (metrics.totalTests == 0) {
        return 0;
    }
    
    int score = (metrics.passingTests * 100) / metrics.totalTests;
    
    // Apply coverage percentage
    score = (score * 80 + (int)metrics.coveragePercentage * 20) / 100;
    
    return qMax(0, qMin(100, score));
}

int WorkspaceHealthAnalyzer::calculateDocumentationScore(const QString& projectPath)
{
    int score = 50;  // Start at baseline
    
    // Check for README
    if (QFile::exists(projectPath + "/README.md")) {
        score += 15;
    }
    
    // Check for API documentation
    if (QFile::exists(projectPath + "/docs") || 
        QFile::exists(projectPath + "/DOCS.md")) {
        score += 15;
    }
    
    // Check for CHANGELOG
    if (QFile::exists(projectPath + "/CHANGELOG.md")) {
        score += 10;
    }
    
    // Check for contributing guide
    if (QFile::exists(projectPath + "/CONTRIBUTING.md")) {
        score += 10;
    }
    
    return qMax(0, qMin(100, score));
}

int WorkspaceHealthAnalyzer::calculateMaintainabilityScore(const QString& sourcePath)
{
    int score = 70;
    
    int codeSmells = detectCodeSmells(sourcePath).count();
    score -= qMin(25, codeSmells * 2);
    
    return qMax(0, qMin(100, score));
}

QStringList WorkspaceHealthAnalyzer::detectCodeSmells(const QString& sourcePath)
{
    QStringList smells;
    
    // Scan for code smells in source files
    QDirIterator iterator(sourcePath, {"*.cpp", "*.h", "*.ts", "*.js"}, 
                         QDir::Files, QDirIterator::Subdirectories);
    
    while (iterator.hasNext()) {
        QString filePath = iterator.next();
        
        QFile file(filePath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = file.readAll();
            file.close();
            
            const QStringList lines = content.split('\n');
            int currentFunctionLines = 0;
            bool inFunction = false;
            for (const QString &line : lines) {
                if (looksLikeFunctionStart(line)) {
                    inFunction = true;
                    currentFunctionLines = 1;
                    continue;
                }

                if (inFunction) {
                    currentFunctionLines++;
                    if (line.contains('}')) {
                        if (currentFunctionLines > 80) {
                            smells << filePath + ": Long method detected";
                        }
                        inFunction = false;
                    }
                }
            }
            
            // Check for deep nesting
            int maxNesting = 0;
            int currentNesting = 0;
            for (const QChar& c : content) {
                if (c == '{') {
                    currentNesting++;
                    maxNesting = qMax(maxNesting, currentNesting);
                } else if (c == '}') {
                    currentNesting--;
                }
            }
            if (maxNesting > 5) {
                smells << filePath + ": Deep nesting detected (depth: " + QString::number(maxNesting) + ")";
            }
            
            // Check for TODO/FIXME comments
            if (content.contains("TODO") || content.contains("FIXME")) {
                smells << filePath + ": TODO/FIXME comments found";
            }

            if (content.contains("goto ")) {
                smells << filePath + ": goto statement detected";
            }
        }
    }
    
    return smells;
}

QStringList WorkspaceHealthAnalyzer::detectDocumentationGaps(const QString& projectPath)
{
    QStringList gaps;
    
    if (!QFile::exists(projectPath + "/README.md")) {
        gaps << "Missing README.md";
    }
    
    if (!QFile::exists(projectPath + "/CONTRIBUTING.md")) {
        gaps << "Missing CONTRIBUTING.md";
    }
    
    if (!QFile::exists(projectPath + "/docs")) {
        gaps << "Missing docs directory";
    }
    
    return gaps;
}

QStringList WorkspaceHealthAnalyzer::detectSecurityIssues(const QString& sourcePath)
{
    QStringList issues;
    
    QDirIterator iterator(sourcePath, {"*.cpp", "*.h", "*.ts", "*.js"}, 
                         QDir::Files, QDirIterator::Subdirectories);
    
    while (iterator.hasNext()) {
        QString filePath = iterator.next();
        
        QFile file(filePath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = file.readAll();
            file.close();
            
            // Check for common security issues
            if (content.contains("eval(") || content.contains("exec(")) {
                issues << filePath + ": Potential code injection vulnerability (eval/exec)";
            }
            
            if (content.contains("system(") && !content.contains("sandboxed")) {
                issues << filePath + ": Potential command injection (system call)";
            }
            
            if (content.contains("hardcoded password") || 
                content.contains("API_KEY = \"")) {
                issues << filePath + ": Potential hardcoded credentials";
            }
        }
    }
    
    return issues;
}

QStringList WorkspaceHealthAnalyzer::detectPerformanceIssues(const QString& sourcePath)
{
    QStringList issues;
    
    QDirIterator iterator(sourcePath, {"*.cpp", "*.h"}, 
                         QDir::Files, QDirIterator::Subdirectories);
    
    while (iterator.hasNext()) {
        QString filePath = iterator.next();
        
        QFile file(filePath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = file.readAll();
            file.close();
            
            // Check for performance anti-patterns
            if (content.contains("QString::number") && content.count("QString::number") > 10) {
                issues << filePath + ": Excessive string conversions";
            }
            
            if (content.contains("new ") && !content.contains("delete")) {
                issues << filePath + ": Potential memory leak (new without delete)";
            }
        }
    }
    
    return issues;
}

QStringList WorkspaceHealthAnalyzer::generateRecommendations(const HealthReport& report)
{
    QStringList recommendations;
    
    for (auto it = report.scores.begin(); it != report.scores.end(); ++it) {
        HealthMetric metric = it.key();
        int score = it.value();
        
        if (score < m_qualityThresholds[metric]) {
            QString recommendation = getDetailedRecommendation(metric, score);
            if (!recommendation.isEmpty()) {
                recommendations << recommendation;
            }
        }
    }
    
    return recommendations;
}

QString WorkspaceHealthAnalyzer::getDetailedRecommendation(HealthMetric metric, int score)
{
    switch (metric) {
        case CodeQuality:
            return "Consider refactoring code to reduce complexity and improve readability";
        case TestCoverage:
            return "Increase test coverage by adding more unit and integration tests";
        case Documentation:
            return "Add comprehensive documentation including README, API docs, and examples";
        case Maintainability:
            return "Address code smells and improve code organization for better maintainability";
        case Dependencies:
            return "Review and update dependencies to latest stable versions";
        case Performance:
            return "Profile code and optimize bottlenecks";
        case Security:
            return "Conduct security review and implement best practices";
        default:
            return QString();
    }
}

QString WorkspaceHealthAnalyzer::generateHealthReport(const HealthReport& report)
{
    QString healthStr;
    switch (report.overallHealth) {
        case Excellent: healthStr = "Excellent"; break;
        case Good: healthStr = "Good"; break;
        case Fair: healthStr = "Fair"; break;
        case Poor: healthStr = "Poor"; break;
        case Critical: healthStr = "Critical"; break;
    }
    
    QString result = "=== Workspace Health Report ===\n\n";
    result += "Overall Health: " + healthStr + " (" + QString::number(report.overallScore) + "/100)\n\n";
    
    result += "Metric Scores:\n";
    for (auto it = report.scores.begin(); it != report.scores.end(); ++it) {
        result += QString("  - %1: %2/100\n").arg(metricName(it.key())).arg(it.value());
    }
    
    if (!report.issues.isEmpty()) {
        result += "\nIssues Found:\n";
        for (const QString& issue : report.issues) {
            result += "  - " + issue + "\n";
        }
    }
    
    if (!report.improvements.isEmpty()) {
        result += "\nRecommendations:\n";
        for (const QString& improvement : report.improvements) {
            result += "  - " + improvement + "\n";
        }
    }
    
    return result;
}

QJsonObject WorkspaceHealthAnalyzer::exportHealthReport(const HealthReport& report)
{
    QJsonObject obj;
    
    obj["overallScore"] = report.overallScore;
    obj["overallHealth"] = healthName(report.overallHealth);
    obj["issues"] = QJsonArray::fromStringList(report.issues);
    obj["improvements"] = QJsonArray::fromStringList(report.improvements);
    
    QJsonObject scores;
    for (auto it = report.scores.begin(); it != report.scores.end(); ++it) {
        scores[metricName(it.key())] = it.value();
    }
    obj["scores"] = scores;
    
    return obj;
}

void WorkspaceHealthAnalyzer::setQualityThresholds(const QMap<HealthMetric, int>& thresholds)
{
    m_qualityThresholds = thresholds;
}

void WorkspaceHealthAnalyzer::enableDetailedAnalysis(bool enabled)
{
    m_detailedAnalysis = enabled;
}

WorkspaceHealthAnalyzer::CodeQualityMetrics WorkspaceHealthAnalyzer::analyzeCodeMetrics(const QString& sourcePath)
{
    CodeQualityMetrics metrics = {0, 0, 0, 0, 0};
    int totalLines = 0;
    int totalCommentLines = 0;
    int functionCount = 0;
    int maxComplexity = 0;
    QSet<QString> seenLines;
    QSet<QString> duplicateLines;

    QDirIterator iterator(sourcePath, sourceFilePatterns(), QDir::Files, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        const QString filePath = iterator.next();
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        const QString content = file.readAll();
        file.close();

        const QStringList lines = content.split('\n');
        totalLines += lines.size();
        maxComplexity = qMax(maxComplexity, calculateCyclomaticComplexity(content));
        metrics.warningCount += detectCodeSmellsInFile(filePath);

        for (const QString &line : lines) {
            const QString trimmed = line.trimmed();
            if (trimmed.startsWith(QStringLiteral("//"))
                || trimmed.startsWith(QStringLiteral("/*"))
                || trimmed.startsWith(QStringLiteral("*"))) {
                totalCommentLines++;
            }

            if (!trimmed.isEmpty()) {
                if (seenLines.contains(trimmed)) {
                    duplicateLines.insert(trimmed);
                } else {
                    seenLines.insert(trimmed);
                }
            }

            if (looksLikeFunctionStart(line)) {
                functionCount++;
            }
        }
    }

    metrics.cyclomaticComplexity = maxComplexity;
    metrics.linesPerFunction = functionCount > 0 ? totalLines / functionCount : totalLines;
    metrics.duplicateLines = duplicateLines.size();
    metrics.commentRatio = totalLines > 0 ? (totalCommentLines * 100) / totalLines : 0;
    return metrics;
}

WorkspaceHealthAnalyzer::TestMetrics WorkspaceHealthAnalyzer::analyzeTests(const QString& projectPath)
{
    TestMetrics metrics = {0, 0, 0, 0.0f};
    int sourceFiles = countFiles(projectPath, "*.cpp") + countFiles(projectPath, "*.h")
        + countFiles(projectPath, "*.qml") + countFiles(projectPath, "*.js") + countFiles(projectPath, "*.ts");
    int testFiles = 0;
    for (const QString &pattern : testFilePatterns()) {
        testFiles += countFiles(projectPath, pattern);
    }

    metrics.totalTests = testFiles;
    metrics.passingTests = testFiles;
    metrics.failingTests = 0;
    if (sourceFiles > 0) {
        metrics.coveragePercentage = qMin(100.0f, (testFiles * 200.0f) / sourceFiles);
    }
    return metrics;
}

int WorkspaceHealthAnalyzer::countFiles(const QString& path, const QString& extension)
{
    int count = 0;
    QString pattern = extension;
    if (!pattern.startsWith('*') && !pattern.contains('.')) {
        pattern = QStringLiteral("*.%1").arg(pattern);
    } else if (!pattern.startsWith('*')) {
        pattern = QStringLiteral("*%1").arg(pattern);
    }

    QDirIterator iterator(path, {pattern}, QDir::Files, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        iterator.next();
        count++;
    }
    return count;
}

int WorkspaceHealthAnalyzer::countLines(const QString& filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return 0;
    }
    int count = 0;
    while (!file.atEnd()) {
        file.readLine();
        count++;
    }
    file.close();
    return count;
}

int WorkspaceHealthAnalyzer::detectCodeSmellsInFile(const QString& filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return 0;
    }
    QString content = file.readAll();
    file.close();
    return content.count("TODO") + content.count("FIXME") + content.count("goto ");
}

int WorkspaceHealthAnalyzer::calculateCyclomaticComplexity(const QString& code)
{
    int complexity = 1;
    complexity += code.count(QRegularExpression(QStringLiteral(R"(\bif\b)")));
    complexity += code.count(QRegularExpression(QStringLiteral(R"(\belse\b)")));
    complexity += code.count(QRegularExpression(QStringLiteral(R"(\bfor\b)")));
    complexity += code.count(QRegularExpression(QStringLiteral(R"(\bwhile\b)")));
    complexity += code.count(QRegularExpression(QStringLiteral(R"(\bcase\b)")));
    complexity += code.count(QRegularExpression(QStringLiteral(R"(\bswitch\b)")));
    complexity += code.count("&&");
    complexity += code.count("||");
    return complexity;
}
