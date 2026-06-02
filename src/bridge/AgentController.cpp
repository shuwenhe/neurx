#include "bridge/AgentController.h"
#include "llm/AnthropicProvider.h"
#include "llm/OpenAIProvider.h"
#include "llm/OllamaProvider.h"
#include "tools/FileSystemTool.h"
#include "tools/PatchTool.h"
#include "tools/ShellTool.h"
#include "tools/SearchTool.h"
#include "tools/WebFetchTool.h"
#include "tools/WebSearchTool.h"
#include "tools/CodexTool.h"
#include "tools/CheckpointTool.h"
#include "tools/KnowledgeTool.h"
#include "tools/McpProxyTool.h"
#include "tools/ReminderTool.h"
#include "tools/LocalGatewayServer.h"
#include "tools/MemoryTool.h"
#include "tools/SessionStore.h"
#include "tools/TodoTool.h"
#include <QFile>
#include <QGuiApplication>
#include <QClipboard>
#include <QTextStream>
#include <QFileInfo>
#include <QDateTime>
#include <QJsonDocument>
#include <QDir>
#include <QList>
#include <QProcessEnvironment>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDebug>
#include <algorithm>
#include <limits>

static const QString kControllerSystemPrompt = R"(
You are NeurX Code, an expert software engineering AI assistant.
You are operating as a code agent, not a chat assistant.
You have access to tools that let you read and write files, apply patches,
run shell commands, and search the codebase. Use them to complete coding tasks accurately.

Guidelines:
- For every coding task, form a concise plan before editing.
- For non-trivial tasks, use the todo tool to maintain a current step list.
- Always read relevant files before making changes.
- Prefer targeted patch edits over rewriting entire files.
- Use web_search to discover current external information, then web_fetch to read the exact page.
- Use knowledge to index and search local workspace documents or notes before reaching for external search.
- Inspect <workspace>/.neurx/mcp.json for additional MCP tools and use them when they fit the task.
- After any edit, verify the result with tests, build commands, or a focused check.
- If verification fails, inspect the failure and iterate until fixed.
- Explain your reasoning briefly before each significant action.
- Ask for clarification if the task is ambiguous.
)";

static const char kSiliconFlowOpenAIEndpoint[] = "https://api.siliconflow.cn/v1/chat/completions";
static const char kSettingsGroup[] = "neurx_code";
static const char kSettingsCurrentProvider[] = "current_provider";
static const char kSettingsCurrentModel[] = "current_model";
static const char kSettingsAnthropicEndpoint[] = "anthropic_endpoint";
static const char kSettingsOpenAIEndpoint[] = "openai_endpoint";
static const char kSettingsAnthropicApiKey[] = "anthropic_api_key";
static const char kSettingsOpenAIApiKey[]    = "openai_api_key";
static const char kSettingsBraveApiKey[]     = "brave_api_key";
static const char kSettingsAutoApproveTools[] = "auto_approve_tools";
static const char kSettingsWorkspacePath[] = "workspace_path";
static const char kSettingsCurrentFilePath[] = "current_file_path";

static QString envValue(const char *name)
{
    return QProcessEnvironment::systemEnvironment().value(name).trimmed();
}

static QString firstNonEmptyEnvValue(std::initializer_list<const char *> names)
{
    for (const char *name : names) {
        const QString value = envValue(name);
        if (!value.isEmpty())
            return value;
    }
    return {};
}

static bool hasAnyEnvValue(std::initializer_list<const char *> names)
{
    const auto env = QProcessEnvironment::systemEnvironment();
    for (const char *name : names) {
        if (!env.value(name).trimmed().isEmpty())
            return true;
    }
    return false;
}

static QString defaultSecretsEnvPath()
{
    return QDir::homePath() + QStringLiteral("/.config/neurx-code/secrets.env");
}

static QString secretsEnvPathIfExists()
{
    const QString p1 = defaultSecretsEnvPath();
    if (QFileInfo::exists(p1))
        return p1;

    const QString appCfg = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (!appCfg.isEmpty()) {
        const QString p2 = QDir(appCfg).filePath(QStringLiteral("secrets.env"));
        if (QFileInfo::exists(p2))
            return p2;
    }
    return {};
}

static QHash<QString, QString> loadDotenvFile(const QString &path)
{
    QHash<QString, QString> out;
    if (path.trimmed().isEmpty())
        return out;

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return out;

    QTextStream ts(&f);
    while (!ts.atEnd()) {
        QString line = ts.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        if (line.startsWith(QStringLiteral("export ")))
            line = line.mid(7).trimmed();

        const int eq = line.indexOf('=');
        if (eq <= 0)
            continue;

        const QString key = line.left(eq).trimmed();
        QString value = line.mid(eq + 1).trimmed();
        if (value.size() >= 2) {
            const QChar q = value.front();
            if ((q == QLatin1Char('\"') || q == QLatin1Char('\'')) && value.back() == q)
                value = value.mid(1, value.size() - 2);
        }
        if (!key.isEmpty() && !value.isEmpty())
            out.insert(key, value);
    }
    return out;
}

static QString firstNonEmptySecretsValue(const QHash<QString, QString> &kv,
                                        std::initializer_list<const char *> names)
{
    for (const char *name : names) {
        const QString v = kv.value(QString::fromUtf8(name)).trimmed();
        if (!v.isEmpty())
            return v;
    }
    return {};
}

static QString normalizeOpenAICompatEndpoint(QString endpoint)
{
    endpoint = endpoint.trimmed();
    if (endpoint.isEmpty())
        return {};
    while (endpoint.endsWith('/'))
        endpoint.chop(1);

    if (endpoint.contains(QStringLiteral("/chat/completions")))
        return endpoint;

    if (endpoint.endsWith(QStringLiteral("/v1")))
        return endpoint + QStringLiteral("/chat/completions");

    if (endpoint.contains(QStringLiteral("/v1")))
        return endpoint + QStringLiteral("/chat/completions");

    return endpoint + QStringLiteral("/v1/chat/completions");
}

static QString fileDisplayName(const QString &path)
{
    if (path.isEmpty())
        return QStringLiteral("Untitled");
    return QFileInfo(path).fileName();
}

static QString logPreview(const QString &text, int maxLen = 120)
{
    const QString compact = text.simplified();
    if (compact.size() <= maxLen)
        return compact;
    return compact.left(maxLen) + QStringLiteral("...");
}

static QString summarizeCheckpointFiles(const QVariantList &files)
{
    if (files.isEmpty())
        return QString{};

    QStringList preview;
    const qsizetype previewCount = std::min(files.size(), qsizetype(3));
    for (qsizetype i = 0; i < previewCount; ++i)
        preview << files.at(i).toString();

    QString summary = QStringLiteral("%1 file%2").arg(files.size()).arg(files.size() == 1 ? "" : "s");
    if (!preview.isEmpty())
        summary += QStringLiteral(": %1").arg(preview.join(QStringLiteral(", ")));
    if (files.size() > previewCount)
        summary += QStringLiteral(", +%1 more").arg(files.size() - previewCount);
    return summary;
}

static QStringList defaultKnowledgeExtensions()
{
    return {
        "cpp", "h", "hpp", "cc", "cxx",
        "qml", "js", "ts",
        "md", "txt", "rst",
        "json", "yaml", "yml",
        "cmake", "sh", "py", "rs"
    };
}

static QString summarizeKnowledgeHits(const QVariantList &hits, const QString &query)
{
    if (hits.isEmpty())
        return QStringLiteral("No results found for: %1").arg(query);

    QStringList lines;
    lines << QStringLiteral("Search results for: %1").arg(query);
    int idx = 1;
    for (const auto &value : hits) {
        const auto map = value.toMap();
        lines << QStringLiteral("[%1] %2 (chunk %3)\n%4")
                     .arg(idx++)
                     .arg(map.value("path").toString())
                     .arg(map.value("chunkIndex").toInt())
                     .arg(map.value("snippet").toString());
    }
    return lines.join(QStringLiteral("\n\n"));
}

static void unregisterToolAndDelete(ToolRegistry *registry, const QString &name)
{
    if (!registry)
        return;

    BaseTool *tool = registry->tool(name);
    if (!tool) {
        registry->unregisterTool(name);
        return;
    }

    registry->unregisterTool(name);
    tool->deleteLater();
}

static QString reminderSummary(const QVariantMap &map)
{
    return QStringLiteral("[%1] %2 at %3")
        .arg(map.value("id").toString(),
             map.value("title").toString(),
             map.value("dueAtUtc").toString());
}

// ── ChatModel ─────────────────────────────────────────────────────────────────

ChatModel::ChatModel(QObject *parent) : QAbstractListModel(parent) {}

QHash<int, QByteArray> ChatModel::roleNames() const
{
    return {
        {RoleRole,      "role"},
        {ContentRole,   "content"},
        {ThinkingRole,  "thinking"},
        {ToolCallsRole, "toolCalls"},
    };
}

