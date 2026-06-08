#include "GuardianAgentTool.h"
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>

GuardianAgentTool::GuardianAgentTool(QObject *parent)
    : BaseTool(parent), m_riskAssessor(this)
{
    // 初始化默认审批策略
    m_approvalPolicies.insert("*", DEFAULT_POLICY);
    m_trustedTools = {
        "ReadFileTool",
        "DirectoryTreeTool",
        "FileMetadataTool",
        "AdvancedSearchTool"
    };
}

GuardianAgentTool::~GuardianAgentTool()
{
}

QString GuardianAgentTool::description() const
{
    return "Guardian Agent - 自动风险评估和审批决策系统。"
           "分析工具操作的安全风险，基于可配置的策略做出自动审批决策。"
           "支持信任工具列表、黑名单管理和灵活的审批策略配置。";
}

QJsonObject GuardianAgentTool::parametersSchema() const
{
    QJsonObject schema;
    schema["type"] = "object";

    QJsonObject properties;

    // action参数
    QJsonObject actionSchema;
    actionSchema["type"] = "string";
    actionSchema["description"] = "操作类型: assess, set_policy, get_policy, "
                                   "add_trusted, remove_trusted, get_trusted, "
                                   "add_blacklist, remove_blacklist, get_blacklist, "
                                   "get_history";
    properties["action"] = actionSchema;

    // tool_name参数
    QJsonObject toolNameSchema;
    toolNameSchema["type"] = "string";
    toolNameSchema["description"] = "要评估的工具名称";
    properties["tool_name"] = toolNameSchema;

    // tool_action参数
    QJsonObject toolActionSchema;
    toolActionSchema["type"] = "string";
    toolActionSchema["description"] = "工具执行的具体动作（如 delete, write, execute）";
    properties["tool_action"] = toolActionSchema;

    // parameters参数
    QJsonObject parametersSchema;
    parametersSchema["type"] = "object";
    parametersSchema["description"] = "工具的参数（用于风险评估）";
    properties["parameters"] = parametersSchema;

    // approval_policy参数
    QJsonObject policySchema;
    policySchema["type"] = "string";
    policySchema["enum"] = QJsonArray{"Never", "OnFailure", "OnRequest", "Granular", "UnlessTrusted"};
    policySchema["description"] = "审批策略";
    properties["approval_policy"] = policySchema;

    schema["properties"] = properties;
    schema["required"] = QJsonArray{"action"};

    return schema;
}

