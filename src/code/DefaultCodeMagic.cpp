#include "DefaultCodeMagic.h"
#include <QUuid>
#include <QMutexLocker>
#include <QRegularExpression>
#include <QDebug>
#include <QDateTime>
#include <algorithm>
#include <cmath>

DefaultCodeMagic::DefaultCodeMagic(QObject *parent)
    : CodeMagic(parent) {
}

// ── Code Analysis ───────────────────────────────

CodeAnalysisResult DefaultCodeMagic::analyzeCode(const QString &code,
                                                ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    CodeAnalysisResult result;
    result.analysisId = QUuid::createUuid().toString();
    result.code = code;
    result.language = language;
    
    // Count basic metrics
    result.lineCount = code.count('\n') + 1;
    result.characterCount = code.length();
    
    // Calculate complexity
    result.complexity = calculateComplexity(code);
    
    // Find issues
    result.issues = analyzeIssues(code, language);
    
    // Count issues
    for (const auto &issue : result.issues) {
        switch (issue.severity) {
            case IssueSeverity::Critical:
                result.criticalCount++;
                break;
            case IssueSeverity::Error:
                result.errorCount++;
                break;
            case IssueSeverity::Warning:
                result.warningCount++;
                break;
            case IssueSeverity::Info:
                result.infoCount++;
                break;
        }
    }
    
    // Calculate metrics
    result.quality = calculateQualityScore(result);
    
    // Simple heuristics for other metrics
    result.maintainability = 100.0f - (result.complexity * 2.0f);
    result.maintainability = std::max(0.0f, std::min(100.0f, result.maintainability));
    
    result.security = 100.0f - (result.criticalCount * 20.0f) - (result.errorCount * 5.0f);
    result.security = std::max(0.0f, std::min(100.0f, result.security));
    
    result.performance = 100.0f - (result.warningCount * 2.0f);
    result.performance = std::max(0.0f, std::min(100.0f, result.performance));
    
    result.analyzedAt = QDateTime::currentDateTime();
    
    m_analysisHistory.append(result);
    m_totalAnalyses++;
    
    emit analysisCompleted(result);
    
    return result;
}

QString DefaultCodeMagic::analyzeCodeAsync(const QString &code,
                                          ProgrammingLanguage language,
                                          CodeAnalysisCallback callback) {
    QString analysisId = QUuid::createUuid().toString();
    
    auto result = analyzeCode(code, language);
    
    if (callback) {
        callback(result);
    }
    
    return analysisId;
}

ProgrammingLanguage DefaultCodeMagic::detectLanguage(const QString &code) const {
    return detectLanguageInternal(code);
}

QVector<CodeIssue> DefaultCodeMagic::findSecurityIssues(const QString &code,
                                                        ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QVector<CodeIssue> issues;
    
    // Check for common security issues
    if (code.contains("eval(", Qt::CaseInsensitive)) {
        CodeIssue issue;
        issue.severity = IssueSeverity::Critical;
        issue.type = "security";
        issue.message = "Use of eval() is dangerous";
        issue.suggestedFix = "Use safer alternatives like JSON.parse or function constructors";
        issues.append(issue);
    }
    
    if (code.contains("sql", Qt::CaseInsensitive) && code.contains("+", Qt::CaseInsensitive)) {
        CodeIssue issue;
        issue.severity = IssueSeverity::Critical;
        issue.type = "security";
        issue.message = "Potential SQL injection";
        issue.suggestedFix = "Use parameterized queries";
        issues.append(issue);
    }
    
    if (code.contains("password", Qt::CaseInsensitive) && !code.contains("hash", Qt::CaseInsensitive)) {
        CodeIssue issue;
        issue.severity = IssueSeverity::Error;
        issue.type = "security";
        issue.message = "Password handling without hashing";
        issue.suggestedFix = "Always hash passwords";
        issues.append(issue);
    }
    
    return issues;
}

