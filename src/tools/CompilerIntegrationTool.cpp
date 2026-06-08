#include "CompilerIntegrationTool.h"
#include <QProcess>
#include <QJsonArray>
#include <QJsonDocument>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QDebug>

CompilerIntegrationTool::CompilerIntegrationTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
}

CompilerIntegrationTool::~CompilerIntegrationTool() = default;

QString CompilerIntegrationTool::name() const
{
    return QStringLiteral("compiler_integration");
}

QString CompilerIntegrationTool::description() const
{
    return QStringLiteral("Run type checkers and compilers (TypeScript tsc, Python, ESLint, Prettier)");
}

QJsonObject CompilerIntegrationTool::parametersSchema() const
{
    QJsonObject schema;
    schema[QStringLiteral("action")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Action: typecheck_typescript, validate_python, run_build, run_eslint, check_prettier")},
        {QStringLiteral("enum"), QJsonArray{
            QStringLiteral("typecheck_typescript"),
            QStringLiteral("validate_python"),
            QStringLiteral("run_build"),
            QStringLiteral("run_eslint"),
            QStringLiteral("check_prettier")
        }}
    };
    
    schema[QStringLiteral("tsconfig_path")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Path to tsconfig.json")}
    };
    
    schema[QStringLiteral("python_file")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Path to Python file to validate")}
    };
    
    schema[QStringLiteral("command")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Build command to run (e.g., 'npm run build')")}
    };
    
    schema[QStringLiteral("working_dir")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Working directory for command execution")}
    };
    
    schema[QStringLiteral("file_path")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("File path for linting/formatting checks")}
    };
    
    return schema;
}

ToolResult CompilerIntegrationTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();
    
    const QString action = args.value(QStringLiteral("action")).toString();
    
    if (action == QStringLiteral("typecheck_typescript")) {
        const QString tsconfigPath = args.value(QStringLiteral("tsconfig_path")).toString();
        
        if (tsconfigPath.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: tsconfig_path is required");
            return result;
        }
        
        const QJsonObject response = typecheckTypeScript(tsconfigPath);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        result.isError = response.value(QStringLiteral("success")).toBool() == false;
        return result;
        
    } else if (action == QStringLiteral("validate_python")) {
        const QString pythonFile = args.value(QStringLiteral("python_file")).toString();
        
        if (pythonFile.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: python_file is required");
            return result;
        }
        
        const QJsonObject response = validatePython(pythonFile);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        result.isError = response.value(QStringLiteral("valid")).toBool() == false;
        return result;
        
    } else if (action == QStringLiteral("run_build")) {
        const QString command = args.value(QStringLiteral("command")).toString();
        const QString workingDir = args.value(QStringLiteral("working_dir")).toString();
        
        if (command.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: command is required");
            return result;
        }
        
        const QJsonObject response = runBuildCommand(command, workingDir);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        result.isError = response.value(QStringLiteral("exit_code")).toInt() != 0;
        return result;
        
    } else if (action == QStringLiteral("run_eslint")) {
        const QString filePath = args.value(QStringLiteral("file_path")).toString();
        
        if (filePath.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: file_path is required");
            return result;
        }
        
        const QJsonObject response = runEslint(filePath);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        result.isError = response.value(QStringLiteral("error_count")).toInt() > 0;
        return result;
        
    } else if (action == QStringLiteral("check_prettier")) {
        const QString filePath = args.value(QStringLiteral("file_path")).toString();
        
        if (filePath.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: file_path is required");
            return result;
        }
        
        const QJsonObject response = checkPrettier(filePath);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        result.isError = response.value(QStringLiteral("needs_formatting")).toBool();
        return result;
    }
    
    result.isError = true;
    result.content = QStringLiteral("Error: Unknown action: %1").arg(action);
    return result;
}

