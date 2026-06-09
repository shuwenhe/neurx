#include "agent/AgentEngine.h"
#include <QtConcurrent/QtConcurrent>
#include <QUuid>
#include <QEventLoop>
#include <QDebug>
#include <QRegularExpression>
#include <QMetaObject>
#include <QMutexLocker>
#include <QMutex>

// Agent Runtime Enhancement components (Tier 3)
#include "agent/SlashCommandManager.h"
#include "agent/EventBus.h"
#include "agent/RuleEngine.h"
#include "agent/MCPManager.h"
#include "agent/ContextManager.h"
#include "agent/ExecutionStrategyManager.h"
#include "security/FolderTrustDiscoveryService.h"

static const QString kDefaultSystem = R"(
You are NeurX Code, an expert software engineering AI assistant.
You have access to tools that let you read and write files, run shell commands,
and search the codebase. Use them to complete coding tasks accurately.

Guidelines:
- Always read relevant files before making changes.
- Prefer targeted edits over rewriting entire files.
- Run tests after making changes when test tooling is available.
- Explain your reasoning briefly before each significant action.
- Ask for clarification if the task is ambiguous.
)";

static QString logMessagePreview(const QString &text, int maxLen = 120)
{
    const QString compact = text.simplified();
    if (compact.size() <= maxLen)
        return compact;
    return compact.left(maxLen) + QStringLiteral("...");
}

AgentEngine::AgentEngine(QObject *parent) : QObject(parent)
{
    m_config.systemPrompt = kDefaultSystem.trimmed();

    // Initialize Agent Runtime Enhancement managers (Tier 3)
    m_eventBus = std::make_unique<EventBus>(this);
    m_slashCommandManager = std::make_unique<SlashCommandManager>(this);
    m_ruleEngine = std::make_unique<RuleEngine>(this);
    m_mcpManager = std::make_unique<MCPManager>(this);
    m_contextManager = std::make_unique<ContextManager>(this);
    m_strategyManager = std::make_unique<ExecutionStrategyManager>(this);

    // Connect EventBus to important signals
    connect(this, &AgentEngine::toolExecuting, m_eventBus.get(), [this](const ToolCall &call) {
        m_eventBus->publishEvent(
            AgentEvent::Type::ToolCalled,
            call.name,
            call.arguments
        );
    });

    connect(this, &AgentEngine::toolFinished, m_eventBus.get(), [this](const ToolResult &result) {
        QJsonObject data;
        data["content"] = result.content;
        data["isError"] = result.isError;
        m_eventBus->publishEvent(
            result.isError ? AgentEvent::Type::ToolFailed : AgentEvent::Type::ToolCompleted,
            result.name,
            data
        );
    });

    connect(this, &AgentEngine::statusChanged, m_eventBus.get(), [this](AgentStatus status) {
        QString statusStr;
        switch (status) {
            case AgentStatus::Thinking:
                statusStr = "Thinking";
                break;
            case AgentStatus::Executing:
                statusStr = "Executing";
                break;
            case AgentStatus::Waiting:
                statusStr = "Waiting";
                break;
            case AgentStatus::Idle:
                statusStr = "Idle";
                break;
        }
        m_eventBus->publishCustomEvent(
            QStringLiteral("ExecutionStatusChanged"),
            QStringLiteral("AgentEngine"),
            QJsonObject{{"status", statusStr}}
        );
    });
}

AgentEngine::~AgentEngine() = default;

void AgentEngine::setProvider(LLMProvider *provider)
{
    if (m_provider) m_provider->disconnect(this);
    m_provider = provider;
    if (m_provider) {
        // Increase context budget for Gemini
        int budget = m_config.contextWindowTokens;
        if (m_provider->providerId() == "gemini") {
            budget = 1000000; // 1M tokens for Gemini
        }
        m_planner.setMaxTokens(m_config.maxCompletionTokens);
        m_planner.setContextBudget(qMax(0, budget - 8192));
        m_planner.setTemperature(0.0f);
        m_executor.setLLMProvider(m_provider);
    }
}