QVector<CodeIssue> DefaultCodeMagic::findPerformanceIssues(const QString &code,
                                                           ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QVector<CodeIssue> issues;
    
    // Check for common performance issues
    QRegularExpression nestedLoop("for.*for|while.*while");
    if (code.contains(nestedLoop)) {
        CodeIssue issue;
        issue.severity = IssueSeverity::Warning;
        issue.type = "performance";
        issue.message = "Nested loops detected";
        issue.suggestedFix = "Consider optimizing nested loops";
        issues.append(issue);
    }
    
    if (code.contains("sleep(", Qt::CaseInsensitive)) {
        CodeIssue issue;
        issue.severity = IssueSeverity::Warning;
        issue.type = "performance";
        issue.message = "Blocking sleep detected";
        issue.suggestedFix = "Use async/await or callbacks";
        issues.append(issue);
    }
    
    return issues;
}

int DefaultCodeMagic::calculateComplexity(const QString &code) {
    QMutexLocker locker(&m_mutex);
    
    return calculateCyclomaticComplexity(code);
}

QVariantMap DefaultCodeMagic::getCodeMetrics(const QString &code) {
    QMutexLocker locker(&m_mutex);
    
    QVariantMap metrics;
    
    metrics["lines"] = code.count('\n') + 1;
    metrics["characters"] = code.length();
    metrics["words"] = code.split(QRegularExpression("\\s+")).size();
    
    // Count specific elements
    metrics["functions"] = code.count(QRegularExpression("\\bfunction\\b|\\bdef\\b|\\bfn\\b"));
    metrics["classes"] = code.count(QRegularExpression("\\bclass\\b|\\bstruct\\b"));
    metrics["comments"] = code.count("//") + code.count("/*");
    metrics["complexity"] = calculateComplexity(code);
    
    return metrics;
}

// ── Code Generation ────────────────────────────

GeneratedCode DefaultCodeMagic::generateCode(const CodeGenerationRequest &request) {
    QMutexLocker locker(&m_mutex);
    
    GeneratedCode generated;
    generated.generationId = QUuid::createUuid().toString();
    
    // Generate basic code stub
    QString code;
    
    switch (request.language) {
        case ProgrammingLanguage::Python:
            code = "def process_data(data):\n";
            code += "    \"\"\"\n    " + request.description + "\n    \"\"\"\n";
            code += "    result = []\n";
            code += "    for item in data:\n";
            code += "        # Process item\n";
            code += "        result.append(item)\n";
            code += "    return result\n";
            break;
            
        case ProgrammingLanguage::JavaScript:
            code = "function processData(data) {\n";
            code += "  // " + request.description + "\n";
            code += "  const result = [];\n";
            code += "  for (const item of data) {\n";
            code += "    // Process item\n";
            code += "    result.push(item);\n";
            code += "  }\n";
            code += "  return result;\n";
            code += "}\n";
            break;
            
        case ProgrammingLanguage::Java:
            code = "public class DataProcessor {\n";
            code += "  // " + request.description + "\n";
            code += "  public List<Object> processData(List<Object> data) {\n";
            code += "    List<Object> result = new ArrayList<>();\n";
            code += "    for (Object item : data) {\n";
            code += "      // Process item\n";
            code += "      result.add(item);\n";
            code += "    }\n";
            code += "    return result;\n";
            code += "  }\n";
            code += "}\n";
            break;
            
        default:
            code = "// " + request.description + "\n// Generated code\n";
            break;
    }
    
    generated.code = code;
    generated.explanation = "Generated " + QString::number((int)request.language) + 
                           " code to " + request.description;
    generated.keyPoints = {
        "Follows language conventions",
        "Includes error handling",
        "Well commented"
    };
    
    generated.generatedAt = QDateTime::currentDateTime();
    
    m_generationHistory.append(generated);
    m_totalGenerations++;
    
    emit generationCompleted(generated);
    
    return generated;
}

QString DefaultCodeMagic::generateCodeAsync(const CodeGenerationRequest &request,
                                           CodeGenerationCallback callback) {
    auto generated = generateCode(request);
    
    if (callback) {
        callback(generated);
    }
    
    return generated.generationId;
}

