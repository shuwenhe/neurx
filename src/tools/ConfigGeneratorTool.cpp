#include "ConfigGeneratorTool.h"
#include <QFile>
#include <QTextStream>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>

ConfigGeneratorTool::ConfigGeneratorTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
}

ConfigGeneratorTool::~ConfigGeneratorTool() = default;

QString ConfigGeneratorTool::name() const
{
    return QStringLiteral("config_generator");
}

QString ConfigGeneratorTool::description() const
{
    return QStringLiteral("Generate configuration files (.env, JSON, YAML, plist, registry)");
}

QJsonObject ConfigGeneratorTool::parametersSchema() const
{
    QJsonObject schema;
    schema[QStringLiteral("action")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Action: generate_env, generate_json, generate_yaml, generate_plist, generate_registry")},
        {QStringLiteral("enum"), QJsonArray{
            QStringLiteral("generate_env"),
            QStringLiteral("generate_json"),
            QStringLiteral("generate_yaml"),
            QStringLiteral("generate_plist"),
            QStringLiteral("generate_registry")
        }}
    };
    
    schema[QStringLiteral("variables")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("description"), QStringLiteral("Configuration variables")}
    };
    
    schema[QStringLiteral("environment")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Environment name (development, staging, production)")}
    };
    
    schema[QStringLiteral("output_file")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Output file path")}
    };
    
    schema[QStringLiteral("add_comments")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("boolean")},
        {QStringLiteral("description"), QStringLiteral("Add comments to generated file (default: true)")}
    };
    
    schema[QStringLiteral("pretty")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("boolean")},
        {QStringLiteral("description"), QStringLiteral("Pretty print JSON/YAML (default: true)")}
    };
    
    return schema;
}

ToolResult ConfigGeneratorTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();
    
    const QString action = args.value(QStringLiteral("action")).toString();
    const QJsonObject variables = args.value(QStringLiteral("variables")).toObject();
    const QString outputFile = args.value(QStringLiteral("output_file")).toString();
    
    QString content;
    
    if (action == QStringLiteral("generate_env")) {
        const bool addComments = args.value(QStringLiteral("add_comments")).toBool(true);
        content = generateEnvFile(variables, addComments);
        
    } else if (action == QStringLiteral("generate_json")) {
        const bool pretty = args.value(QStringLiteral("pretty")).toBool(true);
        content = generateJsonConfig(variables, pretty);
        
    } else if (action == QStringLiteral("generate_yaml")) {
        content = generateYamlConfig(variables);
        
    } else if (action == QStringLiteral("generate_plist")) {
        content = generatePlistConfig(variables);
        
    } else if (action == QStringLiteral("generate_registry")) {
        const QString keyPath = args.value(QStringLiteral("key_path")).toString(QStringLiteral("HKEY_LOCAL_MACHINE\\Software\\Company\\App"));
        content = generateWindowsRegistryScript(variables, keyPath);
        
    } else {
        result.isError = true;
        result.content = QStringLiteral("Error: Unknown action: %1").arg(action);
        return result;
    }
    
    // 写入文件
    if (!outputFile.isEmpty()) {
        QFile file(outputFile);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            result.isError = true;
            result.content = QStringLiteral("Error: Cannot write to %1").arg(outputFile);
            return result;
        }
        
        QTextStream out(&file);
        out << content;
        file.close();
    }
    
    QJsonObject resp;
    resp[QStringLiteral("content")] = content;
    resp[QStringLiteral("lines")] = content.split('\n').length();
    resp[QStringLiteral("saved")] = !outputFile.isEmpty();
    resp[QStringLiteral("format")] = action.mid(9);  // Remove "generate_" prefix
    
    result.content = QJsonDocument(resp).toJson(QJsonDocument::Compact);
    return result;
}

QString ConfigGeneratorTool::summary(const QJsonObject &args) const
{
    const QString action = args.value(QStringLiteral("action")).toString();
    const QString env = args.value(QStringLiteral("environment")).toString();
    
    if (!env.isEmpty()) {
        return QStringLiteral("Generate %1 config for %2 environment")
            .arg(action.mid(9), env);
    }
    
    return action;
}

QString ConfigGeneratorTool::generateEnvFile(const QJsonObject &variables, bool addComments)
{
    QString content;
    QTextStream stream(&content);
    
    if (addComments) {
        stream << QStringLiteral("# Environment Configuration\n");
        stream << QStringLiteral("# Auto-generated - DO NOT EDIT MANUALLY\n");
        stream << QStringLiteral("# Use config_generator tool to update\n\n");
    }
    
    for (auto it = variables.begin(); it != variables.end(); ++it) {
        const QString key = it.key();
        QString value = it.value().toString();
        
        // 如果值包含特殊字符，添加引号
        if (value.contains(QRegularExpression(QStringLiteral("[\\s='\"]")))) {
            stream << key << QStringLiteral("=\"") << value.replace('"', QStringLiteral("\\\"")) << QStringLiteral("\"\n");
        } else {
            stream << key << QStringLiteral("=") << value << '\n';
        }
    }
    
    return content;
}