void AgentEngine::setToolRegistry(AgentToolRegistry *registry)
{
    m_registry = registry;
    m_executor.setToolRegistry(registry);
}

void AgentEngine::setApprovalManager(ApprovalManager *manager)
{
    m_approvalManager = manager;
}

void AgentEngine::setConfig(const AgentEngineConfig &config)
{
    m_config = config;
    m_planner.setMaxTokens(m_config.maxCompletionTokens);
    m_planner.setContextBudget(
        qMax(0, m_config.contextWindowTokens - 8192));
    m_planner.setTemperature(0.0f);
    m_planner.setSystemPrompt(m_config.systemPrompt);
}

void AgentEngine::setSystemPrompt(const QString &prompt)
{
    m_config.systemPrompt = prompt;
    m_planner.setSystemPrompt(prompt);
}

void AgentEngine::setAutoApproveTools(bool enabled)
{
    m_config.autoApproveTools = enabled;
}

void AgentEngine::setWorkspaceRoot(const QString &root)
{
    m_workspaceRoot = root;

    // TODO: Perform Folder Trust Discovery when properly integrated
    // Temporarily disabled to avoid duplicate symbol issues
    // FolderDiscoveryResults discovery = FolderTrustDiscoveryService::discover(root);
}

void AgentEngine::setActiveModel(const QString &model)
{
    if (m_activeModel == model) return;
    m_activeModel = model;
    emit activeModelChanged(model);
}

QList<AgentMessage> AgentEngine::history() const
{
    QMutexLocker locker(&m_mutex);
    return m_history;
}

void AgentEngine::setHistory(const QList<AgentMessage> &history)
{
    QMutexLocker locker(&m_mutex);
    m_history = history;
}

void AgentEngine::clearHistory()
{
    QMutexLocker locker(&m_mutex);
    m_history.clear();
}

void AgentEngine::setStatus(AgentStatus s)
{
    if (m_status == s) return;
    m_status = s;
    emit statusChanged(s);
}

void AgentEngine::appendMessage(const AgentMessage &msg)
{
    qDebug() << "[AgentEngine::appendMessage]" << "role=" << (int)msg.role << "content=" << msg.content.left(50);
    {
        QMutexLocker locker(&m_mutex);
        m_history.append(msg);
    }
    emit messageAdded(msg);
}

QString AgentEngine::shellCommandFromCall(const ToolCall &call) const
{
    return call.arguments.value(QStringLiteral("command")).toString().trimmed();
}

bool AgentEngine::isDestructiveShellCommand(const QString &command) const
{
    const QString normalized = command.trimmed().toLower();
    if (normalized.isEmpty())
        return false;

    const QStringList patterns = {
        QStringLiteral(R"(\brm\b.*\s-rf\b)"),
        QStringLiteral(R"(\brm\b.*\s-rf\s)"),
        QStringLiteral(R"(\brm\b.*\s--recursive\b)"),
        QStringLiteral(R"(\bgit\b.*\breset\b.*\b--hard\b)"),
        QStringLiteral(R"(\bgit\b.*\bclean\b.*\b-f\b)"),
        QStringLiteral(R"(\bchmod\b.*\b-R\b.*\b777\b)"),
        QStringLiteral(R"(\bchown\b.*\b-R\b)"),
        QStringLiteral(R"(\bdd\b.*\bof=/dev/\w+\b)"),
        QStringLiteral(R"(\bmkfs\w*\b)"),
        QStringLiteral(R"(\bshutdown\b|\breboot\b|\bhalt\b)"),
        QStringLiteral(R"(\bpowershell\b.*\bremove-item\b.*\b-recurse\b)"),
        QStringLiteral(R"(\bdel\b.*\s\/s\b.*\s\/q\b)")
    };

    for (const auto &pattern : patterns) {
        const QRegularExpression re(pattern, QRegularExpression::CaseInsensitiveOption);
        if (re.match(normalized).hasMatch())
            return true;
    }

    return false;
}

