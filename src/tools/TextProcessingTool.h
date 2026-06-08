#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QJsonObject>

/**
 * @class TextProcessingTool
 * @brief 文本处理工具 - 转换、格式化、编码转换
 * 
 * 从 claude-code 适配：
 * - Base64 编码/解码
 * - URL 编码/解码
 * - JSON 格式化
 * - YAML 到 JSON 转换
 * - 行尾转换（LF/CRLF）
 * - 字符串转换（大小写、蛇形/驼峰命名法）
 */
class TextProcessingTool : public BaseTool {
    Q_OBJECT
public:
    explicit TextProcessingTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "text_processor"; }
    QString description() const override {
        return "Process text: Base64 encoding/decoding, URL encoding, "
               "JSON formatting, line endings conversion, and string case conversion.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    struct TextOp {
        QString type;  // "base64_encode", "base64_decode", "url_encode", "url_decode",
                       // "json_format", "convert_lineendings", "case_convert"
        QString text;
        QString format;  // for lineendings, case conversion
    };

    TextOp parseOp(const QJsonObject &args);
    
    ToolResult opBase64Encode(const QString &callId, const TextOp &op);
    ToolResult opBase64Decode(const QString &callId, const TextOp &op);
    ToolResult opUrlEncode(const QString &callId, const TextOp &op);
    ToolResult opUrlDecode(const QString &callId, const TextOp &op);
    ToolResult opJsonFormat(const QString &callId, const TextOp &op);
    ToolResult opConvertLineEndings(const QString &callId, const TextOp &op);
    ToolResult opCaseConvert(const QString &callId, const TextOp &op);

    // 辅助方法
    QString toSnakeCase(const QString &str);
    QString toCamelCase(const QString &str);
    QString toPascalCase(const QString &str);
    QString toKebabCase(const QString &str);

    QString m_workspaceRoot;
};
