#include "agent/AgentEngine.h"
#include <QtConcurrent/QtConcurrent>
#include <QUuid>
#include <QEventLoop>
#include <QDebug>
#include <QRegularExpression>
#include <QMetaObject>
#include <QMutexLocker>
#include <QMutex>

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
        m_planner.setMaxTokens(budget);
        m_planner.setContextBudget(qMax(0, budget - 8192));
        m_planner.setTemperature(0.0f);
    }
}

void AgentEngine::setToolRegistry(ToolRegistry *registry)
{
    m_registry = registry;
    m_executor.setToolRegistry(registry);
}

void AgentEngine::setApprovalManager(ApprovalManager *manager)
{
    m_approvalManager = manager;
}

void AgentEngine::setConfig(const AgentConfig &config)
{
    m_config = config;
    m_planner.setMaxTokens(m_config.contextWindowTokens);
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

void AgentEngine::setActiveModel(const QString &model)
{
    if (m_activeModel == model) return;
    m_activeModel = model;
    emit activeModelChanged(model);
}

void AgentEngine::setHistory(const QList<AgentMessage> &history)
{
    m_history = history;
}

void AgentEngine::clearHistory() { m_history.clear(); }

void AgentEngine::setStatus(AgentStatus s)
{
    if (m_status == s) return;
    m_status = s;
    emit statusChanged(s);
}

void AgentEngine::appendMessage(const AgentMessage &msg)
{
    m_history.append(msg);
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
        || toolName == QStringLiteral("file_system")
        || toolName == QStringLiteral("github")
        || toolName == QStringLiteral("gitlab")
        || toolName == QStringLiteral("jira"))
        return QStringLiteral("high");

    if (toolName == QStringLiteral("web_search")
        || toolName == QStringLiteral("google_search")
        || toolName == QStringLiteral("web_fetch")
        || toolName == QStringLiteral("codex_agent"))
        return QStringLiteral("medium");

    return QStringLiteral("low");
}

QString AgentEngine::approvalResourceForCall(const ToolCall &call) const
{
    const QString toolName = call.name.trimmed();
    if (toolName == QStringLiteral("run_command") || toolName == QStringLiteral("run_docker_command"))
        return shellCommandFromCall(call);
    if (toolName == QStringLiteral("patch"))
        return call.arguments.value(QStringLiteral("patch")).toString();
    if (toolName == QStringLiteral("github") || toolName == QStringLiteral("gitlab") || toolName == QStringLiteral("jira"))
        return QStringLiteral("%1 %2").arg(call.arguments.value("action").toString(), call.arguments.value("repo").toString() + call.arguments.value("project").toString() + call.arguments.value("issue_key").toString());
    if (toolName == QStringLiteral("file_system")) {
        const QString op = call.arguments.value(QStringLiteral("operation")).toString();
        const QString path = call.arguments.value(QStringLiteral("path")).toString();
        const QString destination = call.arguments.value(QStringLiteral("destination")).toString();
        return destination.isEmpty()
            ? QStringLiteral("%1 %2").arg(op, path)
            : QStringLiteral("%1 %2 -> %3").arg(op, path, destination);
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

    AgentMessage msg;
    msg.role    = MessageRole::User;
    msg.content = ctx;
    appendMessage(msg);
}

void AgentEngine::submitUserMessage(const QString &text, const QVariantList &attachments)
{
    if (m_status != AgentStatus::Idle) return;

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
    if (!m_pendingApprovals.contains(callId)) return;
    if (!approved) {
        m_pendingApprovals.remove(callId);
        ToolResult denied{callId, "", true, "Tool execution denied by user."};
        AgentMessage resultMsg;
        resultMsg.role = MessageRole::Tool;
        resultMsg.toolResults.append(denied);
        appendMessage(resultMsg);
    }
    // If approved, the runLoop re-checks and proceeds.
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
        const LLMRequest req = m_planner.buildRequest(
            m_history,
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
                m_pendingApprovals[call.id] = call;
                emit toolApprovalRequired(call, approvalRiskLevel(call));
                setStatus(AgentStatus::Waiting);
                // Wait for approval (poll with small sleep — production would use semaphore)
                while (m_pendingApprovals.contains(call.id) && !m_interrupted)
                    QThread::msleep(100);
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