QString AgentEngine::approvalRiskLevel(const ToolCall &call) const
{
    const QString toolName = call.name.trimmed();
    if (toolName == QStringLiteral("run_command") || toolName == QStringLiteral("run_docker_command")) {
        const QString command = shellCommandFromCall(call);
        if (isDestructiveShellCommand(command))
            return QStringLiteral("critical");
        if (toolName == QStringLiteral("run_docker_command"))
            return QStringLiteral("low"); // Sandbox is safer
        return QStringLiteral("high");
    }

    if (toolName == QStringLiteral("patch")
        || toolName == QStringLiteral("apply_patch")
        || toolName == QStringLiteral("file_system")
        || toolName == QStringLiteral("codex_file_system")
        || toolName == QStringLiteral("github")
        || toolName == QStringLiteral("gitlab")
        || toolName == QStringLiteral("jira"))
        return QStringLiteral("high");

    if (toolName == QStringLiteral("web_search")
        || toolName == QStringLiteral("google_search")
        || toolName == QStringLiteral("web_fetch"))
        return QStringLiteral("medium");

    if (toolName == QStringLiteral("codex_agent")) {
        if (!call.arguments.value(QStringLiteral("file_path")).toString().trimmed().isEmpty()
            || !call.arguments.value(QStringLiteral("new_text")).toString().isEmpty()) {
            return QStringLiteral("high");
        }
        return QStringLiteral("medium");
    }

    return QStringLiteral("low");
}

QString AgentEngine::approvalResourceForCall(const ToolCall &call) const
{
    const QString toolName = call.name.trimmed();
    if (toolName == QStringLiteral("run_command") || toolName == QStringLiteral("run_docker_command"))
        return shellCommandFromCall(call);
    if (toolName == QStringLiteral("patch") || toolName == QStringLiteral("apply_patch")) {
        const QString patch = call.arguments.value(QStringLiteral("patch")).toString();
        return patch.isEmpty() ? call.arguments.value(QStringLiteral("input")).toString() : patch;
    }
    if (toolName == QStringLiteral("github") || toolName == QStringLiteral("gitlab") || toolName == QStringLiteral("jira"))
        return QStringLiteral("%1 %2").arg(call.arguments.value("action").toString(), call.arguments.value("repo").toString() + call.arguments.value("project").toString() + call.arguments.value("issue_key").toString());
    if (toolName == QStringLiteral("file_system")
        || toolName == QStringLiteral("codex_file_system")) {
        const QString op = call.arguments.value(QStringLiteral("operation")).toString();
        const QString path = call.arguments.value(QStringLiteral("path")).toString();
        const QString destination = call.arguments.value(QStringLiteral("destination")).toString();
        return destination.isEmpty()
            ? QStringLiteral("%1 %2").arg(op, path)
            : QStringLiteral("%1 %2 -> %3").arg(op, path, destination);
    }
    if (toolName == QStringLiteral("codex_agent")) {
        const QString filePath = call.arguments.value(QStringLiteral("file_path")).toString();
        return !filePath.trimmed().isEmpty()
            ? QStringLiteral("write %1").arg(filePath)
            : call.arguments.value(QStringLiteral("task")).toString();
    }
    return QString();
}

bool AgentEngine::shouldRequireApproval(const ToolCall &call) const
{
    const QString toolName = call.name.trimmed();
    const QString resource = approvalResourceForCall(call);

    if (m_approvalManager) {
        const AskForApproval policy = m_approvalManager->getPolicyFor(toolName, resource);
        if (policy == AskForApproval::Never)
            return false;
        if (!m_config.autoApproveTools)
            return true;
        if (policy == AskForApproval::OnRequest
            || policy == AskForApproval::Granular
            || policy == AskForApproval::UnlessTrusted)
            return true;
        if (policy == AskForApproval::OnFailure)
            return false;
    }

    if (!m_config.autoApproveTools)
        return true;
    const QString risk = approvalRiskLevel(call);
    return risk == QStringLiteral("high") || risk == QStringLiteral("critical");
}