QVariant ChatModel::data(const QModelIndex &idx, int role) const
{
    if (!idx.isValid() || idx.row() >= m_msgs.size()) return {};
    const auto &m = m_msgs[idx.row()];
    switch (role) {
    case RoleRole:      return m.role;
    case ContentRole:   return m.content;
    case ThinkingRole:  return m.thinking;
    case ToolCallsRole: return m.toolCalls;
    default:            return {};
    }
}

void ChatModel::append(const ChatMessage &msg)
{
    beginInsertRows({}, m_msgs.size(), m_msgs.size());
    m_msgs.append(msg);
    endInsertRows();
}

void ChatModel::updateLastContent(const QString &delta)
{
    if (m_msgs.isEmpty()) return;
    m_msgs.last().content += delta;
    const auto idx = index(m_msgs.size() - 1);
    emit dataChanged(idx, idx, {ContentRole});
}

void ChatModel::replaceLast(const ChatMessage &msg)
{
    if (m_msgs.isEmpty()) {
        append(msg);
        return;
    }

    m_msgs.last() = msg;
    const auto idx = index(m_msgs.size() - 1);
    emit dataChanged(idx, idx, {RoleRole, ContentRole, ThinkingRole, ToolCallsRole});
}

void ChatModel::appendToolCallToLastAssistant(const QVariantMap &card)
{
    for (int i = m_msgs.size() - 1; i >= 0; --i) {
        if (m_msgs[i].role != "assistant")
            continue;
        m_msgs[i].toolCalls.append(card);
        const auto idx = index(i);
        emit dataChanged(idx, idx, {ToolCallsRole});
        return;
    }
}

void ChatModel::updateToolCall(const QString &callId, const QVariantMap &card)
{
    for (int i = m_msgs.size() - 1; i >= 0; --i) {
        if (m_msgs[i].role != "assistant")
            continue;

        for (int j = 0; j < m_msgs[i].toolCalls.size(); ++j) {
            const auto existing = m_msgs[i].toolCalls[j].toMap();
            if (existing.value("id").toString() != callId)
                continue;
            m_msgs[i].toolCalls[j] = card;
            const auto idx = index(i);
            emit dataChanged(idx, idx, {ToolCallsRole});
            return;
        }
    }
}

void ChatModel::clear()
{
    beginResetModel();
    m_msgs.clear();
    endResetModel();
}

// ── AgentController ───────────────────────────────────────────────────────────

AgentController::AgentController(QObject *parent) : QObject(parent)
{
    m_chatModel = new ChatModel(this);
    m_registry  = new ToolRegistry(this);
    m_engine    = new AgentEngine(this);
    m_workspaceContext = new WorkspaceContext(this);
    m_workspaceIndex   = new WorkspaceIndex(this);

    // Register providers
    auto *anthropic = new AnthropicProvider(this);
    auto *openai    = new OpenAIProvider(this);
    auto *ollama    = new OllamaProvider(this);
    m_providers["anthropic"] = anthropic;
    m_providers["openai"]    = openai;
    m_providers["ollama"]    = ollama;

    m_currentProvider = "openai";
    m_currentModel    = openai->availableModels().first();
    m_anthropicEndpoint = QStringLiteral("https://api.anthropic.com/v1/messages");
    m_openaiEndpoint  = QString::fromUtf8(kSiliconFlowOpenAIEndpoint);
    m_sessionId = TaskSessionStore::defaultSessionId();

    loadSettings();
    setupEngine();
    restoreTaskSession();
    startLocalGateway();

    if (!m_currentFilePath.isEmpty() && QFileInfo::exists(m_currentFilePath)) {
        openEditorFile(m_currentFilePath);
    }
}

void AgentController::loadSettings()
{
    QSettings s;
    s.beginGroup(kSettingsGroup);

    const QString provider = s.value(kSettingsCurrentProvider, m_currentProvider).toString();
    const QString model = s.value(kSettingsCurrentModel, m_currentModel).toString();
    const QString anthropicEndpoint = s.value(kSettingsAnthropicEndpoint, m_anthropicEndpoint).toString();
    const QString endpoint = s.value(kSettingsOpenAIEndpoint, m_openaiEndpoint).toString();
    const QString anthropicApiKey = s.value(kSettingsAnthropicApiKey, m_anthropicApiKey).toString();
    const QString openaiApiKey = s.value(kSettingsOpenAIApiKey, m_openaiApiKey).toString();
    const bool autoApprove = s.value(kSettingsAutoApproveTools, m_autoApproveTools).toBool();
    const QString workspace = s.value(kSettingsWorkspacePath, QString{}).toString();
    const QString currentFile = s.value(kSettingsCurrentFilePath, QString{}).toString();

    s.endGroup();

    m_anthropicEndpoint = anthropicEndpoint.trimmed().isEmpty()
        ? QStringLiteral("https://api.anthropic.com/v1/messages")
        : anthropicEndpoint.trimmed();
    const QString envEndpoint = firstNonEmptyEnvValue({
        // SiliconFlow / OpenAI-compatible
        "SILICONFLOW_API_URL",
        "SILICONFLOW_API_ENDPOINT",
        "SILICONFLOW_API_BASE_URL",
        // Generic OpenAI-compatible
        "OPENAI_API_URL",
        "OPENAI_API_ENDPOINT",
        "OPENAI_API_BASE_URL",
        "OPENAI_BASE_URL",
    });

    const QString secretsPath = secretsEnvPathIfExists();
    const auto secrets = loadDotenvFile(secretsPath);
    const QString secretsEndpoint = firstNonEmptySecretsValue(secrets, {
        "SILICONFLOW_API_URL",
        "SILICONFLOW_API_ENDPOINT",
        "SILICONFLOW_API_BASE_URL",
        "OPENAI_API_URL",
        "OPENAI_API_ENDPOINT",
        "OPENAI_API_BASE_URL",
        "OPENAI_BASE_URL",
    });

    const QString settingsEndpoint = endpoint.trimmed();

    // Precedence: env > Settings(UI) > secrets.env > default.
    QString chosenEndpoint;
    if (!envEndpoint.isEmpty()) {
        chosenEndpoint = envEndpoint;
        m_openaiEndpointFromRuntime = true;
    } else if (!settingsEndpoint.isEmpty()) {
        chosenEndpoint = settingsEndpoint;
        m_openaiEndpointFromRuntime = false;
    } else if (!secretsEndpoint.isEmpty()) {
        chosenEndpoint = secretsEndpoint;
        m_openaiEndpointFromRuntime = true;
    } else {
        chosenEndpoint = QString::fromUtf8(kSiliconFlowOpenAIEndpoint);
        m_openaiEndpointFromRuntime = false;
    }
    m_openaiEndpoint = normalizeOpenAICompatEndpoint(chosenEndpoint);

    m_anthropicApiKey = anthropicApiKey.trimmed();

    const QString envOpenaiKey = firstNonEmptyEnvValue({
        "SILICONFLOW_API_KEY",
        "OPENAI_API_KEY",
        "OPENAI_COMPATIBLE_API_KEY",
    });
    const QString secretsOpenaiKey = firstNonEmptySecretsValue(secrets, {
        "SILICONFLOW_API_KEY",
        "OPENAI_API_KEY",
        "OPENAI_COMPATIBLE_API_KEY",
    });
    const QString settingsOpenaiKey = openaiApiKey.trimmed();

    // Precedence: env > Settings(UI) > secrets.env.
    if (!envOpenaiKey.isEmpty()) {
        m_openaiApiKey = envOpenaiKey;
        m_openaiApiKeyFromRuntime = true;
    } else if (!settingsOpenaiKey.isEmpty()) {
        m_openaiApiKey = settingsOpenaiKey;
        m_openaiApiKeyFromRuntime = false;
    } else {
        m_openaiApiKey = secretsOpenaiKey;
        m_openaiApiKeyFromRuntime = !secretsOpenaiKey.isEmpty();
    }

    // Try to load from local secrets.json if still empty or as an override fallback
    if (m_openaiApiKey.isEmpty() || m_anthropicApiKey.isEmpty()) {
        QString secretsPath = QDir::current().filePath(".neurx/secrets.json");
        if (!workspace.isEmpty() && !QFileInfo::exists(secretsPath)) {
            secretsPath = QDir(workspace).filePath(".neurx/secrets.json");
        }
        if (QFileInfo::exists(secretsPath)) {
            QFile f(secretsPath);
            if (f.open(QIODevice::ReadOnly)) {
                const QJsonObject obj = QJsonDocument::fromJson(f.readAll()).object();
                if (m_openaiApiKey.isEmpty() && obj.contains("openai_api_key"))
                    m_openaiApiKey = obj["openai_api_key"].toString().trimmed();
                if (m_anthropicApiKey.isEmpty() && obj.contains("anthropic_api_key"))
                    m_anthropicApiKey = obj["anthropic_api_key"].toString().trimmed();
            }
        }
    }

    m_autoApproveTools = autoApprove;

    if (m_providers.contains(provider)) {
        m_currentProvider = provider;
        auto modelsForProvider = m_providers.value(m_currentProvider)->availableModels();
        if (!model.isEmpty() && modelsForProvider.contains(model))
            m_currentModel = model;
        else if (!modelsForProvider.isEmpty())
            m_currentModel = modelsForProvider.first();
    }

    if (!workspace.isEmpty())
        m_workspacePath = workspace;

    if (!currentFile.isEmpty())
        m_currentFilePath = currentFile;
}