QString CompilerIntegrationTool::summary(const QJsonObject &args) const
{
    const QString action = args.value(QStringLiteral("action")).toString();
    
    if (action == QStringLiteral("typecheck_typescript")) {
        return QStringLiteral("TypeScript type checking with tsc");
    } else if (action == QStringLiteral("validate_python")) {
        return QStringLiteral("Python syntax validation");
    } else if (action == QStringLiteral("run_build")) {
        return QStringLiteral("Run build command: %1").arg(args.value(QStringLiteral("command")).toString());
    }
    
    return action;
}

QJsonObject CompilerIntegrationTool::typecheckTypeScript(const QString &tsconfigPath)
{
    QJsonObject result;
    
    if (!isCompilerAvailable(QStringLiteral("tsc"))) {
        result[QStringLiteral("success")] = false;
        result[QStringLiteral("error")] = QStringLiteral("tsc (TypeScript compiler) not found");
        return result;
    }
    
    QProcess process;
    process.setWorkingDirectory(m_workspaceRoot);
    process.start(QStringLiteral("tsc"), QStringList{QStringLiteral("--project"), tsconfigPath});
    
    if (!process.waitForFinished(30000)) {
        result[QStringLiteral("success")] = false;
        result[QStringLiteral("error")] = QStringLiteral("tsc execution timed out");
        return result;
    }
    
    const QString output = QString::fromUtf8(process.readAllStandardOutput());
    const QString errorOutput = QString::fromUtf8(process.readAllStandardError());
    const int exitCode = process.exitCode();
    
    result[QStringLiteral("success")] = (exitCode == 0);
    result[QStringLiteral("exit_code")] = exitCode;
    result[QStringLiteral("output")] = output;
    result[QStringLiteral("errors")] = parseCompilerErrors(errorOutput, QStringLiteral("tsc"));
    
    return result;
}

QJsonObject CompilerIntegrationTool::validatePython(const QString &pythonFile)
{
    QJsonObject result;
    
    if (!isCompilerAvailable(QStringLiteral("python3"))) {
        result[QStringLiteral("valid")] = false;
        result[QStringLiteral("error")] = QStringLiteral("python3 not found");
        return result;
    }
    
    QProcess process;
    process.start(QStringLiteral("python3"), QStringList{QStringLiteral("-m"), QStringLiteral("py_compile"), pythonFile});
    
    if (!process.waitForFinished(10000)) {
        result[QStringLiteral("valid")] = false;
        result[QStringLiteral("error")] = QStringLiteral("Python validation timed out");
        return result;
    }
    
    const QString errorOutput = QString::fromUtf8(process.readAllStandardError());
    const int exitCode = process.exitCode();
    
    result[QStringLiteral("valid")] = (exitCode == 0);
    result[QStringLiteral("exit_code")] = exitCode;
    if (!errorOutput.isEmpty()) {
        result[QStringLiteral("error")] = errorOutput;
    }
    
    return result;
}

QJsonObject CompilerIntegrationTool::runBuildCommand(const QString &command, const QString &workingDir)
{
    QJsonObject result;
    
    QProcess process;
    if (!workingDir.isEmpty()) {
        process.setWorkingDirectory(workingDir);
    } else {
        process.setWorkingDirectory(m_workspaceRoot);
    }
    
    // 在 shell 中执行命令
    process.start(QStringLiteral("/bin/sh"), QStringList{QStringLiteral("-c"), command});
    
    if (!process.waitForFinished(60000)) {
        result[QStringLiteral("exit_code")] = -1;
        result[QStringLiteral("error")] = QStringLiteral("Build command timed out");
        return result;
    }
    
    const QString output = QString::fromUtf8(process.readAllStandardOutput());
    const QString errorOutput = QString::fromUtf8(process.readAllStandardError());
    const int exitCode = process.exitCode();
    
    result[QStringLiteral("exit_code")] = exitCode;
    result[QStringLiteral("stdout")] = output;
    result[QStringLiteral("stderr")] = errorOutput;
    result[QStringLiteral("success")] = (exitCode == 0);
    
    return result;
}

