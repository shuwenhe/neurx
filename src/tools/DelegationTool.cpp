#include "tools/DelegationTool.h"
#include <QEventLoop>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

DelegationTool::DelegationTool(AgentToolRegistry *registry, LLMProvider *provider,
                             const QString &model, QObject *parent)
    : BaseTool(parent), m_registry(registry), m_provider(provider), m_model(model)
{}

QJsonObject DelegationTool::parametersSchema() const
{
    return QJsonDocument::fromJson(R"({
        "type": "object",
        "properties": {
            "task": {
                "type": "string",
                "description": "The specific sub-task for the sub-agent to complete."
            },
            "context_files": {
                "type": "array",
                "items": { "type": "string" },
                "description": "Optional list of files the sub-agent should read first."
            }
        },
        "required": ["task"]
    })").object();
}

QString DelegationTool::summary(const QJsonObject &args) const
{
    return "Delegating: " + args["task"].toString();
}

ToolResult DelegationTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString task = args["task"].toString();
    if (task.isEmpty())
        return {callId, name(), true, "Task description is empty."};

    qInfo().noquote() << "[delegation] spawning sub-agent for task:" << task;

    // Create a new independent engine for the sub-task
    AgentEngine subEngine;
    subEngine.setProvider(m_provider);
    subEngine.setToolRegistry(m_registry);
    subEngine.setActiveModel(m_model);
    subEngine.setAutoApproveTools(true); // Sub-agents usually run in full-auto

    // Inject specialized system prompt based on role
    const QString role = args["role"].toString("Generalist");
    QString subSystemPrompt = QString("You are a %1 sub-agent. Task: %2\n").arg(role, task);

    if (role == "Tester") {
        subSystemPrompt += "Focus: Write comprehensive tests (unit, integration). Follow existing project test patterns.";
    } else if (role == "Cleaner") {
        subSystemPrompt += "Focus: Fix style violations, lint errors, and improve documentation. Do not change logic.";
    } else if (role == "Coder") {
        subSystemPrompt += "Focus: Implement details based on the provided architecture. Adhere strictly to interfaces.";
    }

    subSystemPrompt += "\nReturn a concise summary of changes and any remaining issues.";
    subEngine.setSystemPrompt(subSystemPrompt);

    // If context files are provided, inject them
    const QJsonArray files = args["context_files"].toArray();
    for (const auto &f : files) {
        // In a real implementation, we would read the file content here
        // For now, we'll let the sub-agent use its 'search' or 'file_system' tools
    }

    QEventLoop loop;
    QString resultSummary;
    bool isError = false;

    connect(&subEngine, &AgentEngine::turnComplete, &loop, &QEventLoop::quit);
    connect(&subEngine, &AgentEngine::errorOccurred, [&](const QString &err) {
        resultSummary = err;
        isError = true;
        loop.quit();
    });

    // We need to capture the last assistant message as the summary
    connect(&subEngine, &AgentEngine::messageAdded, [&](const AgentMessage &msg) {
        if (msg.role == MessageRole::Assistant) {
            resultSummary = msg.content;
        }
    });

    // Start the sub-agent
    connect(&subEngine, &AgentEngine::tokenReceived, [&](const TokenEvent &ev) {
        if (ev.type == TokenEvent::Type::TextDelta) {
            emit outputChunk(callId, ev.delta);
        }
    });

    connect(&subEngine, &AgentEngine::toolExecuting, [&](const ToolCall &subCall) {
        emit outputChunk(callId, QString("\n> Sub-Agent Action: %1\n").arg(subCall.name));
        QVariantMap event;
        event["kind"] = "subagent_tool";
        event["title"] = "Sub-Agent: " + subCall.name;
        event["status"] = "running";
        event["toolName"] = subCall.name;
        emit eventOccurred(callId, event);
    });

    connect(&subEngine, &AgentEngine::toolFinished, [&](const ToolResult &res) {
        if (res.isError) {
            emit outputChunk(callId, QString("\n! Sub-Agent Tool Failed: %1\n").arg(res.content));
        }
        QVariantMap event;
        event["kind"] = "subagent_tool";
        event["title"] = "Sub-Agent: " + res.name;
        event["status"] = res.isError ? "error" : "done";
        event["details"] = res.content.left(100);
        emit eventOccurred(callId, event);
    });

    subEngine.submitUserMessage("Please complete the following task: " + task);

    loop.exec();

    qInfo().noquote() << "[delegation] sub-agent finished. Summary length:" << resultSummary.length();

    return {callId, name(), isError, resultSummary};
}