void AgentController::saveSettings() const
{
    QSettings s;
    s.beginGroup(kSettingsGroup);
    s.setValue(kSettingsCurrentProvider, m_currentProvider);
    s.setValue(kSettingsCurrentModel, m_currentModel);
    s.setValue(kSettingsAnthropicEndpoint, m_anthropicEndpoint);

    // If endpoint/key are supplied via environment/secrets.env, treat them as runtime-only
    // and avoid persisting them into local QSettings.
    if (!m_openaiEndpointFromRuntime) {
        s.setValue(kSettingsOpenAIEndpoint, m_openaiEndpoint);
    }

    s.setValue(kSettingsAnthropicApiKey, m_anthropicApiKey);
    if (!m_openaiApiKeyFromRuntime) {
        s.setValue(kSettingsOpenAIApiKey, m_openaiApiKey);
    }
    s.setValue(kSettingsAutoApproveTools, m_autoApproveTools);
    s.setValue(kSettingsWorkspacePath, m_workspacePath);
    s.setValue(kSettingsCurrentFilePath, m_currentFilePath);
    s.endGroup();
    s.sync();
}

QVariantList AgentController::openFiles() const
{
    QVariantList files;
    for (int i = 0; i < m_documents.size(); ++i) {
        const auto &doc = m_documents.at(i);
        QVariantMap item;
        item["path"] = doc.path;
        item["name"] = fileDisplayName(doc.path);
        item["dirty"] = doc.dirty;
        item["active"] = (i == m_currentEditorIndex);
        files.append(item);
    }
    return files;
}

QVariantList AgentController::todoItems() const
{
    if (auto *todoTool = qobject_cast<TodoTool *>(m_registry ? m_registry->tool("todo") : nullptr))
        return todoTool->todoItems();
    return {};
}

QVariantList AgentController::recentCheckpoints() const
{
    if (auto *checkpointTool = qobject_cast<CheckpointTool *>(m_registry ? m_registry->tool("checkpoint") : nullptr))
        return checkpointTool->recentCheckpoints();
    return {};
}

QVariantList AgentController::recentSessions() const
{
    QVariantList sessions;
    const QList<QVariantMap> items = TaskSessionStore::listSessions();
    for (const auto &item : items)
        sessions.append(item);
    return sessions;
}

QVariantList AgentController::knowledgeSources() const
{
    if (auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr))
        return knowledgeTool->sources();
    return {};
}

QVariantList AgentController::scheduledTasks() const
{
    if (auto *reminderTool = qobject_cast<ReminderTool *>(m_registry ? m_registry->tool("schedule") : nullptr))
        return reminderTool->reminders();
    return {};
}

QJsonObject AgentController::localGatewayState() const
{
    QJsonObject state;
    state.insert(QStringLiteral("busy"), m_busy);
    state.insert(QStringLiteral("workspacePath"), m_workspacePath);
    state.insert(QStringLiteral("currentProvider"), m_currentProvider);
    state.insert(QStringLiteral("currentModel"), m_currentModel);
    state.insert(QStringLiteral("currentFilePath"), m_currentFilePath);
    state.insert(QStringLiteral("sessionId"), m_sessionId);
    state.insert(QStringLiteral("todoCount"), int(todoItems().size()));
    state.insert(QStringLiteral("scheduledTaskCount"), int(scheduledTasks().size()));
    state.insert(QStringLiteral("knowledgeSourceCount"), int(knowledgeSources().size()));
    state.insert(QStringLiteral("pendingReminderCount"), m_pendingReminderPrompts.size());
    state.insert(QStringLiteral("workspaceSummary"), workspaceSummary());
    return state;
}

void AgentController::startLocalGateway()
{
    if (!m_gatewayServer)
        m_gatewayServer = new LocalGatewayServer(this);

    quint16 preferredPort = 18081;
    bool ok = false;
    const int envPort = qEnvironmentVariableIntValue("NEURX_GATEWAY_PORT", &ok);
    if (ok && envPort > 0 && envPort <= std::numeric_limits<quint16>::max())
        preferredPort = quint16(envPort);

    if (!m_gatewayServer->start(preferredPort,
        [this](const QString &message) {
            QMetaObject::invokeMethod(this, [this, message]() {
                sendMessage(message);
            }, Qt::QueuedConnection);
        },
        [this]() { return localGatewayState(); })) {
        m_localGatewayUrl.clear();
        m_localGatewayPort = 0;
        emit localGatewayUrlChanged();
        qWarning().noquote() << "[gateway] failed to start local gateway server";
        return;
    }

    m_localGatewayPort = m_gatewayServer->port();
    m_localGatewayUrl = m_gatewayServer->baseUrl();
    emit localGatewayUrlChanged();
    qInfo().noquote() << "[gateway] listening on" << m_localGatewayUrl;
}

void AgentController::setupEngine()
{
    m_engine->setProvider(m_providers.value(m_currentProvider));
    m_engine->setToolRegistry(m_registry);
    m_engine->setActiveModel(m_currentModel);
    m_engine->setAutoApproveTools(m_autoApproveTools);
    if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value("anthropic"))) {
        anthropic->setEndpointOverride(m_anthropicEndpoint);
        anthropic->setApiKey(m_anthropicApiKey);
    }
    if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value("openai"))) {
        openai->setEndpointOverride(m_openaiEndpoint);
        openai->setApiKey(m_openaiApiKey);
    }
    refreshSystemPrompt();

    connect(m_engine, &AgentEngine::tokenReceived,
            this, &AgentController::onTokenReceived);
    connect(m_engine, &AgentEngine::messageAdded,
            this, &AgentController::onMessageAdded);
    connect(m_engine, &AgentEngine::toolExecuting,
            this, &AgentController::onToolExecuting);
    connect(m_engine, &AgentEngine::toolFinished,
            this, &AgentController::onToolFinished);
    connect(m_engine, &AgentEngine::toolOutputChunk,
            this, &AgentController::onToolOutputChunk);
    connect(m_engine, &AgentEngine::toolApprovalRequired,
            this, [this](const ToolCall &call) {
                qInfo().noquote() << "[agent] tool approval required:" << call.name
                                  << "callId=" << call.id;
                emit toolApprovalRequired(call.id, call.name,
                    m_registry->tool(call.name)
                        ? m_registry->tool(call.name)->summary(call.arguments)
                        : call.name);
            });
    connect(m_engine, &AgentEngine::turnComplete,
            this, [this]() {
                qInfo().noquote() << "[agent] turn complete";
                setBusy(false);
                processScheduledReminderQueue();
            });
    connect(m_engine, &AgentEngine::errorOccurred,
            this, [this](const QString &e) {
                qWarning().noquote() << "[agent] error:" << e;
                setBusy(false);
                emit errorOccurred(e);
            });
    connect(m_engine, &AgentEngine::statusChanged,
            this, [this](AgentEngine::AgentStatus s) {
                setBusy(s != AgentEngine::AgentStatus::Idle);
            });

    if (m_workspaceContext) {
        connect(m_workspaceContext, &WorkspaceContext::recentFilesChanged,
                this, &AgentController::refreshSystemPrompt);
        connect(m_workspaceContext, &WorkspaceContext::gitBranchChanged,
                this, &AgentController::refreshSystemPrompt);
    }
    if (m_workspaceIndex) {
        connect(m_workspaceIndex, &WorkspaceIndex::indexChanged,
                this, &AgentController::refreshSystemPrompt);
    }
    emit workspaceSummaryChanged();
}

void AgentController::restoreTaskSession()
{
    const TaskSessionSnapshot snapshot = TaskSessionStore::loadLatest();
    if (!snapshot.isValid())
        return;

    applyTaskSession(snapshot);
}

void AgentController::applyTaskSession(const TaskSessionSnapshot &snapshot)
{
    m_sessionId = snapshot.sessionId;
    m_documents.clear();
    m_currentEditorIndex = -1;
    m_currentFilePath.clear();
    m_currentFileContent.clear();
    emit openFilesChanged();
    emit currentEditorIndexChanged();
    emit currentFilePathChanged();
    emit currentFileContentChanged();

    if (!snapshot.currentProvider.isEmpty() && m_providers.contains(snapshot.currentProvider)) {
        m_currentProvider = snapshot.currentProvider;
        m_engine->setProvider(m_providers.value(m_currentProvider));
    }

    if (!snapshot.currentModel.isEmpty()) {
        m_currentModel = snapshot.currentModel;
        m_engine->setActiveModel(m_currentModel);
    }

    if (!snapshot.workspacePath.isEmpty())
        setWorkspacePath(snapshot.workspacePath);

    if (auto *todoTool = qobject_cast<TodoTool *>(m_registry ? m_registry->tool("todo") : nullptr))
        todoTool->setTodoItems(snapshot.todoItems);

    m_engine->setHistory(snapshot.messages);
    rebuildChatModelFromHistory();

    if (!snapshot.currentFilePath.isEmpty() && QFileInfo::exists(snapshot.currentFilePath))
        openEditorFile(snapshot.currentFilePath);
}

