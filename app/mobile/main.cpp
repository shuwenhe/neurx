#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QFont>

#include "../bridge/AgentListModel.h"
#include "../bridge/LogModel.h"
#include "../bridge/neurx_bridge.h"

int main(int argc, char* argv[]) {
    QQuickStyle::setStyle("Material");
    QGuiApplication app(argc, argv);
    app.setApplicationName("NeurX Mobile");
    app.setOrganizationName("NeurX");

    QFont ui_font = app.font();
    ui_font.setPointSize(10);
    ui_font.setStyleHint(QFont::SansSerif);
    app.setFont(ui_font);

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
    engine.loadFromModule("neurx.mobile", "MobileMain");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