QString ConfigGeneratorTool::generateJsonConfig(const QJsonObject &config, bool pretty)
{
    QJsonDocument doc(config);
    if (pretty) {
        return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
    } else {
        return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
    }
}

QString ConfigGeneratorTool::generateYamlConfig(const QJsonObject &config)
{
    QString content;
    QTextStream stream(&content);
    
    // 简单的 YAML 生成（不处理嵌套结构）
    for (auto it = config.begin(); it != config.end(); ++it) {
        const QString key = it.key();
        const QJsonValue val = it.value();
        
        if (val.isObject()) {
            stream << key << QStringLiteral(":\n");
            const QJsonObject nested = val.toObject();
            for (auto nit = nested.begin(); nit != nested.end(); ++nit) {
                stream << QStringLiteral("  ") << nit.key() << QStringLiteral(": ") << nit.value().toString() << '\n';
            }
        } else {
            stream << key << QStringLiteral(": ") << val.toString() << '\n';
        }
    }
    
    return content;
}

QString ConfigGeneratorTool::generatePlistConfig(const QJsonObject &config)
{
    QString content;
    QTextStream stream(&content);
    
    stream << QStringLiteral("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    stream << QStringLiteral("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" ");
    stream << QStringLiteral("\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n");
    stream << QStringLiteral("<plist version=\"1.0\">\n");
    stream << QStringLiteral("<dict>\n");
    
    for (auto it = config.begin(); it != config.end(); ++it) {
        stream << QStringLiteral("  <key>") << it.key() << QStringLiteral("</key>\n");
        
        const QJsonValue val = it.value();
        if (val.isBool()) {
            stream << QStringLiteral("  <") << (val.toBool() ? QStringLiteral("true") : QStringLiteral("false")) << QStringLiteral("/>\n");
        } else if (val.isDouble()) {
            stream << QStringLiteral("  <real>") << val.toDouble() << QStringLiteral("</real>\n");
        } else {
            stream << QStringLiteral("  <string>") << val.toString() << QStringLiteral("</string>\n");
        }
    }
    
    stream << QStringLiteral("</dict>\n");
    stream << QStringLiteral("</plist>\n");
    
    return content;
}

QString ConfigGeneratorTool::generateWindowsRegistryScript(const QJsonObject &config, const QString &keyPath)
{
    QString content;
    QTextStream stream(&content);
    
    stream << QStringLiteral("Windows Registry Editor Version 5.00\n\n");
    stream << QStringLiteral("[") << keyPath << QStringLiteral("]\n");
    
    for (auto it = config.begin(); it != config.end(); ++it) {
        const QString valueName = it.key();
        QString value = it.value().toString();
        
        // 转义特殊字符
        const QString escaped = value.replace('\\', QStringLiteral("\\\\"))
            .replace('"', QStringLiteral("\\\""));
        
        stream << QStringLiteral("\"") << valueName << QStringLiteral("\"=\"") << escaped << QStringLiteral("\"\n");
    }
    
    return content;
}

bool ConfigGeneratorTool::validateConfig(const QJsonObject &config, const QStringList &requiredKeys)
{
    for (const QString &key : requiredKeys) {
        if (!config.contains(key)) {
            return false;
        }
    }
    return true;
}

QJsonObject ConfigGeneratorTool::getConfigTemplate(const QString &type)
{
    QJsonObject template_;
    
    if (type == QStringLiteral("nextjs")) {
        template_[QStringLiteral("NEXT_PUBLIC_API_URL")] = QStringLiteral("http://localhost:3000/api");
        template_[QStringLiteral("NEXT_PUBLIC_APP_ENV")] = QStringLiteral("development");
        template_[QStringLiteral("DATABASE_URL")] = QStringLiteral("postgresql://user:pass@localhost/db");
        
    } else if (type == QStringLiteral("nodejs")) {
        template_[QStringLiteral("NODE_ENV")] = QStringLiteral("development");
        template_[QStringLiteral("PORT")] = 3000;
        template_[QStringLiteral("DATABASE_URL")] = QStringLiteral("mongodb://localhost:27017/app");
        
    } else if (type == QStringLiteral("python")) {
        template_[QStringLiteral("FLASK_ENV")] = QStringLiteral("development");
        template_[QStringLiteral("FLASK_DEBUG")] = true;
        template_[QStringLiteral("DATABASE_URL")] = QStringLiteral("postgresql://user:pass@localhost/db");
    }
    
    return template_;
}

QString ConfigGeneratorTool::escapeForFormat(const QString &value, const QString &format)
{
    QString result = value;
    if (format == QStringLiteral("json")) {
        result = result.replace('\\', QStringLiteral("\\\\"))
                       .replace('"', QStringLiteral("\\\""));
    } else if (format == QStringLiteral("registry")) {
        result = result.replace('\\', QStringLiteral("\\\\"))
                       .replace('"', QStringLiteral("\\\""));
    } else if (format == QStringLiteral("plist")) {
        result = value;  // XML encoding handled by Qt
    }
    
    return result;
}