void AgentEngine::injectContext(const QString &filePath, const QString &content,
                                int startLine, int endLine)
{
    QString ctx = QString("```\n// File: %1").arg(filePath);
    if (startLine > 0) ctx += QString(" (lines %1-%2)").arg(startLine).arg(endLine);
    ctx += "\n" + content + "\n```";

    if (m_contextManager) {
        ContextItem item;
        item.type = QStringLiteral("file");
        item.source = filePath;
        item.content = content;
        item.transient = true;
        item.priority = 55;
        item.metadata["display"] = ctx;
        if (startLine > 0) item.metadata["startLine"] = startLine;
        if (endLine > 0) item.metadata["endLine"] = endLine;
        m_contextManager->addContextItem(item);
    }

    AgentMessage msg;
    msg.role    = MessageRole::User;
    msg.content = ctx;
    appendMessage(msg);
}

void AgentEngine::submitUserMessage(const QString &text, const QVariantList &attachments)
{
    if (m_status != AgentStatus::Idle) return;

    // Check for slash commands (Tier 3 enhancement)
    if (text.startsWith('/') && m_slashCommandManager) {
        QJsonObject slashContext;
        slashContext["workspaceRoot"] = m_workspaceRoot;
        slashContext["activeModel"] = m_activeModel;
        slashContext["historySize"] = static_cast<int>(m_history.size());
        if (m_contextManager) {
            slashContext["contextItems"] = m_contextManager->getContextAsJSON();
            slashContext["contextText"] = m_contextManager->getContextAsText();
            slashContext["contextSize"] = m_contextManager->getContextSize();
            slashContext["contextCount"] = static_cast<int>(m_contextManager->allContextItems().size());
        }

        SlashCommandResult result = m_slashCommandManager->executeCommand(text, slashContext);
        if (result.success) {
            AgentMessage cmdResponse;
            cmdResponse.role = MessageRole::Assistant;
            cmdResponse.content = result.output;
            appendMessage(cmdResponse);

            // If the command specified an agent, we might want to switch or delegate
            if (result.metadata.contains("agent")) {
                // Future: implementation for agent delegation
                qDebug() << "[AgentEngine] Command requested specialized agent:" << result.metadata["agent"].toString();
            }

            emit turnComplete();
            return;
        }
    }

    AgentMessage userMsg;
    userMsg.role    = MessageRole::User;
    userMsg.content = text;
    userMsg.attachments = attachments;
    appendMessage(userMsg);

    m_interrupted = false;
    setStatus(AgentStatus::Thinking);

    const auto future = QtConcurrent::run([this]() { runLoop(); });
    Q_UNUSED(future);
}

void AgentEngine::interrupt() { m_interrupted = true; }

void AgentEngine::approveTool(const QString &callId, bool approved)
{
    QMutexLocker locker(&m_mutex);
    if (!m_pendingApprovals.contains(callId)) return;
    if (!approved) {
        m_pendingApprovals.remove(callId);
        ToolResult denied{callId, "", true, "Tool execution denied by user."};
        AgentMessage resultMsg;
        resultMsg.role = MessageRole::Tool;
        resultMsg.toolResults.append(denied);
        locker.unlock();
        appendMessage(resultMsg);
        return;
    }

    // Approval must remove the pending entry so the waiting runLoop can continue.
    m_pendingApprovals.remove(callId);
}