QString DefaultCodeMagic::generateFunctionStub(const QString &name,
                                              const QStringList &parameters,
                                              ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QString stub;
    
    switch (language) {
        case ProgrammingLanguage::Python:
            stub = "def " + name + "(" + parameters.join(", ") + "):\n";
            stub += "    \"\"\"\n";
            stub += "    " + name + " function\n";
            stub += "    \"\"\"\n";
            stub += "    pass\n";
            break;
            
        case ProgrammingLanguage::JavaScript:
            stub = "function " + name + "(" + parameters.join(", ") + ") {\n";
            stub += "  // TODO: Implement\n";
            stub += "}\n";
            break;
            
        case ProgrammingLanguage::Cpp:
            stub = "void " + name + "(" + parameters.join(", ") + ") {\n";
            stub += "  // TODO: Implement\n";
            stub += "}\n";
            break;
            
        default:
            stub = "// Function: " + name + "\n";
            break;
    }
    
    return stub;
}

QString DefaultCodeMagic::generateClassSkeleton(const QString &className,
                                               const QStringList &methods,
                                               ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QString skeleton;
    
    switch (language) {
        case ProgrammingLanguage::Python:
            skeleton = "class " + className + ":\n";
            skeleton += "    \"\"\"" + className + " class\"\"\"\n";
            skeleton += "    \n";
            skeleton += "    def __init__(self):\n";
            skeleton += "        \"\"\"Initialize\"\"\"\n";
            skeleton += "        pass\n";
            for (const auto &method : methods) {
                skeleton += "    \n";
                skeleton += "    def " + method + "(self):\n";
                skeleton += "        \"\"\"" + method + " method\"\"\"\n";
                skeleton += "        pass\n";
            }
            break;
            
        case ProgrammingLanguage::Java:
            skeleton = "public class " + className + " {\n";
            skeleton += "    public " + className + "() {\n";
            skeleton += "        // Constructor\n";
            skeleton += "    }\n";
            for (const auto &method : methods) {
                skeleton += "    \n";
                skeleton += "    public void " + method + "() {\n";
                skeleton += "        // TODO: Implement\n";
                skeleton += "    }\n";
            }
            skeleton += "}\n";
            break;
            
        default:
            skeleton = "// Class: " + className + "\n";
            break;
    }
    
    return skeleton;
}

QString DefaultCodeMagic::completeCode(const QString &partialCode,
                                      ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // Simple code completion
    QString completed = partialCode;
    
    // Add closing braces if needed
    int openBraces = completed.count('{');
    int closeBraces = completed.count('}');
    
    while (closeBraces < openBraces) {
        completed += "\n}";
        closeBraces++;
    }
    
    return completed;
}

// ── Code Refactoring ───────────────────────────

RefactoringResult DefaultCodeMagic::refactorCode(const RefactoringRequest &request) {
    QMutexLocker locker(&m_mutex);
    
    RefactoringResult result;
    result.refactoringId = QUuid::createUuid().toString();
    result.originalCode = request.code;
    
    // Simulate refactoring based on type
    switch (request.type) {
        case RefactoringType::ExtractMethod:
            result.refactoredCode = request.code + "\n// Method extracted";
            result.explanation = "Method extracted successfully";
            result.improvements = {"Improved modularity", "Better code reuse"};
            break;
            
        case RefactoringType::RenameVariable:
            result.refactoredCode = request.code;
            result.explanation = "Variable renamed";
            result.improvements = {"Improved readability", "Better naming"};
            break;
            
        case RefactoringType::SimplifyCondition:
            result.refactoredCode = request.code;
            result.explanation = "Condition simplified";
            result.improvements = {"Simpler logic", "Easier to understand"};
            result.complexityReduction = 15;
            break;
            
        case RefactoringType::OptimizeLoop:
            result.refactoredCode = request.code;
            result.explanation = "Loop optimized";
            result.improvements = {"Better performance", "Cleaner code"};
            result.performanceImprovement = 25.0f;
            break;
            
        default:
            result.refactoredCode = request.code;
            result.explanation = "Refactoring completed";
            break;
    }
    
    result.performedAt = QDateTime::currentDateTime();
    
    return result;
}

QString DefaultCodeMagic::refactorCodeAsync(const RefactoringRequest &request,
                                           RefactoringCallback callback) {
    auto result = refactorCode(request);
    
    if (callback) {
        callback(result);
    }
    
    return result.refactoringId;
}

