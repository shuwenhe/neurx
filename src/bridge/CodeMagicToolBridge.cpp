#include "CodeMagicToolBridge.h"
#include <QDebug>
#include <QDateTime>
#include <QCryptographicHash>
#include <QRegularExpression>

namespace {

ProgrammingLanguage parseProgrammingLanguage(const QString &language)
{
    const QString value = language.trimmed().toLower();
    if (value == "python" || value == "py") return ProgrammingLanguage::Python;
    if (value == "javascript" || value == "js") return ProgrammingLanguage::JavaScript;
    if (value == "typescript" || value == "ts") return ProgrammingLanguage::TypeScript;
    if (value == "java") return ProgrammingLanguage::Java;
    if (value == "csharp" || value == "c#") return ProgrammingLanguage::CSharp;
    if (value == "cpp" || value == "c++" || value == "cc") return ProgrammingLanguage::Cpp;
    if (value == "c") return ProgrammingLanguage::C;
    if (value == "go" || value == "golang") return ProgrammingLanguage::Go;
    if (value == "rust" || value == "rs") return ProgrammingLanguage::Rust;
    if (value == "ruby" || value == "rb") return ProgrammingLanguage::Ruby;
    if (value == "php") return ProgrammingLanguage::PHP;
    if (value == "swift") return ProgrammingLanguage::Swift;
    if (value == "kotlin" || value == "kt") return ProgrammingLanguage::Kotlin;
    if (value == "sql") return ProgrammingLanguage::SQL;
    if (value == "html") return ProgrammingLanguage::HTML;
    if (value == "css") return ProgrammingLanguage::CSS;
    if (value == "scala") return ProgrammingLanguage::Scala;
    if (value == "haskell" || value == "hs") return ProgrammingLanguage::Haskell;
    return ProgrammingLanguage::Unknown;
}

RefactoringType parseRefactoringType(const QString &type)
{
    const QString value = type.trimmed().toLower();
    if (value == "extractmethod" || value == "extract_method") return RefactoringType::ExtractMethod;
    if (value == "inlinevariable" || value == "inline_variable") return RefactoringType::InlineVariable;
    if (value == "renamevariable" || value == "rename_variable") return RefactoringType::RenameVariable;
    if (value == "movefunction" || value == "move_function") return RefactoringType::MoveFunction;
    if (value == "extractclass" || value == "extract_class") return RefactoringType::ExtractClass;
    if (value == "simplifycondition" || value == "simplify_condition") return RefactoringType::SimplifyCondition;
    if (value == "optimizeloop" || value == "optimize_loop") return RefactoringType::OptimizeLoop;
    if (value == "reducecomplexity" || value == "reduce_complexity") return RefactoringType::ReduceComplexity;
    if (value == "improvereadability" || value == "improve_readability") return RefactoringType::ImproveReadability;
    return RefactoringType::Custom;
}

QString languageName(ProgrammingLanguage language)
{
    switch (language) {
    case ProgrammingLanguage::Python: return "python";
    case ProgrammingLanguage::JavaScript: return "javascript";
    case ProgrammingLanguage::TypeScript: return "typescript";
    case ProgrammingLanguage::Java: return "java";
    case ProgrammingLanguage::CSharp: return "csharp";
    case ProgrammingLanguage::Cpp: return "cpp";
    case ProgrammingLanguage::C: return "c";
    case ProgrammingLanguage::Go: return "go";
    case ProgrammingLanguage::Rust: return "rust";
    case ProgrammingLanguage::Ruby: return "ruby";
    case ProgrammingLanguage::PHP: return "php";
    case ProgrammingLanguage::Swift: return "swift";
    case ProgrammingLanguage::Kotlin: return "kotlin";
    case ProgrammingLanguage::SQL: return "sql";
    case ProgrammingLanguage::HTML: return "html";
    case ProgrammingLanguage::CSS: return "css";
    case ProgrammingLanguage::Scala: return "scala";
    case ProgrammingLanguage::Haskell: return "haskell";
    default: return "unknown";
    }
}

} // namespace

CodeMagicToolBridge::CodeMagicToolBridge(
    std::shared_ptr<ClaudeToolSystem> toolSystem,
    std::shared_ptr<DefaultCodeMagic> codeMagic)
    : m_toolSystem(toolSystem), m_codeMagic(codeMagic) {
}