void AgentController::rebuildChatModelFromHistory()
{
    m_chatModel->clear();
    m_streamingText.clear();
    m_streamingAssistantActive = false;
    m_restoringSessionHistory = true;

    for (const auto &msg : m_engine->history()) {
        if (msg.role == MessageRole::Tool) {
            for (const auto &result : msg.toolResults)
                onToolFinished(result);
            continue;
        }
        onMessageAdded(msg);
    }

    m_restoringSessionHistory = false;
}

void AgentController::saveTaskSession()
{
    TaskSessionSnapshot snapshot;
    snapshot.sessionId = m_sessionId.trimmed().isEmpty()
        ? TaskSessionStore::defaultSessionId()
        : m_sessionId;
    snapshot.workspacePath = m_workspacePath;
    snapshot.currentProvider = m_currentProvider;
    snapshot.currentModel = m_currentModel;
    snapshot.currentFilePath = m_currentFilePath;
    snapshot.todoItems = todoItems();
    snapshot.messages = m_engine->history();
    snapshot.updatedAt = QDateTime::currentDateTimeUtc();
    TaskSessionStore::saveLatest(snapshot);
    emit recentSessionsChanged();
}

void AgentController::unloadMcpTools()
{
    const QStringList names = m_mcpToolNames;
    for (const QString &name : names)
        unregisterToolAndDelete(m_registry, name);
    m_mcpToolNames.clear();
    emit mcpToolsChanged();
}

void AgentController::unloadReminderTool()
{
    unregisterToolAndDelete(m_registry, "schedule");
    emit scheduledTasksChanged();
}

void AgentController::processScheduledReminderQueue()
{
    if (m_pendingReminderPrompts.isEmpty())
        return;
    if (!m_engine || m_engine->status() != AgentEngine::AgentStatus::Idle)
        return;

    const QString prompt = m_pendingReminderPrompts.takeFirst();
    qInfo().noquote() << "[agent] reminder follow-up:" << logPreview(prompt);
    QMetaObject::invokeMethod(this, [this, prompt]() {
        sendMessage(prompt);
    }, Qt::QueuedConnection);
}

bool AgentController::resumeTaskSession(const QString &sessionId)
{
    const TaskSessionSnapshot snapshot = TaskSessionStore::loadById(sessionId);
    if (!snapshot.isValid()) {
        emit errorOccurred(QStringLiteral("Session not found."));
        return false;
    }

    applyTaskSession(snapshot);
    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();
    emit workspacePathChanged();
    emit workspaceSummaryChanged();
    emit recentSessionsChanged();
    return true;
}

void AgentController::appendSessionStoreMessage(const QString &role, const QString &content)
{
    if (m_restoringSessionHistory)
        return;
    if (content.trimmed().isEmpty())
        return;
    if (auto *store = qobject_cast<SessionStore *>(m_registry ? m_registry->tool("session_search") : nullptr))
        store->appendMessage(role, content);
}

void AgentController::refreshSystemPrompt()
{
    QString prompt = kControllerSystemPrompt.trimmed();
    const QString workspaceSummary = m_workspaceContext ? m_workspaceContext->buildContextSummary() : QString{};
    const QString indexSummary = m_workspaceIndex ? m_workspaceIndex->buildContextSummary() : QString{};

    if (!workspaceSummary.isEmpty()) {
        prompt += "\n\nWorkspace context:\n" + workspaceSummary;
    }
    if (!indexSummary.isEmpty()) {
        prompt += "\n\nWorkspace index:\n" + indexSummary;
    }
    if (auto *memoryTool = qobject_cast<MemoryTool *>(m_registry ? m_registry->tool("memory") : nullptr)) {
        const QString memorySnapshot = memoryTool->buildSnapshot().trimmed();
        if (!memorySnapshot.isEmpty())
            prompt += "\n\nPersistent memory:\n" + memorySnapshot;
    }
    const QVariantList currentTodos = todoItems();
    if (!currentTodos.isEmpty()) {
        QStringList todoLines;
        for (const QVariant &item : currentTodos) {
            const QVariantMap map = item.toMap();
            todoLines << QStringLiteral("- [%1] %2: %3")
                             .arg(map.value("status").toString(),
                                  map.value("id").toString(),
                                  map.value("content").toString());
        }
        prompt += "\n\nCurrent task plan:\n" + todoLines.join('\n');
    }

    m_engine->setSystemPrompt(prompt);
    emit workspaceSummaryChanged();
}

QStringList AgentController::providers() const { return m_providers.keys(); }

QStringList AgentController::models() const
{
    auto *p = m_providers.value(m_currentProvider);
    return p ? p->availableModels() : QStringList{};
}

QString AgentController::workspaceSummary() const
{
    if (!m_workspaceContext || !m_workspaceIndex) return {};

    QString summary = m_workspaceContext->buildContextSummary();
    const QString indexSummary = m_workspaceIndex->buildContextSummary();
    if (!indexSummary.isEmpty()) {
        if (!summary.isEmpty())
            summary += "\n";
        summary += indexSummary;
    }
    return summary;
}

int AgentController::workspaceFileCount() const
{
    return m_workspaceIndex ? m_workspaceIndex->fileCount() : 0;
}

QStringList AgentController::workspaceTopExtensions() const
{
    return m_workspaceIndex ? m_workspaceIndex->topExtensions() : QStringList{};
}

QStringList AgentController::workspaceRecentFiles() const
{
    return m_workspaceContext ? m_workspaceContext->recentFiles() : QStringList{};
}

QStringList AgentController::searchWorkspacePaths(const QString &needle) const
{
    return m_workspaceIndex ? m_workspaceIndex->searchPaths(needle) : QStringList{};
}

QVariantList AgentController::checkpointPreview(const QString &checkpointId) const
{
    auto *checkpointTool = qobject_cast<CheckpointTool *>(m_registry ? m_registry->tool("checkpoint") : nullptr);
    if (!checkpointTool)
        return {};

    const QString normalizedId = checkpointId.trimmed();
    if (normalizedId.isEmpty())
        return {};

    QString error;
    const QVariantList files = checkpointTool->filesForCheckpoint(normalizedId, &error);
    if (!error.isEmpty())
        qWarning().noquote() << "[checkpoint] preview failed:" << error;
    return files;
}

bool AgentController::currentFileDirty() const
{
    if (m_currentEditorIndex < 0 || m_currentEditorIndex >= m_documents.size())
        return false;
    return m_documents.at(m_currentEditorIndex).dirty;
}

void AgentController::setAnthropicEndpoint(const QString &url)
{
    const QString normalized = url.trimmed().isEmpty()
        ? QStringLiteral("https://api.anthropic.com/v1/messages")
        : url.trimmed();
    if (m_anthropicEndpoint == normalized) return;
    m_anthropicEndpoint = normalized;
    if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value("anthropic"))) {
        anthropic->setEndpointOverride(m_anthropicEndpoint);
    }
    saveSettings();
    emit anthropicEndpointChanged();
}

void AgentController::setOpenaiEndpoint(const QString &url)
{
    const QString fallback = QString::fromUtf8(kSiliconFlowOpenAIEndpoint);
    const QString normalized = normalizeOpenAICompatEndpoint(url.trimmed().isEmpty() ? fallback : url);
    if (m_openaiEndpoint == normalized) return;
    m_openaiEndpoint = normalized;
    m_openaiEndpointFromRuntime = false;
    saveSettings();
    if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value("openai"))) {
        openai->setEndpointOverride(m_openaiEndpoint);
    }
    emit openaiEndpointChanged();
}

void AgentController::setAnthropicApiKey(const QString &key)
{
    const QString normalized = key.trimmed();
    if (m_anthropicApiKey == normalized) return;
    m_anthropicApiKey = normalized;
    if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value("anthropic"))) {
        anthropic->setApiKey(m_anthropicApiKey);
    }
    saveSettings();
    emit anthropicApiKeyChanged();
}

void AgentController::setOpenaiApiKey(const QString &key)
{
    const QString normalized = key.trimmed();
    if (m_openaiApiKey == normalized) return;
    m_openaiApiKey = normalized;
    m_openaiApiKeyFromRuntime = false;
    if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value("openai"))) {
        openai->setApiKey(m_openaiApiKey);
    }
    saveSettings();
    emit openaiApiKeyChanged();
}

void AgentController::setBraveApiKey(const QString &key)
{
    const QString normalized = key.trimmed();
    if (m_braveApiKey == normalized) return;
    m_braveApiKey = normalized;
    saveSettings();
    emit braveApiKeyChanged();
}

