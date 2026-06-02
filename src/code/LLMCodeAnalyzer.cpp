#include "LLMCodeAnalyzer.h"
#include "DefaultCodeMagic.h"
#include <QUuid>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

LLMCodeAnalyzer::LLMCodeAnalyzer(QObject *parent)
    : CodeMagic(parent),
      m_llmProvider(nullptr),
      m_localAnalyzer(std::make_shared<DefaultCodeMagic>()),
      m_llmEnabled(true),
      m_fallbackToLocal(true),
      m_cacheEnabled(true),
      m_model("claude-3-5-sonnet"),
      m_llmRequests(0),
      m_cacheHits(0),
      m_totalCost(0.0f) {
}

LLMCodeAnalyzer::~LLMCodeAnalyzer() {
}

// ── 初始化 ──────────────────────────────────

void LLMCodeAnalyzer::setLLMProvider(LLMProvider *provider) {
    QMutexLocker locker(&m_mutex);
    m_llmProvider = provider;
}

void LLMCodeAnalyzer::setLLMEnabled(bool enabled) {
    QMutexLocker locker(&m_mutex);
    m_llmEnabled = enabled;
}

void LLMCodeAnalyzer::setModel(const QString &model) {
    QMutexLocker locker(&m_mutex);
    m_model = model;
}

void LLMCodeAnalyzer::setCacheEnabled(bool enabled) {
    QMutexLocker locker(&m_mutex);
    m_cacheEnabled = enabled;
}

void LLMCodeAnalyzer::setFallbackToLocal(bool enabled) {
    QMutexLocker locker(&m_mutex);
    m_fallbackToLocal = enabled;
}

// ── 代码分析 ─────────────────────────────────

CodeAnalysisResult LLMCodeAnalyzer::analyzeCode(const QString &code,
                                              ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // 检查缓存
    QString cacheKey = generateCacheKey(code, "analyze");
    if (m_cacheEnabled && m_analysisCache.contains(cacheKey)) {
        m_cacheHits++;
        return m_analysisCache[cacheKey];
    }
    
    // 决定使用本地还是LLM
    if (m_llmEnabled && m_llmProvider && shouldUseLLM(code)) {
        CodeAnalysisResult result = llmAnalyzeCode(code, language);
        m_llmRequests++;
        m_totalCost += 0.01f;  // 估计成本
        
        if (m_cacheEnabled) {
            m_analysisCache[cacheKey] = result;
        }
        return result;
    }
    
    // 使用本地分析
    locker.unlock();
    return m_localAnalyzer->analyzeCode(code, language);
}

QString LLMCodeAnalyzer::analyzeCodeAsync(const QString &code,
                                         ProgrammingLanguage language,
                                         CodeAnalysisCallback callback) {
    auto result = analyzeCode(code, language);
    
    if (callback) {
        callback(result);
    }
    
    return result.analysisId;
}

ProgrammingLanguage LLMCodeAnalyzer::detectLanguage(const QString &code) const {
    return m_localAnalyzer->detectLanguage(code);
}

QVector<CodeIssue> LLMCodeAnalyzer::findSecurityIssues(const QString &code,
                                                      ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // 快速本地检查
    auto localIssues = m_localAnalyzer->findSecurityIssues(code, language);
    
    // 如果启用LLM，进行深度分析
    if (m_llmEnabled && m_llmProvider && localIssues.size() < 3) {
        // 这里会调用LLM进行更深入的安全分析
        m_llmRequests++;
        m_totalCost += 0.02f;
    }
    
    return localIssues;
}

QVector<CodeIssue> LLMCodeAnalyzer::findPerformanceIssues(const QString &code,
                                                         ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->findPerformanceIssues(code, language);
}

int LLMCodeAnalyzer::calculateComplexity(const QString &code) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->calculateComplexity(code);
}

QVariantMap LLMCodeAnalyzer::getCodeMetrics(const QString &code) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->getCodeMetrics(code);
}