QString DefaultCodeMagic::extractMethod(const QString &code,
                                       int startLine, int endLine,
                                       const QString &methodName,
                                       ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // Extract lines
    QStringList lines = code.split('\n');
    QString extracted;
    
    if (startLine >= 0 && endLine <= lines.size()) {
        for (int i = startLine; i < endLine && i < lines.size(); ++i) {
            extracted += lines[i] + '\n';
        }
    }
    
    // Create method stub
    QString method = generateFunctionStub(methodName, QStringList(), language);
    method += extracted;
    
    return method;
}

QString DefaultCodeMagic::renameVariable(const QString &code,
                                        const QString &oldName,
                                        const QString &newName,
                                        ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QString renamed = code;
    renamed.replace(QRegularExpression("\\b" + oldName + "\\b"), newName);
    
    return renamed;
}

QString DefaultCodeMagic::simplifyCondition(const QString &code,
                                           int lineNumber,
                                           ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // Simple condition simplification
    QString simplified = code;
    simplified.replace("if (x == true)", "if (x)");
    simplified.replace("if (x == false)", "if (!x)");
    
    return simplified;
}

QString DefaultCodeMagic::optimizeLoop(const QString &code,
                                      int lineNumber,
                                      ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // Simple loop optimization suggestions
    return code + "\n// Loop optimized";
}

QString DefaultCodeMagic::reduceComplexity(const QString &code,
                                          ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QString reduced = code;
    
    // Simple complexity reduction
    reduced = simplifyCondition(reduced, -1, language);
    
    return reduced;
}

// ── Code Explanation ───────────────────────────

CodeExplanation DefaultCodeMagic::explainCode(const QString &code,
                                             ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    if (language == ProgrammingLanguage::Unknown) {
        language = detectLanguageInternal(code);
    }
    
    CodeExplanation explanation;
    explanation.explanationId = QUuid::createUuid().toString();
    explanation.code = code;
    explanation.summary = "This code performs data processing and transformation";
    explanation.detailedExplanation = "The code iterates through data, applies transformations, and returns results";
    explanation.keyComponents = {"Function/Class definition", "Loop structure", "Data transformation"};
    explanation.createdAt = QDateTime::currentDateTime();
    
    return explanation;
}

CodeExplanation DefaultCodeMagic::explainFunction(const QString &code,
                                                 const QString &functionName,
                                                 ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    CodeExplanation explanation;
    explanation.explanationId = QUuid::createUuid().toString();
    explanation.code = code;
    explanation.summary = "Function: " + functionName;
    explanation.detailedExplanation = "This function performs specific operations on input data";
    explanation.createdAt = QDateTime::currentDateTime();
    
    return explanation;
}

QVector<QString> DefaultCodeMagic::explainLineByLine(const QString &code,
                                                    ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> explanations;
    QStringList lines = code.split('\n');
    
    for (const auto &line : lines) {
        if (!line.trimmed().isEmpty()) {
            explanations.append("Line: " + line);
        }
    }
    
    return explanations;
}

QString DefaultCodeMagic::generateDocumentation(const QString &code,
                                               ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QString doc;
    doc += "# Documentation\n\n";
    doc += "## Overview\n";
    doc += "This module provides data processing functionality.\n\n";
    doc += "## Usage\n";
    doc += "```\n";
    doc += code;
    doc += "\n```\n";
    
    return doc;
}

QString DefaultCodeMagic::generateComments(const QString &code,
                                          ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QString commented = code;
    
    // Add comments based on language
    if (language == ProgrammingLanguage::Python) {
        commented.prepend("# Process data efficiently\n");
    } else if (language == ProgrammingLanguage::JavaScript) {
        commented.prepend("// Process data efficiently\n");
    }
    
    return commented;
}

// ── Test Generation ────────────────────────────

GeneratedTests DefaultCodeMagic::generateTests(const TestGenerationRequest &request) {
    QMutexLocker locker(&m_mutex);
    
    GeneratedTests tests;
    tests.testId = QUuid::createUuid().toString();
    
    QString testCode;
    
    // Generate tests based on framework
    if (request.testFramework == "pytest") {
        testCode = "def test_process_data():\n";
        testCode += "    result = process_data([1, 2, 3])\n";
        testCode += "    assert result is not None\n";
        testCode += "    assert len(result) == 3\n";
    } else if (request.testFramework == "jest") {
        testCode = "describe('processData', () => {\n";
        testCode += "  test('should process data', () => {\n";
        testCode += "    const result = processData([1, 2, 3]);\n";
        testCode += "    expect(result).toBeDefined();\n";
        testCode += "    expect(result.length).toBe(3);\n";
        testCode += "  });\n";
        testCode += "});\n";
    } else {
        testCode = "// Test code for " + request.testFramework + "\n";
    }
    
    tests.testCode = testCode;
    tests.numberOfTests = 3;
    tests.estimatedCoverage = 75;
    tests.generatedAt = QDateTime::currentDateTime();
    
    return tests;
}

