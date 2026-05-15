#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "bridge/neurx_bridge.h"

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("Neurx Qt Agent Shell");

    NeurxBridge bridge;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Runtime", &bridge);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("neurx.qt", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