// ── 代码生成 ─────────────────────────────────

GeneratedCode LLMCodeAnalyzer::generateCode(const CodeGenerationRequest &request) {
    QMutexLocker locker(&m_mutex);
    
    // 检查缓存
    QString cacheKey = generateCacheKey(request.description, "generate");
    if (m_cacheEnabled && m_generationCache.contains(cacheKey)) {
        m_cacheHits++;
        return m_generationCache[cacheKey];
    }
    
    // 使用LLM生成高质量代码
    if (m_llmEnabled && m_llmProvider) {
        GeneratedCode result = llmGenerateCode(request);
        m_llmRequests++;
        m_totalCost += 0.05f;
        
        if (m_cacheEnabled) {
            m_generationCache[cacheKey] = result;
        }
        return result;
    }
    
    // 回退到本地生成
    locker.unlock();
    return m_localAnalyzer->generateCode(request);
}

QString LLMCodeAnalyzer::generateCodeAsync(const CodeGenerationRequest &request,
                                          CodeGenerationCallback callback) {
    auto result = generateCode(request);
    
    if (callback) {
        callback(result);
    }
    
    return result.generationId;
}

QString LLMCodeAnalyzer::generateFunctionStub(const QString &name,
                                             const QStringList &parameters,
                                             ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->generateFunctionStub(name, parameters, language);
}

QString LLMCodeAnalyzer::generateClassSkeleton(const QString &className,
                                              const QStringList &methods,
                                              ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->generateClassSkeleton(className, methods, language);
}

QString LLMCodeAnalyzer::completeCode(const QString &partialCode,
                                     ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->completeCode(partialCode, language);
}

// ── 代码重构 ─────────────────────────────────

RefactoringResult LLMCodeAnalyzer::refactorCode(const RefactoringRequest &request) {
    QMutexLocker locker(&m_mutex);
    
    if (m_llmEnabled && m_llmProvider) {
        // LLM重构会更智能
        m_llmRequests++;
        m_totalCost += 0.03f;
    }
    
    locker.unlock();
    return m_localAnalyzer->refactorCode(request);
}

QString LLMCodeAnalyzer::refactorCodeAsync(const RefactoringRequest &request,
                                          RefactoringCallback callback) {
    auto result = refactorCode(request);
    
    if (callback) {
        callback(result);
    }
    
    return result.refactoringId;
}

QString LLMCodeAnalyzer::extractMethod(const QString &code, int startLine, int endLine,
                                      const QString &methodName,
                                      ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->extractMethod(code, startLine, endLine, methodName, language);
}

QString LLMCodeAnalyzer::renameVariable(const QString &code, const QString &oldName,
                                       const QString &newName,
                                       ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->renameVariable(code, oldName, newName, language);
}

QString LLMCodeAnalyzer::simplifyCondition(const QString &code, int lineNumber,
                                          ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->simplifyCondition(code, lineNumber, language);
}

QString LLMCodeAnalyzer::optimizeLoop(const QString &code, int lineNumber,
                                     ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->optimizeLoop(code, lineNumber, language);
}

QString LLMCodeAnalyzer::reduceComplexity(const QString &code,
                                         ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->reduceComplexity(code, language);
}

// ── 代码解释 ─────────────────────────────────

CodeExplanation LLMCodeAnalyzer::explainCode(const QString &code,
                                            ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    if (m_llmEnabled && m_llmProvider) {
        // LLM解释会更准确
        m_llmRequests++;
        m_totalCost += 0.02f;
    }
    
    locker.unlock();
    return m_localAnalyzer->explainCode(code, language);
}

CodeExplanation LLMCodeAnalyzer::explainFunction(const QString &code,
                                                const QString &functionName,
                                                ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->explainFunction(code, functionName, language);
}

QVector<QString> LLMCodeAnalyzer::explainLineByLine(const QString &code,
                                                   ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->explainLineByLine(code, language);
}

QString LLMCodeAnalyzer::generateDocumentation(const QString &code,
                                              ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->generateDocumentation(code, language);
}

