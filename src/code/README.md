# CodeMagic - Claude Code核心功能模块

CodeMagic是neurx中的智能代码分析、生成、修复和优化系统，提供Claude Code的核心能力。

## 核心功能

### 🔍 代码分析
- **质量评估** - 评估代码质量分数（0-100）
- **复杂度计算** - 循环复杂度和认知复杂度
- **问题检测** - 安全、性能、风格问题
- **指标收集** - 行数、复杂度、函数数等
- **语言检测** - 自动检测编程语言

### 💡 代码生成
- **智能生成** - 根据描述生成代码
- **函数框架** - 生成函数签名和骨架
- **类骨架** - 生成类定义和方法
- **代码补全** - 自动补全不完整代码
- **多语言** - 支持15+编程语言

### 🔧 代码重构
- **方法提取** - 提取代码块为方法
- **变量重命名** - 安全重命名变量
- **条件简化** - 简化条件表达式
- **循环优化** - 优化循环性能
- **复杂度降低** - 自动降低代码复杂度

### 📖 代码解释
- **代码讲解** - 详细解释代码功能
- **逐行注解** - 逐行代码解释
- **函数说明** - 函数级别的说明
- **文档生成** - 生成API文档
- **注释生成** - 自动添加注释

### 🧪 测试生成
- **单元测试** - 生成单元测试用例
- **集成测试** - 生成集成测试
- **边界测试** - 生成边界条件测试
- **Mock支持** - 生成Mock和Fixture
- **覆盖率** - 估计测试覆盖率

### ✅ 代码审查
- **自动审查** - 自动代码审查
- **建议提供** - 提供改进建议
- **标准检查** - 检查编码标准
- **相似度** - 检测重复代码
- **评分** - 代码质量评分

## 支持的编程语言

```
✓ Python          ✓ JavaScript      ✓ TypeScript
✓ Java            ✓ C#              ✓ C++
✓ C               ✓ Go              ✓ Rust
✓ Ruby            ✓ PHP             ✓ Swift
✓ Kotlin          ✓ SQL             ✓ HTML/CSS
```

## 使用示例

### 代码分析

```cpp
#include "DefaultCodeMagic.h"

auto codeMagic = std::make_shared<DefaultCodeMagic>();

// 分析代码
QString code = R"(
    def process_data(data):
        result = []
        for item in data:
            if item > 0:
                result.append(item * 2)
        return result
)";

CodeAnalysisResult analysis = codeMagic->analyzeCode(code, ProgrammingLanguage::Python);

qDebug() << "Lines:" << analysis.lineCount;
qDebug() << "Complexity:" << analysis.complexity;
qDebug() << "Quality:" << analysis.quality;
qDebug() << "Issues:" << analysis.issues.size();

// 异步分析
auto analysisId = codeMagic->analyzeCodeAsync(code, ProgrammingLanguage::Python,
    [](const CodeAnalysisResult &result) {
        qDebug() << "Analysis complete:" << result.quality;
    });

// 检测语言
auto language = codeMagic->detectLanguage(code);

// 获取指标
auto metrics = codeMagic->getCodeMetrics(code);
qDebug() << "Functions:" << metrics["functions"];
qDebug() << "Classes:" << metrics["classes"];
```

### 代码生成

```cpp
// 生成代码
CodeGenerationRequest request;
request.language = ProgrammingLanguage::Python;
request.description = "读取CSV文件并返回数据";
request.includeComments = true;
request.includeTests = true;

GeneratedCode generated = codeMagic->generateCode(request);
qDebug() << "Generated code:" << generated.code;
qDebug() << "Explanation:" << generated.explanation;

// 生成函数框架
QString functionStub = codeMagic->generateFunctionStub(
    "calculate_average",
    {"numbers"},
    ProgrammingLanguage::Python
);

// 生成类骨架
QString classCode = codeMagic->generateClassSkeleton(
    "DataProcessor",
    {"process", "validate", "export"},
    ProgrammingLanguage::Java
);

// 代码补全
QString partial = "def greet(name):\n    print(f\"Hello {name}\"";
QString completed = codeMagic->completeCode(partial, ProgrammingLanguage::Python);
```

### 代码重构

