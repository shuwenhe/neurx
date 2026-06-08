#ifndef EDITORCOMMANDMANAGER_H
#define EDITORCOMMANDMANAGER_H

#include "agent/AgentToolRegistry.h"
#include "CommandRegistry.h"
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <functional>

/**
 * @class EditorCommandManager
 * @brief 编辑器命令执行与管理系统
 * 
 * 继承自BaseTool，作为Agent工具使用
 * 功能：
 * - 执行已注册的编辑器命令
 * - 管理命令快捷键
 * - 提供命令搜索与发现
 * - 处理命令参数验证
 * - 记录命令执行结果
 */

class EditorCommandManager : public BaseTool
{
    Q_OBJECT

public:
    using CommandHandler = std::function<QJsonObject(const QJsonObject &)>;

    explicit EditorCommandManager(QObject *parent = nullptr);
    ~EditorCommandManager() override;

    // BaseTool接口实现
    QString name() const override { return "EditorCommandManager"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

    // 命令执行
    QJsonObject executeCommand(const QString &commandId, const QJsonObject &parameters = {});
    
    // 注册命令处理器
    void registerHandler(const QString &commandId, CommandHandler handler);
    
    // 获取命令信息
    CommandRegistry::RegisteredCommand getCommand(const QString &commandId);
    QList<CommandRegistry::RegisteredCommand> listAllCommands();
    QList<CommandRegistry::RegisteredCommand> searchCommands(const QString &query);
    
    // 快捷键管理
    void bindKey(const QString &commandId, const QString &keyCombination);
    QString getCommandFromKey(const QString &keyCombination);
    QList<CommandRegistry::KeyBinding> getKeyBindings();
    
    // 获取命令注册表
    CommandRegistry *getRegistry() { return m_registry; }

signals:
    void commandExecuted(const QString &commandId, const QJsonObject &result);
    void commandFailed(const QString &commandId, const QString &error);
    void commandParametersMissing(const QString &commandId, const QStringList &missing);

private:
    CommandRegistry *m_registry;
    QMap<QString, CommandHandler> m_handlers;
    
    // 内置命令处理器
    void registerBuiltinHandlers();
    
    // 处理特定类型的命令
    QJsonObject handleAgentCommand(const QString &commandId, const QJsonObject &params);
    QJsonObject handleFileCommand(const QString &commandId, const QJsonObject &params);
    QJsonObject handleGitCommand(const QString &commandId, const QJsonObject &params);
    QJsonObject handleNavigationCommand(const QString &commandId, const QJsonObject &params);
    QJsonObject handleDebugCommand(const QString &commandId, const QJsonObject &params);
    
    // 参数验证
    bool validateParameters(const QString &commandId, const QJsonObject &params, QStringList &missing);
    
    // 工具栏命令
    QJsonObject executeListCommands(const QJsonObject &params);
    QJsonObject executeSearchCommands(const QJsonObject &params);
    QJsonObject executeGetKeyBindings(const QJsonObject &params);
    QJsonObject executeBindKey(const QJsonObject &params);
    QJsonObject executeGetHistory(const QJsonObject &params);
};

#endif // EDITORCOMMANDMANAGER_H