void AgentEngine::runLoop()
{
    int iterations = 0;

    while (iterations++ < m_config.maxIterations && !m_interrupted) {
        if (!m_provider) {
            emit errorOccurred("No LLM provider configured.");
            break;
        }

        // ── Plan request ─────────────────────────────────────────────────────
        const QString providerId = m_provider ? m_provider->providerId() : QString{};
        QList<AgentMessage> requestHistory = history();
        if (m_contextManager) {
            const QString contextText = m_contextManager->getContextAsText().trimmed();
            if (!contextText.isEmpty()) {
                AgentMessage contextMsg;
                contextMsg.role = MessageRole::System;
                contextMsg.content = QStringLiteral(
                    "Workspace context snapshot:\n"
                ) + contextText;
                requestHistory.prepend(contextMsg);
            }
        }
        const LLMRequest req = m_planner.buildRequest(
            requestHistory,
            m_activeModel,
            providerId,
            m_registry);

        qInfo().noquote() << "[agent] request start:"
                  << "provider=" << providerId
                  << "model=" << (req.model.isEmpty() ? m_activeModel : req.model)
                  << "iteration=" << iterations
                  << "messages=" << req.messages.size()
                  << "tools=" << req.tools.size();

        setStatus(AgentStatus::Thinking);

        LLMResponse response;
        bool        done = false;
        QString     providerError;

        // Connect provider signals for this request.
        QMetaObject::Connection connToken = connect(
            m_provider, &LLMProvider::tokenReceived,
            this, [this](const TokenEvent &ev) { emit tokenReceived(ev); });

        QMetaObject::Connection connComplete = connect(
            m_provider, &LLMProvider::responseComplete,
            this, [&](const LLMResponse &r) { response = r; done = true; });

        QMetaObject::Connection connError = connect(
            m_provider, &LLMProvider::requestError,
            this, [&](const QString &err) { providerError = err; done = true; });

        // Run the network request on the provider's own thread. The providers
        // own QNetworkAccessManager instances, so calling them from the worker
        // thread trips Qt's cross-thread QObject checks.
        QEventLoop loop;
        connect(m_provider, &LLMProvider::responseComplete, &loop, &QEventLoop::quit);
        connect(m_provider, &LLMProvider::requestError,     &loop, &QEventLoop::quit);
        if (m_provider->thread() == QThread::currentThread()) {
            m_provider->sendRequest(req);
        } else {
            QMetaObject::invokeMethod(
                m_provider,
                [provider = m_provider, req]() { provider->sendRequest(req); },
                Qt::QueuedConnection);
        }
        loop.exec();

        disconnect(connToken);
        disconnect(connComplete);
        disconnect(connError);

        if (!providerError.isEmpty()) {
            qWarning().noquote() << "[agent] request failed:" << providerError;
            emit errorOccurred(providerError);
            break;
        }

        qInfo().noquote() << "[agent] response received:"
                          << "content=" << logMessagePreview(response.message.content)
                          << "toolCalls=" << response.message.toolCalls.size();

        appendMessage(response.message);

        // ── No tool calls → turn is complete ─────────────────────────────────
        if (m_verifier.turnComplete(response.message)) {
            break;
        }

        // ── Execute tool calls ────────────────────────────────────────────────
        setStatus(AgentStatus::Executing);
        AgentMessage resultsMsg;
        resultsMsg.role = MessageRole::Tool;

        for (const auto &call : response.message.toolCalls) {
            if (m_interrupted) break;

            if (shouldRequireApproval(call)) {
                {
                    QMutexLocker locker(&m_mutex);
                    m_pendingApprovals[call.id] = call;
                }
                emit toolApprovalRequired(call, approvalRiskLevel(call));
                setStatus(AgentStatus::Waiting);
                // Wait for approval
                bool pending = true;
                while (pending && !m_interrupted) {
                    QThread::msleep(100);
                    QMutexLocker locker(&m_mutex);
                    pending = m_pendingApprovals.contains(call.id);
                }
                setStatus(AgentStatus::Executing);
                if (m_interrupted) break;
            }

            emit toolExecuting(call);
            // Forward streaming chunks from the tool to our own signal so the
            // main-thread UI can update the tool card live.
            QMetaObject::Connection streamConn;
            if (auto *t = m_registry->tool(call.name))
                streamConn = connect(t, &BaseTool::outputChunk,
                                     this, &AgentEngine::toolOutputChunk,
                                     Qt::DirectConnection);
            const ToolResult result = m_executor.execute(call);
            if (streamConn) disconnect(streamConn);
            qInfo().noquote() << "[agent] tool result:"
                              << call.name
                              << "callId=" << call.id
                              << "error=" << (result.isError ? "true" : "false");
            emit toolFinished(result);
            resultsMsg.toolResults.append(result);
        }

        appendMessage(resultsMsg);
    }

    setStatus(AgentStatus::Idle);
    emit turnComplete();
}
