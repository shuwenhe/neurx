#include "HookManager.h"
#include <QDebug>
#include <QFile>
#include <QJsonDocument>
#include <QTextStream>
#include <QDir>

// ── 构造和析构 ──────────────────────────────────────────────────────────────

HookManager::HookManager(QObject *parent)
    : QObject(parent)
{
    qInfo() << "[HookManager] Initialized";
}

HookManager::~HookManager()
{
    qInfo() << "[HookManager] Destroyed";
}

// ── Hook 注册和管理 ─────────────────────────────────────────────────────────

void HookManager::registerHook(const HookConfig& config)
{
    if (config.name.isEmpty()) {
        qWarning() << "[HookManager] Cannot register hook with empty name";
        return;
    }

    m_hooks[config.name] = config;
    m_hooksByType[config.type].append(config.name);

    qInfo() << "[HookManager] Registered hook:" << config.name 
            << "type:" << hookTypeToString(config.type)
            << "mode:" << (config.mode == HookMode::PromptBased ? "prompt" : "command");
}

void HookManager::unregisterHook(const QString& name)
{
    if (!m_hooks.contains(name)) {
        qWarning() << "[HookManager] Hook not found:" << name;
        return;
    }

    HookType type = m_hooks[name].type;
    m_hooksByType[type].removeAll(name);
    m_hooks.remove(name);

    qInfo() << "[HookManager] Unregistered hook:" << name;
}

void HookManager::setHookEnabled(const QString& name, bool enabled)
{
    if (!m_hooks.contains(name)) {
        qWarning() << "[HookManager] Hook not found:" << name;
        return;
    }

    m_hooks[name].enabled = enabled;
    qInfo() << "[HookManager] Hook" << name << (enabled ? "enabled" : "disabled");
}

QList<HookManager::HookConfig> HookManager::allHooks() const
{
    return m_hooks.values();
}

QList<HookManager::HookConfig> HookManager::hooksForType(HookType type) const
{
    QList<HookConfig> result;
    if (m_hooksByType.contains(type)) {
        for (const QString& name : m_hooksByType[type]) {
            if (m_hooks.contains(name)) {
                result.append(m_hooks[name]);
            }
        }
    }
    return result;
}

// ── Hook 执行 ───────────────────────────────────────────────────────────────

QList<HookManager::HookResult> HookManager::executeHooks(HookType type, const QJsonObject& context)
{
    QList<HookResult> results;
    
    QList<HookConfig> hooks = hooksForType(type);
    qInfo() << "[HookManager] Executing" << hooks.size() << "hooks for type:" << hookTypeToString(type);

    for (const HookConfig& hook : hooks) {
        if (!hook.enabled) {
            qDebug() << "[HookManager] Skipping disabled hook:" << hook.name;
            continue;
        }

        HookResult result = executeHook(hook, context);
        results.append(result);

        emit hookExecuted(type, hook.name, result);

        // 如果任何 hook 阻止操作，记录日志
        if (result.blockOperation) {
            qWarning() << "[HookManager] Hook" << hook.name << "blocked operation";
        }
    }

    return results;
}

HookManager::HookResult HookManager::executeHook(const HookConfig& hook, const QJsonObject& context)
{
    qDebug() << "[HookManager] Executing hook:" << hook.name;

    try {
        if (hook.mode == HookMode::PromptBased) {
            return executePromptHook(hook, context);
        } else {
            return executeCommandHook(hook, context);
        }
    } catch (const std::exception& e) {
        qCritical() << "[HookManager] Hook execution failed:" << hook.name << e.what();
        
        HookResult errorResult;
        errorResult.systemMessage = QString("Hook '%1' failed: %2").arg(hook.name, e.what());
        errorResult.blockOperation = false;  // 错误时不阻止操作
        
        emit hookError(hook.type, hook.name, e.what());
        
        return errorResult;
    }
}

// ── Prompt-based Hook 执行 ──────────────────────────────────────────────────