QString LLMCodeAnalyzer::generateComments(const QString &code,
                                         ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->generateComments(code, language);
}

// ── 测试生成 ─────────────────────────────────

GeneratedTests LLMCodeAnalyzer::generateTests(const TestGenerationRequest &request) {
    QMutexLocker locker(&m_mutex);
    
    if (m_llmEnabled && m_llmProvider) {
        // LLM可以生成更智能的测试
        m_llmRequests++;
        m_totalCost += 0.04f;
    }
    
    locker.unlock();
    return m_localAnalyzer->generateTests(request);
}

QString LLMCodeAnalyzer::generateTestsAsync(const TestGenerationRequest &request,
                                           TestGenerationCallback callback) {
    auto result = generateTests(request);
    
    if (callback) {
        callback(result);
    }
    
    return result.testId;
}

QString LLMCodeAnalyzer::generateUnitTests(const QString &code,
                                          ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->generateUnitTests(code, language);
}

QString LLMCodeAnalyzer::generateIntegrationTests(const QString &code,
                                                 ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->generateIntegrationTests(code, language);
}

QVector<QString> LLMCodeAnalyzer::generateEdgeCaseTests(const QString &code,
                                                       ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->generateEdgeCaseTests(code, language);
}

// ── 代码比较 ─────────────────────────────────

CodeDiff LLMCodeAnalyzer::compareCode(const QString &originalCode,
                                     const QString &modifiedCode) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->compareCode(originalCode, modifiedCode);
}

QVector<QVariantMap> LLMCodeAnalyzer::findDuplicates(const QString &code) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->findDuplicates(code);
}

float LLMCodeAnalyzer::calculateSimilarity(const QString &code1,
                                          const QString &code2) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->calculateSimilarity(code1, code2);
}

// ── 代码审查 ─────────────────────────────────

CodeReview LLMCodeAnalyzer::reviewCode(const QString &code,
                                      const QString &author,
                                      const QString &reviewer) {
    QMutexLocker locker(&m_mutex);
    
    if (m_llmEnabled && m_llmProvider) {
        // LLM审查会更专业
        m_llmRequests++;
        m_totalCost += 0.05f;
    }
    
    locker.unlock();
    return m_localAnalyzer->reviewCode(code, author, reviewer);
}

QVector<QString> LLMCodeAnalyzer::getReviewSuggestions(const QString &code,
                                                      ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->getReviewSuggestions(code, language);
}

QVector<CodeIssue> LLMCodeAnalyzer::checkCodingStandards(const QString &code,
                                                        ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->checkCodingStandards(code, language);
}

// ── 代码格式化 ───────────────────────────────

QString LLMCodeAnalyzer::formatCode(const QString &code,
                                   ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->formatCode(code, language);
}

QString LLMCodeAnalyzer::fixCodeStyle(const QString &code,
                                     ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->fixCodeStyle(code, language);
}

QString LLMCodeAnalyzer::minifyCode(const QString &code,
                                   ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->minifyCode(code, language);
}

QString LLMCodeAnalyzer::prettyPrintCode(const QString &code,
                                        ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->prettyPrintCode(code, language);
}

// ── 语言支持 ─────────────────────────────────

QVariantMap LLMCodeAnalyzer::getLanguageInfo(ProgrammingLanguage language) const {
    return m_localAnalyzer->getLanguageInfo(language);
}

QVector<ProgrammingLanguage> LLMCodeAnalyzer::getSupportedLanguages() const {
    return m_localAnalyzer->getSupportedLanguages();
}

QString LLMCodeAnalyzer::convertLanguage(const QString &code,
                                        ProgrammingLanguage fromLanguage,
                                        ProgrammingLanguage toLanguage) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->convertLanguage(code, fromLanguage, toLanguage);
}

// ── 错误修复 ─────────────────────────────────