ToolResult GuardianAgentTool::execute(const QString &callId, const QJsonObject &args)
{
    QString action = args.value("action").toString().toLower();
    ToolResult result;
    result.callId = callId;
    result.name = name();
    result.isError = false;

    try {
        if (action == "assess") {
            // 评估工具操作的风险
            QString toolName = args.value("tool_name").toString();
            QString toolAction = args.value("tool_action").toString();
            QJsonObject params = args.value("parameters").toObject();

            if (toolName.isEmpty() || toolAction.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing tool_name or tool_action"}
                }).toJson();
                return result;
            }

            QString policy = args.value("approval_policy").toString(DEFAULT_POLICY);
            QJsonObject decisionDetails;

            ApprovalDecision decision = assessOperation(
                toolName, toolAction, params, policy, decisionDetails);

            QJsonObject resultObj;
            resultObj["decision"] = (decision == APPROVED ? "APPROVED" :
                                    decision == REJECTED ? "REJECTED" : "REQUIRES_REVIEW");
            resultObj["details"] = decisionDetails;
            resultObj["timestamp"] = getCurrentTimestamp();

            result.content = QJsonDocument(resultObj).toJson();

        } else if (action == "set_policy") {
            QString toolName = args.value("tool_name").toString();
            QString policy = args.value("approval_policy").toString();

            if (toolName.isEmpty() || policy.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing tool_name or approval_policy"}
                }).toJson();
                return result;
            }

            setApprovalPolicy(toolName, policy);
            result.content = QJsonDocument(QJsonObject{
                {"message", QString("Policy set for %1 to %2").arg(toolName, policy)}
            }).toJson();

        } else if (action == "get_policy") {
            QString toolName = args.value("tool_name").toString();
            if (toolName.isEmpty()) {
                toolName = "*";
            }

            QString policy = getApprovalPolicy(toolName);
            result.content = QJsonDocument(QJsonObject{
                {"tool_name", toolName},
                {"policy", policy}
            }).toJson();

        } else if (action == "add_trusted") {
            QString toolName = args.value("tool_name").toString();
            if (toolName.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing tool_name"}
                }).toJson();
                return result;
            }

            addTrustedTool(toolName);
            result.content = QJsonDocument(QJsonObject{
                {"message", QString("%1 added to trusted tools").arg(toolName)}
            }).toJson();

        } else if (action == "remove_trusted") {
            QString toolName = args.value("tool_name").toString();
            if (toolName.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing tool_name"}
                }).toJson();
                return result;
            }

            removeTrustedTool(toolName);
            result.content = QJsonDocument(QJsonObject{
                {"message", QString("%1 removed from trusted tools").arg(toolName)}
            }).toJson();

        } else if (action == "get_trusted") {
            QJsonArray trustedArray;
            for (const auto &tool : getTrustedTools()) {
                trustedArray.append(tool);
            }
            result.content = QJsonDocument(QJsonObject{
                {"trusted_tools", trustedArray}
            }).toJson();

        } else if (action == "add_blacklist") {
            QString toolName = args.value("tool_name").toString();
            if (toolName.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing tool_name"}
                }).toJson();
                return result;
            }

            addBlacklistedTool(toolName);
            result.content = QJsonDocument(QJsonObject{
                {"message", QString("%1 added to blacklist").arg(toolName)}
            }).toJson();

        } else if (action == "remove_blacklist") {
            QString toolName = args.value("tool_name").toString();
            if (toolName.isEmpty()) {
                result.isError = true;
                result.content = QJsonDocument(QJsonObject{
                    {"error", "Missing tool_name"}
                }).toJson();
                return result;
            }

            removeBlacklistedTool(toolName);
            result.content = QJsonDocument(QJsonObject{
                {"message", QString("%1 removed from blacklist").arg(toolName)}
            }).toJson();

        } else if (action == "get_blacklist") {
            QJsonArray blacklistArray;
            for (const auto &tool : getBlacklistedTools()) {
                blacklistArray.append(tool);
            }
            result.content = QJsonDocument(QJsonObject{
                {"blacklist", blacklistArray}
            }).toJson();

        } else if (action == "get_history") {
            QJsonArray historyArray;
            for (const auto &record : m_approvalHistory) {
                QJsonObject recordObj;
                recordObj["tool_name"] = record.toolName;
                recordObj["action"] = record.action;
                recordObj["decision"] = (record.decision == APPROVED ? "APPROVED" :
                                        record.decision == REJECTED ? "REJECTED" : "REQUIRES_REVIEW");
                recordObj["timestamp"] = record.timestamp;
                recordObj["reason"] = record.reason;
                historyArray.append(recordObj);
            }
            result.content = QJsonDocument(QJsonObject{
                {"history", historyArray},
                {"count", static_cast<int>(historyArray.size())}
            }).toJson();

        } else {
            result.isError = true;
            result.content = QJsonDocument(QJsonObject{
                {"error", QString("Unknown action: %1").arg(action)}
            }).toJson();
        }

    } catch (const std::exception &e) {
        result.isError = true;
        result.content = QJsonDocument(QJsonObject{
            {"error", QString("Exception: %1").arg(e.what())}
        }).toJson();
    }

    return result;
}

QString GuardianAgentTool::summary(const QJsonObject &args) const
{
    QString action = args.value("action").toString();
    QString toolName = args.value("tool_name").toString();

    if (action == "assess") {
        return QString("Guardian: Assessing risk for %1").arg(toolName);
    } else if (action == "set_policy") {
        return QString("Guardian: Setting policy for %1").arg(toolName);
    } else if (action == "get_policy") {
        return QString("Guardian: Getting policy for %1").arg(toolName);
    }

    return QString("Guardian: %1").arg(action);
}

GuardianAgentTool::ApprovalDecision GuardianAgentTool::assessOperation(
    const QString &toolName,
    const QString &action,
    const QJsonObject &params,
    const QString &approvalPolicy,
    QJsonObject &decisionDetails)
{
    // 检查黑名单
    if (getBlacklistedTools().contains(toolName)) {
        decisionDetails["reason"] = "Tool is blacklisted";
        recordApprovalDecision({
            toolName, action, REJECTED,
            getCurrentTimestamp(), "Tool is blacklisted", {}
        });
        emit operationRejected(toolName);
        return REJECTED;
    }

    // 进行风险评估
    auto findings = m_riskAssessor.assessToolOperation(toolName, action, params);
    auto riskReport = m_riskAssessor.generateRiskReport(findings);
    auto maxRisk = m_riskAssessor.getMaxRiskLevel(findings);

    decisionDetails["risk_level"] = RiskAssessor::riskLevelName(maxRisk);
    decisionDetails["findings_count"] = findings.size();
    decisionDetails["risk_report"] = riskReport;

    // 检查信任工具
    if (getBlacklistedTools().contains(toolName) == false && 
        m_trustedTools.contains(toolName)) {
        if (maxRisk <= RiskAssessor::LOW) {
            recordApprovalDecision({
                toolName, action, APPROVED,
                getCurrentTimestamp(), "Trusted tool with low risk", riskReport
            });
            emit operationApproved(toolName);
            return APPROVED;
        }
    }

    // 基于风险等级和审批策略做决策
    ApprovalDecision decision = evaluateRiskDecision(maxRisk, approvalPolicy);

    if (decision == REQUIRES_REVIEW) {
        decisionDetails["policy"] = approvalPolicy;
        emit approvalRequired(QJsonObject{
            {"tool_name", toolName},
            {"action", action},
            {"risk_level", RiskAssessor::riskLevelName(maxRisk)},
            {"details", decisionDetails}
        });
    }

    // 记录决策
    QString reason;
    if (decision == APPROVED) {
        reason = "Risk level acceptable under policy";
        emit operationApproved(toolName);
    } else if (decision == REJECTED) {
        reason = "Risk level too high";
        emit operationRejected(toolName);
    } else {
        reason = "Requires manual review";
    }

    recordApprovalDecision({
        toolName, action, decision,
        getCurrentTimestamp(), reason, riskReport
    });

    return decision;
}