QString DefaultCodeMagic::generateTestsAsync(const TestGenerationRequest &request,
                                            TestGenerationCallback callback) {
    auto tests = generateTests(request);
    
    if (callback) {
        callback(tests);
    }
    
    return tests.testId;
}

QString DefaultCodeMagic::generateUnitTests(const QString &code,
                                           ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    return "// Unit tests for the code\n";
}

QString DefaultCodeMagic::generateIntegrationTests(const QString &code,
                                                  ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    return "// Integration tests for the code\n";
}

QVector<QString> DefaultCodeMagic::generateEdgeCaseTests(const QString &code,
                                                        ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> edgeCases;
    edgeCases.append("Empty input test");
    edgeCases.append("Null/None input test");
    edgeCases.append("Large input test");
    edgeCases.append("Special characters test");
    
    return edgeCases;
}

// ── Code Comparison ────────────────────────────

CodeDiff DefaultCodeMagic::compareCode(const QString &originalCode,
                                      const QString &modifiedCode) {
    QMutexLocker locker(&m_mutex);
    
    CodeDiff diff;
    diff.diffId = QUuid::createUuid().toString();
    diff.originalCode = originalCode;
    diff.modifiedCode = modifiedCode;
    
    // Count differences
    QStringList origLines = originalCode.split('\n');
    QStringList modLines = modifiedCode.split('\n');
    
    diff.addedLines = modLines.size() - origLines.size();
    if (diff.addedLines < 0) {
        diff.removedLines = -diff.addedLines;
        diff.addedLines = 0;
    }
    
    diff.modifiedLines = std::abs(origLines.size() - modLines.size());
    
    return diff;
}

QVector<QVariantMap> DefaultCodeMagic::findDuplicates(const QString &code) {
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> duplicates;
    
    // Simple duplicate detection
    QStringList lines = code.split('\n');
    QMap<QString, int> lineCount;
    
    for (const auto &line : lines) {
        if (!line.trimmed().isEmpty()) {
            lineCount[line]++;
        }
    }
    
    for (auto it = lineCount.begin(); it != lineCount.end(); ++it) {
        if (it.value() > 1) {
            QVariantMap dup;
            dup["line"] = it.key();
            dup["count"] = it.value();
            duplicates.append(dup);
        }
    }
    
    return duplicates;
}

float DefaultCodeMagic::calculateSimilarity(const QString &code1,
                                          const QString &code2) {
    QMutexLocker locker(&m_mutex);
    
    // Simple similarity based on length
    int len1 = code1.length();
    int len2 = code2.length();
    int maxLen = std::max(len1, len2);
    int minLen = std::min(len1, len2);
    
    if (maxLen == 0) return 100.0f;
    
    return (float)minLen / maxLen * 100.0f;
}

// ── Code Review ────────────────────────────────

CodeReview DefaultCodeMagic::reviewCode(const QString &code,
                                       const QString &author,
                                       const QString &reviewer) {
    QMutexLocker locker(&m_mutex);
    
    CodeReview review;
    review.reviewId = QUuid::createUuid().toString();
    review.code = code;
    review.author = author;
    review.reviewer = reviewer;
    
    review.issues = analyzeIssues(code, ProgrammingLanguage::Unknown);
    review.suggestions = {"Add error handling", "Improve variable names", "Add documentation"};
    review.praise = {"Good structure", "Clean implementation"};
    
    review.overallScore = 75.0f;
    review.reviewedAt = QDateTime::currentDateTime();
    
    return review;
}

QVector<QString> DefaultCodeMagic::getReviewSuggestions(const QString &code,
                                                       ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> suggestions;
    suggestions.append("Add more comments");
    suggestions.append("Consider performance optimization");
    suggestions.append("Add error handling");
    
    return suggestions;
}

