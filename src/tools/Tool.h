#ifndef NEURX_TOOLS_TOOL_H
#define NEURX_TOOLS_TOOL_H

#include <QObject>
#include <QJsonObject>

#if defined(__has_include)
  #if __has_include("agent/BaseTool.h")
    #include "agent/BaseTool.h"
  #elif __has_include("agent/AgentToolRegistry.h")
    /* AgentToolRegistry 可能定义 BaseTool 类型或需要它—包含以便可用 */
    #include "agent/AgentToolRegistry.h"
  #elif __has_include("tools/BaseTool.h")
    #include "tools/BaseTool.h"
  #endif
#endif

// 如果上面的包含没有带来 Tool / BaseTool 定义，则在此提供最小替代
#ifndef NEURX_HAS_TOOL_BASE
class Tool : public QObject
{
    Q_OBJECT
public:
    explicit Tool(QObject *parent = nullptr) : QObject(parent) {}
    virtual QString name() const = 0;
    virtual QString description() const { return {}; }
    virtual QJsonObject schema() const { return QJsonObject(); }
    // run: args -> QJsonObject result (must be implemented)
    virtual QJsonObject run(const QJsonObject &args) = 0;
};
#define NEURX_HAS_TOOL_BASE 1
#endif

#endif // NEURX_TOOLS_TOOL_H

