#pragma once

#include "CodeMagicTypes.h"
#include <QObject>
#include <memory>

/**
 * @class CodeMagic
 * @brief Claude Code核心功能模块
 * 
 * 提供：
 * - 代码分析和质量评估
 * - 智能代码生成
 * - 代码重构和优化
 * - 代码解释和文档
 * - 测试生成
 * - 代码审查
 */
class CodeMagic : public QObject {
    Q_OBJECT
public:
    explicit CodeMagic(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~CodeMagic() = default;
    
    // ── Code Analysis ───────────────────────────────
    
    /// Analyze code quality and issues
    virtual CodeAnalysisResult analyzeCode(const QString &code,
                                          ProgrammingLanguage language) = 0;
    
    /// Analyze code asynchronously
    virtual QString analyzeCodeAsync(const QString &code,
                                    ProgrammingLanguage language,
                                    CodeAnalysisCallback callback = nullptr) = 0;
    
    /// Detect programming language
    virtual ProgrammingLanguage detectLanguage(const QString &code) const = 0;
    
    /// Check for security issues
    virtual QVector<CodeIssue> findSecurityIssues(const QString &code,
                                                  ProgrammingLanguage language) = 0;
    
    /// Check for performance issues
    virtual QVector<CodeIssue> findPerformanceIssues(const QString &code,
                                                     ProgrammingLanguage language) = 0;
    
    /// Calculate code complexity
    virtual int calculateComplexity(const QString &code) = 0;
    
    /// Get code metrics
    virtual QVariantMap getCodeMetrics(const QString &code) = 0;
    
    // ── Code Generation ────────────────────────────
    
    /// Generate code from description
    virtual GeneratedCode generateCode(const CodeGenerationRequest &request) = 0;
    
    /// Generate code asynchronously
    virtual QString generateCodeAsync(const CodeGenerationRequest &request,
                                     CodeGenerationCallback callback = nullptr) = 0;
    
    /// Generate function stub
    virtual QString generateFunctionStub(const QString &name,
                                        const QStringList &parameters,
                                        ProgrammingLanguage language) = 0;
    
    /// Generate class skeleton
    virtual QString generateClassSkeleton(const QString &className,
                                         const QStringList &methods,
                                         ProgrammingLanguage language) = 0;
    
    /// Complete partial code
    virtual QString completeCode(const QString &partialCode,
                                ProgrammingLanguage language) = 0;
    
    // ── Code Refactoring ───────────────────────────
    
    /// Refactor code
    virtual RefactoringResult refactorCode(const RefactoringRequest &request) = 0;
    
    /// Refactor code asynchronously
    virtual QString refactorCodeAsync(const RefactoringRequest &request,
                                     RefactoringCallback callback = nullptr) = 0;
    
    /// Extract method
    virtual QString extractMethod(const QString &code,
                                 int startLine, int endLine,
                                 const QString &methodName,
                                 ProgrammingLanguage language) = 0;
    
    /// Rename variable
    virtual QString renameVariable(const QString &code,
                                  const QString &oldName,
                                  const QString &newName,
                                  ProgrammingLanguage language) = 0;
    
    /// Simplify condition
    virtual QString simplifyCondition(const QString &code,
                                     int lineNumber,
                                     ProgrammingLanguage language) = 0;
    
    /// Optimize loops
    virtual QString optimizeLoop(const QString &code,
                               int lineNumber,
                               ProgrammingLanguage language) = 0;
    
    /// Reduce complexity
    virtual QString reduceComplexity(const QString &code,
                                    ProgrammingLanguage language) = 0;
    
    // ── Code Explanation ───────────────────────────
    
    /// Explain code
    virtual CodeExplanation explainCode(const QString &code,
                                       ProgrammingLanguage language = ProgrammingLanguage::Unknown) = 0;
    
    /// Explain specific function
    virtual CodeExplanation explainFunction(const QString &code,
                                           const QString &functionName,
                                           ProgrammingLanguage language) = 0;
    
    /// Explain line by line
    virtual QVector<QString> explainLineByLine(const QString &code,
                                              ProgrammingLanguage language) = 0;
    
    /// Generate documentation
    virtual QString generateDocumentation(const QString &code,
                                         ProgrammingLanguage language) = 0;
    
    /// Generate code comments
    virtual QString generateComments(const QString &code,
                                    ProgrammingLanguage language) = 0;
    
    // ── Test Generation ────────────────────────────
    
    /// Generate tests
    virtual GeneratedTests generateTests(const TestGenerationRequest &request) = 0;
    
    /// Generate tests asynchronously
    virtual QString generateTestsAsync(const TestGenerationRequest &request,
                                      TestGenerationCallback callback = nullptr) = 0;
    
    /// Generate unit tests
    virtual QString generateUnitTests(const QString &code,
                                     ProgrammingLanguage language) = 0;
    
    /// Generate integration tests
    virtual QString generateIntegrationTests(const QString &code,
                                            ProgrammingLanguage language) = 0;
    
    /// Generate edge case tests
    virtual QVector<QString> generateEdgeCaseTests(const QString &code,
                                                   ProgrammingLanguage language) = 0;
    
    // ── Code Comparison ────────────────────────────
    
    /// Compare two code versions
    virtual CodeDiff compareCode(const QString &originalCode,
                                const QString &modifiedCode) = 0;
    
    /// Find code duplicates
    virtual QVector<QVariantMap> findDuplicates(const QString &code) = 0;
    
    /// Check similarity
    virtual float calculateSimilarity(const QString &code1,
                                     const QString &code2) = 0;
    
    // ── Code Review ─────────────────────────────────
    
    /// Review code
    virtual CodeReview reviewCode(const QString &code,
                                 const QString &author = "",
                                 const QString &reviewer = "") = 0;
    
    /// Get review suggestions
    virtual QVector<QString> getReviewSuggestions(const QString &code,
                                                 ProgrammingLanguage language) = 0;
    
    /// Check code standards
    virtual QVector<CodeIssue> checkCodingStandards(const QString &code,
                                                    ProgrammingLanguage language) = 0;
    
    // ── Code Formatting ────────────────────────────
    
    /// Format code
    virtual QString formatCode(const QString &code,
                              ProgrammingLanguage language) = 0;
    
    /// Fix code style
    virtual QString fixCodeStyle(const QString &code,
                                ProgrammingLanguage language) = 0;
    
    /// Minify code
    virtual QString minifyCode(const QString &code,
                              ProgrammingLanguage language) = 0;
    
    /// Pretty print code
    virtual QString prettyPrintCode(const QString &code,
                                   ProgrammingLanguage language) = 0;
    
    // ── Language Features ───────────────────────────
    
    /// Get language info
    virtual QVariantMap getLanguageInfo(ProgrammingLanguage language) const = 0;
    
    /// Get supported languages
    virtual QVector<ProgrammingLanguage> getSupportedLanguages() const = 0;
    
    /// Convert between languages
    virtual QString convertLanguage(const QString &code,
                                   ProgrammingLanguage fromLanguage,
                                   ProgrammingLanguage toLanguage) = 0;
    
    // ── Debugging and Fixing ────────────────────────
    
    /// Find bugs
    virtual QVector<CodeIssue> findBugs(const QString &code,
                                       ProgrammingLanguage language) = 0;
    
    /// Suggest fixes
    virtual QVector<QString> suggestFixes(const CodeIssue &issue,
                                         const QString &code) = 0;
    
    /// Fix common errors
    virtual QString fixCommonErrors(const QString &code,
                                   ProgrammingLanguage language) = 0;
    
    // ── History and Statistics ──────────────────────
    
    /// Get analysis history
    virtual QVector<CodeAnalysisResult> getAnalysisHistory(int limit = 50) const = 0;
    
    /// Get generation history
    virtual QVector<GeneratedCode> getGenerationHistory(int limit = 50) const = 0;
    
    /// Get statistics
    virtual QVariantMap getStatistics() const = 0;

signals:
    /// Analysis completed
    void analysisCompleted(const CodeAnalysisResult &result);
    
    /// Generation completed
    void generationCompleted(const GeneratedCode &code);
    
    /// Refactoring completed
    void refactoringCompleted(const RefactoringResult &result);
    
    /// Tests generated
    void testsGenerated(const GeneratedTests &tests);
    
    /// Error occurred
    void errorOccurred(const QString &error);
};

using CodeMagicPtr = std::shared_ptr<CodeMagic>;