HookManager::HookResult HookManager::executePromptHook(const HookConfig& hook, const QJsonObject& context)
{
    qDebug() << "[HookManager] Executing prompt-based hook:" << hook.name;

    // TODO: 集成 LLM 进行决策
    // 这里需要：
    // 1. 将 hook.hookPrompt 和 context 发送给 LLM
    // 2. 解析 LLM 返回的 JSON 格式响应
    // 3. 提取 systemMessage, userMessage, blockOperation

    HookResult result;
    result.systemMessage = QString("⚠️ Prompt-based hook '%1' executed (LLM integration pending)").arg(hook.name);
    result.userMessage = "Hook evaluation requires LLM integration";
    result.blockOperation = false;

    qInfo() << "[HookManager] Prompt hook" << hook.name << "completed (stub)";
    
    return result;
}

// ── Command-based Hook 执行 ─────────────────────────────────────────────────

HookManager::HookResult HookManager::executeCommandHook(const HookConfig& hook, const QJsonObject& context)
{
    qDebug() << "[HookManager] Executing command-based hook:" << hook.name;

    HookResult result;

    // 准备命令
    QString command = expandVariables(hook.command, context);
    QStringList args = hook.args;
    for (QString& arg : args) {
        arg = expandVariables(arg, context);
    }

    // 执行命令
    QProcess process;
    if (!hook.workingDir.isEmpty()) {
        process.setWorkingDirectory(expandVariables(hook.workingDir, context));
    }

    // 传递 context 作为 stdin（JSON 格式）
    process.start(command, args);
    
    if (!process.waitForStarted(1000)) {
        QString error = QString("Failed to start command: %1").arg(process.errorString());
        qCritical() << "[HookManager]" << error;
        result.systemMessage = error;
        result.blockOperation = false;
        return result;
    }

    // 写入 context
    QJsonDocument doc(context);
    process.write(doc.toJson());
    process.closeWriteChannel();

    // 等待完成
    if (!process.waitForFinished(hook.timeout)) {
        qWarning() << "[HookManager] Hook timeout:" << hook.name;
        process.kill();
        result.systemMessage = QString("Hook '%1' timed out").arg(hook.name);
        result.blockOperation = false;
        return result;
    }

    // 读取输出
    result.exitCode = process.exitCode();
    QString output = QString::fromUtf8(process.readAllStandardOutput());
    QString errorOutput = QString::fromUtf8(process.readAllStandardError());

    if (!errorOutput.isEmpty()) {
        qWarning() << "[HookManager] Hook stderr:" << errorOutput;
    }

    // 解析输出（期望 JSON 格式）
    QJsonObject outputJson = parseHookOutput(output);
    
    result.systemMessage = outputJson.value("systemMessage").toString();
    result.userMessage = outputJson.value("userMessage").toString();
    result.blockOperation = outputJson.value("blockOperation").toBool(false);
    result.metadata = outputJson.value("metadata").toObject();

    qInfo() << "[HookManager] Command hook" << hook.name 
            << "completed with exit code:" << result.exitCode
            << "block:" << result.blockOperation;

    return result;
}

// ── 便捷方法 ────────────────────────────────────────────────────────────────

bool HookManager::shouldAllowToolUse(const QString& toolName, const QJsonObject& toolInput)
{
    QJsonObject context;
    context["tool_name"] = toolName;
    context["tool_input"] = toolInput;

    QList<HookResult> results = executeHooks(HookType::PreToolUse, context);

    // 如果任何 hook 阻止，返回 false
    for (const HookResult& result : results) {
        if (result.blockOperation) {
            qWarning() << "[HookManager] Tool use blocked for:" << toolName;
            return false;
        }
    }

    return true;
}

QString HookManager::getSessionStartPrompt()
{
    QJsonObject context;
    context["event"] = "session_start";

    QList<HookResult> results = executeHooks(HookType::SessionStart, context);

    QStringList prompts;
    for (const HookResult& result : results) {
        if (!result.systemMessage.isEmpty()) {
            prompts.append(result.systemMessage);
        }
    }

    return prompts.join("\n\n");
}