void GuardianAgentTool::setApprovalPolicy(const QString &toolName, const QString &policy)
{
    m_approvalPolicies[toolName] = policy;
}

QString GuardianAgentTool::getApprovalPolicy(const QString &toolName)
{
    if (m_approvalPolicies.contains(toolName)) {
        return m_approvalPolicies[toolName];
    }
    return m_approvalPolicies.value("*", DEFAULT_POLICY);
}

QStringList GuardianAgentTool::getTrustedTools() const
{
    return m_trustedTools;
}

void GuardianAgentTool::addTrustedTool(const QString &toolName)
{
    if (!m_trustedTools.contains(toolName)) {
        m_trustedTools.append(toolName);
    }
}

void GuardianAgentTool::removeTrustedTool(const QString &toolName)
{
    m_trustedTools.removeAll(toolName);
}

QStringList GuardianAgentTool::getBlacklistedTools() const
{
    return m_blacklistedTools;
}

void GuardianAgentTool::addBlacklistedTool(const QString &toolName)
{
    if (!m_blacklistedTools.contains(toolName)) {
        m_blacklistedTools.append(toolName);
    }
}

void GuardianAgentTool::removeBlacklistedTool(const QString &toolName)
{
    m_blacklistedTools.removeAll(toolName);
}

QJsonObject GuardianAgentTool::generateApprovalReport(
    const QString &toolName,
    const QString &action,
    const QJsonObject &params,
    ApprovalDecision decision)
{
    QJsonObject report;
    report["tool_name"] = toolName;
    report["action"] = action;
    report["decision"] = (decision == APPROVED ? "APPROVED" :
                         decision == REJECTED ? "REJECTED" : "REQUIRES_REVIEW");
    report["timestamp"] = getCurrentTimestamp();
    report["parameters_count"] = params.size();

    return report;
}

GuardianAgentTool::ApprovalDecision GuardianAgentTool::evaluateRiskDecision(
    RiskAssessor::RiskLevel maxRisk,
    const QString &approvalPolicy)
{
    // CRITICAL风险：总是需要人工审核
    if (maxRisk == RiskAssessor::CRITICAL) {
        return REQUIRES_REVIEW;
    }

    // 根据审批策略评估
    if (approvalPolicy == "Never") {
        return APPROVED;
    } else if (approvalPolicy == "OnFailure") {
        return maxRisk >= RiskAssessor::HIGH ? REQUIRES_REVIEW : APPROVED;
    } else if (approvalPolicy == "OnRequest") {
        return REQUIRES_REVIEW;
    } else if (approvalPolicy == "Granular") {
        if (maxRisk >= RiskAssessor::HIGH) {
            return REQUIRES_REVIEW;
        }
        return APPROVED;
    } else if (approvalPolicy == "UnlessTrusted") {
        return maxRisk >= RiskAssessor::MEDIUM ? REQUIRES_REVIEW : APPROVED;
    }

    // 默认：安全第一
    return maxRisk >= RiskAssessor::MEDIUM ? REQUIRES_REVIEW : APPROVED;
}

QString GuardianAgentTool::getCurrentTimestamp() const
{
    return QDateTime::currentDateTime().toString(Qt::ISODate);
}

void GuardianAgentTool::recordApprovalDecision(const ApprovalRecord &record)
{
    m_approvalHistory.append(record);
    trimApprovalHistory();
}

void GuardianAgentTool::trimApprovalHistory()
{
    if (m_approvalHistory.size() > MAX_HISTORY_RECORDS) {
        // 保留最新的记录
        auto newHistory = m_approvalHistory.mid(m_approvalHistory.size() - MAX_HISTORY_RECORDS);
        m_approvalHistory = newHistory;
    }
}