bool CodeMagicToolBridge::registerAllTools() {
    QVector<QString> toolIds = {
        "code-analyzer",
        "code-refactor",
        "code-generator",
        "complexity-checker",
        "security-analyzer",
        "performance-analyzer"
    };

    bool allSuccess = true;
    for (const auto &toolId : toolIds) {
        if (!registerTool(toolId)) {
            qWarning() << "Failed to register tool:" << toolId;
            allSuccess = false;
        }
    }

    return allSuccess;
}

bool CodeMagicToolBridge::registerTool(const QString &toolId) {
    if (m_registeredTools.contains(toolId)) {
        return true;  // 已注册
    }

    auto toolSystem = m_toolSystem;
    if (!toolSystem) {
        qWarning() << "ToolSystem is nullptr";
        return false;
    }

    ToolSchema schema;
    QVector<ToolCapabilityDefinition> capabilities;

    if (toolId == "code-analyzer") {
        schema.toolId = "code-analyzer";
        schema.name = "Code Analyzer";
        schema.description = "Analyze code for issues, bugs, and code quality problems";
        schema.category = "CodeAnalysis";
        schema.author = "Claude Code System";
        schema.version = "1.0.0";

        ToolCapabilityDefinition cap;
        cap.name = "analyze";
        cap.description = "Analyze code for issues";
        cap.inputParams = {"code", "language"};
        cap.outputParams = {"issues", "metrics"};
        capabilities.append(cap);

    } else if (toolId == "code-refactor") {
        schema.toolId = "code-refactor";
        schema.name = "Code Refactor";
        schema.description = "Provide code refactoring suggestions";
        schema.category = "CodeRefactoring";
        schema.author = "Claude Code System";
        schema.version = "1.0.0";

        ToolCapabilityDefinition cap;
        cap.name = "refactor";
        cap.description = "Generate refactoring suggestions";
        cap.inputParams = {"code", "language", "refactorType"};
        cap.outputParams = {"success", "refactoredCode", "explanation"};
        capabilities.append(cap);

    } else if (toolId == "code-generator") {
        schema.toolId = "code-generator";
        schema.name = "Code Generator";
        schema.description = "Generate code from description";
        schema.category = "CodeGeneration";
        schema.author = "Claude Code System";
        schema.version = "1.0.0";

        ToolCapabilityDefinition cap;
        cap.name = "generate";
        cap.description = "Generate code from description";
        cap.inputParams = {"description", "language"};
        cap.outputParams = {"code", "explanation"};
        capabilities.append(cap);

    } else if (toolId == "complexity-checker") {
        schema.toolId = "complexity-checker";
        schema.name = "Complexity Checker";
        schema.description = "Check code complexity (cyclomatic, cognitive, etc)";
        schema.category = "CodeAnalysis";
        schema.author = "Claude Code System";
        schema.version = "1.0.0";

        ToolCapabilityDefinition cap;
        cap.name = "check";
        cap.description = "Calculate code complexity metrics";
        cap.inputParams = {"code", "language"};
        cap.outputParams = {"cyclomaticComplexity", "level"};
        capabilities.append(cap);

    } else if (toolId == "security-analyzer") {
        schema.toolId = "security-analyzer";
        schema.name = "Security Analyzer";
        schema.description = "Detect security vulnerabilities in code";
        schema.category = "Security";
        schema.author = "Claude Code System";
        schema.version = "1.0.0";

        ToolCapabilityDefinition cap;
        cap.name = "analyze";
        cap.description = "Detect security issues";
        cap.inputParams = {"code", "language"};
        cap.outputParams = {"vulnerabilitiesFound", "severity"};
        capabilities.append(cap);

    } else if (toolId == "performance-analyzer") {
        schema.toolId = "performance-analyzer";
        schema.name = "Performance Analyzer";
        schema.description = "Identify performance issues and optimization opportunities";
        schema.category = "Performance";
        schema.author = "Claude Code System";
        schema.version = "1.0.0";

        ToolCapabilityDefinition cap;
        cap.name = "analyze";
        cap.description = "Find performance issues";
        cap.inputParams = {"code", "language"};
        cap.outputParams = {"performanceIssues", "hasBottlenecks"};
        capabilities.append(cap);

    } else {
        qWarning() << "Unknown tool ID:" << toolId;
        return false;
    }

    // 设置基本属性
    schema.capabilities = capabilities;
    schema.category = "Code";
    schema.tags = QStringList{"code", "analysis", "refactor"};
    schema.minPermissionLevel = PermissionLevel::Internal;

    // 注册工具
    ToolPermission permission;
    permission.toolId = toolId;
    permission.level = PermissionLevel::Internal;
    permission.scope = PermissionScope::Workspace;

    auto registeredId = toolSystem->registerTool(schema, permission);

    if (registeredId.isEmpty()) {
        qWarning() << "Failed to register tool:" << toolId;
        return false;
    }

    m_registeredTools.insert(toolId);
    qDebug() << "Tool registered successfully:" << toolId;
    return true;
}

