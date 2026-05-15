#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "bridge/AgentListModel.h"
#include "bridge/LogModel.h"
#include "bridge/neurx_bridge.h"

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("Neurx Qt Agent Shell");

    NeurxBridge bridge;
    AgentListModel agent_model;
    LogModel log_model;

    QObject::connect(&bridge, &NeurxBridge::runtime_status_changed,
        &agent_model, &AgentListModel::set_primary_agent_status);
    QObject::connect(&bridge, &NeurxBridge::log_message,
        &log_model, &LogModel::append);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Runtime", &bridge);
    engine.rootContext()->setContextProperty("AgentModel", &agent_model);
    engine.rootContext()->setContextProperty("LogModel", &log_model);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("neurx.qt", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
