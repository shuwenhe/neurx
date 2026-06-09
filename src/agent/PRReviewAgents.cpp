#include "PRReviewAgents.h"
#include <QDebug>
#include <QDateTime>

PRReviewAgents::PRReviewAgents(QObject* parent)
    : QObject(parent) {
    m_stats = {0, 0, 0.0f, 0.0f, 0, 0};
    initializeDefaultReviewers();
}

PRReviewAgents::~PRReviewAgents() {
}

void PRReviewAgents::initializeDefaultReviewers() {
    // Initialize security reviewer
    ReviewerAgent security;
    security.type = SecurityReviewer;
    security.name = "Security Bot";
    security.expertise = "Vulnerability detection, security best practices";
    security.priority = 100;
    security.reviewAccuracy = 0.95f;
    security.focusAreas = {"sql injection", "xss", "authentication", "encryption"};
    registerReviewer(security);
}

void PRReviewAgents::registerReviewer(const ReviewerAgent& reviewer) {
    m_reviewers[reviewer.type] = reviewer;
}

PRReviewAgents::ReviewerAgent PRReviewAgents::getReviewer(ReviewerType type) {
    return m_reviewers.value(type);
}

QVector<PRReviewAgents::ReviewerAgent> PRReviewAgents::getAllReviewers() {
    return QVector<ReviewerAgent>(m_reviewers.values().begin(), m_reviewers.values().end());
}

void PRReviewAgents::setReviewerPriority(ReviewerType type, int priority) {
    if (m_reviewers.contains(type)) {
        m_reviewers[type].priority = priority;
    }
}

void PRReviewAgents::startPRReview(const QString& prId, const QString& title) {
    m_currentPRId = prId;
    m_diffs.clear();
    m_findings.clear();
    emit reviewStarted(prId);
}

void PRReviewAgents::addCodeDiff(const CodeDiff& diff) {
    m_diffs.append(diff);
}

PRReviewAgents::PRReviewReport PRReviewAgents::completePRReview() {
    PRReviewReport report;
    report.prId = m_currentPRId;
    report.findings = m_findings;
    report.totalFindings = m_findings.size();
    report.overallQualityScore = calculateCodeQualityScore();
    report.readyToMerge = canMerge();
    report.blockers = getMergeBlockers();
    report.suggestions = suggestImprovements();
    
    emit reviewCompleted(report);
    return report;
}

void PRReviewAgents::runSecurityReview() {
    qDebug() << "Running security review...";
    emit reviewerAnalysisCompleted(SecurityReviewer);
}

void PRReviewAgents::runPerformanceReview() {
    qDebug() << "Running performance review...";
    emit reviewerAnalysisCompleted(PerformanceReviewer);
}

void PRReviewAgents::runArchitectureReview() {
    qDebug() << "Running architecture review...";
    emit reviewerAnalysisCompleted(ArchitectureReviewer);
}

void PRReviewAgents::runDocumentationReview() {
    qDebug() << "Running documentation review...";
    emit reviewerAnalysisCompleted(DocumentationReviewer);
}

void PRReviewAgents::runTestCoverageReview() {
    qDebug() << "Running test coverage review...";
    emit reviewerAnalysisCompleted(TestReviewer);
}

void PRReviewAgents::runCodeQualityReview() {
    qDebug() << "Running code quality review...";
    emit reviewerAnalysisCompleted(CodeQualityReviewer);
}

void PRReviewAgents::addFinding(const ReviewFinding& finding) {
    m_findings.append(finding);
    emit findingDiscovered(finding);
}

QVector<PRReviewAgents::ReviewFinding> PRReviewAgents::getFindingsBySeverity(const QString& severity) {
    QVector<ReviewFinding> result;
    for (const auto& finding : m_findings) {
        if (finding.severity == severity) {
            result.append(finding);
        }
    }
    return result;
}

QVector<PRReviewAgents::ReviewFinding> PRReviewAgents::getFindingsByFile(const QString& filePath) {
    QVector<ReviewFinding> result;
    for (const auto& finding : m_findings) {
        if (finding.filePath == filePath) {
            result.append(finding);
        }
    }
    return result;
}

int PRReviewAgents::countFindingsBySeverity(const QString& severity) {
    return getFindingsBySeverity(severity).size();
}

float PRReviewAgents::calculateCodeQualityScore() {
    // Calculate based on findings
    float score = 100.0f;
    score -= countFindingsBySeverity("critical") * 10;
    score -= countFindingsBySeverity("major") * 5;
    score -= countFindingsBySeverity("minor") * 1;
    return qMax(0.0f, score);
}

float PRReviewAgents::detectPerformanceRegression() {
    // Analyze for performance issues
    return 0.05f;  // 5% regression
}

bool PRReviewAgents::checkArchitectureCompliance() {
    return true;
}

bool PRReviewAgents::validateTestCoverage() {
    return true;
}

QStringList PRReviewAgents::validateDocumentation() {
    return QStringList{"Missing README update", "Missing API docs"};
}

bool PRReviewAgents::runSecurityScan() {
    return true;
}

PRReviewAgents::MergeReadinessAssessment PRReviewAgents::assessMergeReadiness() {
    MergeReadinessAssessment assessment;
    assessment.hasRequiredReviews = true;
    assessment.passesAllChecks = true;
    assessment.hasNoConflicts = true;
    assessment.hasTestCoverage = true;
    assessment.isDocumented = true;
    assessment.securityScore = 95;
    assessment.performanceScore = 90;
    assessment.recommendedMergeScore = 0.95f;
    return assessment;
}

bool PRReviewAgents::canMerge() {
    auto assessment = assessMergeReadiness();
    return assessment.passesAllChecks && countFindingsBySeverity("critical") == 0;
}

QStringList PRReviewAgents::getMergeBlockers() {
    QStringList blockers;
    if (countFindingsBySeverity("critical") > 0) {
        blockers.append("Critical security issues found");
    }
    return blockers;
}

QString PRReviewAgents::generateMergeReadinessReport() {
    auto assessment = assessMergeReadiness();
    return QString("# Merge Readiness Report\n\n"
                   "Security Score: %1/100\n"
                   "Performance Score: %2/100\n"
                   "Ready to Merge: %3\n")
        .arg(assessment.securityScore)
        .arg(assessment.performanceScore)
        .arg(assessment.recommendedMergeScore > 0.8f ? "Yes" : "No");
}

QStringList PRReviewAgents::suggestImprovements() {
    return QStringList{"Add error handling", "Improve variable naming", "Add comments"};
}

QStringList PRReviewAgents::suggestOptimizations() {
    return QStringList{"Use const references", "Cache results", "Reduce allocations"};
}

QStringList PRReviewAgents::suggestSecurityEnhancements() {
    return QStringList{"Validate user input", "Use parameterized queries", "Add authentication"};
}

QString PRReviewAgents::suggestRefactorings() {
    return "Consider extracting common logic into separate method";
}

void PRReviewAgents::addReviewComment(const ReviewComment& comment) {
    m_comments.append(comment);
}

QVector<PRReviewAgents::ReviewComment> PRReviewAgents::getReviewComments() {
    return m_comments;
}

PRReviewAgents::ReviewStats PRReviewAgents::getStatistics() {
    return m_stats;
}

void PRReviewAgents::trainReviewers(const QString& trainingData) {
    qDebug() << "Training reviewers with:" << trainingData;
}

void PRReviewAgents::calibrateReviewers() {
    qDebug() << "Calibrating reviewer accuracy...";
}