void AgentController::setCurrentFileContent(const QString &text)
{
    if (m_currentEditorIndex < 0 || m_currentEditorIndex >= m_documents.size()) {
        if (m_currentFileContent == text) return;
        m_currentFileContent = text;
        emit currentFileContentChanged();
        return;
    }

    auto &doc = m_documents[m_currentEditorIndex];
    if (doc.content == text) return;
    doc.content = text;
    doc.dirty = (doc.content != doc.savedContent);
    m_currentFileContent = text;
    emit openFilesChanged();
    emit currentFileContentChanged();
}

void AgentController::setCurrentEditorIndex(int index)
{
    if (index < 0 || index >= m_documents.size() || m_currentEditorIndex == index)
        return;

    m_currentEditorIndex = index;
    const auto &doc = m_documents.at(m_currentEditorIndex);
    qInfo().noquote() << QStringLiteral("[AgentController] setCurrentEditorIndex -> index=%1 path=%2").arg(index).arg(doc.path);
    const QString oldPath = m_currentFilePath;
    const QString oldContent = m_currentFileContent;
    m_currentFilePath = doc.path;
    m_currentFileContent = doc.content;

    if (oldPath != m_currentFilePath)
        emit currentFilePathChanged();
    if (oldContent != m_currentFileContent)
        emit currentFileContentChanged();
    emit currentEditorIndexChanged();
    emit openFilesChanged();
    saveSettings();
    refreshSystemPrompt();
}

void AgentController::copyPathToClipboard(const QString &path)
{
    const QString normalized = path.trimmed();
    if (normalized.isEmpty())
        return;
    if (auto *clipboard = QGuiApplication::clipboard())
        clipboard->setText(normalized);
}

void AgentController::setCurrentProvider(const QString &id)
{
    if (!m_providers.contains(id) || m_currentProvider == id) return;
    m_currentProvider = id;
    m_engine->setProvider(m_providers.value(id));
    if (id == "anthropic") {
        if (auto *anthropic = qobject_cast<AnthropicProvider *>(m_providers.value(id))) {
            anthropic->setEndpointOverride(m_anthropicEndpoint);
            anthropic->setApiKey(m_anthropicApiKey);
        }
    }
    if (id == "openai") {
        if (auto *openai = qobject_cast<OpenAIProvider *>(m_providers.value(id))) {
            openai->setEndpointOverride(m_openaiEndpoint);
            openai->setApiKey(m_openaiApiKey);
        }
    }
    m_currentModel = models().value(0);
    m_engine->setActiveModel(m_currentModel);
    saveSettings();
    emit currentProviderChanged();
    emit currentModelChanged();
}

void AgentController::setCurrentModel(const QString &model)
{
    if (m_currentModel == model) return;
    m_currentModel = model;
    m_engine->setActiveModel(model);
    saveSettings();
    emit currentModelChanged();
}

void AgentController::setWorkspacePath(const QString &path)
{
    if (m_workspacePath == path) return;
    unloadMcpTools();
    m_workspacePath = path;
    if (m_workspaceContext) m_workspaceContext->setRootPath(path);
    if (m_workspaceIndex)   m_workspaceIndex->setRootPath(path);

    // Re-instantiate file-system tools with the new root.
    unregisterToolAndDelete(m_registry, "file_system");
    unregisterToolAndDelete(m_registry, "patch");
    unregisterToolAndDelete(m_registry, "run_command");
    unregisterToolAndDelete(m_registry, "search");
    unregisterToolAndDelete(m_registry, "web_search");
    unregisterToolAndDelete(m_registry, "web_fetch");
    unregisterToolAndDelete(m_registry, "codex_agent");
    unregisterToolAndDelete(m_registry, "checkpoint");
    unregisterToolAndDelete(m_registry, "memory");
    unregisterToolAndDelete(m_registry, "session_search");
    unregisterToolAndDelete(m_registry, "todo");
    unregisterToolAndDelete(m_registry, "knowledge");
    unloadReminderTool();

    m_registry->registerTool(new FileSystemTool(path, m_registry));
    m_registry->registerTool(new PatchTool(path, m_registry));
    m_registry->registerTool(new ShellTool(path, m_registry));
    m_registry->registerTool(new SearchTool(path, m_registry));
    m_registry->registerTool(new WebSearchTool(m_registry));
    m_registry->registerTool(new WebFetchTool(m_registry));
    m_registry->registerTool(new CodexTool(path, m_registry));
    auto *checkpointTool = new CheckpointTool(path, m_registry);
    connect(checkpointTool, &CheckpointTool::checkpointRolledBack,
            this, [this]() {
                if (m_workspaceIndex)
                    m_workspaceIndex->refresh();
                if (!m_currentFilePath.isEmpty() && QFileInfo::exists(m_currentFilePath))
                    openEditorFile(m_currentFilePath);
                refreshSystemPrompt();
                emit recentCheckpointsChanged();
    });
    m_registry->registerTool(checkpointTool);
    m_registry->registerTool(new MemoryTool(path, m_registry));
    auto *knowledgeTool = new KnowledgeTool(m_registry);
    knowledgeTool->setDbPath(QDir(path).filePath(QStringLiteral(".neurx/knowledge.db")));
    m_registry->registerTool(knowledgeTool);
    auto *reminderTool = new ReminderTool(path, m_registry);
    connect(reminderTool, &ReminderTool::reminderTriggered,
            this, [this](const QVariantMap &reminder) {
                const QString summary = reminderSummary(reminder);
                const QString prompt = QStringLiteral(
                    "Scheduled reminder triggered: %1. Acknowledge it and take the next relevant action.")
                    .arg(summary);
                ChatMessage msg;
                msg.role = QStringLiteral("tool");
                msg.content = QStringLiteral("schedule: due %1").arg(summary);
                m_chatModel->append(msg);
                appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
                saveTaskSession();
                emit successOccurred(QStringLiteral("Reminder due: %1").arg(summary));
                if (m_engine && m_engine->status() == AgentEngine::AgentStatus::Idle) {
                    QMetaObject::invokeMethod(this, [this, prompt]() {
                        sendMessage(prompt);
                    }, Qt::QueuedConnection);
                } else {
                    m_pendingReminderPrompts.append(prompt);
                }
            });
    connect(reminderTool, &ReminderTool::remindersChanged,
            this, &AgentController::scheduledTasksChanged);
    m_registry->registerTool(reminderTool);
    auto *sessionStore = new SessionStore(m_registry);
    sessionStore->beginSession(path);
    m_registry->registerTool(sessionStore);
    auto *todoTool = new TodoTool(m_registry);
    connect(todoTool, &TodoTool::todoItemsChanged,
            this, &AgentController::todoItemsChanged);
    connect(todoTool, &TodoTool::todoItemsChanged,
            this, [this]() {
                saveTaskSession();
                refreshSystemPrompt();
    });
    m_registry->registerTool(todoTool);

    const QList<BaseTool *> mcpTools = McpServerLoader::loadFromConfig(path, m_registry);
    for (BaseTool *tool : mcpTools) {
        if (!tool)
            continue;
        if (m_registry->tool(tool->name())) {
            qWarning().noquote() << "[MCP] Skipping duplicate tool name:" << tool->name();
            tool->deleteLater();
            continue;
        }
        m_registry->registerTool(tool);
        m_mcpToolNames.append(tool->name());
    }
    emit mcpToolsChanged();

    if (!m_currentFilePath.isEmpty() && QFileInfo::exists(m_currentFilePath)) {
        openEditorFile(m_currentFilePath);
    }

    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();

    emit workspacePathChanged();
    emit workspaceSummaryChanged();
    emit recentCheckpointsChanged();
    emit knowledgeSourcesChanged();
}