```cpp
// 提取方法
QString refactored = codeMagic->extractMethod(
    code,
    5, 10,
    "extract_logic",
    ProgrammingLanguage::Python
);

// 重命名变量
QString renamed = codeMagic->renameVariable(
    code,
    "temp",
    "temporary_value",
    ProgrammingLanguage::Python
);

// 简化条件
QString simplified = codeMagic->simplifyCondition(
    "if (x == true) { ... }",
    1,
    ProgrammingLanguage::JavaScript
);

// 优化循环
QString optimized = codeMagic->optimizeLoop(code, 5, ProgrammingLanguage::Python);

// 降低复杂度
QString reduced = codeMagic->reduceComplexity(code, ProgrammingLanguage::Python);

// 通过请求重构
RefactoringRequest refRequest;
refRequest.code = code;
refRequest.type = RefactoringType::ExtractMethod;
refRequest.description = "提取数据处理逻辑";

RefactoringResult result = codeMagic->refactorCode(refRequest);
qDebug() << "Refactored:" << result.refactoredCode;
qDebug() << "Improvements:" << result.improvements.size();
```

### 代码解释

```cpp
// 解释代码
CodeExplanation explanation = codeMagic->explainCode(code, ProgrammingLanguage::Python);
qDebug() << "Summary:" << explanation.summary;
qDebug() << "Detailed:" << explanation.detailedExplanation;

// 解释函数
CodeExplanation funcExpl = codeMagic->explainFunction(
    code,
    "process_data",
    ProgrammingLanguage::Python
);

// 逐行解释
auto lineExplanations = codeMagic->explainLineByLine(code, ProgrammingLanguage::Python);
for (const auto &explanation : lineExplanations) {
    qDebug() << explanation;
}

// 生成文档
QString documentation = codeMagic->generateDocumentation(code, ProgrammingLanguage::Python);

// 生成注释
QString commented = codeMagic->generateComments(code, ProgrammingLanguage::Python);
```

### 测试生成

```cpp
// 生成测试
TestGenerationRequest testRequest;
testRequest.code = code;
testRequest.language = ProgrammingLanguage::Python;
testRequest.testFramework = "pytest";
testRequest.includeEdgeCases = true;
testRequest.minCoverage = 80;

GeneratedTests tests = codeMagic->generateTests(testRequest);
qDebug() << "Test code:" << tests.testCode;
qDebug() << "Coverage:" << tests.estimatedCoverage << "%";

// 生成单元测试
QString unitTests = codeMagic->generateUnitTests(code, ProgrammingLanguage::Python);

// 生成集成测试
QString integrationTests = codeMagic->generateIntegrationTests(code, ProgrammingLanguage::Python);

// 生成边界测试
auto edgeCases = codeMagic->generateEdgeCaseTests(code, ProgrammingLanguage::Python);
```

### 代码比较

```cpp
// 比较代码
CodeDiff diff = codeMagic->compareCode(originalCode, modifiedCode);
qDebug() << "Added lines:" << diff.addedLines;
qDebug() << "Removed lines:" << diff.removedLines;

// 查找重复
auto duplicates = codeMagic->findDuplicates(code);

// 计算相似度
float similarity = codeMagic->calculateSimilarity(code1, code2);
qDebug() << "Similarity:" << similarity << "%";
```

### 代码审查

```cpp
// 审查代码
CodeReview review = codeMagic->reviewCode(
    code,
    "john@example.com",
    "reviewer@example.com"
);
qDebug() << "Score:" << review.overallScore;
qDebug() << "Issues:" << review.issues.size();
qDebug() << "Suggestions:" << review.suggestions;

// 获取审查建议
auto suggestions = codeMagic->getReviewSuggestions(code, ProgrammingLanguage::Python);

// 检查编码标准
auto styleIssues = codeMagic->checkCodingStandards(code, ProgrammingLanguage::Python);
```

### 代码格式化

```cpp
// 格式化代码
QString formatted = codeMagic->formatCode(code, ProgrammingLanguage::Python);

// 修复代码风格
QString styled = codeMagic->fixCodeStyle(code, ProgrammingLanguage::Python);

// 代码最小化
QString minified = codeMagic->minifyCode(code, ProgrammingLanguage::JavaScript);

// 美化输出
QString pretty = codeMagic->prettyPrintCode(code, ProgrammingLanguage::Python);
```

