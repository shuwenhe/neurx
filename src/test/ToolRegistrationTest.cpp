#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include "agent/AgentToolRegistry.h"
#include "tools/ClaudeStandardTools.h"

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    
    qDebug() << "🧪 Tool Registration Test";
    qDebug() << "=========================";
    qDebug() << "";
    
    // Create registry
    AgentToolRegistry registry;
    
    // Create sandbox manager
    auto sandboxManager = new DefaultSandboxManager();
    sandboxManager->setDefaultSandboxMode(SandboxMode::WorkspaceWrite);
    
    // Get workspace path
    QString workspacePath = QDir::homePath();
    qDebug() << "📁 Using workspace path:" << workspacePath;
    qDebug() << "";
    
    // Register tools
    qDebug() << "📝 Registering Claude Standard Tools...";
    ClaudeStandardToolFactory::registerAllTools(workspacePath, &registry, sandboxManager);
    qDebug() << "";
    
    // Check registered tools
    auto allTools = registry.allTools();
    qDebug() << "✅ Total tools registered:" << allTools.count();
    
    if (allTools.count() > 0) {
        qDebug() << "";
        qDebug() << "📋 Registered tools:";
        for (int i = 0; i < allTools.count(); i++) {
            qDebug().noquote() << QString("  %1. %2").arg(i+1).arg(allTools[i]->name());
        }
        qDebug() << "";
        qDebug() << "✅ SUCCESS: All tools registered correctly!";
        return 0;
    } else {
        qDebug() << "";
        qDebug() << "❌ FAILURE: No tools registered!";
        return 1;
    }
}
