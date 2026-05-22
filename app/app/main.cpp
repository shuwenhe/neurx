#include <QGuiApplication>
#include <QQuickStyle>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QFont>

#include "bridge/AgentListModel.h"
#include "bridge/LogModel.h"
#include "bridge/neurx_bridge.h"

int main(int argc, char* argv[]) {
    QQuickStyle::setStyle("Fusion");
    QGuiApplication app(argc, argv);
    app.setApplicationName("Neurx App Shell");
    QFont ui_font(QStringLiteral("Segoe UI"), 10);
    ui_font.setStyleHint(QFont::SansSerif);
    ui_font.setStyleStrategy(QFont::PreferOutline);
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

    engine.load(QUrl(QStringLiteral("qrc:/neurx/app/qml/Main.qml")));

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