### 错误查找和修复

```cpp
// 查找Bug
auto bugs = codeMagic->findBugs(code, ProgrammingLanguage::Python);

// 建议修复
auto fixes = codeMagic->suggestFixes(bugs[0], code);

// 修复常见错误
QString fixed = codeMagic->fixCommonErrors(code, ProgrammingLanguage::Python);

// 查找安全问题
auto securityIssues = codeMagic->findSecurityIssues(code, ProgrammingLanguage::Python);

// 查找性能问题
auto perfIssues = codeMagic->findPerformanceIssues(code, ProgrammingLanguage::Python);
```

### 语言支持

```cpp
// 获取支持的语言
auto languages = codeMagic->getSupportedLanguages();

// 获取语言信息
auto pythonInfo = codeMagic->getLanguageInfo(ProgrammingLanguage::Python);
qDebug() << "Version:" << pythonInfo["version"];

// 语言转换
QString jsCode = codeMagic->convertLanguage(
    pythonCode,
    ProgrammingLanguage::Python,
    ProgrammingLanguage::JavaScript
);
```

### 历史和统计

```cpp
// 获取分析历史
auto history = codeMagic->getAnalysisHistory(50);
for (const auto &result : history) {
    qDebug() << "Quality:" << result.quality;
}

// 获取生成历史
auto genHistory = codeMagic->getGenerationHistory(50);

// 获取统计信息
auto stats = codeMagic->getStatistics();
qDebug() << "Total analyses:" << stats["totalAnalyses"];
qDebug() << "Total generations:" << stats["totalGenerations"];
```

### 信号连接

```cpp
// 分析完成
connect(codeMagic.get(), &CodeMagic::analysisCompleted,
    [](const CodeAnalysisResult &result) {
        qDebug() << "Analysis done, quality:" << result.quality;
    });

// 生成完成
connect(codeMagic.get(), &CodeMagic::generationCompleted,
    [](const GeneratedCode &code) {
        qDebug() << "Code generated";
    });

// 重构完成
connect(codeMagic.get(), &CodeMagic::refactoringCompleted,
    [](const RefactoringResult &result) {
        qDebug() << "Refactoring done";
    });

// 测试生成
connect(codeMagic.get(), &CodeMagic::testsGenerated,
    [](const GeneratedTests &tests) {
        qDebug() << "Tests generated, coverage:" << tests.estimatedCoverage;
    });

// 错误发生
connect(codeMagic.get(), &CodeMagic::errorOccurred,
    [](const QString &error) {
        qDebug() << "Error:" << error;
    });
```

## 核心概念

### 问题严重程度
- **Info** - 提示信息
- **Warning** - 警告，可能问题
- **Error** - 错误，需要修复
- **Critical** - 严重错误，必须修复

### 问题类型
- **security** - 安全问题
- **performance** - 性能问题
- **style** - 代码风格
- **bug** - 潜在Bug

### 重构类型
- **ExtractMethod** - 提取方法
- **RenameVariable** - 重命名变量
- **SimplifyCondition** - 简化条件
- **OptimizeLoop** - 优化循环
- **ReduceComplexity** - 降低复杂度
- **ImproveReadability** - 改进可读性

## 最佳实践

1. **先分析后修复** - 分析代码找出问题
2. **使用异步API** - 大文件使用异步处理
3. **检查安全性** - 优先处理安全问题
4. **生成测试** - 为关键代码生成测试
5. **记录历史** - 追踪代码演进
6. **检查复杂度** - 及时降低复杂度
7. **遵守标准** - 检查编码标准
8. **语言转换** - 跨语言学习

## 架构特点

✅ **多语言支持** - 15+编程语言  
✅ **智能分析** - 深度代码分析  
✅ **自动生成** - 代码和测试生成  
✅ **灵活重构** - 多种重构操作  
✅ **异步API** - 非阻塞操作  
✅ **历史追踪** - 完整的操作历史  
✅ **信号事件** - 事件驱动架构  
✅ **线程安全** - Mutex保护  

## 集成点

- **CoreAgent** - 作为agent的代码能力
- **LLM Extensions** - 调用LLM改进分析
- **Memory System** - 存储代码分析结果
- **Logging System** - 记录所有操作
- **Test Framework** - 整合测试生成
