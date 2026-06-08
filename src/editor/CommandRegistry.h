#ifndef COMMANDREGISTRY_H
#define COMMANDREGISTRY_H

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QList>
#include <QObject>
#include <functional>

/**
 * @class CommandRegistry
 * @brief VS Code编辑器命令注册与管理系统
 * 
 * 功能：
 * - 注册编辑器命令 (command id, handler, metadata)
 * - 管理快捷键绑定
 * - 支持命令参数验证
 * - 提供命令历史记录
 * - 快捷键冲突检测
 */

class CommandRegistry : public QObject
{
    Q_OBJECT

public:
    // 命令参数类型
    enum ParameterType {
        STRING,
        NUMBER,
        BOOLEAN,
        ARRAY,
        OBJECT
    };

    // 命令分类
    enum CommandCategory {
        Agent,           // Agent操作
        FileOperation,   // 文件操作
        GitOperation,    // Git操作
        Navigation,      // 导航
        Debug,           // 调试
        Custom           // 自定义
    };

    struct CommandParameter {
        QString name;
        ParameterType type;
        bool required;
        QString description;
        QJsonValue defaultValue;
    };

    struct KeyBinding {
        QString commandId;
        QString keyCombination;      // e.g., "Ctrl+Shift+A"
        QString when;                // e.g., "editorFocus"
        QString description;
        bool enabled;
    };

    struct RegisteredCommand {
        QString id;                  // e.g., "neurx.runAgent"
        QString title;
        QString description;
        CommandCategory category;
        QList<CommandParameter> parameters;
        QString icon;
        bool enabled;
        QString createdAt;
    };

    struct CommandExecution {
        QString commandId;
        QString executedAt;
        QString status;              // success, failed, cancelled
        QJsonObject result;
        QString error;
        qint64 executionTimeMs;
    };

    explicit CommandRegistry(QObject *parent = nullptr);
    ~CommandRegistry();

    // 命令注册
    void registerCommand(const QString &id,
                        const QString &title,
                        const QString &description,
                        CommandCategory category,
                        const QList<CommandParameter> &parameters = {});

    RegisteredCommand getCommand(const QString &id);
    QList<RegisteredCommand> listCommands();
    QList<RegisteredCommand> listCommandsByCategory(CommandCategory category);
    bool commandExists(const QString &id);

    // 快捷键管理
    void bindKey(const QString &commandId,
                const QString &keyCombination,
                const QString &when = "",
                const QString &description = "");
    
    void unbindKey(const QString &commandId);
    QList<KeyBinding> getKeyBindings(const QString &commandId = "");
    QString getCommandFromKey(const QString &keyCombination);
    bool isKeyConflict(const QString &keyCombination);
    QList<KeyBinding> getConflictingBindings(const QString &keyCombination);

    // 命令执行历史
    void recordExecution(const CommandExecution &execution);
    QList<CommandExecution> getExecutionHistory(const QString &commandId = "", int limit = 100);
    void clearExecutionHistory(const QString &commandId = "");

    // 命令搜索与过滤
    QList<RegisteredCommand> searchCommands(const QString &query);
    QList<RegisteredCommand> filterByCategory(CommandCategory category);
    QList<RegisteredCommand> getRecentCommands(int count = 10);

    // 导入/导出
    QJsonObject exportCommands();
    QJsonObject exportKeyBindings();
    void importCommands(const QJsonObject &data);
    void importKeyBindings(const QJsonObject &data);

    // 统计信息
    QJsonObject getStatistics();
    int getTotalCommandCount();
    int getExecutionCount(const QString &commandId);

    // 重置为默认
    void resetToDefaults();

signals:
    void commandRegistered(const QString &commandId);
    void commandExecuted(const QString &commandId, const QJsonObject &result);
    void commandFailed(const QString &commandId, const QString &error);
    void keyBindingAdded(const QString &commandId, const QString &keyCombination);
    void keyBindingRemoved(const QString &commandId);
    void keyConflictDetected(const QString &keyCombination);

private:
    QMap<QString, RegisteredCommand> m_commands;
    QMap<QString, KeyBinding> m_keyBindings;
    QList<CommandExecution> m_executionHistory;

    // 统计
    QMap<QString, int> m_executionStats;

    // 默认命令
    void initializeDefaultCommands();
};

#endif // COMMANDREGISTRY_H
