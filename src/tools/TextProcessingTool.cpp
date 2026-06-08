#include "tools/TextProcessingTool.h"
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

TextProcessingTool::TextProcessingTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_workspaceRoot(workspaceRoot)
{
    qInfo() << "[TextProcessingTool] Initialized for workspace:" << workspaceRoot;
}

QJsonObject TextProcessingTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";
    
    QJsonObject properties;
    
    QJsonObject typeObj;
    typeObj["type"] = "string";
    typeObj["enum"] = QJsonArray::fromStringList({
        "base64_encode", "base64_decode", "url_encode", "url_decode",
        "json_format", "convert_lineendings", "case_convert"
    });
    typeObj["description"] = "Type of text operation";
    properties["type"] = typeObj;
    
    QJsonObject textObj;
    textObj["type"] = "string";
    textObj["description"] = "Text to process";
    properties["text"] = textObj;
    
    QJsonObject formatObj;
    formatObj["type"] = "string";
    formatObj["description"] = "Format parameter (for lineendings: lf/crlf, for case: snake/camel/pascal/kebab)";
    properties["format"] = formatObj;
    
    schema["properties"] = properties;
    schema["required"] = QJsonArray::fromStringList({"type", "text"});
    
    return schema;
}

ToolResult TextProcessingTool::execute(const QString &callId, const QJsonObject &args)
{
    TextOp op = parseOp(args);
    
    if (op.type == "base64_encode") {
        return opBase64Encode(callId, op);
    } else if (op.type == "base64_decode") {
        return opBase64Decode(callId, op);
    } else if (op.type == "url_encode") {
        return opUrlEncode(callId, op);
    } else if (op.type == "url_decode") {
        return opUrlDecode(callId, op);
    } else if (op.type == "json_format") {
        return opJsonFormat(callId, op);
    } else if (op.type == "convert_lineendings") {
        return opConvertLineEndings(callId, op);
    } else if (op.type == "case_convert") {
        return opCaseConvert(callId, op);
    }
    
    return {callId, name(), true, "Unknown operation type: " + op.type};
}

QString TextProcessingTool::summary(const QJsonObject &args) const
{
    return QString("%1 on text (%2 chars)")
        .arg(args["type"].toString())
        .arg(args["text"].toString().length());
}

TextProcessingTool::TextOp TextProcessingTool::parseOp(const QJsonObject &args)
{
    TextOp op;
    op.type = args["type"].toString();
    op.text = args["text"].toString();
    op.format = args["format"].toString();
    return op;
}

ToolResult TextProcessingTool::opBase64Encode(const QString &callId, const TextOp &op)
{
    QByteArray encoded = op.text.toUtf8().toBase64();
    
    QJsonObject result;
    result["input_length"] = op.text.length();
    result["output"] = QString::fromLatin1(encoded);
    result["output_length"] = encoded.length();
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult TextProcessingTool::opBase64Decode(const QString &callId, const TextOp &op)
{
    QByteArray encoded = op.text.toLatin1();
    QByteArray decoded = QByteArray::fromBase64(encoded);
    
    if (decoded.isEmpty() && !encoded.isEmpty()) {
        return {callId, name(), true, "Invalid Base64 input"};
    }
    
    QString output = QString::fromUtf8(decoded);
    
    QJsonObject result;
    result["input_length"] = op.text.length();
    result["output"] = output;
    result["output_length"] = output.length();
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult TextProcessingTool::opUrlEncode(const QString &callId, const TextOp &op)
{
    QString encoded = QUrl::toPercentEncoding(op.text);
    
    QJsonObject result;
    result["input"] = op.text;
    result["output"] = encoded;
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult TextProcessingTool::opUrlDecode(const QString &callId, const TextOp &op)
{
    QString decoded = QUrl::fromPercentEncoding(op.text.toLatin1());
    
    QJsonObject result;
    result["input"] = op.text;
    result["output"] = decoded;
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult TextProcessingTool::opJsonFormat(const QString &callId, const TextOp &op)
{
    QJsonDocument doc = QJsonDocument::fromJson(op.text.toUtf8());
    
    if (doc.isNull()) {
        return {callId, name(), true, "Invalid JSON input"};
    }
    
    QString formatted = doc.toJson(QJsonDocument::Indented);
    
    QJsonObject result;
    result["valid"] = true;
    result["formatted"] = formatted;
    result["is_object"] = doc.isObject();
    result["is_array"] = doc.isArray();
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

ToolResult TextProcessingTool::opConvertLineEndings(const QString &callId, const TextOp &op)
{
    QString converted = op.text;
    
    // 先转换为 LF
    converted.replace("\r\n", "\n");
    converted.replace("\r", "\n");
    
    // 再转换为目标格式
    if (op.format == "crlf" || op.format == "windows") {
        converted.replace("\n", "\r\n");
    }
    // 否则保持 LF（Unix 格式）
    
    QJsonObject result;
    result["target_format"] = (op.format == "crlf" || op.format == "windows") ? "CRLF" : "LF";
    result["output"] = converted;
    
    return {callId, name(), false, QJsonDocument(result).toJson(QJsonDocument::Compact)};
}

QString TextProcessingTool::toSnakeCase(const QString &str)
{
    QString result;
    for (int i = 0; i < str.length(); ++i) {
        QChar ch = str[i];
        if (ch.isUpper() && i > 0) {
            result += "_";
            result += ch.toLower();
        } else if (ch == "-" || ch == " ") {
            result += "_";
        } else {
            result += ch.toLower();
        }
    }
    return result;
}

QString TextProcessingTool::toCamelCase(const QString &str)
{
    QStringList parts = str.split(QRegularExpression("[_\\-\\s]"), Qt::SkipEmptyParts);
    if (parts.isEmpty()) return str;
    
    QString result = parts[0].toLower();
    for (int i = 1; i < parts.length(); ++i) {
        if (!parts[i].isEmpty()) {
            result += parts[i][0].toUpper() + parts[i].mid(1).toLower();
        }
    }
    return result;
}

QString TextProcessingTool::toPascalCase(const QString &str)
{
    QStringList parts = str.split(QRegularExpression("[_\\-\\s]"), Qt::SkipEmptyParts);
    
    QString result;
    for (const QString &part : parts) {
        if (!part.isEmpty()) {
            result += part[0].toUpper() + part.mid(1).toLower();
        }
    }
    return result;
}

QString TextProcessingTool::toKebabCase(const QString &str)
{
    QString result;
    for (int i = 0; i < str.length(); ++i) {
        QChar ch = str[i];
        if (ch.isUpper() && i > 0) {
            result += "-";
            result += ch.toLower();
        } else if (ch == "_" || ch == " ") {
            result += "-";
        } else {
            result += ch.toLower();
        }
    }
    return result;
}

ToolResult TextProcessingTool::opCaseConvert(const QString &callId, const TextOp &op)
{
    QString result;
    
    if (op.format == "snake") {
        result = toSnakeCase(op.text);
    } else if (op.format == "camel") {
        result = toCamelCase(op.text);
    } else if (op.format == "pascal") {
        result = toPascalCase(op.text);
    } else if (op.format == "kebab") {
        result = toKebabCase(op.text);
    } else if (op.format == "upper") {
        result = op.text.toUpper();
    } else if (op.format == "lower") {
        result = op.text.toLower();
    } else {
        return {callId, name(), true, "Unknown format: " + op.format};
    }
    
    QJsonObject resultObj;
    resultObj["input"] = op.text;
    resultObj["format"] = op.format;
    resultObj["output"] = result;
    
    return {callId, name(), false, QJsonDocument(resultObj).toJson(QJsonDocument::Compact)};
}