// ── 工具执行 ────────────────────────────────────────

ToolExecutionResult CodeMagicToolBridge::executeCodeAnalyzer(const QVariantMap &parameters) {
    QString code = parameters.value("code", "").toString();
    QString language = parameters.value("language", "cpp").toString();

    if (code.isEmpty()) {
        ToolExecutionResult result;
        result.status = ExecutionStatus::Failed;
        result.error = "Code parameter is empty";
        return result;
    }

    // 调用CodeMagic API
    const auto analysisResult = m_codeMagic->analyzeCode(code, parseProgrammingLanguage(language));
    const auto metrics = m_codeMagic->getCodeMetrics(code);

    QVariantMap resultMap;
    resultMap["issues"] = analysisResult.issues.size();
    resultMap["metrics"] = QVariantMap{
        {"lines", analysisResult.lineCount},
        {"characters", analysisResult.characterCount},
        {"complexity", analysisResult.complexity},
        {"functions", metrics.value("functions")}
    };
    resultMap["quality"] = analysisResult.quality;
    resultMap["maintainability"] = analysisResult.maintainability;
    resultMap["security"] = analysisResult.security;
    resultMap["performance"] = analysisResult.performance;

    QString executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    return convertResult(executionId, "code-analyzer", resultMap);
}

ToolExecutionResult CodeMagicToolBridge::executeCodeRefactor(const QVariantMap &parameters) {
    QString code = parameters.value("code", "").toString();
    QString language = parameters.value("language", "cpp").toString();
    QString refactorType = parameters.value("refactorType", "general").toString();

    if (code.isEmpty()) {
        ToolExecutionResult result;
        result.status = ExecutionStatus::Failed;
        result.error = "Code parameter is empty";
        return result;
    }

    // 构造重构请求
    RefactoringRequest request;
    request.code = code;
    request.type = parseRefactoringType(refactorType);
    request.description = refactorType;
    request.options["language"] = language;

    auto refactoringResult = m_codeMagic->refactorCode(request);

    QVariantMap resultMap;
    resultMap["success"] = refactoringResult.successful;
    resultMap["originalCode"] = code;
    resultMap["refactoredCode"] = refactoringResult.refactoredCode;
    resultMap["explanation"] = refactoringResult.explanation;
    resultMap["suggestions"] = QVariantList();

    QString executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    return convertResult(executionId, "code-refactor", resultMap);
}

ToolExecutionResult CodeMagicToolBridge::executeCodeGenerator(const QVariantMap &parameters) {
    QString description = parameters.value("description", "").toString();
    QString language = parameters.value("language", "cpp").toString();

    if (description.isEmpty()) {
        ToolExecutionResult result;
        result.status = ExecutionStatus::Failed;
        result.error = "Description parameter is empty";
        return result;
    }

    // 构造生成请求
    CodeGenerationRequest request;
    request.description = description;
    request.language = parseProgrammingLanguage(language);

    auto generatedCode = m_codeMagic->generateCode(request);

    QVariantMap resultMap;
    resultMap["code"] = generatedCode.code;
    resultMap["explanation"] = generatedCode.explanation;
    resultMap["language"] = language;

    QString executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    return convertResult(executionId, "code-generator", resultMap);
}

ToolExecutionResult CodeMagicToolBridge::executeComplexityChecker(const QVariantMap &parameters) {
    QString code = parameters.value("code", "").toString();
    QString language = parameters.value("language", "cpp").toString();

    if (code.isEmpty()) {
        ToolExecutionResult result;
        result.status = ExecutionStatus::Failed;
        result.error = "Code parameter is empty";
        return result;
    }

    // 计算复杂度
    int complexity = m_codeMagic->calculateComplexity(code);

    QVariantMap resultMap;
    resultMap["cyclomaticComplexity"] = complexity;
    resultMap["level"] = complexity > 10 ? "High" : (complexity > 5 ? "Medium" : "Low");

    QString executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    return convertResult(executionId, "complexity-checker", resultMap);
}