QJsonObject CompilerIntegrationTool::runEslint(const QString &filePath)
{
    QJsonObject result;
    
    if (!isCompilerAvailable(QStringLiteral("eslint"))) {
        result[QStringLiteral("error")] = QStringLiteral("eslint not found");
        result[QStringLiteral("error_count")] = 0;
        result[QStringLiteral("warning_count")] = 0;
        return result;
    }
    
    QProcess process;
    process.setWorkingDirectory(m_workspaceRoot);
    process.start(QStringLiteral("eslint"), QStringList{filePath, QStringLiteral("--format"), QStringLiteral("json")});
    
    if (!process.waitForFinished(15000)) {
        result[QStringLiteral("error")] = QStringLiteral("eslint execution timed out");
        return result;
    }
    
    const QString output = QString::fromUtf8(process.readAllStandardOutput());
    
    // 解析 JSON 输出
    QJsonDocument doc = QJsonDocument::fromJson(output.toUtf8());
    if (doc.isArray()) {
        const QJsonArray results = doc.array();
        int totalErrors = 0, totalWarnings = 0;
        QJsonArray issues;
        
        for (const QJsonValue &val : results) {
            const QJsonObject obj = val.toObject();
            const QJsonArray messages = obj.value(QStringLiteral("messages")).toArray();
            
            for (const QJsonValue &msgVal : messages) {
                const QJsonObject msg = msgVal.toObject();
                if (msg.value(QStringLiteral("severity")).toInt() == 2) {
                    totalErrors++;
                } else {
                    totalWarnings++;
                }
                issues.append(msg);
            }
        }
        
        result[QStringLiteral("error_count")] = totalErrors;
        result[QStringLiteral("warning_count")] = totalWarnings;
        result[QStringLiteral("issues")] = issues;
    }
    
    return result;
}

QJsonObject CompilerIntegrationTool::checkPrettier(const QString &filePath)
{
    QJsonObject result;
    
    if (!isCompilerAvailable(QStringLiteral("prettier"))) {
        result[QStringLiteral("error")] = QStringLiteral("prettier not found");
        result[QStringLiteral("needs_formatting")] = false;
        return result;
    }
    
    QProcess process;
    process.setWorkingDirectory(m_workspaceRoot);
    process.start(QStringLiteral("prettier"), QStringList{filePath, QStringLiteral("--check")});
    
    if (!process.waitForFinished(10000)) {
        result[QStringLiteral("error")] = QStringLiteral("prettier execution timed out");
        return result;
    }
    
    const int exitCode = process.exitCode();
    result[QStringLiteral("needs_formatting")] = (exitCode != 0);
    result[QStringLiteral("exit_code")] = exitCode;
    
    return result;
}

QJsonArray CompilerIntegrationTool::parseCompilerErrors(const QString &output, const QString &compiler)
{
    QJsonArray errors;
    
    const QStringList lines = output.split('\n');
    QRegularExpression errorPattern;
    
    if (compiler == QStringLiteral("tsc")) {
        // 匹配 TypeScript 错误格式: file.ts(10,5): error TS1234: message
        errorPattern.setPattern(QStringLiteral(R"(^(.+?)\((\d+),(\d+)\):\s+error\s+(\w+):\s+(.+)$)"));
    }
    
    for (const QString &line : lines) {
        const QRegularExpressionMatch match = errorPattern.match(line);
        if (match.hasMatch()) {
            QJsonObject error;
            error[QStringLiteral("file")] = match.captured(1);
            error[QStringLiteral("line")] = match.captured(2).toInt();
            error[QStringLiteral("column")] = match.captured(3).toInt();
            error[QStringLiteral("code")] = match.captured(4);
            error[QStringLiteral("message")] = match.captured(5);
            errors.append(error);
        }
    }
    
    return errors;
}

bool CompilerIntegrationTool::isCompilerAvailable(const QString &command)
{
    QProcess process;
    process.start(QStringLiteral("which"), QStringList{command});
    process.waitForFinished(2000);
    return process.exitCode() == 0;
}
