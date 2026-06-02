#pragma once

#include "CodeMagic.h"
#include <QMap>
#include <QRecursiveMutex>

/**
 * @class DefaultCodeMagic
 * @brief Default implementation of CodeMagic
 * 
 * Features:
 * - Code analysis and quality metrics
 * - Intelligent code generation
 * - Code refactoring and optimization
 * - Explanation and documentation
 * - Test generation
 * - Code review
 */
class DefaultCodeMagic : public CodeMagic {
    Q_OBJECT
public:
    explicit DefaultCodeMagic(QObject *parent = nullptr);
    ~DefaultCodeMagic() = default;
    
    // Code Analysis
    CodeAnalysisResult analyzeCode(const QString &code,
                                  ProgrammingLanguage language) override;
    QString analyzeCodeAsync(const QString &code,
                            ProgrammingLanguage language,
                            CodeAnalysisCallback callback = nullptr) override;
    ProgrammingLanguage detectLanguage(const QString &code) const override;
    QVector<CodeIssue> findSecurityIssues(const QString &code,
                                          ProgrammingLanguage language) override;
    QVector<CodeIssue> findPerformanceIssues(const QString &code,
                                             ProgrammingLanguage language) override;
    int calculateComplexity(const QString &code) override;
    QVariantMap getCodeMetrics(const QString &code) override;
    
    // Code Generation
    GeneratedCode generateCode(const CodeGenerationRequest &request) override;
    QString generateCodeAsync(const CodeGenerationRequest &request,
                             CodeGenerationCallback callback = nullptr) override;
    QString generateFunctionStub(const QString &name,
                                const QStringList &parameters,
                                ProgrammingLanguage language) override;
    QString generateClassSkeleton(const QString &className,
                                 const QStringList &methods,
                                 ProgrammingLanguage language) override;
    QString completeCode(const QString &partialCode,
                        ProgrammingLanguage language) override;
    
    // Code Refactoring
    RefactoringResult refactorCode(const RefactoringRequest &request) override;
    QString refactorCodeAsync(const RefactoringRequest &request,
                             RefactoringCallback callback = nullptr) override;
    QString extractMethod(const QString &code,
                         int startLine, int endLine,
                         const QString &methodName,
                         ProgrammingLanguage language) override;
    QString renameVariable(const QString &code,
                          const QString &oldName,
                          const QString &newName,
                          ProgrammingLanguage language) override;
    QString simplifyCondition(const QString &code,
                             int lineNumber,
                             ProgrammingLanguage language) override;
    QString optimizeLoop(const QString &code,
                        int lineNumber,
                        ProgrammingLanguage language) override;
    QString reduceComplexity(const QString &code,
                            ProgrammingLanguage language) override;
    
    // Code Explanation
    CodeExplanation explainCode(const QString &code,
                               ProgrammingLanguage language = ProgrammingLanguage::Unknown) override;
    CodeExplanation explainFunction(const QString &code,
                                   const QString &functionName,
                                   ProgrammingLanguage language) override;
    QVector<QString> explainLineByLine(const QString &code,
                                      ProgrammingLanguage language) override;
    QString generateDocumentation(const QString &code,
                                 ProgrammingLanguage language) override;
    QString generateComments(const QString &code,
                            ProgrammingLanguage language) override;
    
    // Test Generation
    GeneratedTests generateTests(const TestGenerationRequest &request) override;
    QString generateTestsAsync(const TestGenerationRequest &request,
                              TestGenerationCallback callback = nullptr) override;
    QString generateUnitTests(const QString &code,
                             ProgrammingLanguage language) override;
    QString generateIntegrationTests(const QString &code,
                                    ProgrammingLanguage language) override;
    QVector<QString> generateEdgeCaseTests(const QString &code,
                                          ProgrammingLanguage language) override;
    
    // Code Comparison
    CodeDiff compareCode(const QString &originalCode,
                        const QString &modifiedCode) override;
    QVector<QVariantMap> findDuplicates(const QString &code) override;
    float calculateSimilarity(const QString &code1,
                             const QString &code2) override;
    
    // Code Review
    CodeReview reviewCode(const QString &code,
                         const QString &author = "",
                         const QString &reviewer = "") override;
    QVector<QString> getReviewSuggestions(const QString &code,
                                         ProgrammingLanguage language) override;
    QVector<CodeIssue> checkCodingStandards(const QString &code,
                                            ProgrammingLanguage language) override;
    
    // Code Formatting
    QString formatCode(const QString &code,
                      ProgrammingLanguage language) override;
    QString fixCodeStyle(const QString &code,
                        ProgrammingLanguage language) override;
    QString minifyCode(const QString &code,
                      ProgrammingLanguage language) override;
    QString prettyPrintCode(const QString &code,
                           ProgrammingLanguage language) override;
    
    // Language Features
    QVariantMap getLanguageInfo(ProgrammingLanguage language) const override;
    QVector<ProgrammingLanguage> getSupportedLanguages() const override;
    QString convertLanguage(const QString &code,
                           ProgrammingLanguage fromLanguage,
                           ProgrammingLanguage toLanguage) override;
    
    // Debugging and Fixing
    QVector<CodeIssue> findBugs(const QString &code,
                               ProgrammingLanguage language) override;
    QVector<QString> suggestFixes(const CodeIssue &issue,
                                 const QString &code) override;
    QString fixCommonErrors(const QString &code,
                           ProgrammingLanguage language) override;
    
    // History and Statistics
    QVector<CodeAnalysisResult> getAnalysisHistory(int limit = 50) const override;
    QVector<GeneratedCode> getGenerationHistory(int limit = 50) const override;
    QVariantMap getStatistics() const override;

private:
    QVector<CodeAnalysisResult> m_analysisHistory;
    QVector<GeneratedCode> m_generationHistory;
    QVector<RefactoringResult> m_refactoringHistory;
    
    int m_totalAnalyses = 0;
    int m_totalGenerations = 0;
    int m_totalRefactorings = 0;
    
    mutable QRecursiveMutex m_mutex;
    
    // Helper methods
    ProgrammingLanguage detectLanguageInternal(const QString &code) const;
    int calculateCyclomaticComplexity(const QString &code);
    float calculateQualityScore(const CodeAnalysisResult &result);
    QVector<CodeIssue> analyzeIssues(const QString &code, ProgrammingLanguage language);
    QString generateCodeStub(const QString &description, ProgrammingLanguage language);
};

using DefaultCodeMagicPtr = std::shared_ptr<DefaultCodeMagic>;