bool AgentController::indexWorkspaceKnowledge()
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }
    if (m_workspacePath.isEmpty()) {
        emit errorOccurred(QStringLiteral("Open a workspace first."));
        return false;
    }

    const ToolResult result = knowledgeTool->execute(
        QStringLiteral("ui-knowledge-index"),
        QJsonObject{
            {"action", "index_directory"},
            {"path", m_workspacePath},
            {"extensions", QJsonArray::fromStringList(defaultKnowledgeExtensions())},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge: %1").arg(result.content);
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();
    m_knowledgeSearchQuery.clear();
    m_knowledgeSearchResults.clear();
    emit knowledgeSearchResultsChanged();
    emit knowledgeSourcesChanged();
    emit successOccurred(result.content);
    return true;
}

bool AgentController::indexCurrentFileKnowledge()
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }

    if (m_currentFilePath.isEmpty() || !QFileInfo::exists(m_currentFilePath)) {
        emit errorOccurred(QStringLiteral("Open a file first."));
        return false;
    }

    const ToolResult result = knowledgeTool->execute(
        QStringLiteral("ui-knowledge-index-file"),
        QJsonObject{
            {"action", "index_file"},
            {"path", m_currentFilePath},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge: %1").arg(result.content);
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();
    m_knowledgeSearchQuery.clear();
    m_knowledgeSearchResults.clear();
    emit knowledgeSearchResultsChanged();
    emit knowledgeSourcesChanged();
    emit successOccurred(result.content);
    return true;
}

bool AgentController::indexRecentFilesKnowledge()
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }

    const QStringList recentFiles = m_workspaceContext ? m_workspaceContext->recentFiles() : QStringList{};
    if (recentFiles.isEmpty()) {
        emit errorOccurred(QStringLiteral("No recent files to index."));
        return false;
    }

    int indexedCount = 0;
    QStringList indexedPaths;
    QStringList skippedPaths;
    for (const QString &path : recentFiles.mid(0, 8)) {
        if (path.trimmed().isEmpty() || !QFileInfo::exists(path)) {
            skippedPaths << path;
            continue;
        }

        const ToolResult result = knowledgeTool->execute(
            QStringLiteral("ui-knowledge-index-file"),
            QJsonObject{
                {"action", "index_file"},
                {"path", path},
            });
        if (result.isError) {
            skippedPaths << path;
            continue;
        }
        ++indexedCount;
        indexedPaths << path;
    }

    emit knowledgeSourcesChanged();

    if (indexedCount == 0) {
        emit errorOccurred(QStringLiteral("No recent files could be indexed."));
        return false;
    }

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge: indexed %1 recent file%2.")
                      .arg(indexedCount)
                      .arg(indexedCount == 1 ? "" : "s");
    if (!indexedPaths.isEmpty())
        msg.content += QStringLiteral(" %1").arg(indexedPaths.join(QStringLiteral(", ")));
    if (!skippedPaths.isEmpty())
        msg.content += QStringLiteral(" Skipped %1 path%2.")
                           .arg(skippedPaths.size())
                           .arg(skippedPaths.size() == 1 ? "" : "s");
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();
    m_knowledgeSearchQuery.clear();
    m_knowledgeSearchResults.clear();
    emit knowledgeSearchResultsChanged();
    emit successOccurred(QStringLiteral("Indexed %1 recent file%2.")
                            .arg(indexedCount)
                            .arg(indexedCount == 1 ? "" : "s"));
    return true;
}

QString AgentController::searchWorkspaceKnowledge(const QString &query)
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        const QString error = QStringLiteral("Knowledge tool is not available.");
        emit errorOccurred(error);
        return error;
    }

    const QString normalized = query.trimmed();
    if (normalized.isEmpty()) {
        const QString error = QStringLiteral("Search query cannot be empty.");
        emit errorOccurred(error);
        return error;
    }

    QString error;
    const QVariantList hits = knowledgeTool->searchEntries(normalized, 5, &error);
    const ToolResult result = error.isEmpty()
        ? ToolResult{
            QStringLiteral("ui-knowledge-search"),
            knowledgeTool->name(),
            false,
            summarizeKnowledgeHits(hits, normalized),
        }
        : ToolResult{
            QStringLiteral("ui-knowledge-search"),
            knowledgeTool->name(),
            true,
            error,
        };

    ChatMessage msg;
    msg.role = QStringLiteral("tool");
    msg.content = QStringLiteral("knowledge search: %1").arg(result.content);
    m_chatModel->append(msg);
    appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
    saveTaskSession();

    if (result.isError) {
        m_knowledgeSearchQuery = normalized;
        m_knowledgeSearchResults.clear();
        emit knowledgeSearchResultsChanged();
        emit errorOccurred(result.content);
        return result.content;
    }

    m_knowledgeSearchQuery = normalized;
    m_knowledgeSearchResults = hits;
    emit knowledgeSearchResultsChanged();
    emit knowledgeSourcesChanged();
    emit successOccurred(QStringLiteral("Knowledge search completed."));
    return result.content;
}

bool AgentController::removeKnowledgeSource(const QString &path)
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool) {
        emit errorOccurred(QStringLiteral("Knowledge tool is not available."));
        return false;
    }

    QString error;
    if (!knowledgeTool->removeSourcePath(path, &error)) {
        emit errorOccurred(error.isEmpty() ? QStringLiteral("Failed to remove knowledge source.") : error);
        return false;
    }

    emit knowledgeSourcesChanged();
    emit successOccurred(QStringLiteral("Removed knowledge source."));
    return true;
}