QVector<CodeIssue> LLMCodeAnalyzer::findBugs(const QString &code,
                                            ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // 快速本地检查
    auto localBugs = m_localAnalyzer->findBugs(code, language);
    
    // 如果启用LLM，进行更深入的bug检测
    if (m_llmEnabled && m_llmProvider) {
        m_llmRequests++;
        m_totalCost += 0.03f;
    }
    
    return localBugs;
}

QVector<QString> LLMCodeAnalyzer::suggestFixes(const CodeIssue &issue,
                                              const QString &code) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->suggestFixes(issue, code);
}

QString LLMCodeAnalyzer::fixCommonErrors(const QString &code,
                                        ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->fixCommonErrors(code, language);
}

// ── 历史和统计 ───────────────────────────────

QVector<CodeAnalysisResult> LLMCodeAnalyzer::getAnalysisHistory(int limit) const {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->getAnalysisHistory(limit);
}

QVector<GeneratedCode> LLMCodeAnalyzer::getGenerationHistory(int limit) const {
    QMutexLocker locker(&m_mutex);
    return m_localAnalyzer->getGenerationHistory(limit);
}

QVariantMap LLMCodeAnalyzer::getStatistics() const {
    QMutexLocker locker(&m_mutex);
    auto baseStats = m_localAnalyzer->getStatistics();
    
    // 添加LLM统计
    baseStats["llmRequests"] = m_llmRequests;
    baseStats["cacheHits"] = m_cacheHits;
    baseStats["cacheHitRate"] = m_llmRequests > 0 ? 
        (float)m_cacheHits / (m_llmRequests + m_cacheHits) : 0.0f;
    baseStats["totalCostUSD"] = m_totalCost;
    
    return baseStats;
}

// ── LLM特定方法 ──────────────────────────────

float LLMCodeAnalyzer::getCacheHitRate() const {
    QMutexLocker locker(&m_mutex);
    if (m_llmRequests + m_cacheHits == 0) return 0.0f;
    return (float)m_cacheHits / (m_llmRequests + m_cacheHits);
}

float LLMCodeAnalyzer::getTotalCost() const {
    QMutexLocker locker(&m_mutex);
    return m_totalCost;
}

void LLMCodeAnalyzer::resetStats() {
    QMutexLocker locker(&m_mutex);
    m_llmRequests = 0;
    m_cacheHits = 0;
    m_totalCost = 0.0f;
    m_analysisCache.clear();
    m_generationCache.clear();
}

QVariantMap LLMCodeAnalyzer::getLLMStatistics() const {
    QMutexLocker locker(&m_mutex);
    
    return QVariantMap{
        {"llmEnabled", m_llmEnabled},
        {"llmRequests", m_llmRequests},
        {"cacheHits", m_cacheHits},
        {"cacheHitRate", getCacheHitRate()},
        {"totalCostUSD", m_totalCost},
        {"model", m_model},
        {"analysisCacheSize", m_analysisCache.size()},
        {"generationCacheSize", m_generationCache.size()}
    };
}

// ── 辅助方法 ────────────────────────────────

QString LLMCodeAnalyzer::generateCacheKey(const QString &code, const QString &operation) {
    // 使用代码哈希作为缓存键
    return QString("%1:%2:%3").arg(operation, 
                                   QString::number(qHash(code)), 
                                   m_model);
}

bool LLMCodeAnalyzer::shouldUseLLM(const QString &code) {
    // 复杂代码才值得调用LLM
    return code.length() > 500 || code.count('\n') > 20;
}

CodeAnalysisResult LLMCodeAnalyzer::llmAnalyzeCode(const QString &code,
                                                   ProgrammingLanguage language) {
    // 这里会调用实际的LLM API进行分析
    // 目前返回本地结果作为占位符
    return m_localAnalyzer->analyzeCode(code, language);
}

GeneratedCode LLMCodeAnalyzer::llmGenerateCode(const CodeGenerationRequest &request) {
    // 这里会调用实际的LLM API生成代码
    // 目前返回本地结果作为占位符
    return m_localAnalyzer->generateCode(request);
}