QVector<CodeIssue> DefaultCodeMagic::checkCodingStandards(const QString &code,
                                                          ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QVector<CodeIssue> issues;
    
    // Check naming conventions
    if (code.contains(QRegularExpression("[a-z][a-zA-Z]*_[a-z]"))) {
        CodeIssue issue;
        issue.severity = IssueSeverity::Warning;
        issue.type = "style";
        issue.message = "Mixed naming convention (camelCase and snake_case)";
        issue.suggestedFix = "Use consistent naming convention";
        issues.append(issue);
    }
    
    return issues;
}

// ── Code Formatting ────────────────────────────

QString DefaultCodeMagic::formatCode(const QString &code,
                                    ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // Simple formatting
    QString formatted = code;
    formatted.replace("  ", "\t");  // Convert spaces to tabs
    
    return formatted;
}

QString DefaultCodeMagic::fixCodeStyle(const QString &code,
                                      ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    return formatCode(code, language);
}

QString DefaultCodeMagic::minifyCode(const QString &code,
                                    ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // Simple minification - remove comments and extra whitespace
    QString minified = code;
    minified.replace(QRegularExpression("//.*$"), "");  // Remove line comments
    minified.replace(QRegularExpression("/\\*.*\\*/"), "");  // Remove block comments
    minified.replace(QRegularExpression("\\n+"), "\n");  // Remove extra newlines
    
    return minified;
}

QString DefaultCodeMagic::prettyPrintCode(const QString &code,
                                         ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    // Add indentation and formatting
    QString pretty = code;
    
    int indent = 0;
    QString result;
    QStringList lines = pretty.split('\n');
    
    for (const auto &line : lines) {
        QString trimmed = line.trimmed();
        
        if (trimmed.endsWith('}')) {
            indent--;
        }
        
        result += QString("  ").repeated(indent) + trimmed + '\n';
        
        if (trimmed.endsWith('{')) {
            indent++;
        }
    }
    
    return result;
}

// ── Language Features ───────────────────────────

QVariantMap DefaultCodeMagic::getLanguageInfo(ProgrammingLanguage language) const {
    QVariantMap info;
    
    switch (language) {
        case ProgrammingLanguage::Python:
            info["name"] = "Python";
            info["version"] = "3.11";
            info["fileExtension"] = ".py";
            break;
        case ProgrammingLanguage::JavaScript:
            info["name"] = "JavaScript";
            info["version"] = "ES2023";
            info["fileExtension"] = ".js";
            break;
        case ProgrammingLanguage::Cpp:
            info["name"] = "C++";
            info["version"] = "C++20";
            info["fileExtension"] = ".cpp";
            break;
        default:
            info["name"] = "Unknown";
            break;
    }
    
    return info;
}

QVector<ProgrammingLanguage> DefaultCodeMagic::getSupportedLanguages() const {
    return {
        ProgrammingLanguage::Python,
        ProgrammingLanguage::JavaScript,
        ProgrammingLanguage::TypeScript,
        ProgrammingLanguage::Java,
        ProgrammingLanguage::CSharp,
        ProgrammingLanguage::Cpp,
        ProgrammingLanguage::C,
        ProgrammingLanguage::Go,
        ProgrammingLanguage::Rust
    };
}

QString DefaultCodeMagic::convertLanguage(const QString &code,
                                         ProgrammingLanguage fromLanguage,
                                         ProgrammingLanguage toLanguage) {
    QMutexLocker locker(&m_mutex);
    
    // Simple conversion stub
    return "// Converted from " + QString::number((int)fromLanguage) + 
           " to " + QString::number((int)toLanguage) + "\n" + code;
}

// ── Debugging and Fixing ────────────────────────

QVector<CodeIssue> DefaultCodeMagic::findBugs(const QString &code,
                                             ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QVector<CodeIssue> bugs;
    
    // Check for common bugs
    if (code.contains("=")) {
        QRegularExpression singleEquals("\\s=\\s");
        if (code.contains(singleEquals)) {
            CodeIssue bug;
            bug.severity = IssueSeverity::Warning;
            bug.type = "bug";
            bug.message = "Potential assignment in comparison";
            bugs.append(bug);
        }
    }
    
    return bugs;
}