bool AgentController::createReminder(const QString &title, int dueInMinutes, int repeatMinutes)
{
    auto *reminderTool = qobject_cast<ReminderTool *>(m_registry ? m_registry->tool("schedule") : nullptr);
    if (!reminderTool) {
        emit errorOccurred(QStringLiteral("Schedule tool is not available."));
        return false;
    }

    if (title.trimmed().isEmpty()) {
        emit errorOccurred(QStringLiteral("Title cannot be empty."));
        return false;
    }
    if (dueInMinutes < 0 || repeatMinutes < 0) {
        emit errorOccurred(QStringLiteral("Time values must be zero or greater."));
        return false;
    }

    const ToolResult result = reminderTool->execute(
        QStringLiteral("ui-schedule-create"),
        QJsonObject{
            {"action", "create"},
            {"title", title.trimmed()},
            {"due_in_minutes", dueInMinutes},
            {"repeat_minutes", repeatMinutes},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    emit scheduledTasksChanged();
    emit successOccurred(result.content);
    return true;
}

bool AgentController::cancelReminder(const QString &id)
{
    auto *reminderTool = qobject_cast<ReminderTool *>(m_registry ? m_registry->tool("schedule") : nullptr);
    if (!reminderTool) {
        emit errorOccurred(QStringLiteral("Schedule tool is not available."));
        return false;
    }

    const ToolResult result = reminderTool->execute(
        QStringLiteral("ui-schedule-cancel"),
        QJsonObject{
            {"action", "cancel"},
            {"id", id.trimmed()},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    emit scheduledTasksChanged();
    emit successOccurred(result.content);
    return true;
}

void AgentController::syncKnowledgeForPathChange(const QString &oldPath, const QString &newPath, bool wasDirectory)
{
    auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr);
    if (!knowledgeTool)
        return;

    QString error;
    const QString oldAbs = QFileInfo(oldPath).absoluteFilePath();
    if (!oldAbs.isEmpty()) {
        if (wasDirectory)
            knowledgeTool->removeSourcePrefix(oldAbs, &error);
        else
            knowledgeTool->removeSourcePath(oldAbs, &error);
        if (!error.isEmpty())
            qWarning().noquote() << "[knowledge] cleanup failed:" << error;
    }

    const QString newAbs = QFileInfo(newPath).absoluteFilePath();
    if (newAbs.isEmpty() || !QFileInfo::exists(newAbs))
        return;

    const ToolResult result = QFileInfo(newAbs).isDir()
        ? knowledgeTool->execute(
              QStringLiteral("ui-knowledge-index-directory"),
              QJsonObject{
                  {"action", "index_directory"},
                  {"path", newAbs},
                  {"extensions", QJsonArray::fromStringList(defaultKnowledgeExtensions())},
              })
        : knowledgeTool->execute(
              QStringLiteral("ui-knowledge-index-file"),
              QJsonObject{
                  {"action", "index_file"},
                  {"path", newAbs},
              });

    if (!result.isError)
        emit knowledgeSourcesChanged();
    else
        qWarning().noquote() << "[knowledge] reindex failed:" << result.content;
}

void AgentController::openEditorFile(const QString &filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QTextStream in(&f);
    const QString content = in.readAll();

    int index = -1;
    for (int i = 0; i < m_documents.size(); ++i) {
        if (m_documents[i].path == filePath) {
            index = i;
            break;
        }
    }

    if (index < 0) {
        EditorDocument doc;
        doc.path = filePath;
        doc.content = content;
        doc.savedContent = content;
        doc.dirty = false;
        m_documents.append(doc);
        index = m_documents.size() - 1;
        emit openFilesChanged();
    } else if (!m_documents[index].dirty && m_documents[index].savedContent != content) {
        m_documents[index].content = content;
        m_documents[index].savedContent = content;
    }

    qInfo().noquote() << QStringLiteral("[AgentController] openEditorFile -> path=%1 index=%2 contentLen=%3").arg(filePath).arg(index).arg(content.size());
    setCurrentEditorIndex(index);
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(filePath);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(filePath);
}

bool AgentController::createWorkspaceEntry(const QString &parentPath, const QString &name, bool directory)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString cleanName = QFileInfo(name.trimmed()).fileName();
    if (cleanName.isEmpty()) {
        emit errorOccurred(QStringLiteral("Name cannot be empty."));
        return false;
    }

    const QString absParent = QFileInfo(parentPath).isDir()
        ? QFileInfo(parentPath).absoluteFilePath()
        : QFileInfo(parentPath).absolutePath();
    if (!absParent.startsWith(m_workspacePath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    const QString absPath = QDir(absParent).filePath(cleanName);
    if (QFileInfo::exists(absPath)) {
        emit errorOccurred(QStringLiteral("Path already exists."));
        return false;
    }

    bool ok = false;
    if (directory) {
        ok = QDir().mkpath(absPath);
    } else {
        QSaveFile file(absPath);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            file.commit();
            ok = true;
        }
    }

    if (!ok) {
        emit errorOccurred(directory
                           ? QStringLiteral("Failed to create folder.")
                           : QStringLiteral("Failed to create file."));
        return false;
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();

    if (!directory)
        openEditorFile(absPath);

    m_lastWorkspaceActionType.clear();
    m_lastWorkspaceActionSource.clear();
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();

    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();
    return true;
}

bool AgentController::rollbackCheckpoint(const QString &checkpointId)
{
    auto *checkpointTool = qobject_cast<CheckpointTool *>(m_registry ? m_registry->tool("checkpoint") : nullptr);
    if (!checkpointTool) {
        emit errorOccurred(QStringLiteral("Checkpoint tool is not available."));
        return false;
    }

    const QString normalizedId = checkpointId.trimmed();
    if (normalizedId.isEmpty()) {
        emit errorOccurred(QStringLiteral("Checkpoint id cannot be empty."));
        return false;
    }

    const QVariantList affectedFiles = checkpointPreview(normalizedId);
    const QString affectedFilesSummary = summarizeCheckpointFiles(affectedFiles);

    const ToolResult result = checkpointTool->execute(
        QStringLiteral("ui-checkpoint-%1").arg(normalizedId),
        QJsonObject{
            {"action", "rollback"},
            {"checkpoint_id", normalizedId},
        });

    if (result.isError) {
        emit errorOccurred(result.content);
        return false;
    }

    QString detail = QStringLiteral("%1: %2").arg(result.name, result.content);
    if (!affectedFilesSummary.isEmpty())
        detail += QStringLiteral(" Restored %1.").arg(affectedFilesSummary);

    ChatMessage statusMsg;
    statusMsg.role = QStringLiteral("tool");
    statusMsg.content = detail;
    m_chatModel->append(statusMsg);

    appendSessionStoreMessage(QStringLiteral("tool"),
                              detail);
    saveTaskSession();
    emit recentCheckpointsChanged();

    QString successMessage = QStringLiteral("Restored checkpoint %1").arg(normalizedId);
    if (!affectedFilesSummary.isEmpty())
        successMessage += QStringLiteral(" (%1)").arg(affectedFilesSummary);
    successMessage += QStringLiteral(".");
    emit successOccurred(successMessage);
    return true;
}

bool AgentController::renameWorkspacePath(const QString &path, const QString &newName)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString absPath = QFileInfo(path).absoluteFilePath();
    if (!absPath.startsWith(m_workspacePath) || !QFileInfo::exists(absPath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    const QString cleanName = QFileInfo(newName.trimmed()).fileName();
    if (cleanName.isEmpty()) {
        emit errorOccurred(QStringLiteral("Name cannot be empty."));
        return false;
    }

    QFileInfo info(absPath);
    const QString parentPath = info.dir().absolutePath();
    const QString newAbsPath = QDir(parentPath).filePath(cleanName);
    if (newAbsPath == absPath)
        return true;
    if (QFileInfo::exists(newAbsPath)) {
        emit errorOccurred(QStringLiteral("Target already exists."));
        return false;
    }

    QDir parentDir(parentPath);
    const bool ok = parentDir.rename(info.fileName(), cleanName);
    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to rename path."));
        return false;
    }

    for (auto &doc : m_documents) {
        if (doc.path == absPath || doc.path.startsWith(absPath + "/")) {
            doc.path.replace(absPath, newAbsPath);
        }
    }

    if (m_currentFilePath == absPath || m_currentFilePath.startsWith(absPath + "/")) {
        m_currentFilePath.replace(absPath, newAbsPath);
        emit currentFilePathChanged();
    }

    if (m_currentEditorIndex >= 0 && m_currentEditorIndex < m_documents.size()) {
        m_currentFileContent = m_documents[m_currentEditorIndex].content;
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();

    emit openFilesChanged();
    syncKnowledgeForPathChange(absPath, newAbsPath, info.isDir());
    m_lastWorkspaceActionType.clear();
    m_lastWorkspaceActionSource.clear();
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();
    refreshSystemPrompt();
    saveSettings();
    saveTaskSession();
    return true;
}

bool AgentController::deleteWorkspacePath(const QString &path)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString absPath = QFileInfo(path).absoluteFilePath();
    if (!absPath.startsWith(m_workspacePath) || !QFileInfo::exists(absPath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    QFileInfo info(absPath);
    bool ok = false;
    if (info.isDir()) {
        QDir dir(absPath);
        ok = dir.removeRecursively();
    } else {
        ok = QFile::remove(absPath);
    }

    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to delete path."));
        return false;
    }

    for (int i = m_documents.size() - 1; i >= 0; --i) {
        if (m_documents[i].path == absPath || m_documents[i].path.startsWith(absPath + "/")) {
            m_documents.removeAt(i);
            if (i == m_currentEditorIndex)
                m_currentEditorIndex = -1;
            else if (i < m_currentEditorIndex)
                --m_currentEditorIndex;
        }
    }

    if (m_currentFilePath == absPath || m_currentFilePath.startsWith(absPath + "/")) {
        m_currentFilePath.clear();
        m_currentFileContent.clear();
        emit currentFilePathChanged();
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();
    emit openFilesChanged();
    syncKnowledgeForPathChange(absPath, QString{}, info.isDir());
    m_lastWorkspaceActionType = "delete";
    m_lastWorkspaceActionSource = absPath;
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();
    saveSettings();
    refreshSystemPrompt();
    saveTaskSession();
    return true;
}

bool AgentController::moveWorkspacePath(const QString &path, const QString &destinationDir)
{
    if (m_workspacePath.isEmpty())
        return false;

    const QString absPath = QFileInfo(path).absoluteFilePath();
    const QString absDestinationDir = QFileInfo(destinationDir).absoluteFilePath();
    if (!absPath.startsWith(m_workspacePath) || !absDestinationDir.startsWith(m_workspacePath)) {
        emit errorOccurred(QStringLiteral("Path is outside the workspace."));
        return false;
    }

    QFileInfo info(absPath);
    if (!info.exists()) {
        emit errorOccurred(QStringLiteral("Path does not exist."));
        return false;
    }

    QDir destDir(absDestinationDir);
    if (!destDir.exists()) {
        emit errorOccurred(QStringLiteral("Destination directory does not exist."));
        return false;
    }

    const QString newAbsPath = destDir.filePath(info.fileName());
    if (newAbsPath == absPath)
        return true;
    if (QFileInfo::exists(newAbsPath)) {
        emit errorOccurred(QStringLiteral("Target already exists."));
        return false;
    }

    const bool ok = info.isDir() ? QDir().rename(absPath, newAbsPath)
                                 : QFile::rename(absPath, newAbsPath);
    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to move path."));
        return false;
    }

    for (auto &doc : m_documents) {
        if (doc.path == absPath || doc.path.startsWith(absPath + "/")) {
            doc.path.replace(absPath, newAbsPath);
        }
    }

    if (m_currentFilePath == absPath || m_currentFilePath.startsWith(absPath + "/")) {
        m_currentFilePath.replace(absPath, newAbsPath);
        emit currentFilePathChanged();
    }

    if (m_currentEditorIndex >= 0 && m_currentEditorIndex < m_documents.size()) {
        m_currentFileContent = m_documents[m_currentEditorIndex].content;
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();
    emit openFilesChanged();
    syncKnowledgeForPathChange(absPath, newAbsPath, info.isDir());
    m_lastWorkspaceActionType = "move";
    m_lastWorkspaceActionSource = absPath;
    m_lastWorkspaceActionDestination = newAbsPath;
    emit undoWorkspaceActionChanged();
    saveSettings();
    refreshSystemPrompt();
    saveTaskSession();
    return true;
}

bool AgentController::undoLastWorkspaceAction()
{
    if (m_lastWorkspaceActionType != "move" || m_lastWorkspaceActionSource.isEmpty() || m_lastWorkspaceActionDestination.isEmpty())
        return false;

    const QString src = m_lastWorkspaceActionSource;
    const QString dest = m_lastWorkspaceActionDestination;
    if (!QFileInfo::exists(dest)) {
        emit errorOccurred(QStringLiteral("Nothing to undo."));
        return false;
    }

    QFileInfo info(dest);
    const bool ok = info.isDir() ? QDir().rename(dest, src)
                                 : QFile::rename(dest, src);
    if (!ok) {
        emit errorOccurred(QStringLiteral("Failed to undo move."));
        return false;
    }

    for (auto &doc : m_documents) {
        if (doc.path == dest || doc.path.startsWith(dest + "/")) {
            doc.path.replace(dest, src);
        }
    }

    if (m_currentFilePath == dest || m_currentFilePath.startsWith(dest + "/")) {
        m_currentFilePath.replace(dest, src);
        emit currentFilePathChanged();
    }

    if (m_currentEditorIndex >= 0 && m_currentEditorIndex < m_documents.size()) {
        m_currentFileContent = m_documents[m_currentEditorIndex].content;
        emit currentFileContentChanged();
    }

    if (m_workspaceIndex)
        m_workspaceIndex->refresh();
    emit openFilesChanged();

    m_lastWorkspaceActionType.clear();
    m_lastWorkspaceActionSource.clear();
    m_lastWorkspaceActionDestination.clear();
    emit undoWorkspaceActionChanged();
    saveSettings();
    refreshSystemPrompt();
    saveTaskSession();
    return true;
}

void AgentController::saveCurrentFile()
{
    if (m_currentEditorIndex < 0 || m_currentEditorIndex >= m_documents.size())
        return;

    auto &doc = m_documents[m_currentEditorIndex];
    if (doc.path.isEmpty())
        return;

    QSaveFile f(doc.path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return;

    QTextStream out(&f);
    out << doc.content;
    if (!f.commit())
        return;
    doc.savedContent = doc.content;
    doc.dirty = false;
    m_currentFileContent = doc.content;
    m_currentFilePath = doc.path;
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(doc.path);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(doc.path);
    emit openFilesChanged();
    emit currentFileContentChanged();
    saveSettings();
    saveTaskSession();

    if (auto *knowledgeTool = qobject_cast<KnowledgeTool *>(m_registry ? m_registry->tool("knowledge") : nullptr)) {
        const ToolResult result = knowledgeTool->execute(
            QStringLiteral("ui-knowledge-index-file"),
            QJsonObject{
                {"action", "index_file"},
                {"path", doc.path},
            });
        if (!result.isError) {
            emit knowledgeSourcesChanged();
        } else {
            qWarning().noquote() << "[knowledge] auto-index failed:" << result.content;
        }
    }
}

void AgentController::closeEditorTab(int index)
{
    closeEditorTabInternal(index, false);
}

void AgentController::forceCloseEditorTab(int index)
{
    closeEditorTabInternal(index, true);
}

void AgentController::closeEditorTabInternal(int index, bool allowDirtyClose)
{
    if (index < 0 || index >= m_documents.size())
        return;

    if (!allowDirtyClose && m_documents[index].dirty) {
        emit errorOccurred(QStringLiteral("Save the file before closing this tab."));
        return;
    }

    const bool closingCurrent = (index == m_currentEditorIndex);
    m_documents.removeAt(index);

    if (m_documents.isEmpty()) {
        m_currentEditorIndex = -1;
        const bool hadPath = !m_currentFilePath.isEmpty();
        const bool hadContent = !m_currentFileContent.isEmpty();
        m_currentFilePath.clear();
        m_currentFileContent.clear();
        if (hadPath) emit currentFilePathChanged();
        if (hadContent) emit currentFileContentChanged();
        emit currentEditorIndexChanged();
        emit openFilesChanged();
        saveSettings();
        refreshSystemPrompt();
        saveTaskSession();
        return;
    }

    if (closingCurrent) {
        const int nextIndex = std::min(index, static_cast<int>(m_documents.size()) - 1);
        m_currentEditorIndex = -1;
        emit openFilesChanged();
        setCurrentEditorIndex(nextIndex);
        return;
    }

    if (index < m_currentEditorIndex)
        --m_currentEditorIndex;

    emit openFilesChanged();
    emit currentEditorIndexChanged();
    saveSettings();
    saveTaskSession();
}

bool AgentController::autoApproveTools() const { return m_autoApproveTools; }
bool AgentController::canUndoWorkspaceAction() const
{
    return m_lastWorkspaceActionType == "move"
        && !m_lastWorkspaceActionSource.isEmpty()
        && !m_lastWorkspaceActionDestination.isEmpty();
}
void AgentController::setAutoApproveTools(bool v)
{
    if (m_autoApproveTools == v) return;
    m_autoApproveTools = v;
    m_engine->setAutoApproveTools(v);
    saveSettings();
    saveTaskSession();
    emit autoApproveToolsChanged();
}

void AgentController::setBusy(bool b)
{
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
}

void AgentController::sendMessage(const QString &text)
{
    if (text.trimmed().isEmpty()) return;
    qInfo().noquote() << "[agent] user message:" << logPreview(text);
    m_streamingText.clear();
    m_streamingAssistantActive = false;
    appendSessionStoreMessage(QStringLiteral("user"), text);
    m_engine->submitUserMessage(text);
    saveTaskSession();
}

void AgentController::injectFile(const QString &filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QTextStream in(&f);
    const QString content = in.readAll();
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(filePath);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(filePath);
    refreshSystemPrompt();
    m_engine->injectContext(filePath, content);
}

void AgentController::injectSelection(const QString &filePath, const QString &code,
                                      int startLine, int endLine)
{
    if (m_workspaceContext) m_workspaceContext->recordFileAccess(filePath);
    if (m_workspaceIndex)   m_workspaceIndex->recordFileAccess(filePath);
    refreshSystemPrompt();
    m_engine->injectContext(filePath, code, startLine, endLine);
}

void AgentController::interrupt()     { m_engine->interrupt(); }
void AgentController::clearHistory()
{
    m_engine->clearHistory();
    m_chatModel->clear();
    m_streamingAssistantActive = false;
    m_streamingText.clear();
    m_sessionId = TaskSessionStore::defaultSessionId();
    if (auto *store = qobject_cast<SessionStore *>(m_registry ? m_registry->tool("session_search") : nullptr))
        store->beginSession(m_workspacePath);
    saveTaskSession();
    emit recentSessionsChanged();
}
void AgentController::approveTool(const QString &callId) { m_engine->approveTool(callId, true); }
void AgentController::rejectTool(const QString &callId)  { m_engine->approveTool(callId, false); }

void AgentController::onTokenReceived(const TokenEvent &ev)
{
    if (ev.type == TokenEvent::Type::TextDelta) {
        if (!m_streamingAssistantActive) {
            ChatMessage cm;
            cm.role = "assistant";
            m_chatModel->append(cm);
            m_streamingAssistantActive = true;
        }
        m_streamingText += ev.delta;
        emit streamingTextChanged();
        m_chatModel->updateLastContent(ev.delta);
    }
}

void AgentController::onMessageAdded(const AgentMessage &msg)
{
    saveTaskSession();
    switch (msg.role) {
    case MessageRole::System:
        appendSessionStoreMessage(QStringLiteral("system"), msg.content);
        break;
    case MessageRole::User:
        break;
    case MessageRole::Assistant:
        appendSessionStoreMessage(QStringLiteral("assistant"), msg.content);
        break;
    case MessageRole::Tool:
        appendSessionStoreMessage(QStringLiteral("tool"), msg.content);
        break;
    }
    if (msg.role == MessageRole::Tool) return; // tool results shown as cards

    ChatMessage cm;
    switch (msg.role) {
    case MessageRole::User:      cm.role = "user";      break;
    case MessageRole::Assistant: cm.role = "assistant"; break;
    default:                     cm.role = "system";    break;
    }
    cm.content = msg.content;

    for (const auto &tc : msg.toolCalls) {
        QVariantMap card;
        card["id"]     = tc.id;
        card["name"]   = tc.name;
        card["status"] = "pending";
        card["args"]   = QJsonDocument(tc.arguments).toJson(QJsonDocument::Indented);
        cm.toolCalls.append(card);
    }

    if (msg.role == MessageRole::Assistant && m_streamingAssistantActive) {
        m_chatModel->replaceLast(cm);
        m_streamingAssistantActive = false;
    } else {
        m_chatModel->append(cm);
    }
}

void AgentController::onToolExecuting(const ToolCall &call)
{
    qInfo().noquote() << "[agent] tool executing:" << call.name
                      << "callId=" << call.id;
    QVariantMap card;
    card["id"]     = call.id;
    card["name"]   = call.name;
    card["status"] = "running";
    card["args"]   = QJsonDocument(call.arguments).toJson(QJsonDocument::Indented);
    m_chatModel->appendToolCallToLastAssistant(card);
}

void AgentController::onToolFinished(const ToolResult &result)
{
    appendSessionStoreMessage(QStringLiteral("tool"),
                              QStringLiteral("%1: %2").arg(result.name, result.content));
    qInfo().noquote() << "[agent] tool finished:" << result.name
                      << "callId=" << result.callId
                      << "status=" << (result.isError ? "error" : "done")
                      << "preview=" << logPreview(result.content);
    QVariantMap card;
    card["id"]     = result.callId;
    card["name"]   = result.name;
    card["status"] = result.isError ? "error" : "done";
    card["result"] = result.content;
    m_chatModel->updateToolCall(result.callId, card);

    if (!result.isError
        && (result.name == QStringLiteral("file_system")
            || result.name == QStringLiteral("patch")
            || result.name == QStringLiteral("checkpoint"))) {
        emit recentCheckpointsChanged();
    }
    m_runningToolOutput.remove(result.callId);
}

void AgentController::onToolOutputChunk(const QString &callId, const QString &chunk)
{
    m_runningToolOutput[callId] += chunk;
    QVariantMap card;
    card["id"]     = callId;
    card["status"] = "running";
    card["result"] = m_runningToolOutput.value(callId);
    m_chatModel->updateToolCall(callId, card);
}
