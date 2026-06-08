#pragma once

#include <QObject>
#include <QHash>
#include <QJsonObject>
#include <QJsonArray>
#include <QString>
#include <QProcess>

/**
 * @class HookManager
 * @brief 管理 Agent 生命周期中的各种 hooks
 * 
 * 实现类似 claude-code 的 hook 系统：
 * - PreToolUse: 工具调用前拦截（验证、警告、阻止）
 * - PostToolUse: 工具调用后处理
 * - SessionStart: 会话开始时注入上下文
 * - SessionEnd: 会话结束时清理
 * - Stop: 退出前拦截（用于自动循环）
 * - PreCompact: 上下文压缩前保存状态
 */
class HookManager : public QObject {
    Q_OBJECT

public:
    /**
     * @brief Hook 类型枚举
     */
    enum class HookType {
        PreToolUse,      ///< 工具调用前
        PostToolUse,     ///< 工具调用后
        SessionStart,    ///< 会话开始
        SessionEnd,      ///< 会话结束
        Stop,            ///< 退出前
        SubagentStop,    ///< 子 agent 停止
        UserPromptSubmit,///< 用户提交前
        PreCompact,      ///< 上下文压缩前
        Notification     ///< 通知事件
    };
    Q_ENUM(HookType)

    /**
     * @brief Hook 实现方式
     */
    enum class HookMode {
        PromptBased,     ///< 通过 LLM 决策（灵活、智能）
        CommandBased     ///< 通过脚本执行（确定性、快速）
    };
    Q_ENUM(HookMode)

    /**
     * @brief Hook 执行结果
     */
    struct HookResult {
        QString systemMessage;    ///< 显示给 Claude 的消息
        QString userMessage;      ///< 显示给用户的消息（可选）
        bool blockOperation;      ///< 是否阻止操作执行
        int exitCode;             ///< 脚本退出码（CommandBased）
        QJsonObject metadata;     ///< 额外元数据

        HookResult() : blockOperation(false), exitCode(0) {}
    };

    /**
     * @brief Hook 配置
     */
    struct HookConfig {
        QString name;             ///< Hook 名称
        HookType type;            ///< Hook 类型
        HookMode mode;            ///< 实现方式
        bool enabled;             ///< 是否启用
        
        // Prompt-based 配置
        QString hookPrompt;       ///< Hook 的系统提示
        bool requiresLLMDecision; ///< 是否需要 LLM 决策
        
        // Command-based 配置
        QString command;          ///< 执行的命令
        QStringList args;         ///< 命令参数
        QString workingDir;       ///< 工作目录
        int timeout;              ///< 超时时间（毫秒）
        
        HookConfig() : enabled(true), requiresLLMDecision(false), timeout(5000) {}
    };

    explicit HookManager(QObject *parent = nullptr);
    ~HookManager();

    // ── Hook 注册和管理 ────────────────────────────────────────────────────
    
    /**
     * @brief 注册一个 hook
     */
    void registerHook(const HookConfig& config);
    
    /**
     * @brief 注销 hook
     */
    void unregisterHook(const QString& name);
    
    /**
     * @brief 启用/禁用 hook
     */
    void setHookEnabled(const QString& name, bool enabled);
    
    /**
     * @brief 获取所有已注册的 hooks
     */
    QList<HookConfig> allHooks() const;
    
    /**
     * @brief 获取特定类型的 hooks
     */
    QList<HookConfig> hooksForType(HookType type) const;

    // ── Hook 执行 ──────────────────────────────────────────────────────────
    
    /**
     * @brief 执行指定类型的所有 hooks
     * @param type Hook 类型
     * @param context 上下文数据（JSON 格式）
     * @return Hook 执行结果列表
     */
    QList<HookResult> executeHooks(HookType type, const QJsonObject& context);
    
    /**
     * @brief 执行单个 hook
     */
    HookResult executeHook(const HookConfig& hook, const QJsonObject& context);

    // ── 便捷方法 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 工具调用前检查
     * @return 如果任何 hook 返回 blockOperation=true，则返回 false
     */
    bool shouldAllowToolUse(const QString& toolName, const QJsonObject& toolInput);
    
    /**
     * @brief 会话开始时注入的系统提示
     */
    QString getSessionStartPrompt();
    
    /**
     * @brief 检查是否应该阻止退出
     * @return 如果应该继续（不退出），返回 true
     */
    bool shouldContinueSession(const QJsonObject& context);

signals:
    /**
     * @brief Hook 执行完成
     */
    void hookExecuted(HookType type, const QString& hookName, const HookResult& result);
    
    /**
     * @brief Hook 执行出错
     */
    void hookError(HookType type, const QString& hookName, const QString& error);

private:
    // ── Prompt-based Hook 执行 ─────────────────────────────────────────────
    HookResult executePromptHook(const HookConfig& hook, const QJsonObject& context);
    
    // ── Command-based Hook 执行 ────────────────────────────────────────────
    HookResult executeCommandHook(const HookConfig& hook, const QJsonObject& context);
    
    // ── 辅助方法 ────────────────────────────────────────────────────────────
    QString expandVariables(const QString& text, const QJsonObject& context);
    QJsonObject parseHookOutput(const QString& output);
    
    // ── 数据成员 ────────────────────────────────────────────────────────────
    QHash<QString, HookConfig> m_hooks;           ///< 已注册的 hooks
    QHash<HookType, QStringList> m_hooksByType;  ///< 按类型索引的 hooks
};

// ── 辅助函数 ────────────────────────────────────────────────────────────────

/**
 * @brief 将 HookType 转换为字符串
 */
QString hookTypeToString(HookManager::HookType type);

/**
 * @brief 从字符串解析 HookType
 */
HookManager::HookType hookTypeFromString(const QString& str);

/**
 * @brief 加载 hook 配置文件（Markdown + YAML frontmatter）
 */
HookManager::HookConfig loadHookFromFile(const QString& filePath);

/**
 * @brief 保存 hook 配置到文件
 */
bool saveHookToFile(const QString& filePath, const HookManager::HookConfig& config);