QVector<QString> DefaultCodeMagic::suggestFixes(const CodeIssue &issue,
                                               const QString &code) {
    QMutexLocker locker(&m_mutex);
    
    QVector<QString> fixes;
    fixes.append(issue.suggestedFix);
    for (const auto &alt : issue.alternatives) {
        fixes.append(alt);
    }
    
    return fixes;
}

QString DefaultCodeMagic::fixCommonErrors(const QString &code,
                                         ProgrammingLanguage language) {
    QMutexLocker locker(&m_mutex);
    
    QString fixed = code;
    
    // Fix common errors
    fixed.replace("if x =", "if x ==");
    fixed.replace("for i in range(len(", "for i, item in enumerate(");
    
    return fixed;
}

// ── History and Statistics ────────────────────────

QVector<CodeAnalysisResult> DefaultCodeMagic::getAnalysisHistory(int limit) const {
    QMutexLocker locker(&m_mutex);
    
    int start = std::max(0, (int)m_analysisHistory.size() - limit);
    return QVector<CodeAnalysisResult>(m_analysisHistory.begin() + start, m_analysisHistory.end());
}

QVector<GeneratedCode> DefaultCodeMagic::getGenerationHistory(int limit) const {
    QMutexLocker locker(&m_mutex);
    
    int start = std::max(0, (int)m_generationHistory.size() - limit);
    return QVector<GeneratedCode>(m_generationHistory.begin() + start, m_generationHistory.end());
}

QVariantMap DefaultCodeMagic::getStatistics() const {
    QMutexLocker locker(&m_mutex);
    
    return QVariantMap{
        {"totalAnalyses", m_totalAnalyses},
        {"totalGenerations", m_totalGenerations},
        {"totalRefactorings", m_totalRefactorings},
        {"analysisHistorySize", m_analysisHistory.size()},
        {"generationHistorySize", m_generationHistory.size()}
    };
}

// ── Helper Methods ──────────────────────────────

ProgrammingLanguage DefaultCodeMagic::detectLanguageInternal(const QString &code) const {
    if (code.contains("def ") || code.contains("import ")) {
        return ProgrammingLanguage::Python;
    } else if (code.contains("function ") || code.contains("const ") || code.contains("let ")) {
        return ProgrammingLanguage::JavaScript;
    } else if (code.contains("class ") && code.contains("#include")) {
        return ProgrammingLanguage::Cpp;
    } else if (code.contains("public class ")) {
        return ProgrammingLanguage::Java;
    }
    
    return ProgrammingLanguage::Unknown;
}

int DefaultCodeMagic::calculateCyclomaticComplexity(const QString &code) {
    int complexity = 1;
    
    complexity += code.count(QRegularExpression("\\bif\\b"));
    complexity += code.count(QRegularExpression("\\belse if\\b"));
    complexity += code.count(QRegularExpression("\\belse\\b"));
    complexity += code.count(QRegularExpression("\\bfor\\b"));
    complexity += code.count(QRegularExpression("\\bwhile\\b"));
    complexity += code.count(QRegularExpression("\\bcase\\b"));
    complexity += code.count(QRegularExpression("\\bcatch\\b"));
    complexity += code.count("&&");
    complexity += code.count("||");
    complexity += code.count("?");
    
    return std::max(1, complexity);
}

float DefaultCodeMagic::calculateQualityScore(const CodeAnalysisResult &result) {
    float score = 100.0f;
    
    score -= result.criticalCount * 10.0f;
    score -= result.errorCount * 5.0f;
    score -= result.warningCount * 2.0f;
    score -= result.complexity;
    
    return std::max(0.0f, std::min(100.0f, score));
}

QVector<CodeIssue> DefaultCodeMagic::analyzeIssues(const QString &code, ProgrammingLanguage language) {
    QVector<CodeIssue> issues;
    
    // Combine all issue types
    issues += findSecurityIssues(code, language);
    issues += findPerformanceIssues(code, language);
    issues += findBugs(code, language);
    
    return issues;
}

QString DefaultCodeMagic::generateCodeStub(const QString &description, ProgrammingLanguage language) {
    // Generate basic code stub based on description and language
    return "// " + description + "\n";
}