ToolExecutionResult CodeMagicToolBridge::executeSecurityAnalyzer(const QVariantMap &parameters) {
    QString code = parameters.value("code", "").toString();
    QString language = parameters.value("language", "cpp").toString();

    if (code.isEmpty()) {
        ToolExecutionResult result;
        result.status = ExecutionStatus::Failed;
        result.error = "Code parameter is empty";
        return result;
    }

    // 查找安全问题
    auto issues = m_codeMagic->findSecurityIssues(code, parseProgrammingLanguage(language));

    QVariantMap resultMap;
    resultMap["vulnerabilitiesFound"] = issues.size();
    resultMap["severity"] = "Medium";  // 简化

    QString executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    return convertResult(executionId, "security-analyzer", resultMap);
}

ToolExecutionResult CodeMagicToolBridge::executePerformanceAnalyzer(const QVariantMap &parameters) {
    QString code = parameters.value("code", "").toString();
    QString language = parameters.value("language", "cpp").toString();

    if (code.isEmpty()) {
        ToolExecutionResult result;
        result.status = ExecutionStatus::Failed;
        result.error = "Code parameter is empty";
        return result;
    }

    // 查找性能问题
    auto issues = m_codeMagic->findPerformanceIssues(code, parseProgrammingLanguage(language));

    QVariantMap resultMap;
    resultMap["performanceIssues"] = issues.size();
    resultMap["hasBottlenecks"] = issues.size() > 0;

    QString executionId = QString::number(QDateTime::currentDateTime().toMSecsSinceEpoch());
    return convertResult(executionId, "performance-analyzer", resultMap);
}

// ── 统计和管理 ────────────────────────────────────────

QVariantMap CodeMagicToolBridge::getStatistics() const {
    QVariantMap stats;
    stats["totalExecutions"] = m_totalExecutions;
    stats["cacheHits"] = m_cacheHits;
    stats["cacheMisses"] = m_cacheMisses;
    stats["cacheSize"] = m_cache.size();
    stats["registeredTools"] = static_cast<int>(m_registeredTools.size());

    if (m_totalExecutions > 0) {
        const int cacheSamples = m_cacheHits + m_cacheMisses;
        stats["cacheHitRate"] = cacheSamples > 0
            ? static_cast<float>(m_cacheHits) / cacheSamples
            : 0.0f;
    }

    return stats;
}

void CodeMagicToolBridge::clearCache() {
    m_cache.clear();
    m_cacheHits = 0;
    m_cacheMisses = 0;
}

// ── 私有方法 ────────────────────────────────────────

ToolSchema CodeMagicToolBridge::createToolSchema(
    const QString &toolId,
    const QString &name,
    const QString &description,
    const QVector<ToolCapabilityDefinition> &capabilities) {

    ToolSchema schema;
    schema.toolId = toolId;
    schema.name = name;
    schema.description = description;
    schema.capabilities = capabilities;
    schema.category = "Code";
    schema.author = "CodeMagic Integration";
    schema.version = "1.0.0";

    return schema;
}

ToolExecutionResult CodeMagicToolBridge::convertResult(
    const QString &executionId,
    const QString &toolId,
    const QVariantMap &codeMagicResult) {

    ToolExecutionResult result;
    result.executionId = executionId;
    result.toolId = toolId;
    result.status = ExecutionStatus::Completed;
    result.result = codeMagicResult;
    result.durationMs = 100;  // 简化
    result.fromCache = false;
    result.costEstimate = 0.01f;

    return result;
}

QString CodeMagicToolBridge::generateCacheKey(const QString &toolId, const QVariantMap &parameters) {
    QString key = toolId;

    for (auto it = parameters.begin(); it != parameters.end(); ++it) {
        key += "_" + it.key() + ":" + it.value().toString();
    }

    QByteArray hash = QCryptographicHash::hash(key.toUtf8(), QCryptographicHash::Md5);
    return hash.toHex();
}

bool CodeMagicToolBridge::hasCache(const QString &cacheKey) {
    return m_cache.contains(cacheKey);
}

QVariantMap CodeMagicToolBridge::getCache(const QString &cacheKey) {
    if (m_cache.contains(cacheKey)) {
        m_cacheHits++;
        return m_cache[cacheKey];
    }
    m_cacheMisses++;
    return QVariantMap();
}

void CodeMagicToolBridge::setCache(const QString &cacheKey, const QVariantMap &result) {
    m_cache[cacheKey] = result;
}
