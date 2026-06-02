#pragma once

#include "../code/CodeMagic.h"
#include "LLMProvider.h"
#include <QMap>
#include <QMutex>

/**
 * @class LLMCodeAnalyzer
 * @brief 使用LLM增强的代码分析器
 * 
 * 混合策略：
 * - 快速问题：使用本地规则（立即返回）
 * - 复杂问题：使用LLM分析（高准确度）
 * - 智能缓存：避免重复API调用
 */
class LLMCodeAnalyzer : public CodeMagic {
    Q_OBJECT
public:
    explicit LLMCodeAnalyzer(QObject *parent = nullptr);
    virtual ~LLMCodeAnalyzer();
    
    // ── 初始化 ──────────────────────────────────
    
    /// 设置LLM提供商
    void setLLMProvider(LLMProvider *provider);
    
    /// 启用/禁用LLM分析
    void setLLMEnabled(bool enabled);
    
    /// 设置模型
    void setModel(const QString &model);
    
    /// 启用/禁用缓存
    void setCacheEnabled(bool enabled);
    
    /// 设置本地回退策略
    void setFallbackToLocal(bool enabled);
    
    // ── 代码分析 ─────────────────────────────────
    
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
    
    // ── 代码生成 ─────────────────────────────────
    
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
    
    // ── 代码重构 ─────────────────────────────────
    
    RefactoringResult refactorCode(const RefactoringRequest &request) override;
    
    QString refactorCodeAsync(const RefactoringRequest &request,
                             RefactoringCallback callback = nullptr) override;
    
    QString extractMethod(const QString &code, int startLine, int endLine,
                         const QString &methodName,
                         ProgrammingLanguage language) override;
    
    QString renameVariable(const QString &code, const QString &oldName,
                          const QString &newName,
                          ProgrammingLanguage language) override;
    
    QString simplifyCondition(const QString &code, int lineNumber,
                             ProgrammingLanguage language) override;
    
    QString optimizeLoop(const QString &code, int lineNumber,
                        ProgrammingLanguage language) override;
    
    QString reduceComplexity(const QString &code,
                            ProgrammingLanguage language) override;
    
    // ── 代码解释 ─────────────────────────────────
    
    CodeExplanation explainCode(const QString &code,
                               ProgrammingLanguage language) override;
    
    CodeExplanation explainFunction(const QString &code,
                                   const QString &functionName,
                                   ProgrammingLanguage language) override;
    
    QVector<QString> explainLineByLine(const QString &code,
                                      ProgrammingLanguage language) override;
    
    QString generateDocumentation(const QString &code,
                                 ProgrammingLanguage language) override;
    
    QString generateComments(const QString &code,
                            ProgrammingLanguage language) override;
    
    // ── 测试生成 ─────────────────────────────────
    
    GeneratedTests generateTests(const TestGenerationRequest &request) override;
    
    QString generateTestsAsync(const TestGenerationRequest &request,
                              TestGenerationCallback callback = nullptr) override;
    
    QString generateUnitTests(const QString &code,
                             ProgrammingLanguage language) override;
    
    QString generateIntegrationTests(const QString &code,
                                    ProgrammingLanguage language) override;
    
    QVector<QString> generateEdgeCaseTests(const QString &code,
                                          ProgrammingLanguage language) override;
    
    // ── 代码比较 ─────────────────────────────────
    
    CodeDiff compareCode(const QString &originalCode,
                        const QString &modifiedCode) override;
    
    QVector<QVariantMap> findDuplicates(const QString &code) override;
    
    float calculateSimilarity(const QString &code1,
                             const QString &code2) override;
    
    // ── 代码审查 ─────────────────────────────────
    
    CodeReview reviewCode(const QString &code,
                         const QString &author = "",
                         const QString &reviewer = "") override;
    
    QVector<QString> getReviewSuggestions(const QString &code,
                                         ProgrammingLanguage language) override;
    
    QVector<CodeIssue> checkCodingStandards(const QString &code,
                                           ProgrammingLanguage language) override;
    
    // ── 代码格式化 ───────────────────────────────
    
    QString formatCode(const QString &code,
                      ProgrammingLanguage language) override;
    
    QString fixCodeStyle(const QString &code,
                        ProgrammingLanguage language) override;
    
    QString minifyCode(const QString &code,
                      ProgrammingLanguage language) override;
    
    QString prettyPrintCode(const QString &code,
                           ProgrammingLanguage language) override;
    
    // ── 语言支持 ─────────────────────────────────
    
    QVariantMap getLanguageInfo(ProgrammingLanguage language) const override;
    
    QVector<ProgrammingLanguage> getSupportedLanguages() const override;
    
    QString convertLanguage(const QString &code,
                           ProgrammingLanguage fromLanguage,
                           ProgrammingLanguage toLanguage) override;
    
    // ── 错误修复 ─────────────────────────────────
    
    QVector<CodeIssue> findBugs(const QString &code,
                               ProgrammingLanguage language) override;
    
    QVector<QString> suggestFixes(const CodeIssue &issue,
                                 const QString &code) override;
    
    QString fixCommonErrors(const QString &code,
                           ProgrammingLanguage language) override;
    
    // ── 历史和统计 ───────────────────────────────
    
    QVector<CodeAnalysisResult> getAnalysisHistory(int limit = 50) const override;
    
    QVector<GeneratedCode> getGenerationHistory(int limit = 50) const override;
    
    QVariantMap getStatistics() const override;
    
    // ── LLM特定方法 ──────────────────────────────
    
    /// 获取缓存命中率
    float getCacheHitRate() const;
    
    /// 获取总成本（美元）
    float getTotalCost() const;
    
    /// 重置统计
    void resetStats();
    
    /// 获取LLM统计
    QVariantMap getLLMStatistics() const;

private:
    LLMProvider *m_llmProvider;
    std::shared_ptr<CodeMagic> m_localAnalyzer;
    
    // 配置
    bool m_llmEnabled;
    bool m_fallbackToLocal;
    bool m_cacheEnabled;
    QString m_model;
    
    // 缓存
    QMap<QString, CodeAnalysisResult> m_analysisCache;
    QMap<QString, GeneratedCode> m_generationCache;
    
    // 统计
    mutable QMutex m_mutex;
    int m_llmRequests;
    int m_cacheHits;
    float m_totalCost;
    
    // 辅助方法
    QString generateCacheKey(const QString &code, const QString &operation);
    bool shouldUseLLM(const QString &code);
    CodeAnalysisResult llmAnalyzeCode(const QString &code,
                                      ProgrammingLanguage language);
    GeneratedCode llmGenerateCode(const CodeGenerationRequest &request);
};

#endif // LLMCODEANALYZER_H