bool HookManager::shouldContinueSession(const QJsonObject& context)
{
    QList<HookResult> results = executeHooks(HookType::Stop, context);

    // 如果任何 hook 阻止退出，返回 true（继续会话）
    for (const HookResult& result : results) {
        if (result.blockOperation) {
            qInfo() << "[HookManager] Session exit blocked, continuing...";
            return true;
        }
    }

    return false;
}

// ── 辅助方法 ────────────────────────────────────────────────────────────────

QString HookManager::expandVariables(const QString& text, const QJsonObject& context)
{
    QString result = text;

    // 展开环境变量
    result.replace("${HOME}", QDir::homePath());
    result.replace("${PWD}", QDir::currentPath());

    // 展开 context 中的变量
    for (const QString& key : context.keys()) {
        QString placeholder = QString("${%1}").arg(key);
        QString value = context.value(key).toVariant().toString();
        result.replace(placeholder, value);
    }

    return result;
}

QJsonObject HookManager::parseHookOutput(const QString& output)
{
    // 尝试解析 JSON
    QJsonDocument doc = QJsonDocument::fromJson(output.toUtf8());
    
    if (!doc.isNull() && doc.isObject()) {
        return doc.object();
    }

    // 如果不是 JSON，构造一个简单的对象
    QJsonObject result;
    result["systemMessage"] = output.trimmed();
    result["blockOperation"] = false;
    
    return result;
}

// ── 辅助函数实现 ────────────────────────────────────────────────────────────

QString hookTypeToString(HookManager::HookType type)
{
    switch (type) {
        case HookManager::HookType::PreToolUse: return "PreToolUse";
        case HookManager::HookType::PostToolUse: return "PostToolUse";
        case HookManager::HookType::SessionStart: return "SessionStart";
        case HookManager::HookType::SessionEnd: return "SessionEnd";
        case HookManager::HookType::Stop: return "Stop";
        case HookManager::HookType::SubagentStop: return "SubagentStop";
        case HookManager::HookType::UserPromptSubmit: return "UserPromptSubmit";
        case HookManager::HookType::PreCompact: return "PreCompact";
        case HookManager::HookType::Notification: return "Notification";
        default: return "Unknown";
    }
}

HookManager::HookType hookTypeFromString(const QString& str)
{
    if (str == "PreToolUse") return HookManager::HookType::PreToolUse;
    if (str == "PostToolUse") return HookManager::HookType::PostToolUse;
    if (str == "SessionStart") return HookManager::HookType::SessionStart;
    if (str == "SessionEnd") return HookManager::HookType::SessionEnd;
    if (str == "Stop") return HookManager::HookType::Stop;
    if (str == "SubagentStop") return HookManager::HookType::SubagentStop;
    if (str == "UserPromptSubmit") return HookManager::HookType::UserPromptSubmit;
    if (str == "PreCompact") return HookManager::HookType::PreCompact;
    if (str == "Notification") return HookManager::HookType::Notification;
    
    qWarning() << "[HookManager] Unknown hook type:" << str;
    return HookManager::HookType::PreToolUse;
}

HookManager::HookConfig loadHookFromFile(const QString& filePath)
{
    // TODO: 实现 Markdown + YAML frontmatter 解析
    // 格式示例：
    // ---
    // name: security-check
    // type: PreToolUse
    // mode: command
    // command: /path/to/script.py
    // ---
    // 
    // Hook 描述（Markdown）
    
    HookManager::HookConfig config;
    config.name = QFileInfo(filePath).baseName();
    
    qInfo() << "[HookManager] Loading hook from file:" << filePath << "(stub)";
    
    return config;
}

bool saveHookToFile(const QString& filePath, const HookManager::HookConfig& config)
{
    // TODO: 实现保存为 Markdown + YAML frontmatter
    
    qInfo() << "[HookManager] Saving hook to file:" << filePath << "(stub)";
    
    return true;
}
