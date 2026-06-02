#pragma once

#include <QString>
#include <QStringList>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * Code analysis and generation types
 */

// ── Programming Languages ───────────────────────────

enum class ProgrammingLanguage {
    Python,
    JavaScript,
    TypeScript,
    Java,
    CSharp,
    Cpp,
    C,
    Go,
    Rust,
    Ruby,
    PHP,
    Swift,
    Kotlin,
    SQL,
    HTML,
    CSS,
    Scala,
    Haskell,
    Unknown
};

// ── Code Issues ─────────────────────────────────────

enum class IssueSeverity {
    Info,
    Warning,
    Error,
    Critical
};

struct CodeIssue {
    QString id;
    IssueSeverity severity;
    QString type;               // e.g., "performance", "security", "style"
    QString message;
    
    int lineNumber = -1;
    int columnNumber = -1;
    
    QString suggestedFix;
    QVector<QString> alternatives;
    
    QString rule;               // What rule was violated
    QString documentation;      // Link to documentation
};

// ── Code Analysis Result ────────────────────────────

struct CodeAnalysisResult {
    QString analysisId;
    QString filename;
    ProgrammingLanguage language;
    
    QString code;
    int lineCount = 0;
    int characterCount = 0;
    int complexity = 0;
    
    QVector<CodeIssue> issues;
    int criticalCount = 0;
    int errorCount = 0;
    int warningCount = 0;
    int infoCount = 0;
    
    float quality = 0.0f;       // 0-100
    float maintainability = 0.0f;
    float security = 0.0f;
    float performance = 0.0f;
    
    QDateTime analyzedAt;
};

// ── Code Generation Request ────────────────────────

struct CodeGenerationRequest {
    QString requestId;
    
    QString description;        // What to generate
    ProgrammingLanguage language;
    QString template_;          // Template or starting code
    
    QMap<QString, QString> requirements;  // key-value pairs
    
    bool includeComments = true;
    bool includeTests = false;
    bool optimizeForPerformance = false;
    
    int maxLines = 500;
};

// ── Generated Code ──────────────────────────────────

struct GeneratedCode {
    QString generationId;
    QString code;
    
    QString explanation;        // Why this code
    QVector<QString> keyPoints;
    
    QVector<CodeIssue> issues;  // Potential issues in generated code
    
    QDateTime generatedAt;
};

// ── Code Refactoring ────────────────────────────────

enum class RefactoringType {
    ExtractMethod,
    InlineVariable,
    RenameVariable,
    MoveFunction,
    ExtractClass,
    SimplifyCondition,
    OptimizeLoop,
    ReduceComplexity,
    ImproveReadability,
    Custom
};

struct RefactoringRequest {
    QString requestId;
    
    QString code;
    int startLine = 0;
    int endLine = -1;
    
    RefactoringType type;
    QString description;        // Reason for refactoring
    
    QVariantMap options;        // Type-specific options
};

struct RefactoringResult {
    QString refactoringId;
    
    QString originalCode;
    QString refactoredCode;
    
    QString explanation;
    QVector<QString> improvements;
    
    bool successful = true;
    QString error;
    
    int complexityReduction = 0;
    float performanceImprovement = 0.0f;
    
    QDateTime performedAt;
};

// ── Code Explanation ────────────────────────────────

struct CodeExplanation {
    QString explanationId;
    
    QString code;
    QString summary;            // Brief summary
    QString detailedExplanation;
    
    QVector<QString> keyComponents;
    QVector<QVariantMap> lineByLineExplanation;
    
    QVector<QString> suggestedImprovements;
    
    QDateTime createdAt;
};

// ── Test Generation ────────────────────────────────

struct TestGenerationRequest {
    QString requestId;
    
    QString code;
    ProgrammingLanguage language;
    
    QString testFramework;      // e.g., "pytest", "jest", "junit"
    bool includeEdgeCases = true;
    bool includeMocking = true;
    int minCoverage = 80;       // Minimum coverage %
};

struct GeneratedTests {
    QString testId;
    
    QString testCode;
    QString setupCode;         // Fixtures, mocks, etc.
    
    int estimatedCoverage = 0;
    int numberOfTests = 0;
    
    QVector<QString> testCases;
    QVector<QString> edgeCases;
    
    QDateTime generatedAt;
};

// ── Code Diff ───────────────────────────────────────

struct CodeDiff {
    QString diffId;
    
    QString originalCode;
    QString modifiedCode;
    
    QVector<QVariantMap> changes;  // Line-by-line changes
    
    int addedLines = 0;
    int removedLines = 0;
    int modifiedLines = 0;
    
    QString summary;
};

// ── Code Review ─────────────────────────────────────

struct CodeReview {
    QString reviewId;
    
    QString code;
    QString author;
    QString reviewer;
    
    QVector<CodeIssue> issues;
    QVector<QString> suggestions;
    QVector<QString> praise;
    
    float overallScore = 0.0f;  // 0-100
    
    QDateTime reviewedAt;
};

// ── Callbacks ───────────────────────────────────────

using CodeAnalysisCallback = std::function<void(const CodeAnalysisResult &)>;
using CodeGenerationCallback = std::function<void(const GeneratedCode &)>;
using RefactoringCallback = std::function<void(const RefactoringResult &)>;
using ExplanationCallback = std::function<void(const CodeExplanation &)>;
using TestGenerationCallback = std::function<void(const GeneratedTests &)>;
